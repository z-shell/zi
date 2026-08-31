#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -R zsh
setopt pipe_fail

typeset project_root="${0:A:h:h}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-parallel-update-test.XXXXXXXX")" || exit 1
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

command mkdir -p -- \
  "$temp_root/home" \
  "$temp_root/zdotdir" \
  "$temp_root/data" \
  "$temp_root/cache" \
  "$temp_root/config" || fail "create isolated environment"

typeset -gx HOME="$temp_root/home"
typeset -gx ZDOTDIR="$temp_root/zdotdir"
typeset -gx XDG_DATA_HOME="$temp_root/data"
typeset -gx XDG_CACHE_HOME="$temp_root/cache"
typeset -gx XDG_CONFIG_HOME="$temp_root/config"
typeset -gAH ZI OPTS
ZI[BIN_DIR]="$project_root"
builtin source "$project_root/zi.zsh" >/dev/null || fail "source Zi"
builtin source "$project_root/lib/zsh/autoload.zsh" >/dev/null || fail "source autoload library"

new_case() {
  builtin emulate -L zsh
  local label="$1"
  REPLY="$temp_root/$label"
  command mkdir -p -- "$REPLY/snippets" "$REPLY/plugins" "$REPLY/tmp" ||
    fail "create $label fixture"
  ZI[SNIPPETS_DIR]="$REPLY/snippets"
  ZI[PLUGINS_DIR]="$REPLY/plugins"
  ZI[DEBUG_MODE]=0
  OPTS=()
  OPTS[value]=2
  OPTS[opt_-q,--quiet]=1
  OPTS[opt_-d,--debug]=0
  OPTS[opt_-s,--snippets]=1
  OPTS[opt_-l,--plugins]=0
  typeset -gx TMPDIR="$REPLY/tmp"
}

add_snippet() {
  builtin emulate -L zsh
  local case_root="$1" name="$2" url="$3"
  local metadata="$case_root/snippets/$name/._zi"
  command mkdir -p -- "$metadata" || fail "create $name snippet metadata"
  builtin print -r -- single >| "$metadata/mode" || fail "write $name mode"
  builtin print -r -- "$url" >| "$metadata/url" || fail "write $name URL"
}

add_invalid_snippet() {
  builtin emulate -L zsh
  local case_root="$1" name="$2"
  local metadata="$case_root/snippets/$name/._zi"
  command mkdir -p -- "$metadata" || fail "create invalid $name metadata"
  builtin print -r -- single >| "$metadata/mode" || fail "write invalid $name mode"
}

assert_temp_clean() {
  builtin emulate -L zsh
  local case_root="$1" label="$2"
  local -a remaining=( "$case_root/tmp"/*(ND) )
  (( ${#remaining} == 0 )) || fail "$label left temporary output behind"
}

run_parallel() {
  builtin emulate -L zsh
  local st=update
  .zi-update-all-parallel
}

# A valid job followed by malformed metadata must still be reaped.
(
  new_case trailing-invalid
  local case_root="$REPLY" completed="$REPLY/completed"
  add_snippet "$case_root" a-valid https://example.invalid/valid
  add_invalid_snippet "$case_root" z-invalid
  .zi-update-or-status-snippet() {
    command sleep 0.15
    builtin print -r -- "$2" >> "$completed"
  }
  run_parallel >/dev/null || fail "trailing invalid metadata returned failure"
  [[ -f $completed && "$(<$completed)" == https://example.invalid/valid ]] ||
    fail "trailing invalid metadata allowed a live job to escape"
  assert_temp_clean "$case_root" "trailing invalid metadata"
) || exit 1
pass "trailing invalid metadata does not skip the final wait"

# A child failure must become the aggregate updater status and remain visible.
(
  new_case child-failure
  local case_root="$REPLY"
  add_snippet "$case_root" failing https://example.invalid/failing
  .zi-update-or-status-snippet() {
    builtin print -r -- "simulated update failure"
    return 7
  }
  run_parallel >/dev/null
  local update_rc=$?
  (( update_rc == 7 )) || fail "child status 7 became $update_rc"
  assert_temp_clean "$case_root" "child failure"
) || exit 1
pass "child failures propagate from the parallel updater"

# The configured bound is an upper limit, not a threshold exceeded by one.
(
  new_case concurrency
  local case_root="$REPLY" event_log="$REPLY/events"
  local index
  for index in {1..5}; do
    add_snippet "$case_root" "$index" "https://example.invalid/$index"
  done
  .zi-update-or-status-snippet() {
    builtin print -r -- start >> "$event_log"
    command sleep 0.12
    builtin print -r -- end >> "$event_log"
  }
  run_parallel >/dev/null || fail "bounded parallel update failed"
  integer active=0 peak=0
  local event
  while IFS= builtin read -r event; do
    if [[ $event == start ]]; then
      (( ++active ))
      (( active > peak )) && peak=$active
    else
      (( --active ))
    fi
  done < "$event_log"
  (( peak == 2 && active == 0 )) ||
    fail "parallel limit 2 observed peak $peak with $active unfinished: ${(j: :)${(@f)$(<$event_log)}}"
  assert_temp_clean "$case_root" "bounded parallel update"
) || exit 1
pass "parallel updates honor the configured concurrency limit"

# Snippet and plugin phases own separate complete job batches.
(
  new_case both-phases
  local case_root="$REPLY" phase_log="$REPLY/phases"
  OPTS[opt_-s,--snippets]=0
  OPTS[opt_-l,--plugins]=0
  add_snippet "$case_root" snippet https://example.invalid/snippet
  command mkdir -p -- "$case_root/plugins/owner---plugin/._zi" || fail "create plugin fixture"
  builtin print -r -- 1 >| "$case_root/plugins/owner---plugin/._zi/is_release" ||
    fail "mark plugin fixture as a release"
  .zi-update-or-status-snippet() {
    builtin print -r -- snippet >> "$phase_log"
  }
  .zi-update-or-status() {
    builtin print -r -- plugin >> "$phase_log"
  }
  run_parallel >/dev/null || fail "combined phases failed"
  local -a phases=( "${(@f)$(<$phase_log)}" )
  [[ "${(j: :)phases}" == "snippet plugin" ]] ||
    fail "combined phases ran ${(j: :)phases}"
  assert_temp_clean "$case_root" "combined phases"
) || exit 1
pass "snippet and plugin phases flush independently"

# Output follows discovery order even when jobs complete out of order.
(
  new_case output-order
  local case_root="$REPLY" output
  add_snippet "$case_root" first https://example.invalid/first
  add_snippet "$case_root" second https://example.invalid/second
  .zi-update-or-status-snippet() {
    [[ $2 == */first ]] && command sleep 0.12 || command sleep 0.01
    builtin print -r -- "${2:t}"
    builtin print -r -- 1 >| "$PUFILE.ind"
  }
  output="$(run_parallel)" || fail "ordered output update failed"
  [[ $output == $'first\nsecond' ]] || fail "parallel output order was ${(qqq)output}"
  assert_temp_clean "$case_root" "ordered output"
) || exit 1
pass "parallel output is deterministic"

# Pattern captures are scoped and the temporary directory is removed on TERM.
(
  new_case interruption
  local case_root="$REPLY" started="$REPLY/started" result="$REPLY/result"
  add_snippet "$case_root" interrupted https://example.invalid/interrupted
  builtin unset MATCH MBEGIN MEND
  .zi-update-or-status-snippet() {
    builtin print -r -- started >| "$started"
    command sleep 10
  }
  (
    run_parallel >/dev/null
    builtin print -r -- $? >| "$result"
  ) &
  local updater_pid=$!
  integer attempt=0
  while [[ ! -f $started && attempt -lt 100 ]]; do
    command sleep 0.02
    (( ++attempt ))
  done
  [[ -f $started ]] || fail "interrupted child did not start"
  builtin kill -TERM "$updater_pid" || fail "signal parallel updater"
  wait "$updater_pid" || fail "interrupted updater wrapper failed"
  [[ -f $result && "$(<$result)" == 143 ]] || fail "TERM status was not preserved"
  (( ! ${+parameters[MATCH]} && ! ${+parameters[MBEGIN]} && ! ${+parameters[MEND]} )) ||
    fail "pattern capture parameters leaked globally"
  assert_temp_clean "$case_root" "interrupted update"
) || exit 1
pass "parallel updater scopes captures and cleans up after interruption"
