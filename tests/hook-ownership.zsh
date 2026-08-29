#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# Hook-ownership contract for plugin unload (z-shell/zi#108).
#
# Zi must record which standard add-zsh-hook entries a plugin registered, so
# that unload removes exactly those and nothing else. Ownership is a property
# of the registration, not of who defined the function: a plugin that
# registers a function it did not define still owns that hook entry.

builtin emulate -R zsh
setopt pipe_fail

typeset project_root="${0:A:h:h}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-hook-ownership-test.XXXXXXXX")" || exit 1
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

integer failures=0

fail() {
  builtin emulate -L zsh
  builtin print -u2 -r -- "not ok - $1"
  (( failures++ ))
}

pass() {
  builtin emulate -L zsh
  builtin print -r -- "ok - $1"
}

# Membership test for a hook array named by $1.
in_hook() {
  builtin emulate -L zsh
  local array_name="$1" entry="$2"
  local -a current=( "${(@P)array_name}" )
  (( ${current[(I)$entry]} > 0 ))
}

assert_absent() {
  builtin emulate -L zsh
  local array_name="$1" entry="$2" label="$3"
  if in_hook "$array_name" "$entry"; then
    fail "$label: \`$entry' still present in \$$array_name (${(j:,:)${(@P)array_name}})"
    return 1
  fi
  return 0
}

assert_present() {
  builtin emulate -L zsh
  local array_name="$1" entry="$2" label="$3"
  if in_hook "$array_name" "$entry"; then
    return 0
  fi
  fail "$label: \`$entry' missing from \$$array_name (${(j:,:)${(@P)array_name}})"
  return 1
}

command mkdir -p -- \
  "$temp_root/home" \
  "$temp_root/zdotdir" \
  "$temp_root/data" \
  "$temp_root/cache" \
  "$temp_root/config" \
  "$temp_root/tmp" || { builtin print -u2 "not ok - create isolated environment"; exit 1 }

typeset -gx HOME="$temp_root/home"
typeset -gx ZDOTDIR="$temp_root/zdotdir"
typeset -gx XDG_DATA_HOME="$temp_root/data"
typeset -gx XDG_CACHE_HOME="$temp_root/cache"
typeset -gx XDG_CONFIG_HOME="$temp_root/config"
typeset -gx TMPDIR="$temp_root/tmp"
typeset -gAH ZI OPTS ICE ZI_SICE
ZI[BIN_DIR]="$project_root"
builtin source "$project_root/zi.zsh" >/dev/null || { builtin print -u2 "not ok - source Zi"; exit 1 }
builtin source "$project_root/lib/zsh/autoload.zsh" >/dev/null || { builtin print -u2 "not ok - source autoload library"; exit 1 }
builtin source "$project_root/lib/zsh/install.zsh" >/dev/null || { builtin print -u2 "not ok - source install library"; exit 1 }
unsetopt warn_create_global
OPTS[opt_-q,--quiet]=1

builtin autoload -Uz add-zsh-hook

# Write a plugin fixture into the isolated plugins directory.
make_plugin() {
  builtin emulate -L zsh
  local name="$1" body="$2"
  local dir="${ZI[PLUGINS_DIR]}/owner---$name"
  command mkdir -p -- "$dir" || return 1
  builtin print -r -- "$body" >| "$dir/$name.plugin.zsh" || return 1
  REPLY="$dir"
}

load_plugin() {
  builtin emulate -L zsh
  ICE=()
  .zi-load owner "$1" >/dev/null
}

unload_plugin() {
  builtin emulate -L zsh
  unsetopt warn_create_global
  .zi-unload owner "$1" -q >/dev/null
}

#
# 1. Every standard hook array is cleaned, including the one the unfunction
#    step never covered.
#

make_plugin all-arrays '
builtin autoload -Uz add-zsh-hook
owned_chpwd() { : }
owned_precmd() { : }
owned_preexec() { : }
owned_periodic() { : }
owned_addhistory() { return 0 }
owned_exit() { : }
owned_dirname() { return 1 }
add-zsh-hook chpwd owned_chpwd
add-zsh-hook precmd owned_precmd
add-zsh-hook preexec owned_preexec
add-zsh-hook periodic owned_periodic
add-zsh-hook zshaddhistory owned_addhistory
add-zsh-hook zshexit owned_exit
add-zsh-hook zsh_directory_name owned_dirname
' || fail "create all-arrays fixture"

load_plugin all-arrays || fail "load all-arrays fixture"
unload_plugin all-arrays

integer all_arrays_ok=1
assert_absent chpwd_functions owned_chpwd "all hook arrays" || all_arrays_ok=0
assert_absent precmd_functions owned_precmd "all hook arrays" || all_arrays_ok=0
assert_absent preexec_functions owned_preexec "all hook arrays" || all_arrays_ok=0
assert_absent periodic_functions owned_periodic "all hook arrays" || all_arrays_ok=0
assert_absent zshaddhistory_functions owned_addhistory "all hook arrays" || all_arrays_ok=0
assert_absent zshexit_functions owned_exit "all hook arrays" || all_arrays_ok=0
assert_absent zsh_directory_name_functions owned_dirname "all hook arrays" || all_arrays_ok=0
(( all_arrays_ok )) && pass "unload removes plugin-owned entries from all seven standard hook arrays"

#
# 2. A plugin owns a hook entry it registered even for a function it did not
#    define. The function itself must survive, because the plugin did not
#    create it.
#

preexisting_helper() { : }

make_plugin borrower '
builtin autoload -Uz add-zsh-hook
add-zsh-hook precmd preexisting_helper
' || fail "create borrower fixture"

load_plugin borrower || fail "load borrower fixture"
unload_plugin borrower

integer borrower_ok=1
assert_absent precmd_functions preexisting_helper "borrowed registration" || borrower_ok=0
if (( ! ${+functions[preexisting_helper]} )); then
  fail "borrowed registration: unload deleted a function the plugin did not define"
  borrower_ok=0
fi
(( borrower_ok )) && pass "unload removes a registration for a function the plugin did not define"

#
# 3. Entries owned by another actor are preserved: those present before the
#    load, and those added after it.
#

user_before() { : }
add-zsh-hook precmd user_before

make_plugin coexist '
builtin autoload -Uz add-zsh-hook
coexist_hook() { : }
add-zsh-hook precmd coexist_hook
' || fail "create coexist fixture"

load_plugin coexist || fail "load coexist fixture"

user_after() { : }
add-zsh-hook precmd user_after

unload_plugin coexist

integer coexist_ok=1
assert_present precmd_functions user_before "foreign ownership" || coexist_ok=0
assert_present precmd_functions user_after "foreign ownership" || coexist_ok=0
assert_absent precmd_functions coexist_hook "foreign ownership" || coexist_ok=0
(( coexist_ok )) && pass "unload preserves hook entries owned by the user before and after the load"

add-zsh-hook -d precmd user_before 2>/dev/null
add-zsh-hook -d precmd user_after 2>/dev/null

#
# 4. A hook entry the plugin removed during load is recorded, so that unload
#    reports it rather than silently losing the user's registration. Removal
#    can be intentional, so restoration is not asserted; unload only has to
#    surface it. Like every Zi diff, the record is computed at unload, so the
#    contract is asserted through unload's own output.
#

user_victim() { : }
add-zsh-hook precmd user_victim

make_plugin remover '
builtin autoload -Uz add-zsh-hook
add-zsh-hook -d precmd user_victim
' || fail "create remover fixture"

load_plugin remover || fail "load remover fixture"

if in_hook precmd_functions user_victim; then
  fail "removal record: fixture did not remove the user entry, test is not exercising the case"
else
  # Unqualified unload, so the report is not suppressed by -q.
  typeset remover_output
  unsetopt warn_create_global
  remover_output="$(.zi-unload owner remover 2>&1)"
  if [[ $remover_output == *user_victim*precmd_functions* ]]; then
    pass "unload reports hook entries the plugin removed during load"
  else
    fail "removal record: unload did not report the removal of \`user_victim' from \$precmd_functions"
  fi
fi

add-zsh-hook -d precmd user_victim 2>/dev/null

#
# 5. Repeated loads of the same plugin do not leave a stale hook entry behind
#    after a single unload.
#
#    Scope: this asserts the hook-ownership contract only. The related defect
#    where the function itself survives repeated loads belongs to the per-load
#    identity work in #113, because Zi's function diff attributes a function to
#    the first load that defined it. That is deliberately not asserted here.
#

make_plugin repeated '
builtin autoload -Uz add-zsh-hook
repeated_hook() { : }
add-zsh-hook precmd repeated_hook
' || fail "create repeated fixture"

load_plugin repeated || fail "load repeated fixture (first)"
load_plugin repeated || fail "load repeated fixture (second)"
unload_plugin repeated

if assert_absent precmd_functions repeated_hook "repeated load"; then
  pass "a single unload clears hook entries left by repeated loads of one plugin"
fi

if (( failures )); then
  builtin print -u2 -r -- "# $failures assertion(s) failed"
  exit 1
fi

builtin print -r -- "# all hook-ownership assertions passed"
exit 0
