#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -LR zsh
setopt errexit nounset pipefail

typeset project_root="${0:A:h:h}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-version-test.XXXXXXXX")"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

fail() {
  print -u2 "not ok - $1"
  exit 1
}

run_case() {
  local label="$1" checkout="$2" expected="$3"
  local case_root="${temp_root}/${label}"
  command mkdir -p \
    "${case_root}/home" \
    "${case_root}/cache" \
    "${case_root}/config" \
    "${case_root}/data" \
    "${case_root}/zdotdir"

  env \
    HOME="${case_root}/home" \
    XDG_CACHE_HOME="${case_root}/cache" \
    XDG_CONFIG_HOME="${case_root}/config" \
    XDG_DATA_HOME="${case_root}/data" \
    ZDOTDIR="${case_root}/zdotdir" \
    ZI_TEST_CHECKOUT="$checkout" \
    ZI_TEST_EXPECTED="$expected" \
    zsh -f <<'ZSH' || fail "$label"
builtin emulate -LR zsh
setopt errexit pipefail

typeset -gAH ZI
ZI[BIN_DIR]="$ZI_TEST_CHECKOUT"
builtin source "${ZI[BIN_DIR]}/zi.zsh"

if [[ ${ZI[VERSION]} != "$ZI_TEST_EXPECTED" ]]; then
  print -u2 -r -- "expected ZI[VERSION] '$ZI_TEST_EXPECTED', got '${ZI[VERSION]}'"
  return 1
fi

typeset argument output
for argument in version --version -V; do
  output="$(zi "$argument")"
  if [[ $output != *"Zi version: ${ZI_TEST_EXPECTED}"* ]]; then
    print -u2 -r -- "expected '$argument' to report '$ZI_TEST_EXPECTED', got '${(q)output}'"
    return 1
  fi
done
ZSH

  print "ok - ${label}"
}

typeset untagged_checkout="${temp_root}/untagged-checkout"
command git clone -q --no-hardlinks "$project_root" "$untagged_checkout"
command git -C "$untagged_checkout" config user.name "Version Test"
command git -C "$untagged_checkout" config user.email "version-test@example.invalid"
command git -C "$untagged_checkout" commit -qm "test: create untagged fixture" --allow-empty
typeset untagged_version
untagged_version="$(command git -C "$untagged_checkout" rev-parse --short HEAD)"
run_case untagged "$untagged_checkout" "$untagged_version"

typeset tagged_checkout="${temp_root}/tagged-checkout"
command git clone -q --no-hardlinks "$project_root" "$tagged_checkout"
command git -C "$tagged_checkout" config user.name "Version Test"
command git -C "$tagged_checkout" config user.email "version-test@example.invalid"
command git -C "$tagged_checkout" commit -qm "test: create tagged fixture" --allow-empty
command git -C "$tagged_checkout" tag zi-version-test
run_case tagged "$tagged_checkout" zi-version-test

typeset archive_checkout="${temp_root}/archive-checkout"
command mkdir -p "$archive_checkout"
command git -C "$project_root" archive HEAD | command tar -x -C "$archive_checkout"
run_case archive "$archive_checkout" unknown
