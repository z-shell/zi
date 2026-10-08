#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

# `zi load -h' and `zi load --help' print the options of `load' and return 1,
# as `zi light -h' does, instead of taking `-h' as a plug-in ID and trying to
# clone it (#579). `load' lists only -h and --help: -b is documented for
# `light' alone.

builtin emulate -R zsh
setopt pipe_fail extended_glob

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-load-help-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/zpfx" \
  "${temp_root}/bin" || fail "create isolated environment"

# A git, curl and wget that never reach the network. Once the probe has
# sourced zi.zsh (which reads its own revision with git), they record each
# call, so a download attempt by the command under test is seen.
typeset tool
for tool in git curl wget; do
  builtin print -rl -- \
    '#!/bin/sh' \
    '[ -n "${ZI_TEST_RECORD-}" ] || exit 1' \
    "printf '%s\\n' \"${tool} \$*\" >> \"\${ZI_TEST_ROOT}/downloads\"" \
    'exit 1' \
    > "${temp_root}/bin/${tool}" || fail "write the ${tool} recorder"
  command chmod +x "${temp_root}/bin/${tool}" || fail "make the ${tool} recorder executable"
done

# Run one zi command in a fresh shell and print its return status on the
# first line, then its output without colour sequences.
probe() {  # probe <zi command>
  env \
    HOME="${temp_root}/home" \
    XDG_CACHE_HOME="${temp_root}/cache" \
    XDG_CONFIG_HOME="${temp_root}/config" \
    XDG_DATA_HOME="${temp_root}/data" \
    ZDOTDIR="${temp_root}/zdotdir" \
    ZPFX="${temp_root}/zpfx" \
    PATH="${temp_root}/bin:${PATH}" \
    ZI_TEST_CHECKOUT="$project_root" \
    ZI_TEST_ROOT="$temp_root" \
    ZI_TEST_COMMAND="$1" \
    zsh -f <<'ZSH'
builtin emulate -R zsh
setopt extended_glob

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

typeset -a before after
before=( "${ZI[PLUGINS_DIR]}"/*(DN) )
export ZI_TEST_RECORD=1
typeset out
out="$(builtin eval "$ZI_TEST_COMMAND" 2>&1)"
builtin print -r -- $?
after=( "${ZI[PLUGINS_DIR]}"/*(DN) )
builtin print -r -- "created:${${after:|before}:+ ${after:|before}}"
builtin print -r -- "${out//$'\e'\[[0-9;]#m/}"
ZSH
}

typeset -i failures=0
not_ok() {
  builtin print -u2 -r -- "not ok - $1"
  (( ++failures ))
}

# expect_help <label> <zi command> <subcommand> <listed options> <absent options>
expect_help() {
  typeset label=$1 cmd=$2 sub=$3 listed=$4 absent=$5 actual opt
  typeset -i failed_before=failures
  command rm -f -- "${temp_root}/downloads"
  actual="$(probe "$cmd")" || { not_ok "$label: zi.zsh did not source"; return; }
  typeset -a lines
  lines=( "${(@f)actual}" )
  [[ ${lines[1]} == 1 ]] || not_ok "$label: returned ${lines[1]}, expected 1"
  [[ $actual == *"Available options for \`${sub}\` subcommand:"* ]] ||
    not_ok "$label: no usage line for ${sub}; got [${(j: | :)lines[2,-1]}]"
  # Each option line starts with the short and long forms, as in `-h,--help'.
  for opt in ${=listed}; do
    [[ $actual == *$'\n'"${opt},"* ]] || not_ok "$label: option ${opt} is not listed"
  done
  for opt in ${=absent}; do
    [[ $actual != *$'\n'"${opt},"* ]] || not_ok "$label: option ${opt} is listed"
  done
  [[ ! -e ${temp_root}/downloads ]] ||
    not_ok "$label: tried a download: $(<${temp_root}/downloads)"
  [[ ${lines[2]} == created: ]] || not_ok "$label: ${lines[2]}"
  (( failures == failed_before )) && builtin print -r -- "ok - $label"
}

# Positive control: the recorders see a download that does happen.
command rm -f -- "${temp_root}/downloads"
probe 'zi load example-owner/example-plugin' >/dev/null
[[ -s ${temp_root}/downloads ]] ||
  fail "control: a clone of example-owner/example-plugin was not recorded"

expect_help 'zi load -h'     'zi load -h'     load  '-h' '-b -f -x'
expect_help 'zi load --help' 'zi load --help' load  '-h' '-b -f -x'
expect_help 'zi light -h'    'zi light -h'    light '-h -b' ''

(( failures == 0 )) || fail "${failures} help check(s) failed"
builtin print -r -- "ok - zi load -h prints the load options and downloads nothing"
