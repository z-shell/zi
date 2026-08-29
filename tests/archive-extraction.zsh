#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -LR zsh

typeset project_root="${0:A:h:h}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-archive-test.XXXXXXXX")" || exit 1
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

fail() {
  builtin emulate -L zsh
  print -u2 -r -- "not ok - $1"
  exit 1
}

pass() {
  builtin emulate -L zsh
  print -r -- "ok - $1"
}

for dependency in file tar zip; do
  (( ${+commands[$dependency]} )) || fail "missing test dependency: $dependency"
done

prepare_unzip() {
  builtin emulate -L zsh
  if (( ${+commands[unzip]} )); then
    return 0
  fi
  (( ${+commands[bsdtar]} )) || fail "missing test dependency: unzip"

  typeset shim_dir="${temp_root}/unzip-shim"
  command mkdir -p -- "$shim_dir" || fail "create unzip shim directory"
  {
    print -r -- '#!/bin/sh'
    print -r -- 'if [ "$1" = "-Z1" ]; then exec bsdtar -tf "$2"; fi'
    print -r -- 'exec bsdtar -xf "$2"'
  } >| "${shim_dir}/unzip" || fail "write unzip shim"
  command chmod +x -- "${shim_dir}/unzip" || fail "make unzip shim executable"
  path=( "$shim_dir" "${path[@]}" )
  rehash
}

new_fixture() {
  builtin emulate -L zsh
  typeset label="$1"
  REPLY="${temp_root}/${label}"
  command mkdir -p -- \
    "$REPLY/home" \
    "$REPLY/zdot" \
    "$REPLY/data" \
    "$REPLY/cache" \
    "$REPLY/config" \
    "$REPLY/one" \
    "$REPLY/two" \
    "$REPLY/staging" \
    "$REPLY/work" || fail "create $label fixture directories"

  print -r -- one >| "$REPLY/one/one.txt" || fail "write first payload"
  print -r -- two >| "$REPLY/two/two.txt" || fail "write second payload"
  print -r -- one >| "$REPLY/one/order.txt" || fail "write first ordered payload"
  print -r -- two >| "$REPLY/two/order.txt" || fail "write second ordered payload"
  command tar -cf "$REPLY/staging/one.tar" -C "$REPLY/one" . || fail "create first nested archive"
  command tar -cf "$REPLY/staging/two.tar" -C "$REPLY/two" . || fail "create second nested archive"
  (
    builtin cd -- "$REPLY/staging" || exit 1
    command zip -q "$REPLY/work/outer.bin" one.tar two.tar
  ) || fail "create outer archive"
}

load_zi() {
  builtin emulate -L zsh
  typeset fixture_root="$1"
  typeset -gx HOME="$fixture_root/home"
  typeset -gx ZDOTDIR="$fixture_root/zdot"
  typeset -gx XDG_DATA_HOME="$fixture_root/data"
  typeset -gx XDG_CACHE_HOME="$fixture_root/cache"
  typeset -gx XDG_CONFIG_HOME="$fixture_root/config"
  typeset -gAH ZI OPTS
  ZI[BIN_DIR]="$project_root"
  builtin source "$project_root/zi.zsh" >/dev/null || fail "source Zi"
  builtin source "$project_root/lib/zsh/install.zsh" >/dev/null || fail "source install library"
}

prepare_unzip

# Every nested archive is extracted before the outer archive is removed.
(
  new_fixture success
  typeset fixture_root="$REPLY"
  load_zi "$fixture_root"
  builtin cd -- "$fixture_root/work" || fail "enter success fixture"

  ziextract --auto >/dev/null || fail "extract nested archives"
  [[ -f one.txt ]] || fail "extract first nested payload"
  [[ -f two.txt ]] || fail "extract second nested payload"
  [[ $(<order.txt) = two ]] || fail "extract nested archives in lexical order"
  [[ ! -e outer.bin ]] || fail "remove outer archive after success"
  [[ ! -e ._backup/two.tar ]] || fail "do not back up a nested sibling"
) || exit 1
pass "extract every nested archive"

# A nested failure leaves the outer archive available for retry.
(
  new_fixture failure
  typeset fixture_root="$REPLY"
  typeset real_tar="${commands[tar]}"
  typeset shim_dir="$fixture_root/tar-shim"
  command mkdir -p -- "$shim_dir" || fail "create tar shim directory"
  {
    print -r -- '#!/bin/sh'
    print -r -- 'case "$2" in two.tar|*/two.tar) [ "$1" = "-xf" ] && exit 42;; esac'
    print -r -- "exec ${(q)real_tar} \"\$@\""
  } >| "$shim_dir/tar" || fail "write tar shim"
  command chmod +x -- "$shim_dir/tar" || fail "make tar shim executable"

  load_zi "$fixture_root"
  path=( "$shim_dir" "${path[@]}" )
  rehash
  builtin cd -- "$fixture_root/work" || fail "enter failure fixture"

  if ziextract --auto >/dev/null 2>&1; then
    fail "nested extraction failure returns nonzero"
  fi
  [[ -f outer.bin ]] || fail "preserve outer archive after failure"
  [[ -f two.tar ]] || fail "preserve failed nested archive"
  [[ ! -e ._backup/two.tar ]] || fail "do not back up failed nested archive"
) || exit 1
pass "preserve outer archive after nested failure"

# Member paths are rejected before extraction when they can escape the target.
(
  new_fixture traversal
  typeset fixture_root="$REPLY"
  print -r -- escaped >| "$fixture_root/staging/payload" || fail "write traversal payload"
  if (( ${+commands[bsdtar]} )); then
    command bsdtar -cf "$fixture_root/work/traversal.tar" \
      -s '|^payload$|../escaped.txt|' -C "$fixture_root/staging" payload || fail "create traversal archive"
  else
    command tar -cf "$fixture_root/work/traversal.tar" \
      --transform='s|^payload$|../escaped.txt|' -C "$fixture_root/staging" payload || fail "create traversal archive"
  fi
  load_zi "$fixture_root"
  builtin cd -- "$fixture_root/work" || fail "enter traversal fixture"

  if ziextract traversal.tar --nobkp >/dev/null 2>&1; then
    fail "traversal archive reports success"
  fi
  [[ -f traversal.tar ]] || fail "preserve rejected traversal archive"
  [[ ! -e "$fixture_root/escaped.txt" ]] || fail "write traversal member outside target"
) || exit 1
pass "reject archive member traversal"

# Promotion rejects an existing destination symlink instead of writing through it.
(
  new_fixture symlink-target
  typeset fixture_root="$REPLY"
  command mkdir -p -- "$fixture_root/staging/link" "$fixture_root/external" || fail "create symlink target fixture"
  print -r -- unsafe >| "$fixture_root/staging/link/payload.txt" || fail "write symlink target payload"
  command tar -cf "$fixture_root/work/target.tar" -C "$fixture_root/staging" link || fail "create symlink target archive"
  command ln -s -- "$fixture_root/external" "$fixture_root/work/link" || fail "create destination symlink"
  load_zi "$fixture_root"
  builtin cd -- "$fixture_root/work" || fail "enter symlink target fixture"

  if ziextract target.tar --nobkp >/dev/null 2>&1; then
    fail "unsafe destination target reports success"
  fi
  [[ -L link ]] || fail "replace destination symlink"
  [[ ! -e "$fixture_root/external/payload.txt" ]] || fail "write through destination symlink"
  [[ -f target.tar ]] || fail "preserve archive rejected for unsafe target"
) || exit 1
pass "reject unsafe destination symlinks"

# Relative links that remain inside the extracted tree retain archive behavior.
(
  new_fixture safe-archive-link
  typeset fixture_root="$REPLY"
  print -r -- safe >| "$fixture_root/staging/payload.txt" || fail "write safe linked payload"
  command ln -s -- payload.txt "$fixture_root/staging/linked.txt" || fail "create safe archive symlink"
  command tar -cf "$fixture_root/work/safe-link.tar" -C "$fixture_root/staging" payload.txt linked.txt || \
    fail "create safe archive link fixture"
  load_zi "$fixture_root"
  builtin cd -- "$fixture_root/work" || fail "enter safe archive link fixture"

  ziextract safe-link.tar --nobkp >/dev/null || fail "extract safe archive symlink"
  [[ -L linked.txt && $(<linked.txt) = safe ]] || fail "preserve safe archive symlink"
) || exit 1
pass "preserve safe archive symlinks"

# Links escaping the staged tree are rejected before any result is promoted.
(
  new_fixture unsafe-archive-link
  typeset fixture_root="$REPLY"
  command ln -s -- "$fixture_root/external" "$fixture_root/staging/linked" || fail "create unsafe archive symlink"
  command tar -cf "$fixture_root/work/unsafe-link.tar" -C "$fixture_root/staging" linked || \
    fail "create unsafe archive link fixture"
  load_zi "$fixture_root"
  builtin cd -- "$fixture_root/work" || fail "enter unsafe archive link fixture"

  if ziextract unsafe-link.tar --nobkp >/dev/null 2>&1; then
    fail "escaping archive symlink reports success"
  fi
  [[ ! -e linked && ! -L linked ]] || fail "promote escaping archive symlink"
  [[ -f unsafe-link.tar ]] || fail "preserve archive containing escaping symlink"
) || exit 1
pass "reject escaping archive symlinks"
