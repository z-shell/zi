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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-atinit-marker-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/cmdplug" \
  "${temp_root}/normplug" || fail "create isolated environment"

builtin print -rl -- '#!/bin/sh' 'echo tool' \
  > "${temp_root}/cmdplug/mytool" || fail "write the command plug-in payload"
command chmod +x "${temp_root}/cmdplug/mytool" || fail "make the payload executable"
builtin print -r -- ':' \
  > "${temp_root}/normplug/normplug.plugin.zsh" || fail "write the normal plug-in"

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  ZI_TEST_ROOT="$temp_root" \
  zsh -f <<'ZSH' || fail "a deferred atinit hook did not run"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

# The `!' prefix defers the hook, and the prefix has to be stripped before the
# body is evaluated. Two branches strip it, and each had its own defect:
# the command branch wrote the strip inside the subscript, `${ICE[atinit#!]}',
# which looks up a key that does not exist and silently evaluated nothing; the
# nocd branch of the source path stripped `1' instead of `!', leaving the body
# to fail as a command called `!typeset'.

# Command branch, without nocd.
zi ice as"command" pick"mytool" atinit'!typeset -g ZI_TEST_MARK_CMD=ran'
zi load "${ZI_TEST_ROOT}/cmdplug" >/dev/null 2>&1
[[ ${ZI_TEST_MARK_CMD:-unset} == ran ]] || {
  builtin print -u2 -r -- "as\"command\" deferred atinit did not run: ${ZI_TEST_MARK_CMD:-unset}"
  return 1
}

# Source path, with nocd active.
zi ice nocd atinit'!typeset -g ZI_TEST_MARK_NOCD=ran'
zi load "${ZI_TEST_ROOT}/normplug" >/dev/null 2>&1
[[ ${ZI_TEST_MARK_NOCD:-unset} == ran ]] || {
  builtin print -u2 -r -- "nocd deferred atinit did not run: ${ZI_TEST_MARK_NOCD:-unset}"
  return 1
}
ZSH

builtin print -r -- "ok - the deferred atinit marker is stripped on the command and nocd branches"
