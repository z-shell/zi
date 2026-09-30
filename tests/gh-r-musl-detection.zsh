#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
# Verify that gh-r asset selection does not depend on whether curl is
# installed (z-shell/zi#576), without network access or caller state.
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

# A release that publishes both a glibc and a musl build for this machine.
typeset gnu_asset=/owner/tool/releases/download/v1/tool-${CPUTYPE:-x86_64}-unknown-linux-gnu.tar.gz
typeset musl_asset=/owner/tool/releases/download/v1/tool-${CPUTYPE:-x86_64}-unknown-linux-musl.tar.gz
.zi-download-file-stdout() {
  print -r -- "<a href=\"$gnu_asset\">gnu</a>"
  print -r -- "<a href=\"$musl_asset\">musl</a>"
}
typeset -gA ICE=( ver v1 )

# pick_with_curl 0|1: the asset chosen with curl absent or present. The
# function also runs grep, find and uname, so each case gets a PATH holding
# only those, plus a curl for the second case.
pick_with_curl() {
  local bin=$temp_root/bin$1 tool
  command mkdir -p -- "$bin" || return 1
  for tool in grep find uname; do
    command ln -sf -- "${commands[$tool]:?$tool not found}" "$bin/$tool" || return 1
  done
  if (( $1 )); then
    print -r -- '#!/bin/sh' > "$bin/curl" && command chmod +x -- "$bin/curl" || return 1
  fi
  (
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

# On a host without musl in /lib, the glibc build must win.
typeset -a musl_libs=( /lib/*musl*(N) )
if (( ! $#musl_libs )) && [[ $OSTYPE == linux* ]]; then
  [[ $with_curl == $gnu_asset ]] || {
    print -u2 -r -- "not ok - glibc host chose $with_curl instead of $gnu_asset"
    exit 1
  }
fi
print -r -- 'ok - gh-r musl detection is independent of curl'
