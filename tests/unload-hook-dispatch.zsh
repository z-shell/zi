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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-unload-hook-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/plain" \
  "${temp_root}/hyph-en" || fail "create isolated environment"

# A plug-in whose directory name has no hyphen. Its unload function is named
# after the directory, which is the Plugin Standard shape.
builtin print -rl -- \
  'plain_plugin_unload() { builtin print -r -- plain-hook-ran >> $ZI_TEST_LOG; }' \
  > "${temp_root}/plain/plain.plugin.zsh" || fail "write the plain plug-in"

# A plug-in whose directory name has a hyphen. ADR-0020 namespace rules require
# the shell prefix to use underscores, so the only name it may define is the
# underscore form. Before the fix nothing looked for that name.
builtin print -rl -- \
  'hyph_en_plugin_unload() { builtin print -r -- hyphen-hook-ran >> $ZI_TEST_LOG; }' \
  > "${temp_root}/hyph-en/hyph-en.plugin.zsh" || fail "write the hyphenated plug-in"

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  ZI_TEST_ROOT="$temp_root" \
  ZI_TEST_LOG="${temp_root}/hooks.log" \
  zsh -f <<'ZSH' || fail "the Plugin Standard unload function was not called"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1
: > "$ZI_TEST_LOG"

zi load "${ZI_TEST_ROOT}/plain" >/dev/null 2>&1
(( ${+functions[plain_plugin_unload]} )) || {
  builtin print -u2 -r -- "the plain plug-in did not define its unload function"
  return 1
}
zi unload "${ZI_TEST_ROOT}/plain" >/dev/null 2>&1

zi load "${ZI_TEST_ROOT}/hyph-en" >/dev/null 2>&1
(( ${+functions[hyph_en_plugin_unload]} )) || {
  builtin print -u2 -r -- "the hyphenated plug-in did not define its unload function"
  return 1
}
zi unload "${ZI_TEST_ROOT}/hyph-en" >/dev/null 2>&1

typeset log="$(<$ZI_TEST_LOG)"

# A path-loaded plug-in is identified as `%<absolute path>', so the name derived
# verbatim from the id can never match. The basename is the analogue of a
# repository name.
[[ $log == *plain-hook-ran* ]] || {
  builtin print -u2 -r -- "the unload function of a path-loaded plug-in was not called: [$log]"
  return 1
}

# The underscore form, which is the only name ADR-0020 permits a hyphenated
# plug-in to define.
[[ $log == *hyphen-hook-ran* ]] || {
  builtin print -u2 -r -- "the underscore-named unload function was not called: [$log]"
  return 1
}
ZSH

builtin print -r -- "ok - the Plugin Standard unload function is reached for hyphenated and path-loaded plug-ins"
