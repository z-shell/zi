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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-completion-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" || fail "create isolated environment"

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  zsh -f <<'ZSH' || fail "completion mutations rebuild compinit state"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
ZI[COMPINIT_OPTS]=-i
.zi-prepare-home || return 1

builtin autoload -Uz compinit
compinit -i -d "${ZI[ZCOMPDUMP_PATH]}" || return 1
[[ -z ${_comps[zi_issue_349]} ]] || {
  builtin print -u2 -r -- "completion was registered before its file existed"
  return 1
}

typeset plugin_dir="${ZI[PLUGINS_DIR]}/issue-349---completion"
typeset completion_link="${ZI[COMPLETIONS_DIR]}/_zi_issue_349"
typeset completion_backup="${ZI[COMPLETIONS_DIR]}/zi_issue_349"

command mkdir -p "$plugin_dir" || return 1
builtin printf '%s\n%s\n' \
  '#compdef zi_issue_349' \
  '_zi_issue_349() { _message issue-349; }' \
  > "$plugin_dir/_zi_issue_349" || return 1

(( ${+functions[.zi-install-completions]} )) ||
  builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
.zi-install-completions issue-349 completion 0 -Q || return 1
[[ -L $completion_link && ${_comps[zi_issue_349]} == _zi_issue_349 ]] || {
  builtin print -u2 -r -- "generated completion was not registered after install"
  return 1
}

zi cdisable zi_issue_349 >/dev/null || return 1
[[ ! -e $completion_link && -L $completion_backup && -z ${_comps[zi_issue_349]} ]] || {
  builtin print -u2 -r -- "completion remained registered after disable"
  return 1
}

zi cenable zi_issue_349 >/dev/null || return 1
[[ -L $completion_link && ! -e $completion_backup && ${_comps[zi_issue_349]} == _zi_issue_349 ]] || {
  builtin print -u2 -r -- "completion was not registered after enable"
  return 1
}

zi cuninstall issue-349 completion >/dev/null || return 1
[[ ! -e $completion_link && ! -e $completion_backup && -z ${_comps[zi_issue_349]} ]] || {
  builtin print -u2 -r -- "completion remained registered after uninstall"
  return 1
}
ZSH

builtin print -r -- "ok - completion mutations rebuild compinit state"
