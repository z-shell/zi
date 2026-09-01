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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-autoload-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/plugins/registrar" \
  "${temp_root}/plugins/provider/lib" \
  "${temp_root}/plugins/selfowned" || fail "create isolated environment"

# The registrar stands in for a plug-in that runs compinit, which replays a
# bulk `autoload -Uz' for every completion function recorded in .zcompdump.
# None of those functions belong to the registrar.
builtin print -r -- 'autoload -Uz _issue_471_completion' \
  > "${temp_root}/plugins/registrar/registrar.plugin.zsh" || fail "write registrar plug-in"

# The provider owns the function and is loaded afterwards.
builtin print -rl -- \
  '0=${(%):-%N}' \
  'fpath+=( ${0:A:h}/lib )' \
  'autoload -Uz _issue_471_completion' \
  > "${temp_root}/plugins/provider/provider.plugin.zsh" || fail "write provider plug-in"
builtin print -r -- 'builtin print -r -- provider-body' \
  > "${temp_root}/plugins/provider/lib/_issue_471_completion" || fail "write provided function"

# A plug-in autoloading its own function while its directory stays out of
# $fpath. This is what the autoload substitution exists for and must keep
# working.
builtin print -r -- 'autoload -Uz _issue_471_own' \
  > "${temp_root}/plugins/selfowned/selfowned.plugin.zsh" || fail "write self-owned plug-in"
builtin print -r -- 'builtin print -r -- self-owned-body' \
  > "${temp_root}/plugins/selfowned/_issue_471_own" || fail "write self-owned function"

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  ZI_TEST_ROOT="$temp_root" \
  zsh -f <<'ZSH' || fail "autoload substitution claims functions the plug-in does not own"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

zi load "${ZI_TEST_ROOT}/plugins/registrar" >/dev/null || return 1

[[ ${functions[_issue_471_completion]} != *'local -a fpath'*registrar* ]] || {
  builtin print -u2 -r -- "registrar's directory was baked into a function it does not own"
  return 1
}

zi light "${ZI_TEST_ROOT}/plugins/provider" >/dev/null || return 1

typeset result
result="$(_issue_471_completion 2>&1)" || {
  builtin print -u2 -r -- "function owned by a later plug-in failed to resolve: $result"
  return 1
}
[[ $result == provider-body ]] || {
  builtin print -u2 -r -- "unexpected body resolved: $result"
  return 1
}

# The FPATH-clean autoloading that the substitution exists for must survive.
zi light "${ZI_TEST_ROOT}/plugins/selfowned" >/dev/null || return 1
[[ -z ${fpath[(r)${ZI_TEST_ROOT}/plugins/selfowned]} ]] || {
  builtin print -u2 -r -- "self-owned plug-in directory unexpectedly present in \$fpath"
  return 1
}
result="$(_issue_471_own 2>&1)" || {
  builtin print -u2 -r -- "plug-in's own function failed to autoload: $result"
  return 1
}
[[ $result == self-owned-body ]] || {
  builtin print -u2 -r -- "unexpected self-owned body resolved: $result"
  return 1
}
ZSH

builtin print -r -- "ok - autoload substitution only claims functions the plug-in owns"
