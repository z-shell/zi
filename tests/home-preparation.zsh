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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-home-prep-test.XXXXXXXX")" ||
  fail "create temporary directory"
# The failure case makes a directory read-only; restore it so cleanup can work.
trap 'command chmod -R u+rwX -- "$temp_root" 2>/dev/null; command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" || fail "create isolated environment"

# Running as root would bypass the permission case entirely.
if [[ ${EUID:-$UID} -eq 0 ]]; then
  builtin print -r -- "ok - skipped, the permission case is meaningless as root"
  exit 0
fi

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  zsh -f <<'ZSH' || fail "home preparation is not complete, propagating or retryable"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" >/dev/null 2>&1 || return 1

# A partial layout. The services directory used to be created only inside the
# branch guarded on the snippets directory being absent, so a tree with
# snippets/ present and services/ missing was accepted as ready.
command rm -rf "${ZI[SERVICES_DIR]}"
[[ -d ${ZI[SNIPPETS_DIR]} ]] || {
  builtin print -u2 -r -- "fixture: the snippets directory should still exist"
  return 1
}
unset 'ZI[HOME_READY]'
.zi-prepare-home || {
  builtin print -u2 -r -- "partial layout: preparation reported failure"
  return 1
}
[[ -d ${ZI[SERVICES_DIR]} ]] || {
  builtin print -u2 -r -- "partial layout: the services directory was not created"
  return 1
}

# A required directory that cannot be created has to fail, and must not mark the
# home ready, so a later call can retry.
command rm -rf "${ZI[SERVICES_DIR]}"
command chmod 500 "${ZI[HOME_DIR]}"
unset 'ZI[HOME_READY]'
.zi-prepare-home 2>/dev/null && {
  command chmod 700 "${ZI[HOME_DIR]}"
  builtin print -u2 -r -- "unwritable home: preparation reported success"
  return 1
}
[[ -z ${ZI[HOME_READY]} ]] || {
  command chmod 700 "${ZI[HOME_DIR]}"
  builtin print -u2 -r -- "unwritable home: ZI[HOME_READY] was set despite failure"
  return 1
}

# Retry after the cause is removed.
command chmod 700 "${ZI[HOME_DIR]}"
.zi-prepare-home || {
  builtin print -u2 -r -- "retry: preparation still reported failure"
  return 1
}
[[ -d ${ZI[SERVICES_DIR]} && -n ${ZI[HOME_READY]} ]] || {
  builtin print -u2 -r -- "retry: the home was not completed"
  return 1
}

# An already-ready home is a cheap no-op.
.zi-prepare-home || {
  builtin print -u2 -r -- "second call on a ready home reported failure"
  return 1
}
ZSH

builtin print -r -- "ok - home preparation completes partial layouts, propagates failure and stays retryable"
