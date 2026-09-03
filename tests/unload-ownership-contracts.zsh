#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# The unload ownership contracts that hold today, pinned so a future change to
# the ownership model cannot quietly break them.
#
# z-shell/zi#113 proposes representing function, widget and bindkey ownership
# per load instance rather than by plug-in id. Measuring the current behaviour
# first showed the defect is narrower than that issue's prose: every
# multi-plug-in path already restores the correct previous owner, and only a
# repeated load of the *same* plug-in leaks. The repeated-load case is therefore
# deliberately absent here; it belongs with its fix, not ahead of it.

builtin emulate -R zsh
setopt pipe_fail

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-ownership-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/first" \
  "${temp_root}/second" || fail "create isolated environment"

# Two plug-ins competing for the same function, widget and key binding.
typeset which
for which in first second; do
  builtin print -rl -- \
    "${which}_impl() { builtin print -r -- ${which}-body; }" \
    "zle -N zi-ownership-widget ${which}_impl" \
    "bindkey '^X^P' zi-ownership-widget" \
    > "${temp_root}/${which}/${which}.plugin.zsh" || fail "write the ${which} plug-in"
done

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  ZI_TEST_ROOT="$temp_root" \
  zsh -f <<'ZSH' || fail "an unload ownership contract regressed"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

typeset binding_before="$(bindkey '^X^P')"

# A single load followed by its unload removes everything the plug-in added.
zi load "${ZI_TEST_ROOT}/first" >/dev/null 2>&1
zi unload "${ZI_TEST_ROOT}/first" >/dev/null 2>&1
(( ${+functions[first_impl]} == 0 )) || {
  builtin print -u2 -r -- "single load: the function survived unload"
  return 1
}
[[ -z ${widgets[zi-ownership-widget]} ]] || {
  builtin print -u2 -r -- "single load: the widget survived unload: ${widgets[zi-ownership-widget]}"
  return 1
}
[[ "$(bindkey '^X^P')" == "$binding_before" ]] || {
  builtin print -u2 -r -- "single load: the key binding was not restored: $(bindkey '^X^P')"
  return 1
}

# A second plug-in taking over the same widget and binding, then releasing it,
# restores the first plug-in as the live owner rather than the original state.
zi load "${ZI_TEST_ROOT}/first" >/dev/null 2>&1
zi load "${ZI_TEST_ROOT}/second" >/dev/null 2>&1
[[ ${widgets[zi-ownership-widget]} == *second_impl* ]] || {
  builtin print -u2 -r -- "chain: the second plug-in did not take the widget"
  return 1
}
zi unload "${ZI_TEST_ROOT}/second" >/dev/null 2>&1
[[ ${widgets[zi-ownership-widget]} == *first_impl* ]] || {
  builtin print -u2 -r -- "chain: the previous widget owner was not restored: ${widgets[zi-ownership-widget]}"
  return 1
}

# Unloading the remaining plug-in returns the widget and the binding to the
# state that preceded both loads.
zi unload "${ZI_TEST_ROOT}/first" >/dev/null 2>&1
[[ -z ${widgets[zi-ownership-widget]} ]] || {
  builtin print -u2 -r -- "chain: the widget survived the final unload: ${widgets[zi-ownership-widget]}"
  return 1
}
[[ "$(bindkey '^X^P')" == "$binding_before" ]] || {
  builtin print -u2 -r -- "chain: the binding was not restored: $(bindkey '^X^P')"
  return 1
}

# Unloading in a different order than loading removes only the plug-in named,
# and leaves the other plug-in's state intact.
zi load "${ZI_TEST_ROOT}/first" >/dev/null 2>&1
zi load "${ZI_TEST_ROOT}/second" >/dev/null 2>&1
zi unload "${ZI_TEST_ROOT}/first" >/dev/null 2>&1
(( ${+functions[first_impl]} == 0 )) || {
  builtin print -u2 -r -- "out-of-order: the unloaded plug-in's function survived"
  return 1
}
(( ${+functions[second_impl]} == 1 )) || {
  builtin print -u2 -r -- "out-of-order: the still-loaded plug-in's function was removed"
  return 1
}
ZSH

builtin print -r -- "ok - single load, owner chains and out-of-order unload all restore correctly"
