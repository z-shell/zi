#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# z-shell/zi#113: a repeated load of the same plug-in, then one unload, must
# remove everything the plug-in added across its loads and restore what it
# replaced, without taking state another plug-in loaded in between now owns.
# Each scenario runs in its own clean shell.

builtin emulate -R zsh
setopt pipe_fail

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-repeated-load-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

# write_plugin DIR FUNCTION: a plug-in that defines FUNCTION, makes it the
# zi-repeat-widget widget and binds ^X^P to that widget.
write_plugin() {
  command mkdir -p "${temp_root}/$1" || fail "create the $1 plug-in directory"
  builtin print -rl -- \
    "$2() { builtin print -r -- $2; }" \
    "zle -N zi-repeat-widget $2" \
    "bindkey '^X^P' zi-repeat-widget" \
    > "${temp_root}/$1/$1.plugin.zsh" || fail "write the $1 plug-in"
}

# run_case NAME: run the scenario NAME in a fresh isolated shell.
run_case() {
  local case_root="${temp_root}/$1"
  command mkdir -p "${case_root}"/{home,cache,config,data,zdotdir} || fail "$1: create isolated environment"
  env \
    HOME="${case_root}/home" \
    XDG_CACHE_HOME="${case_root}/cache" \
    XDG_CONFIG_HOME="${case_root}/config" \
    XDG_DATA_HOME="${case_root}/data" \
    ZDOTDIR="${case_root}/zdotdir" \
    ZI_TEST_CHECKOUT="$project_root" \
    ZI_TEST_ROOT="$temp_root" \
    ZI_TEST_CASE="$1" \
    zsh -f <<'ZSH' || fail "$1"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

check() {
  eval "$1" && return 0
  builtin print -u2 -r -- "${ZI_TEST_CASE}: $2"
  return 1
}

typeset binding_before="$(bindkey '^X^P')"
typeset p="${ZI_TEST_ROOT}/p" q="${ZI_TEST_ROOT}/q"

case $ZI_TEST_CASE in
  twice)
    # The same plug-in loaded twice, then unloaded once.
    zi load "$p" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    zi unload "$p" >/dev/null 2>&1
    check '(( ! ${+functions[pa_fn]} ))' "the function survived unload" || return 1
    check '[[ -z ${widgets[zi-repeat-widget]} ]]' "the widget survived unload: ${widgets[zi-repeat-widget]}" || return 1
    check '[[ "$(bindkey "^X^P")" == "$binding_before" ]]' "the binding was not restored: $(bindkey '^X^P')" || return 1
    ;;
  changed)
    # The plug-in gains a function between its loads; both must go.
    zi load "$p" >/dev/null 2>&1
    builtin print -r -- 'pb_fn() { :; }' >> "${p}/p.plugin.zsh"
    zi load "$p" >/dev/null 2>&1
    zi unload "$p" >/dev/null 2>&1
    check '(( ! ${+functions[pa_fn]} ))' "the first load's function survived unload" || return 1
    check '(( ! ${+functions[pb_fn]} ))' "the second load's function survived unload" || return 1
    check '[[ -z ${widgets[zi-repeat-widget]} ]]' "the widget survived unload: ${widgets[zi-repeat-widget]}" || return 1
    check '[[ "$(bindkey "^X^P")" == "$binding_before" ]]' "the binding was not restored: $(bindkey '^X^P')" || return 1
    ;;
  interleaved)
    # Another plug-in takes the widget and binding between the two loads.
    # After p's unload, q is still loaded and must keep what it owns.
    zi load "$p" >/dev/null 2>&1
    zi load "$q" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    zi unload "$p" >/dev/null 2>&1
    check '(( ! ${+functions[pa_fn]} ))' "p's function survived unload" || return 1
    check '(( ${+functions[qa_fn]} ))' "q's function was removed" || return 1
    check '[[ ${widgets[zi-repeat-widget]} == user:qa_fn ]]' "q does not own the widget: ${widgets[zi-repeat-widget]}" || return 1
    check '[[ "$(bindkey "^X^P")" == "\"^X^P\" zi-repeat-widget" ]]' "q's binding was lost: $(bindkey '^X^P')" || return 1
    zi unload "$q" >/dev/null 2>&1
    check '(( ! ${+functions[qa_fn]} ))' "q's function survived its unload" || return 1
    check '[[ -z ${widgets[zi-repeat-widget]} ]]' "the widget survived both unloads: ${widgets[zi-repeat-widget]}" || return 1
    check '[[ "$(bindkey "^X^P")" == "$binding_before" ]]' "the binding was not restored after both unloads: $(bindkey '^X^P')" || return 1
    ;;
  prior)
    # A function the user defined before any load is not the plug-in's.
    pa_fn() { builtin print -r -- user; }
    zi load "$p" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    zi unload "$p" >/dev/null 2>&1
    check '(( ${+functions[pa_fn]} ))' "a function defined before the first load was removed" || return 1
    ;;
  shared)
    # p defines a helper on its first load; r, loaded next, defines the same
    # helper again. After p's repeated load and unload, r still owns it.
    builtin print -r -- 'shared_fn() { :; }' >> "${p}/p.plugin.zsh"
    zi load "$p" >/dev/null 2>&1
    unfunction shared_fn
    zi load "${ZI_TEST_ROOT}/r" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    zi unload "$p" >/dev/null 2>&1
    check '(( ${+functions[shared_fn]} ))' "a function the still-loaded r created was removed" || return 1
    check '(( ! ${+functions[pa_fn]} ))' "p's function survived unload" || return 1
    ;;
  reload)
    # Load, unload, load again, unload: each cycle is independent.
    zi load "$p" >/dev/null 2>&1
    zi unload "$p" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    check '[[ ${widgets[zi-repeat-widget]} == user:pa_fn ]]' "the second cycle did not install the widget: ${widgets[zi-repeat-widget]}" || return 1
    zi unload "$p" >/dev/null 2>&1
    check '(( ! ${+functions[pa_fn]} ))' "the function survived the second unload" || return 1
    check '[[ -z ${widgets[zi-repeat-widget]} ]]' "the widget survived the second unload: ${widgets[zi-repeat-widget]}" || return 1
    check '[[ "$(bindkey "^X^P")" == "$binding_before" ]]' "the binding was not restored after the second unload: $(bindkey '^X^P')" || return 1
    ;;
  *)
    builtin print -u2 -r -- "unknown case: ${ZI_TEST_CASE}"
    return 1
    ;;
esac
ZSH
}

typeset -i failures=0
typeset scenario
for scenario in twice changed interleaved prior shared reload; do
  write_plugin p pa_fn
  write_plugin q qa_fn
  command mkdir -p "${temp_root}/r" || fail "create the r plug-in directory"
  builtin print -r -- 'shared_fn() { :; }' > "${temp_root}/r/r.plugin.zsh" || fail "write the r plug-in"
  if ( run_case "$scenario" ); then
    builtin print -r -- "ok - ${scenario}"
  else
    (( failures++ ))
  fi
done
(( failures == 0 )) || fail "${failures} repeated-load scenario(s) failed"
