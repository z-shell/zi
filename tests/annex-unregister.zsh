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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-annex-unregister-test.XXXXXXXX")" ||
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

builtin print -r -- 'builtin print -r -- first-loaded' \
  > "${temp_root}/first/first.plugin.zsh" || fail "write the first plug-in"
builtin print -r -- 'builtin print -r -- second-loaded' \
  > "${temp_root}/second/second.plugin.zsh" || fail "write the second plug-in"

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  ZI_TEST_ROOT="$temp_root" \
  zsh -f <<'ZSH' || fail "an unregistered annex hook still affects later plug-in loads"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

# Unregistering something never registered is a no-op, not an error.
@zi-unregister-annex never-registered hook:before-load-2 || {
  builtin print -u2 -r -- "unregistering an absent annex reported an error"
  return 1
}

probe_annex_handler() { return 0; }
@zi-register-annex probe-annex hook:before-load-2 probe_annex_handler '' ''

# The Plugin Standard unload contract has the annex remove its own handler.
# Without a matching unregister the ZI_EXTS entry survives, the before-load
# dispatch calls a name that no longer exists, and the resulting 127 is folded
# into the return value and shifts the argument list for the rest of the
# session.
@zi-unregister-annex probe-annex hook:before-load-2
unfunction probe_annex_handler

typeset output status_first status_second
output="$(zi load "${ZI_TEST_ROOT}/first" 2>&1)"
status_first=$?
[[ $status_first -eq 0 ]] || {
  builtin print -u2 -r -- "loading after unregister returned ${status_first}: ${output}"
  return 1
}
[[ $output == *first-loaded* ]] || {
  builtin print -u2 -r -- "the first plug-in did not load: ${output}"
  return 1
}

# A second load proves the argument list was not shifted by the first.
output="$(zi load "${ZI_TEST_ROOT}/second" 2>&1)"
status_second=$?
[[ $status_second -eq 0 ]] || {
  builtin print -u2 -r -- "the second load returned ${status_second}: ${output}"
  return 1
}
[[ $output == *second-loaded* ]] || {
  builtin print -u2 -r -- "the second plug-in did not load: ${output}"
  return 1
}

# The registry itself no longer holds the entry.
typeset key found=0
for key in "${(@k)ZI_EXTS}"; do
  [[ ${ZI_EXTS[$key]} == *probe_annex_handler* ]] && found=1
done
(( found == 0 )) || {
  builtin print -u2 -r -- "a ZI_EXTS entry for the unregistered annex survived"
  return 1
}
ZSH

builtin print -r -- "ok - an unregistered annex hook is removed and later plug-in loads are unaffected"
