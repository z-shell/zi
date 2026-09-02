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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-subst-nesting-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/inner" \
  "${temp_root}/snip" \
  "${temp_root}/nests_plugin" \
  "${temp_root}/nests_snippet" || fail "create isolated environment"

builtin print -r -- ':' > "${temp_root}/inner/inner.plugin.zsh" || fail "write inner plug-in"
builtin print -r -- ':' > "${temp_root}/snip/snippet.zsh" || fail "write inner snippet"

# Loads a plug-in from its own body, then autoloads a function it owns. The
# substitution has to still be installed for that autoload to be intercepted.
builtin print -r -- 'builtin print -r -- nested-plugin-body' \
  > "${temp_root}/nests_plugin/_issue_480_own" || fail "write owned function"
builtin print -rl -- \
  'zi light $ZI_TEST_ROOT/inner >/dev/null 2>&1' \
  'autoload -Uz _issue_480_own' \
  > "${temp_root}/nests_plugin/nests_plugin.plugin.zsh" || fail "write nesting plug-in"

# Loads a snippet from its own body. The inlined compdef substitution used for
# that must not tear down the enclosing plug-in's substitutions.
builtin print -r -- 'zi snippet $ZI_TEST_ROOT/snip/snippet.zsh >/dev/null 2>&1' \
  > "${temp_root}/nests_snippet/nests_snippet.plugin.zsh" || fail "write snippet-nesting plug-in"

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  ZI_TEST_ROOT="$temp_root" \
  zsh -f <<'ZSH' || fail "a nested load disturbs the enclosing substitutions"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

shadowed() {  # names currently replaced by a zi substitution
  # Presence is not the test: compdef legitimately exists once compinit has
  # run. Only a body that dispatches to :zi-tmp-subst-* is zi's.
  typeset -a on
  typeset name
  for name ( autoload bindkey zstyle alias compdef ) {
    [[ ${functions[$name]} == *:zi-tmp-subst-* ]] && on+=( $name )
  }
  builtin print -rn -- "${(j:,:)on}"
}

typeset baseline="$(shadowed)"
[[ -z $baseline ]] || {
  builtin print -u2 -r -- "substitutions were already installed before any load: $baseline"
  return 1
}

# A plug-in that loads a snippet. The inlined compdef substitution shares the
# nesting counter, so it must not remove what the enclosing load installed.
zi light "${ZI_TEST_ROOT}/nests_snippet" >/dev/null 2>&1
typeset leaked="$(shadowed)"
[[ -z $leaked ]] || {
  builtin print -u2 -r -- "a nested snippet load leaked substitutions to the top level: $leaked"
  return 1
}
(( ${ZI[TMP_SUBST_DEPTH]} == 0 )) || {
  builtin print -u2 -r -- "nesting depth did not return to zero: ${ZI[TMP_SUBST_DEPTH]}"
  return 1
}
[[ ${ZI[TMP_SUBST]} == inactive ]] || {
  builtin print -u2 -r -- "the substitution mode was left as ${ZI[TMP_SUBST]}"
  return 1
}

# A plug-in that loads another plug-in and then autoloads its own function. The
# substitution has to survive the inner load, so the function is claimed.
zi light "${ZI_TEST_ROOT}/nests_plugin" >/dev/null 2>&1
typeset result
result="$(_issue_480_own 2>&1)" || {
  builtin print -u2 -r -- "the enclosing plug-in's own function failed after a nested load: $result"
  return 1
}
[[ $result == nested-plugin-body ]] || {
  builtin print -u2 -r -- "unexpected body resolved: $result"
  return 1
}

leaked="$(shadowed)"
[[ -z $leaked ]] || {
  builtin print -u2 -r -- "a nested plug-in load leaked substitutions to the top level: $leaked"
  return 1
}
(( ${ZI[TMP_SUBST_DEPTH]} == 0 )) || {
  builtin print -u2 -r -- "nesting depth did not return to zero: ${ZI[TMP_SUBST_DEPTH]}"
  return 1
}
ZSH

builtin print -r -- "ok - nested loads keep the substitutions installed and remove them once"
