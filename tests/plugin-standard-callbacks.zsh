#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -R zsh
setopt pipe_fail

typeset project_root="${0:A:h:h}"
typeset fixture_root="$project_root/tests/fixtures/plugin-standard-callbacks"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-plugin-callback-test.XXXXXXXX")" || exit 1
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

fail() {
  builtin emulate -L zsh
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

pass() {
  builtin emulate -L zsh
  builtin print -r -- "ok - $1"
}

assert_lines() {
  builtin emulate -L zsh
  local file="$1" label="$2"
  shift 2
  local -a actual=( "${(@f)$(<$file)}" )
  local -a expected=( "$@" )
  [[ "${(j:\n:)actual}" == "${(j:\n:)expected}" ]] ||
    fail "$label: expected ${(qqq)${(j:\n:)expected}}, got ${(qqq)${(j:\n:)actual}}"
}

load_stored_ice() {
  builtin emulate -L zsh
  local object_id="$1"
  local -a packed=( "${(z@)ZI_SICE[$object_id]}" )
  (( ${#packed} > 1 && ${#packed} % 2 == 0 )) ||
    fail "invalid packed ICE for $object_id"
  ICE=( "${(Q)packed[@]}" )
}

command mkdir -p -- \
  "$temp_root/home" \
  "$temp_root/zdotdir" \
  "$temp_root/data" \
  "$temp_root/cache" \
  "$temp_root/config" \
  "$temp_root/tmp" || fail "create isolated environment"

typeset -gx HOME="$temp_root/home"
typeset -gx ZDOTDIR="$temp_root/zdotdir"
typeset -gx XDG_DATA_HOME="$temp_root/data"
typeset -gx XDG_CACHE_HOME="$temp_root/cache"
typeset -gx XDG_CONFIG_HOME="$temp_root/config"
typeset -gx TMPDIR="$temp_root/tmp"
typeset -gx ZI_CALLBACK_LOG="$temp_root/callbacks.log"
typeset -gx ZI_CALLBACK_RETURN=0
typeset -gx ZI_CALLBACK_UNLOAD_RETURN=0
typeset -gAH ZI OPTS ICE ZI_SICE
ZI[BIN_DIR]="$project_root"
builtin source "$project_root/zi.zsh" >/dev/null || fail "source Zi"
builtin source "$project_root/lib/zsh/autoload.zsh" >/dev/null || fail "source autoload library"
builtin source "$project_root/lib/zsh/install.zsh" >/dev/null || fail "source install library"
unsetopt warn_create_global
OPTS[opt_-q,--quiet]=1

[[ $PMSPEC == *U* && $PMSPEC == *p* ]] ||
  fail "PMSPEC does not advertise the implemented unload and update callbacks"
pass "PMSPEC advertises both callback capabilities"

# Registration outside an active load must fail even if a stale dynamic name exists.
typeset -g id_as=stale/object
ZI[CUR_USPL2]=
ICE=()
@zsh-plugin-run-on-unload ':' >/dev/null 2>&1
integer unload_registration_rc=$?
@zsh-plugin-run-on-update ':' >/dev/null 2>&1
integer update_registration_rc=$?
(( unload_registration_rc != 0 && update_registration_rc != 0 )) ||
  fail "callback registration succeeded without an active object"
(( ! ${+ICE[ps-on-unload]} && ! ${+ICE[ps-on-update]} )) ||
  fail "rejected callback registration mutated ICE"
[[ -z ${ZI_SICE[stale/object]} ]] || fail "rejected callback used a stale dynamic identity"
pass "callback registration rejects missing active-load identity"

# Load a regular plugin and verify exact persistence plus update execution.
typeset plugin_id=owner/plugin
typeset plugin_dir="${ZI[PLUGINS_DIR]}/owner---plugin"
command mkdir -p -- "$plugin_dir" || fail "create regular plugin directory"
command cp -- "$fixture_root/plugin.plugin.zsh" "$plugin_dir/plugin.plugin.zsh" ||
  fail "copy regular plugin fixture"
ICE=()
.zi-load owner plugin light >/dev/null || fail "load regular plugin fixture"
[[ -n ${ZI_SICE[$plugin_id]} && -z ${ZI_SICE[stale/object]} ]] ||
  fail "regular plugin callbacks were not stored under $plugin_id"
load_stored_ice "$plugin_id"
[[ ${ICE[ps-on-unload]} == *plugin-unload:first*\;\ *plugin-unload:second*\;\ *ZI_CALLBACK_UNLOAD_RETURN* ]] ||
  fail "regular plugin unload callback order was not preserved"
[[ ${ICE[ps-on-update]} == *plugin-update:first*\;\ *plugin-update:second*\;\ *ZI_CALLBACK_RETURN* ]] ||
  fail "regular plugin update callback order was not preserved"
pass "regular plugin callbacks persist under the effective ID"

: >| "$ZI_CALLBACK_LOG"
ZI_CALLBACK_RETURN=23
typeset original_pwd="$PWD"
∞zi-ps-on-update-hook plugin owner plugin "$plugin_id" "$plugin_dir" atpull-post update:1 >/dev/null
integer plugin_update_rc=$?
(( plugin_update_rc == 23 )) || fail "regular plugin update callback returned $plugin_update_rc instead of 23"
[[ $PWD == "$original_pwd" ]] || fail "regular plugin update callback changed the caller cwd"
assert_lines "$ZI_CALLBACK_LOG" "regular plugin update callback" \
  "plugin-update:first:$plugin_dir:7:plugin,owner,plugin,$plugin_id,$plugin_dir,atpull-post,update:1" \
  "plugin-update:second:$plugin_dir:7:plugin,owner,plugin,$plugin_id,$plugin_dir,atpull-post,update:1"
pass "regular plugin update callback preserves order, cwd, arguments, and status"

: >| "$ZI_CALLBACK_LOG"
ZI_CALLBACK_RETURN=0
ZI_CALLBACK_UNLOAD_RETURN=31
unsetopt warn_create_global
.zi-unload owner plugin -q >/dev/null
integer plugin_unload_rc=$?
(( plugin_unload_rc == 31 )) || fail "regular plugin unload callback returned $plugin_unload_rc instead of 31"
[[ $PWD == "$original_pwd" ]] || fail "regular plugin unload callback changed the caller cwd"
assert_lines "$ZI_CALLBACK_LOG" "regular plugin unload callback" \
  "plugin-unload:first:$plugin_dir:3:owner,plugin,-q" \
  "plugin-unload:second:$plugin_dir:3:owner,plugin,-q"
[[ -z ${ZI_REGISTERED_PLUGINS[(r)$plugin_id]} ]] || fail "regular plugin remained registered after unload"
pass "regular plugin unload callback preserves order, cwd, and arguments"

# Load a snippet, then exercise its persisted callbacks with the same manager
# callback frames used by snippet update and unload execution.
typeset snippet_id=snippet/effective
typeset snippet_source="$fixture_root/snippet.zsh"
ICE=()
ICE[id-as]="$snippet_id"
unsetopt warn_create_global
.zi-load-snippet "$snippet_source" >/dev/null || fail "load snippet fixture"
[[ -n ${ZI_SICE[$snippet_id]} && -z ${ZI_SICE[stale/object]} ]] ||
  fail "snippet callbacks were not stored under $snippet_id"
load_stored_ice "$snippet_id"
[[ ${ICE[ps-on-unload]} == *snippet-unload:first*\;\ *snippet-unload:second*\;\ *ZI_CALLBACK_UNLOAD_RETURN* ]] ||
  fail "snippet unload callback order was not preserved"
[[ ${ICE[ps-on-update]} == *snippet-update:first*\;\ *snippet-update:second*\;\ *ZI_CALLBACK_RETURN* ]] ||
  fail "snippet update callback order was not preserved"
pass "snippet callbacks persist under the effective ID"

.zi-get-object-path snippet "$snippet_id" >/dev/null || fail "resolve loaded snippet directory"
typeset snippet_dir="$REPLY"
: >| "$ZI_CALLBACK_LOG"
ZI_CALLBACK_RETURN=29
∞zi-ps-on-update-hook snippet "$snippet_source" "$snippet_id" "$snippet_dir" atpull-post update:1 >/dev/null
integer snippet_update_rc=$?
(( snippet_update_rc == 29 )) || fail "snippet update callback returned $snippet_update_rc instead of 29"
[[ $PWD == "$original_pwd" ]] || fail "snippet update callback changed the caller cwd"
assert_lines "$ZI_CALLBACK_LOG" "snippet update callback" \
  "snippet-update:first:$snippet_dir:6:snippet,$snippet_source,$snippet_id,$snippet_dir,atpull-post,update:1" \
  "snippet-update:second:$snippet_dir:6:snippet,$snippet_source,$snippet_id,$snippet_dir,atpull-post,update:1"
pass "snippet update callback preserves order, cwd, arguments, and status"

: >| "$ZI_CALLBACK_LOG"
ZI_CALLBACK_UNLOAD_RETURN=37
.zi-run-plugin-standard-unload-callback "${ICE[ps-on-unload]}" "$snippet_dir" \
  snippet "$snippet_source" "$snippet_id" "$snippet_dir" unload
integer snippet_unload_rc=$?
(( snippet_unload_rc == 37 )) || fail "snippet unload callback returned $snippet_unload_rc instead of 37"
[[ $PWD == "$original_pwd" ]] || fail "snippet unload callback changed the caller cwd"
assert_lines "$ZI_CALLBACK_LOG" "snippet unload callback" \
  "snippet-unload:first:$snippet_dir:5:snippet,$snippet_source,$snippet_id,$snippet_dir,unload" \
  "snippet-unload:second:$snippet_dir:5:snippet,$snippet_source,$snippet_id,$snippet_dir,unload"
pass "snippet unload callback preserves order, cwd, arguments, and status"

builtin unset id_as
