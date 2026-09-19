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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-pack-service-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/work" || fail "create isolated environment"

# A package whose default profile declares service''. The git'' ice keeps
# .zi-get-package on the clone path, which the stubbed installer below serves
# without the network. pack'./file:profile' reads the manifest from disk.
builtin print -r -- '{"zsh-data":{"plugin-info":{"user":"fixture","plugin":"svc"},"zi-ices":{"default":{"git":"","id-as":"svc-fixture","service":"svc-fixture","pick":"svc.service.zsh"}}}}' \
  > "${temp_root}/work/package.json" || fail "write manifest"

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  FIXTURE_LOG="${temp_root}/sourced.log" \
  zsh -f <<'ZSH' || fail "a fresh pack'' install with a service'' profile is not dispatched as a service"
builtin emulate -R zsh
setopt pipe_fail

typeset -gAH ZI
ZI[BIN_DIR]=$ZI_TEST_CHECKOUT
builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1
builtin cd -q "${FIXTURE_LOG:h}/work" || return 1

# The dispatcher schedules services only with the scheduler present, which
# sourcing zi.zsh established through zsh/datetime.
(( ZI[HAVE_SCHEDULER] )) || { builtin print -u2 -r -- "scheduler unavailable"; return 1; }

# Load the installer so .zi-get-package exists, then replace the network clone
# with a fixture whose plugin records whether it was sourced by the service
# runner (ZSRV_ID set) or synchronously (ZSRV_ID unset). The stub stores the
# disk ices the way the real installer does, so the second load finds them.
builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
builtin source "${ZI[BIN_DIR]}/lib/zsh/side.zsh" || return 1
typeset -a installs
.zi-setup-plugin-dir() {
  local id_as=$3 local_path
  local_path=${ZI[PLUGINS_DIR]}/${3//\//---}
  command mkdir -p -- "$local_path" || return 1
  builtin print -r -- 'builtin print -r -- "sourced ZSRV_ID=${ZSRV_ID-unset}" >> "$FIXTURE_LOG"' \
    > "$local_path/svc.service.zsh" || return 1
  .zi-store-ices "$local_path/._zi" ICE "" "" "" ""
  installs+=( "$id_as" )
}

sourced_lines() {
  [[ -e $FIXTURE_LOG ]] || { builtin print -r -- 0; return 0; }
  local -a lines
  lines=( "${(@f)$(<$FIXTURE_LOG)}" )
  builtin print -r -- $#lines
}

integer status_first
zi pack'./package.json:default' for @svc-fixture
status_first=$?
(( status_first == 0 )) || {
  builtin print -u2 -r -- "first install: expected status 0, got ${status_first}"
  return 1
}
(( $#installs == 1 )) || {
  builtin print -u2 -r -- "first install: expected one install, got ${#installs}"
  return 1
}
(( $(sourced_lines) == 0 )) || {
  builtin print -u2 -r -- "first install: the plugin was sourced synchronously: $(<$FIXTURE_LOG)"
  return 1
}
(( ${ZI_TASKS[(I)* p1 * svc-fixture*]} )) || {
  builtin print -u2 -r -- "first install: no service task was scheduled: ${(j:|:)ZI_TASKS}"
  return 1
}
[[ -e ${ZI[PLUGINS_DIR]}/svc-fixture/._zi/service && $(<${ZI[PLUGINS_DIR]}/svc-fixture/._zi/service) == svc-fixture ]] || {
  builtin print -u2 -r -- "first install: the service'' disk ice was not stored"
  return 1
}

# The scheduled task carries the profile's ices, so the runner can start the
# service without reading the manifest again.
local -a task_words
task_words=( ${(z)ZI_TASKS[${ZI_TASKS[(I)* p1 * svc-fixture*]}]} )
local -A task_ice
task_ice=( "${(@Q)${(z@)ZI[WAIT_ICE_${task_words[3]}]}}" )
[[ ${task_ice[service]} == svc-fixture && ${+task_ice[pack]} == 1 ]] || {
  builtin print -u2 -r -- "first install: the scheduled task lacks the profile ices: ${(kv)task_ice}"
  return 1
}

# Second load: the package is installed, the disk ices name the service, and
# the behaviour must be the one the first load now has.
integer tasks_before=$#ZI_TASKS
zi pack'./package.json:default' for @svc-fixture || {
  builtin print -u2 -r -- "second load: expected status 0, got $?"
  return 1
}
(( $#installs == 1 )) || { builtin print -u2 -r -- "second load: reinstalled the package"; return 1; }
(( $(sourced_lines) == 0 )) || { builtin print -u2 -r -- "second load: sourced synchronously"; return 1; }
(( $#ZI_TASKS == tasks_before + 1 )) || { builtin print -u2 -r -- "second load: no service task was scheduled"; return 1; }

# A caller-requested cloneonly'' keeps its download-only contract: the package
# is installed, nothing is sourced, and no service task is scheduled.
builtin print -r -- '{"zsh-data":{"plugin-info":{"user":"fixture","plugin":"svc"},"zi-ices":{"default":{"git":"","id-as":"svc-cloneonly","service":"svc-cloneonly","pick":"svc.service.zsh"}}}}' \
  > ./cloneonly.json || return 1
tasks_before=$#ZI_TASKS
zi pack'./cloneonly.json:default' cloneonly'' for @svc-cloneonly || {
  builtin print -u2 -r -- "cloneonly: expected status 0, got $?"
  return 1
}
(( $#installs == 2 )) || { builtin print -u2 -r -- "cloneonly: the package was not installed"; return 1; }
(( $(sourced_lines) == 0 )) || { builtin print -u2 -r -- "cloneonly: sourced the plugin"; return 1; }
(( $#ZI_TASKS == tasks_before )) || { builtin print -u2 -r -- "cloneonly: scheduled a service task: ${(j:|:)ZI_TASKS}"; return 1; }

# A command-supplied turbo ice queues an ordinary task before the profile is
# known. When the scheduler runs that task and the install reveals service'',
# the task runner itself must start the service: the dispatcher that promotes
# tasks is no longer on the stack. zpty is stubbed to observe the request.
builtin print -r -- '{"zsh-data":{"plugin-info":{"user":"fixture","plugin":"svc"},"zi-ices":{"default":{"git":"","id-as":"svc-waited","service":"svc-waited","pick":"svc.service.zsh"}}}}' \
  > ./waited.json || return 1
typeset -a zpty_calls
zpty() { zpty_calls+=( "$*" ); }
tasks_before=$#ZI_TASKS
zi wait'0' pack'./waited.json:default' for @svc-waited || {
  builtin print -u2 -r -- "waited: expected status 0, got $?"
  return 1
}
(( $#installs == 2 )) || { builtin print -u2 -r -- "waited: the first dispatch must only queue the task"; return 1; }
(( $#ZI_TASKS == tasks_before + 1 )) || { builtin print -u2 -r -- "waited: no task was queued"; return 1; }
task_words=( ${(z)ZI_TASKS[-1]} )
[[ ${task_words[2]} == p ]] || { builtin print -u2 -r -- "waited: expected an ordinary p task, got ${task_words[2]}"; return 1; }
# .zi-run-task returns 1 for a finished one-shot task (0 means re-queue), so
# only its effects are asserted.
.zi-run-task 1 "${(@z)ZI_TASKS[-1]}"
(( $#installs == 3 )) || { builtin print -u2 -r -- "waited: the task runner did not install the package"; return 1; }
(( $(sourced_lines) == 0 )) || { builtin print -u2 -r -- "waited: sourced the plugin synchronously"; return 1; }
(( $#zpty_calls == 1 )) && [[ ${zpty_calls[1]} == *"svc-waited"*".zi-service p"* ]] || {
  builtin print -u2 -r -- "waited: the task runner did not start the service: ${(j:|:)zpty_calls}"
  return 1
}
unfunction zpty

# A package that is both is-snippet'' and service'' still loads synchronously
# through .zi-load-snippet (that path returns before the deferral), so it must
# not be queued a second time as a service task.
builtin print -r -- '{"zsh-data":{"plugin-info":{"user":"fixture","plugin":"svc","url":"https://example.invalid/svc.zsh"},"zi-ices":{"default":{"is-snippet":"","id-as":"svc-snippet","service":"svc-snippet"}}}}' \
  > ./snippet.json || return 1
typeset -a snippet_loads
.zi-load-snippet() { snippet_loads+=( "$*" ); return 0; }
tasks_before=$#ZI_TASKS
zi pack'./snippet.json:default' for @svc-snippet || {
  builtin print -u2 -r -- "snippet package: expected status 0, got $?"
  return 1
}
(( $#snippet_loads == 1 )) || { builtin print -u2 -r -- "snippet package: expected one snippet load, got ${#snippet_loads}"; return 1; }
(( $#ZI_TASKS == tasks_before )) || { builtin print -u2 -r -- "snippet package: queued a service task for a load that was not deferred: ${ZI_TASKS[-1]}"; return 1; }
[[ -z ${ZI[pack-service-deferred]} ]] || { builtin print -u2 -r -- "snippet package: stale deferral flag"; return 1; }
unfunction .zi-load-snippet

# The service runner performs the deferred load itself with ZSRV_ID set. It
# must not be deferred again: emulate .zi-run-task's ICE restore and the
# runner's environment, then load.
() {
  local -A ICE ZI_ICE
  ICE=( "${(@Q)${(z@)ZI[WAIT_ICE_${task_words[3]}]}}" )
  ZI_ICE=( "${(kv)ICE[@]}" )
  typeset -g ZSRV_ID=svc-fixture
  .zi-load svc-fixture "" load
} || { builtin print -u2 -r -- "runner load: expected status 0, got $?"; return 1; }
(( $(sourced_lines) == 1 )) && [[ $(<$FIXTURE_LOG) == "sourced ZSRV_ID=svc-fixture" ]] || {
  builtin print -u2 -r -- "runner load: the service runner did not source the plugin: $(<$FIXTURE_LOG 2>/dev/null)"
  return 1
}
ZSH

builtin print -r -- "ok - a fresh pack'' install with a service'' profile is scheduled as a service instead of being sourced synchronously"
