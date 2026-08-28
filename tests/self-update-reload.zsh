#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -LR zsh
setopt errexit pipefail

typeset project_root="${0:A:h:h}"
typeset git_bin="${commands[git]}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-self-update-test.XXXXXXXX")"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

typeset -gx HOME="${temp_root}/home"
typeset -gx ZDOTDIR="${temp_root}/zdotdir"
typeset -gx XDG_DATA_HOME="${temp_root}/data"
typeset -gx XDG_CACHE_HOME="${temp_root}/cache"
typeset -gx XDG_CONFIG_HOME="${temp_root}/config"
typeset -gx TMPDIR="${temp_root}/tmp"
typeset -gx ZPFX="${temp_root}/prefix"
command mkdir -p -- \
  "$HOME" \
  "$ZDOTDIR" \
  "$XDG_DATA_HOME" \
  "$XDG_CACHE_HOME" \
  "$XDG_CONFIG_HOME" \
  "$TMPDIR" \
  "$ZPFX"

fail() {
  print -u2 -r -- "not ok - $1"
  exit 1
}

pass() {
  print -r -- "ok - $1"
}

new_checkout() {
  local label="$1"
  REPLY="${temp_root}/${label}"
  "$git_bin" clone -q --no-hardlinks "$project_root" "$REPLY"
  "$git_bin" -C "$REPLY" config user.name "Self Update Test"
  "$git_bin" -C "$REPLY" config user.email "self-update-test@example.invalid"
  "$git_bin" -C "$REPLY" config commit.gpgsign false
  command cp -- "$project_root/zi.zsh" "$REPLY/zi.zsh"
  command cp -- "$project_root/lib/zsh/autoload.zsh" "$REPLY/lib/zsh/autoload.zsh"
  "$git_bin" -C "$REPLY" add zi.zsh lib/zsh/autoload.zsh
  if ! "$git_bin" -C "$REPLY" diff --cached --quiet; then
    "$git_bin" -C "$REPLY" commit -qm "test: install self-update code under test"
  fi
  command rm -f -- "$REPLY"/*.zwc(N) "$REPLY"/lib/zsh/*.zwc(N)
}

commit_change() {
  local checkout="$1" file_path="$2" content="$3"
  print -r -- "$content" >> "${checkout}/${file_path}"
  "$git_bin" -C "$checkout" add "$file_path"
  "$git_bin" -C "$checkout" commit -qm "test: change reload fixture"
  REPLY="$("$git_bin" -C "$checkout" rev-parse HEAD)"
}

load_zi() {
  typeset -gAH ZI
  ZI[BIN_DIR]="$1"
  builtin source "${ZI[BIN_DIR]}/zi.zsh" >/dev/null || fail "source Zi fixture"
  builtin source "${ZI[BIN_DIR]}/lib/zsh/autoload.zsh" >/dev/null || fail "source autoload fixture"
  [[ ${ZI[HOME_DIR]} == "${XDG_DATA_HOME}/zi" ]] || fail "Zi fixture uses isolated home"
  [[ ${ZI[CACHE_DIR]} == "${XDG_CACHE_HOME}/zi" ]] || fail "Zi fixture uses isolated cache"
  [[ ${ZI[CONFIG_DIR]} == "${XDG_CONFIG_HOME}/zi" ]] || fail "Zi fixture uses isolated config"
  [[ -d ${ZI[HOME_DIR]} ]] || fail "Zi fixture prepares isolated home"
  [[ ${ZI[HOME_LAYOUT]} == xdg ]] || fail "Zi fixture preserves resolved layout"
}

# A current checkout is a true no-op: it neither compiles nor changes the
# revision baseline.
(
  new_checkout no-op
  typeset checkout="$REPLY"
  load_zi "$checkout"
  typeset loaded="${ZI[LOADED_REVISION]}"
  typeset checkout_revision="$("$git_bin" -C "$checkout" rev-parse HEAD)"

  [[ $loaded == "$checkout_revision" ]] || fail "initial load records checkout revision"
  .zi-auto-reload --quiet || fail "no-op reload returns success"
  [[ ${ZI[LOADED_REVISION]} == "$loaded" ]] || fail "no-op preserves loaded revision"
  [[ ! -e "${checkout}/zi.zsh.zwc" ]] || fail "no-op does not compile"
)
pass "no-op reload"

# A successful fast-forward initiated by this shell reloads the merged revision
# before self-update returns.
(
  new_checkout current-shell
  typeset checkout="$REPLY"
  "$git_bin" -C "$checkout" switch -q -C main
  typeset remote="${temp_root}/current-shell-remote.git"
  typeset publisher="${temp_root}/current-shell-publisher"
  "$git_bin" clone -q --bare "$checkout" "$remote"
  "$git_bin" -C "$checkout" remote set-url origin "$remote"
  "$git_bin" clone -q "$remote" "$publisher"
  "$git_bin" -C "$publisher" config user.name "Self Update Publisher"
  "$git_bin" -C "$publisher" config user.email "publisher@example.invalid"
  "$git_bin" -C "$publisher" config commit.gpgsign false

  load_zi "$checkout"
  typeset resolved_home="${ZI[HOME_DIR]}"
  typeset resolved_layout="${ZI[HOME_LAYOUT]}"
  print -r -- '# current-shell revision' >> "${publisher}/lib/zsh/additional.zsh"
  "$git_bin" -C "$publisher" add lib/zsh/additional.zsh
  "$git_bin" -C "$publisher" commit -qm "test: publish self-update fixture"
  "$git_bin" -C "$publisher" push -q origin main
  typeset published_revision="$("$git_bin" -C "$publisher" rev-parse HEAD)"
  typeset output_file="${temp_root}/current-shell-output" output

  zi self-update --quiet >"$output_file" 2>&1 || fail "current-shell self-update returns success"
  output="$(<"$output_file")"
  [[ -z $output ]] || fail "current-shell quiet update emits no progress output"
  [[ $("$git_bin" -C "$checkout" rev-parse HEAD) == "$published_revision" ]] || fail "self-update fast-forwards checkout"
  [[ ${ZI[LOADED_REVISION]} == "$published_revision" ]] || fail "self-update loads merged revision"
  [[ ${ZI[HOME_DIR]} == "$resolved_home" ]] || fail "self-update reload preserves resolved home"
  [[ ${ZI[HOME_LAYOUT]} == "$resolved_layout" ]] || fail "self-update reload preserves resolved layout"
)
pass "current-shell self-update"

# Fetch failures must propagate instead of falling through to the up-to-date
# path and reporting success.
(
  new_checkout fetch-failure
  typeset checkout="$REPLY"
  load_zi "$checkout"
  typeset loaded="${ZI[LOADED_REVISION]}"
  "$git_bin" -C "$checkout" remote set-url origin "${temp_root}/missing-remote.git"

  if zi self-update --quiet >/dev/null 2>&1; then
    fail "fetch failure returns nonzero"
  fi
  [[ ${ZI[LOADED_REVISION]} == "$loaded" ]] || fail "fetch failure preserves baseline"
)
pass "fetch failure"

# A failed changelog query after a successful fetch must also propagate rather
# than being mistaken for an empty, up-to-date log.
(
  new_checkout log-failure
  typeset checkout="$REPLY"
  load_zi "$checkout"
  typeset loaded="${ZI[LOADED_REVISION]}"
  typeset fake_bin="${temp_root}/fake-git-bin"
  command mkdir -p "$fake_bin"
  print -r -- '#!/bin/sh' > "${fake_bin}/git"
  print -r -- 'if [ "$1" = log ]; then exit 42; fi' >> "${fake_bin}/git"
  print -r -- "exec ${(q)git_bin} \"\$@\"" >> "${fake_bin}/git"
  command chmod +x "${fake_bin}/git"

  PATH="${fake_bin}:${PATH}"
  if zi self-update --quiet >/dev/null 2>&1; then
    fail "log failure returns nonzero"
  fi
  [[ ${ZI[LOADED_REVISION]} == "$loaded" ]] || fail "log failure preserves baseline"
)
pass "log failure"

# A revision installed by another shell is detected even when no fetch or merge
# is needed in this process.
(
  new_checkout second-shell
  typeset checkout="$REPLY"
  "$git_bin" -C "$checkout" switch -q -C main
  typeset remote="${temp_root}/second-shell-remote.git"
  "$git_bin" clone -q --bare "$checkout" "$remote"
  "$git_bin" -C "$checkout" remote set-url origin "$remote"
  load_zi "$checkout"
  commit_change "$checkout" lib/zsh/additional.zsh '# second-shell revision'
  typeset changed_revision="$REPLY"

  zi self-update --quiet >/dev/null 2>&1 || fail "second-shell self-update returns success"
  [[ ${ZI[LOADED_REVISION]} == "$changed_revision" ]] || fail "second-shell revision becomes loaded"
  [[ -e "${checkout}/zi.zsh.zwc" ]] || fail "second-shell reload compiles exact sources"
)
pass "update performed by another shell"

# Quiet mode suppresses successful progress output while still performing the
# reload and updating the revision baseline.
(
  new_checkout quiet
  typeset checkout="$REPLY"
  load_zi "$checkout"
  commit_change "$checkout" lib/zsh/additional.zsh '# quiet revision'
  typeset changed_revision="$REPLY" output
  typeset output_file="${temp_root}/quiet-output"

  .zi-auto-reload --quiet >"$output_file" 2>&1 || fail "quiet reload returns success"
  output="$(<"$output_file")"
  [[ -z $output ]] || fail "quiet reload emits no progress output"
  [[ ${ZI[LOADED_REVISION]} == "$changed_revision" ]] || fail "quiet reload updates baseline"
)
pass "quiet reload"

# A compilation error identifies the exact file, returns nonzero, and leaves
# the old revision baseline in place so a later attempt can retry.
(
  new_checkout compile-failure
  typeset checkout="$REPLY"
  load_zi "$checkout"
  typeset loaded="${ZI[LOADED_REVISION]}" output
  commit_change "$checkout" lib/zsh/git-process-output.zsh 'if then'
  typeset output_file="${temp_root}/compile-failure-output"

  if .zi-auto-reload --quiet >"$output_file" 2>&1; then
    fail "compile failure returns nonzero"
  fi
  output="$(<"$output_file")"
  [[ $output == *"lib/zsh/git-process-output.zsh"* ]] || fail "compile failure names path"
  [[ ${ZI[LOADED_REVISION]} == "$loaded" ]] || fail "compile failure preserves baseline"
)
pass "compile failure"

# All files compile before any source is attempted. A source error then names
# the exact file and does not advance the revision baseline.
(
  new_checkout source-failure
  typeset checkout="$REPLY"
  load_zi "$checkout"
  typeset loaded="${ZI[LOADED_REVISION]}" output
  commit_change "$checkout" lib/zsh/additional.zsh 'return 42'
  typeset output_file="${temp_root}/source-failure-output"

  if .zi-auto-reload --quiet >"$output_file" 2>&1; then
    fail "source failure returns nonzero"
  fi
  output="$(<"$output_file")"
  [[ $output == *"lib/zsh/additional.zsh"* ]] || fail "source failure names path"
  [[ ${ZI[LOADED_REVISION]} == "$loaded" ]] || fail "source failure preserves baseline"
)
pass "source failure"

# Even an apparently current checkout must synchronize before accepting the
# no-op. Another updater can already hold the lock and be about to advance HEAD.
(
  new_checkout no-op-race
  typeset checkout="$REPLY"
  load_zi "$checkout"
  typeset lock_file="${checkout}/.git/zi-self-update.lock"
  typeset ready_file="${temp_root}/no-op-race-ready"
  : > "$lock_file"

  zsh -fc '
    zmodload zsh/system || exit 1
    zsystem flock -f lock_fd "$1" || exit 1
    print -r -- ready > "$2"
    sleep 0.2
    print -r -- "# no-op race revision" >> "$3/lib/zsh/additional.zsh"
    "$4" -C "$3" add lib/zsh/additional.zsh
    "$4" -C "$3" commit -qm "test: advance an apparently current checkout"
  ' _ "$lock_file" "$ready_file" "$checkout" "$git_bin" &
  typeset holder_pid=$!
  integer attempts=0
  while [[ ! -e $ready_file && attempts -lt 50 ]]; do
    sleep 0.02
    (( ++attempts ))
  done
  [[ -e $ready_file ]] || fail "no-op race lock holder becomes ready"

  .zi-auto-reload --quiet || fail "no-op race reload returns success"
  wait "$holder_pid" || fail "no-op race checkout update succeeds"
  typeset final_revision="$("$git_bin" -C "$checkout" rev-parse HEAD)"
  [[ ${ZI[LOADED_REVISION]} == "$final_revision" ]] || fail "no-op waits for concurrent checkout update"
)
pass "concurrent update starts during no-op check"

# Re-read HEAD after acquiring the lock. A concurrent updater may advance the
# checkout while this shell waits, and the loaded baseline must match the files
# that were actually compiled and sourced.
(
  new_checkout revision-during-lock-wait
  typeset checkout="$REPLY"
  load_zi "$checkout"
  commit_change "$checkout" lib/zsh/additional.zsh '# first waiting revision'
  typeset lock_file="${checkout}/.git/zi-self-update.lock"
  typeset ready_file="${temp_root}/revision-wait-ready"
  : > "$lock_file"

  zsh -fc '
    zmodload zsh/system || exit 1
    zsystem flock -f lock_fd "$1" || exit 1
    print -r -- ready > "$2"
    sleep 0.2
    print -r -- "# newer waiting revision" >> "$3/lib/zsh/additional.zsh"
    "$4" -C "$3" add lib/zsh/additional.zsh
    "$4" -C "$3" commit -qm "test: advance checkout while lock is held"
  ' _ "$lock_file" "$ready_file" "$checkout" "$git_bin" &
  typeset holder_pid=$!
  integer attempts=0
  while [[ ! -e $ready_file && attempts -lt 50 ]]; do
    sleep 0.02
    (( ++attempts ))
  done
  [[ -e $ready_file ]] || fail "revision lock holder becomes ready"

  .zi-auto-reload --quiet || fail "reload after lock wait returns success"
  wait "$holder_pid" || fail "concurrent checkout update succeeds"
  typeset final_revision="$("$git_bin" -C "$checkout" rev-parse HEAD)"
  [[ ${ZI[LOADED_REVISION]} == "$final_revision" ]] || fail "reload records post-lock revision"
)
pass "revision changes during lock wait"

# A contending process holds the same advisory lock. The reload times out,
# returns nonzero, and remains retryable.
(
  new_checkout lock-contention
  typeset checkout="$REPLY"
  load_zi "$checkout"
  typeset loaded="${ZI[LOADED_REVISION]}"
  commit_change "$checkout" lib/zsh/additional.zsh '# lock contention revision'
  typeset lock_file="${checkout}/.git/zi-self-update.lock"
  typeset ready_file="${temp_root}/lock-ready" output
  : > "$lock_file"

  zsh -fc '
    zmodload zsh/system || exit 1
    zsystem flock -f lock_fd "$1" || exit 1
    print -r -- ready > "$2"
    sleep 5
  ' _ "$lock_file" "$ready_file" &
  typeset holder_pid=$!
  integer attempts=0
  while [[ ! -e $ready_file && attempts -lt 50 ]]; do
    sleep 0.02
    (( ++attempts ))
  done
  [[ -e $ready_file ]] || fail "lock holder becomes ready"

  ZI[SELF_UPDATE_LOCK_TIMEOUT]=0.1
  typeset output_file="${temp_root}/lock-contention-output"
  if .zi-auto-reload --quiet >"$output_file" 2>&1; then
    fail "lock contention returns nonzero"
  fi
  output="$(<"$output_file")"
  kill "$holder_pid" 2>/dev/null || true
  wait "$holder_pid" 2>/dev/null || true
  [[ $output == *"lock"* ]] || fail "lock contention is reported"
  [[ ${ZI[LOADED_REVISION]} == "$loaded" ]] || fail "lock contention preserves baseline"
)
pass "lock contention"
