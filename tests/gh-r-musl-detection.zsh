#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# Verify gh-r musl detection (z-shell/zi#576) without network access or
# caller state: it looks for the musl loader, and does not depend on
# whether curl is installed.
builtin emulate -R zsh
setopt pipe_fail

typeset project_root=${0:A:h:h}
typeset temp_root=$(command mktemp -d "${TMPDIR:-/tmp}/zi-gh-r-musl.XXXXXXXX") || exit 1
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM
export HOME=$temp_root/home ZDOTDIR=$temp_root/home TMPDIR=$temp_root/tmp
command mkdir -p -- "$HOME" "$TMPDIR" || exit 1
typeset -gA ZI=( HOME_DIR $temp_root/data CACHE_DIR $temp_root/cache CONFIG_DIR $temp_root/config )
typeset -gx ZPFX=$temp_root/prefix
source "$project_root/zi.zsh" || exit 1
builtin source "$project_root/lib/zsh/install.zsh" >/dev/null || { print -u2 -r -- 'not ok - source install library'; exit 1; }

# Detection: a directory with the loader is musl; a musl toolchain
# directory or an empty directory is not.
typeset lib_musl=$temp_root/lib-musl lib_toolchain=$temp_root/lib-toolchain lib_empty=$temp_root/lib-empty
command mkdir -p -- "$lib_musl" "$lib_toolchain/musl" "$lib_empty" || exit 1
: > "$lib_musl/ld-musl-${CPUTYPE:-x86_64}.so.1" || exit 1
.zi-has-musl-loader "$lib_musl" || { print -u2 -r -- 'not ok - a musl loader was not detected'; exit 1; }
if .zi-has-musl-loader "$lib_toolchain"; then
  print -u2 -r -- 'not ok - a musl toolchain directory was taken for a musl host'
  exit 1
fi
if .zi-has-musl-loader "$lib_empty"; then
  print -u2 -r -- 'not ok - an empty directory was taken for a musl host'
  exit 1
fi

# A release that publishes both a glibc and a musl build for this machine.
typeset gnu_asset=/owner/tool/releases/download/v1/tool-${CPUTYPE:-x86_64}-unknown-linux-gnu.tar.gz
typeset musl_asset=/owner/tool/releases/download/v1/tool-${CPUTYPE:-x86_64}-unknown-linux-musl.tar.gz
.zi-download-file-stdout() {
  print -r -- "<a href=\"$gnu_asset\">gnu</a>"
  print -r -- "<a href=\"$musl_asset\">musl</a>"
}
typeset -gA ICE=( ver v1 )

# pick_with_curl 0|1 [musl]: the asset chosen with curl absent or present.
# The function runs grep and uname, so each case gets a PATH holding only
# those, plus a curl for the second case. With "musl", the host is taken
# to have a musl loader.
pick_with_curl() {
  local bin=$temp_root/bin$1 tool
  command mkdir -p -- "$bin" || return 1
  for tool in grep uname; do
    command ln -sf -- "${commands[$tool]:?$tool not found}" "$bin/$tool" || return 1
  done
  if (( $1 )); then
    print -r -- '#!/bin/sh' > "$bin/curl" && command chmod +x -- "$bin/curl" || return 1
  fi
  (
    [[ $2 == musl ]] && .zi-has-musl-loader() { return 0; }
    path=( $bin )
    builtin hash -r
    reply=()
    .zi-get-latest-gh-r-url-part owner tool >/dev/null 2>&1 || exit 1
    print -r -- $reply[1]
  )
}

typeset without_curl with_curl
without_curl=$(pick_with_curl 0) || { print -u2 -r -- 'not ok - no asset chosen without curl'; exit 1; }
with_curl=$(pick_with_curl 1) || { print -u2 -r -- 'not ok - no asset chosen with curl'; exit 1; }

[[ $with_curl == $without_curl ]] || {
  print -u2 -r -- "not ok - installing curl changed the chosen asset: $without_curl -> $with_curl"
  exit 1
}

# On a Linux host without a musl loader, the musl preference must not
# apply, so the musl build is not chosen over the glibc build listed
# first. Which of two matching builds wins otherwise is the asset order;
# this test does not claim that glibc is actively preferred.
if [[ $OSTYPE == linux* ]] && ! .zi-has-musl-loader /lib; then
  [[ $with_curl == $gnu_asset ]] || {
    print -u2 -r -- "not ok - a host without a musl loader chose $with_curl instead of $gnu_asset"
    exit 1
  }
fi

# On a musl host the musl build wins even when the glibc build is listed
# first, so the detection result reaches the asset filter.
typeset on_musl
on_musl=$(pick_with_curl 0 musl) || { print -u2 -r -- 'not ok - no asset chosen on a musl host'; exit 1; }
[[ $on_musl == $musl_asset ]] || {
  print -u2 -r -- "not ok - a musl host chose $on_musl instead of $musl_asset"
  exit 1
}
print -r -- 'ok - gh-r musl detection looks for the loader and ignores curl'
