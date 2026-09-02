#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -R zsh
setopt pipe_fail

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-nested-load-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/inner" \
  "${temp_root}/plugin" \
  "${temp_root}/cloneonly" \
  "${temp_root}/snippetter" || fail "create isolated environment"

builtin print -r -- ':' \
  > "${temp_root}/inner/inner.plugin.zsh" || fail "write inner plug-in"
builtin print -r -- ':' \
  > "${temp_root}/inner/snippet.zsh" || fail "write inner snippet"

# Each outer plug-in records the current plug-in before and after a nested load
# of one shape, so the assertions can run outside the load.
record() {  # record <plug-in directory> <nested load command>
  builtin print -rl -- \
    'builtin print -r -- "before ${ZI[CUR_USPL2]}" >> $ZI_TEST_LOG' \
    "$2" \
    'builtin print -r -- "after ${ZI[CUR_USPL2]}" >> $ZI_TEST_LOG' \
    > "${temp_root}/${1}/${1}.plugin.zsh" || fail "write ${1} plug-in"
}
record plugin     'zi light $ZI_TEST_ROOT/inner >/dev/null 2>&1'
record cloneonly  'zi ice cloneonly; zi light $ZI_TEST_ROOT/inner >/dev/null 2>&1'
record snippetter 'zi snippet $ZI_TEST_ROOT/inner/snippet.zsh >/dev/null 2>&1'

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  ZI_TEST_ROOT="$temp_root" \
  ZI_TEST_LOG="${temp_root}/log" \
  zsh -f <<'ZSH' || fail "a nested load does not restore the enclosing plug-in"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

typeset shape
for shape ( plugin cloneonly snippetter ) {
  : > "$ZI_TEST_LOG"
  zi light "${ZI_TEST_ROOT}/${shape}" >/dev/null 2>&1
  typeset -a lines
  lines=( ${(f)"$(<$ZI_TEST_LOG)"} )
  [[ ${lines[1]} == "before %${ZI_TEST_ROOT}/${shape}" ]] || {
    builtin print -u2 -r -- "${shape}: unexpected state before the nested load: ${lines[1]}"
    return 1
  }
  [[ ${lines[2]} == "after %${ZI_TEST_ROOT}/${shape}" ]] || {
    builtin print -u2 -r -- "${shape}: the nested load did not restore the enclosing plug-in: ${lines[2]}"
    return 1
  }
}

# Back at the top level nothing is loading, which is what clearing used to mean.
[[ -z ${ZI[CUR_USPL2]} && -z ${ZI[CUR_USR]} && -z ${ZI[CUR_PLUGIN]} ]] || {
  builtin print -u2 -r -- "a load leaked to the top level: [${ZI[CUR_USR]}] [${ZI[CUR_PLUGIN]}] [${ZI[CUR_USPL2]}]"
  return 1
}
ZSH

builtin print -r -- "ok - a nested load restores the enclosing plug-in and leaves the top level clear"
