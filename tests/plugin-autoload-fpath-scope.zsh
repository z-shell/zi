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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-fpath-scope-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/cwd" \
  "${temp_root}/plugins/plusx/lib" || fail "create isolated environment"

# The plug-in's own functions, one directly in the plug-in directory and one in
# an $fpath subdirectory it registers. Immediate `autoload +X' of either has to
# resolve while the plug-in is loading.
builtin print -r -- 'builtin print -r -- own-body' \
  > "${temp_root}/plugins/plusx/_issue_475_own" || fail "write own function"
builtin print -r -- 'builtin print -r -- lib-body' \
  > "${temp_root}/plugins/plusx/lib/_issue_475_lib" || fail "write lib function"

# A function file that exists only in the directory the shell happens to be in.
# The working directory is not a search path and must never be consulted.
builtin print -r -- 'builtin print -r -- cwd-body' \
  > "${temp_root}/cwd/_issue_475_cwd" || fail "write working-directory function"

builtin print -rl -- \
  '0=${(%):-%N}' \
  'fpath+=( ${0:A:h}/lib )' \
  'autoload +X -Uz _issue_475_own' \
  'autoload +X -Uz _issue_475_lib' \
  'autoload +X -Uz _issue_475_cwd 2>/dev/null' \
  ': the third autoload is expected to find nothing' \
  > "${temp_root}/plugins/plusx/plusx.plugin.zsh" || fail "write plug-in"

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  ZI_TEST_ROOT="$temp_root" \
  zsh -f <<'ZSH' || fail "immediate autoload does not keep to the plug-in's own directories"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

typeset before_fpath="${(j.:.)fpath}" before_FPATH="$FPATH"
builtin cd -q "${ZI_TEST_ROOT}/cwd" || return 1
# blockf so that the plug-in's own `fpath+=' is reverted and anything left
# behind afterwards is a leak from the substitution rather than from the
# plug-in itself.
zi ice blockf
zi load "${ZI_TEST_ROOT}/plugins/plusx" >/dev/null 2>&1

# The `+X' branch replaces $fpath for the duration of the call. Both the array
# and the tied scalar have to be restored for the caller.
[[ ${(j.:.)fpath} == $before_fpath ]] || {
  builtin print -u2 -r -- "\$fpath leaked out of the immediate autoload"
  return 1
}
[[ $FPATH == $before_FPATH ]] || {
  builtin print -u2 -r -- "\$FPATH leaked out of the immediate autoload: $FPATH"
  return 1
}

typeset result
result="$(_issue_475_own 2>&1)" || {
  builtin print -u2 -r -- "immediate autoload of the plug-in's own function failed: $result"
  return 1
}
[[ $result == own-body ]] || {
  builtin print -u2 -r -- "unexpected own body resolved: $result"
  return 1
}

result="$(_issue_475_lib 2>&1)" || {
  builtin print -u2 -r -- "immediate autoload from the plug-in's \$fpath subdirectory failed: $result"
  return 1
}
[[ $result == lib-body ]] || {
  builtin print -u2 -r -- "unexpected lib body resolved: $result"
  return 1
}

[[ ${functions[_issue_475_cwd]} != *cwd-body* ]] || {
  builtin print -u2 -r -- "the working directory was searched: _issue_475_cwd was loaded from \$PWD"
  return 1
}
ZSH

builtin print -r -- "ok - immediate autoload keeps to the plug-in's own directories and restores \$fpath"
