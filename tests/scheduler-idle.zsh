#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -R zsh
setopt pipe_fail

typeset project_root=${0:A:h:h}
typeset temp_root
temp_root=$(command mktemp -d "${TMPDIR:-/tmp}/zi-scheduler-idle.XXXXXXXX") || exit 1
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

typeset -gx HOME=$temp_root/home
typeset -gx ZDOTDIR=$temp_root/zdotdir
typeset -gx XDG_CACHE_HOME=$temp_root/cache
typeset -gx XDG_CONFIG_HOME=$temp_root/config
typeset -gx XDG_DATA_HOME=$temp_root/data
command mkdir -p -- "$HOME" "$ZDOTDIR"

fail() {
  builtin emulate -L zsh
  builtin print -ru2 -- "not ok - $1"
  exit 1
}

pass() {
  builtin emulate -L zsh
  builtin print -r -- "ok - $1"
}

in_hook() {
  builtin emulate -L zsh
  local array_name=$1 entry=$2
  local -a current=( "${(@P)array_name}" )
  (( ${current[(I)$entry]} > 0 ))
}

clear_events() {
  builtin emulate -L zsh
  while (( ${#zsh_scheduled_events} )); do
    sched -1 || return 1
  done
}

typeset -gAH ZI
ZI[BIN_DIR]=$project_root
builtin source "$project_root/zi.zsh" >/dev/null || fail 'source Zi'
zmodload zsh/sched || fail 'load scheduler module'
clear_events || fail 'clear initial events'

# The test exercises scheduler state, not ZLE descriptor integration.
zle() { builtin emulate -L zsh; return 0; }

in_hook precmd_functions @zi-scheduler || fail 'source registers the dormant precmd hook'
@zi-scheduler || fail 'idle precmd check returns success'
(( ${#zsh_scheduled_events} == 0 )) || fail 'idle precmd check armed a timer'
[[ -n ${ZI[START_TIME]} ]] || fail 'idle precmd check did not initialize timing'
in_hook precmd_functions @zi-scheduler || fail 'idle precmd hook was removed'
in_hook chpwd_functions @zi-scheduler && fail 'idle scheduler registered a chpwd hook'
pass 'idle scheduler stays dormant'

ZI_TASKS+=( "$(( EPOCHSECONDS + 60 ))+0+1 p 1 _ owner/repo" )
@zi-scheduler || fail 'pending task activates scheduler'
(( ${#zsh_scheduled_events} == 1 )) || fail 'pending task did not arm one timer'
in_hook chpwd_functions @zi-scheduler || fail 'active scheduler did not register chpwd hook'
in_hook precmd_functions @zi-scheduler && fail 'active scheduler kept the precmd hook'
pass 'pending work activates scheduler'

clear_events || fail 'clear active event'
ZI_TASKS=( '<no-data>' )
@zi-scheduler following || fail 'drained scheduler returns success'
(( ${#zsh_scheduled_events} == 0 )) || fail 'drained scheduler rearmed a timer'
in_hook precmd_functions @zi-scheduler || fail 'drained scheduler did not restore precmd hook'
in_hook chpwd_functions @zi-scheduler && fail 'drained scheduler kept chpwd hook'
pass 'drained scheduler returns to dormant state'

ZI_TASKS+=( "$(( EPOCHSECONDS + 60 ))+0+1 p 1 _ owner/repo" )
@zi-scheduler || fail 'later task reactivates scheduler'
(( ${#zsh_scheduled_events} == 1 )) || fail 'later task did not rearm scheduler'
pass 'later work reactivates scheduler'

clear_events || fail 'clear final event'
