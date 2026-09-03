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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-autoload-ice-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/fns" || fail "create isolated environment"

# zi skips a plug-in it has already loaded, and the autoload substitution never
# touches a function that already exists, so every ice form needs both its own
# plug-in directory and its own function name.
typeset case_name
for case_name ( plain spaced tight bang ) {
  command mkdir -p "${temp_root}/plugins/${case_name}" || fail "create plug-in ${case_name}"
  builtin print -r -- "builtin print -r -- ${case_name}-body" \
    > "${temp_root}/plugins/${case_name}/_issue_476_${case_name}" || fail "write function for ${case_name}"
  builtin print -r -- ': nothing, the ice does the work' \
    > "${temp_root}/plugins/${case_name}/${case_name}.plugin.zsh" || fail "write plug-in ${case_name}"
}

# Reachable through $fpath only, for the @autoload helper, which runs outside
# any plug-in load.
builtin print -r -- 'builtin print -r -- at-plain-body' \
  > "${temp_root}/fns/_issue_476_at_plain" || fail "write @autoload function"
builtin print -r -- 'builtin print -r -- at-rename-body' \
  > "${temp_root}/fns/_issue_476_at_src" || fail "write @autoload rename source"

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  ZI_TEST_ROOT="$temp_root" \
  zsh -f <<'ZSH' || fail "the autoload'' ice does not resolve its forms"
builtin emulate -R zsh
setopt pipe_fail

fpath=( "${ZI_TEST_ROOT}/fns" $fpath )
builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

typeset result

check() {  # check <function> <expected output> <label>
  (( ${+functions[$1]} )) || {
    builtin print -u2 -r -- "$3: $1 was never defined"
    return 1
  }
  result="$( $1 2>&1 )" || {
    builtin print -u2 -r -- "$3: calling $1 failed: $result"
    return 1
  }
  [[ $result == $2 ]] || {
    builtin print -u2 -r -- "$3: $1 produced '$result', expected '$2'"
    return 1
  }
}

# Plain form, which already worked. Guards against a regression.
zi ice autoload'_issue_476_plain'
zi load "${ZI_TEST_ROOT}/plugins/plain" >/dev/null || return 1
check _issue_476_plain plain-body "plain form" || return 1

# Rename form, spaced and unspaced. The arrow has to be rewritten to -S, which
# needs extended_glob at the substitution that does it.
zi ice autoload'_issue_476_spaced -> _issue_476_spaced_new'
zi load "${ZI_TEST_ROOT}/plugins/spaced" >/dev/null || return 1
check _issue_476_spaced_new spaced-body "spaced rename form" || return 1

zi ice autoload'_issue_476_tight->_issue_476_tight_new'
zi load "${ZI_TEST_ROOT}/plugins/tight" >/dev/null || return 1
check _issue_476_tight_new tight-body "unspaced rename form" || return 1

# Bang form. It takes the same -C branch as a rename but supplies no new name,
# so the generated wrapper has to install the body under the original name
# rather than under an empty one, which would recurse until FUNCNEST.
zi ice autoload'!_issue_476_bang'
zi load "${ZI_TEST_ROOT}/plugins/bang" >/dev/null || return 1
check _issue_476_bang bang-body "bang form" || return 1

# The public @autoload helper runs outside a plug-in load and carries both
# defects.
@autoload _issue_476_at_plain >/dev/null 2>&1
check _issue_476_at_plain at-plain-body "@autoload plain" || return 1

@autoload '_issue_476_at_src -> _issue_476_at_new' >/dev/null 2>&1
check _issue_476_at_new at-rename-body "@autoload rename" || return 1
ZSH

builtin print -r -- "ok - the autoload'' ice resolves its plain, rename and bang forms"
