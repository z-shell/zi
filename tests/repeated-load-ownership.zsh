#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# z-shell/zi#113: a repeated load of the same plug-in, then one unload, must
# remove everything the plug-in added across its loads and restore what it
# replaced. When another plug-in took the plug-in's widget or binding over
# between its loads, the result must stay as it is on next: that case is still
# open in the issue. Each scenario runs in its own clean shell.

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
    # That case stays open in z-shell/zi#113; the repeated load must leave it
    # exactly as next does: p's second load records afresh, its unload hands
    # the widget back to what q replaced, and q's unload then restores q's.
    zi load "$p" >/dev/null 2>&1
    zi load "$q" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    zi unload "$p" >/dev/null 2>&1
    check '(( ${+functions[qa_fn]} ))' "q's function was removed" || return 1
    check '[[ ${widgets[zi-repeat-widget]} == user:pa_fn ]]' "the widget differs from next: ${widgets[zi-repeat-widget]}" || return 1
    check '[[ "$(bindkey "^X^P")" == "\"^X^P\" zi-repeat-widget" ]]' "the binding differs from next: $(bindkey '^X^P')" || return 1
    ;;
  interleaved-other-order)
    # The same, unloading q first: p keeps its live widget, as on next.
    zi load "$p" >/dev/null 2>&1
    zi load "$q" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    zi unload "$q" >/dev/null 2>&1
    check '(( ${+functions[pa_fn]} ))' "p's function was removed by q's unload" || return 1
    check '[[ ${widgets[zi-repeat-widget]} == user:pa_fn ]]' "q's unload changed p's live widget: ${widgets[zi-repeat-widget]}" || return 1
    check '[[ "$(bindkey "^X^P")" == "\"^X^P\" zi-repeat-widget" ]]' "q's unload changed p's binding: $(bindkey '^X^P')" || return 1
    ;;
  older)
    # q loaded before p's first load is not a takeover between p's loads:
    # p's repeated load still keeps its records, and its unload removes it.
    zi load "$q" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    zi unload "$p" >/dev/null 2>&1
    check '(( ! ${+functions[pa_fn]} ))' "p's function survived unload" || return 1
    check '[[ ${widgets[zi-repeat-widget]} == user:qa_fn ]]' "q's widget was not restored: ${widgets[zi-repeat-widget]}" || return 1
    ;;
  binding-taken)
    # Another plug-in rebinds only the key between p's loads: like a widget
    # takeover, the result stays as on next.
    zi load "$p" >/dev/null 2>&1
    zi load "${ZI_TEST_ROOT}/k" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    zi unload "$p" >/dev/null 2>&1
    check '[[ "$(bindkey "^X^P")" == "\"^X^P\" end-of-line" ]]' "the binding differs from next: $(bindkey '^X^P')" || return 1
    ;;
  prior)
    # A function the user defined before any load is not the plug-in's.
    pa_fn() { builtin print -r -- user; }
    zi load "$p" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    zi unload "$p" >/dev/null 2>&1
    check '(( ${+functions[pa_fn]} ))' "a function defined before the first load was removed" || return 1
    ;;
  wrapped)
    # A plug-in that replaces an existing widget, loaded twice, restores the
    # original widget on unload, not its own first replacement.
    zi load "${ZI_TEST_ROOT}/w" >/dev/null 2>&1
    zi load "${ZI_TEST_ROOT}/w" >/dev/null 2>&1
    zi unload "${ZI_TEST_ROOT}/w" >/dev/null 2>&1
    check '[[ ${widgets[forward-char]} == builtin ]]' "the replaced widget was not restored: ${widgets[forward-char]}" || return 1
    check '(( ! ${+functions[w_fn]} ))' "the replacement function survived unload" || return 1
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
  shared-twice)
    # As shared, but r is itself loaded twice, so r's claim on the helper
    # comes from r's earlier load, not from its newest one.
    builtin print -r -- 'shared_fn() { :; }' >> "${p}/p.plugin.zsh"
    zi load "$p" >/dev/null 2>&1
    unfunction shared_fn
    zi load "${ZI_TEST_ROOT}/r" >/dev/null 2>&1
    zi load "${ZI_TEST_ROOT}/r" >/dev/null 2>&1
    zi load "$p" >/dev/null 2>&1
    zi unload "$p" >/dev/null 2>&1
    check '(( ${+functions[shared_fn]} ))' "a function the still-loaded r created on its earlier load was removed" || return 1
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
for scenario in twice changed interleaved interleaved-other-order older binding-taken prior wrapped shared shared-twice reload; do
  write_plugin p pa_fn
  write_plugin q qa_fn
  command mkdir -p "${temp_root}/r" "${temp_root}/k" "${temp_root}/w" || fail "create the r, k and w plug-in directories"
  builtin print -r -- 'shared_fn() { :; }' > "${temp_root}/r/r.plugin.zsh" || fail "write the r plug-in"
  builtin print -r -- "bindkey '^X^P' end-of-line" > "${temp_root}/k/k.plugin.zsh" || fail "write the k plug-in"
  builtin print -rl -- 'w_fn() { zle .forward-char; }' 'zle -N forward-char w_fn' > "${temp_root}/w/w.plugin.zsh" || fail "write the w plug-in"
  if ( run_case "$scenario" ); then
    builtin print -r -- "ok - ${scenario}"
  else
    (( failures++ ))
  fi
done
(( failures == 0 )) || fail "${failures} repeated-load scenario(s) failed"
