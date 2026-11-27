#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# Auto-update is wired into Zi's source-executed startup path, disabled by
# default and lazily sourced only when enabled. `.zi-au` checks a timestamp;
# when an update is due it asks for confirmation in an interactive shell and
# then updates in the foreground, printing directly to stdout. Non-interactive
# shells skip silently.

builtin emulate -R zsh
zmodload zsh/datetime
zmodload -F zsh/stat b:zstat

typeset project_root=${0:A:h:h}
source "${0:A:h}/lib/sandbox.zsh" auto-update

typeset -gx HOME=$temp_root/home
typeset -gx ZDOTDIR=$temp_root/home
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

typeset -gAH ZI
ZI[BIN_DIR]=$project_root
# User-supplied state paths with a leading ~ must be expanded at source time.
ZI[UPDATE_STAMP]='~/.zi-au/last-update'
ZI[UPDATE_LOCK]='~/.zi-au/update.lock'

# The default is off: no library is loaded and no auto-update function exists.
cat > "$temp_root/au-default-child.zsh" <<CHILD
#!/usr/bin/env zsh
builtin emulate -R zsh
typeset -gAH ZI
ZI[BIN_DIR]='$project_root'
builtin source '$project_root/zi.zsh'
print "AU-VALUE=\${ZI[AUTO_UPDATE]}"
if (( \${+functions[.zi-au]} )); then
  print 'AU-DEFINED'
else
  print 'AU-ABSENT'
fi
print 'DEFAULT-DONE'
CHILD
typeset default_out
default_out="$(zsh -f "$temp_root/au-default-child.zsh" 2>&1)"
[[ $default_out == *AU-VALUE=0* ]] || fail 'auto-update default is not 0'
[[ $default_out == *AU-ABSENT* ]] || fail 'auto-update lib loaded by default'
[[ $default_out != *AU-DEFINED* ]] || fail '.zi-au defined by default'
[[ $default_out == *DEFAULT-DONE* ]] || fail 'default child completed'
pass 'auto-update is disabled by default and loads no library'

# Explicitly opt in for the behavior checks below. A fresh stamp keeps the
# startup check from launching an update during source; later checks remove it.
ZI[AUTO_UPDATE]=1
command mkdir -p -- "$HOME/.zi-au" || fail 'create state directory'
command touch -- "$HOME/.zi-au/last-update" || fail 'create fresh stamp'
builtin source "$project_root/zi.zsh" >/dev/null || fail 'source Zi'

[[ ${ZI[AUTO_UPDATE]:-unset} == 1 ]] || fail 'explicit auto-update opt-in'
pass 'explicit auto-update opt-in is preserved'

[[ ${ZI[UPDATE_INTERVAL]:-unset} == 604800 ]] || fail 'weekly interval default'
[[ ${ZI[UPDATE_RETRY]:-unset} == 300 ]] || fail 'five-minute retry default'
pass 'weekly interval and five-minute retry are defaults'

[[ ${ZI[UPDATE_STAMP]} == "$HOME"/.zi-au/last-update ]] || fail 'UPDATE_STAMP tilde expansion'
[[ ${ZI[UPDATE_LOCK]} == "$HOME"/.zi-au/update.lock ]] || fail 'UPDATE_LOCK tilde expansion'
pass 'auto-update state paths are configurable and tilde-expanded'

# Sync only: no log configuration, viewer or output helpers are shipped.
[[ -z ${ZI[UPDATE_LOG]:-} ]] || fail 'UPDATE_LOG should not exist'
(( ! ${+functions[zi-au-log]} )) || fail 'zi-au-log should not exist'
(( ! ${+functions[.zi-au-write-log]} )) || fail 'log writer should not exist'
(( ! ${+functions[.zi-au-output]} )) || fail 'output router should not exist'
pass 'sync-only build has no log file machinery'

(( ${+functions[.zi-au]} )) || fail '.zi-au is defined at source'
(( ${+functions[.zi-au-confirm]} )) || fail '.zi-au-confirm is defined at source'
(( ${+functions[.zi-au-lock-acquire]} )) || fail '.zi-au-lock-acquire is defined at source'
(( ${+functions[.zi-au-lock-available]} )) || fail '.zi-au-lock-available is defined at source'
(( ${+functions[.zi-au-run]} )) || fail '.zi-au-run is defined at source'
(( ${+functions[.zi-au-due]} )) || fail '.zi-au-due is defined at source'
pass 'auto-update functions are lazily sourced when enabled'

# An explicit disable avoids loading the library and defining any auto-update function.
cat > "$temp_root/au-disabled-child.zsh" <<CHILD
#!/usr/bin/env zsh
builtin emulate -R zsh
typeset -gAH ZI
ZI[AUTO_UPDATE]=0
ZI[UPDATE_STAMP]='${ZI[UPDATE_STAMP]}'
ZI[UPDATE_LOCK]='${ZI[UPDATE_LOCK]}'
builtin source '$project_root/zi.zsh'
if (( \${+functions[.zi-au]} )); then
  print 'AU-DEFINED'
else
  print 'AU-ABSENT'
fi
print 'DISABLED-DONE'
CHILD
typeset disabled_out
disabled_out="$(zsh -f "$temp_root/au-disabled-child.zsh" 2>&1)"
[[ $disabled_out == *AU-ABSENT* ]] || fail 'auto-update lib loaded while disabled'
[[ $disabled_out != *AU-DEFINED* ]] || fail '.zi-au defined while disabled'
[[ $disabled_out == *DISABLED-DONE* ]] || fail 'disabled child completed'
pass 'ZI[AUTO_UPDATE]=0 skips the auto-update library entirely'

# No timestamp stamp -> an update is due.
command rm -f -- "${ZI[UPDATE_STAMP]}" || fail 'remove fresh stamp'
.zi-au-due && pass '.zi-au-due reports due with no stamp' || fail '.zi-au-due reports due with no stamp'

# A fresh stamp -> not due; `.zi-au` returns without launching the worker.
command touch -- "${ZI[UPDATE_STAMP]}"
! .zi-au-due && pass '.zi-au-due reports not due with a fresh stamp' || fail '.zi-au-due reports not due with a fresh stamp'
.zi-au && pass '.zi-au returns success when not due' || fail '.zi-au returns success when not due'

# Retry scheduling uses a portable timestamp and backdates the stamp.
.zi-au-schedule-retry "${ZI[UPDATE_STAMP]}" 604800 300 && \
  pass '.zi-au-schedule-retry succeeds with portable timestamp' || \
  fail '.zi-au-schedule-retry succeeds with portable timestamp'
! .zi-au-due && pass 'scheduled retry is not yet due' || fail 'scheduled retry is not yet due'

# A retry window longer than the interval must not put the stamp in the future.
command rm -f -- "${ZI[UPDATE_STAMP]}"
.zi-au-schedule-retry "${ZI[UPDATE_STAMP]}" 100 500 || fail 'schedule retry with oversized window'
typeset -a clamp_st
zstat -A clamp_st +mtime -- "${ZI[UPDATE_STAMP]}" || fail 'stat the clamped stamp'
(( clamp_st[1] <= EPOCHSECONDS )) || fail 'retry stamp is in the future'
pass 'oversized retry window is clamped to the interval'

# The worker runs in the foreground and writes to stdout, with no log file.
# Point origin_url at an invalid path so `zi self-update` fails fast offline.
command rm -f -- "${ZI[UPDATE_STAMP]}" "${ZI[UPDATE_LOCK]}"
typeset -gx origin_url=/nonexistent/invalid-origin
typeset run_out
run_out="$(.zi-au-run 2>&1)"
[[ -f "${ZI[UPDATE_LOCK]}" ]] || fail 'worker creates the update lock'
[[ -f "${ZI[UPDATE_STAMP]}" ]] || fail 'worker records a retry stamp after failure'
[[ $run_out == *"Auto-update started."* ]] || fail 'worker prints start to stdout'
[[ $run_out == *"fetching updates"* ]] || fail 'framework update output is suppressed'
[[ $run_out == *"Framework update failed."* ]] || fail 'worker prints failure to stdout'
[[ $run_out == *"Retry scheduled in approximately 300 seconds."* ]] || \
  fail 'worker prints the retry window to stdout'
[[ ! -e "$temp_root/cache/zi/log/update.log" ]] || fail 'worker created a log file'
.zi-au-due && fail 'retry stamp is already due right after a failure'
pass 'worker runs synchronously with output on stdout and no log file'

# Plugins are only checked when the framework update succeeds.
typeset au_calls="$temp_root/au-zcalls"
: > "$au_calls" || fail 'create update call log'
(
  zi() {
    builtin print -r -- "$*" >> "$au_calls"
    [[ $1 == self-update ]] && return 1
    return 0
  }
  command rm -f -- "${ZI[UPDATE_STAMP]}" "${ZI[UPDATE_LOCK]}"
  .zi-au-run >/dev/null 2>&1
)
typeset au_call_log
au_call_log="$(<"$au_calls")"
[[ $au_call_log == *self-update* ]] || fail 'framework update was not invoked'
[[ $au_call_log != *'update --parallel --all'* ]] || \
  fail 'plugin update ran after framework failure'
pass 'worker skips plugin update when framework update fails'

# `zi update` pages changelogs from background jobs. The worker must disable
# job control so those pagers stay in the foreground process group and can read
# /dev/tty instead of being stopped by SIGTTIN.
[[ ${functions[.zi-au-run]} == *'unsetopt monitor'* ]] || \
  fail 'worker does not disable job control for changelog pagers'
pass 'worker keeps changelog pagers in the foreground process group'

# Non-interactive shells skip a due update: no prompt, no worker, stamp untouched.
command rm -f -- "${ZI[UPDATE_STAMP]}"
typeset nonint_out
nonint_out="$(.zi-au 2>&1)"
[[ -z $nonint_out ]] || fail 'non-interactive shell printed a prompt'
[[ ! -f "${ZI[UPDATE_STAMP]}" ]] || fail 'non-interactive shell changed the stamp'
pass 'non-interactive shells skip a due update silently'

# Interactive checks use `zsh -f -i` with piped input: -o interactive is on and
# .zi-au-confirm falls back to a raw line read, so no PTY is needed.
cat > "$temp_root/au-child.zsh" <<CHILD
#!/usr/bin/env zsh
builtin emulate -R zsh
typeset -gAH ZI
ZI[AUTO_UPDATE]=1
ZI[UPDATE_STAMP]='${ZI[UPDATE_STAMP]}'
ZI[UPDATE_LOCK]='${ZI[UPDATE_LOCK]}'
builtin source '$project_root/zi.zsh'
print 'AU-DONE'
CHILD

# Timeout/EOF is not an explicit no: leave the stamp untouched so the next
# interactive shell asks again.
command rm -f -- "${ZI[UPDATE_STAMP]}" "${ZI[UPDATE_LOCK]}"
: > "$temp_root/au-eof.in"
typeset eof_out
eof_out="$(zsh -f -i "$temp_root/au-child.zsh" < "$temp_root/au-eof.in" 2>&1)"
[[ $eof_out == *"Update now? [y/N]"* ]] || fail 'prompt shown before EOF'
[[ $eof_out != *"Update declined"* ]] || fail 'EOF treated as explicit no'
[[ $eof_out != *"Auto-update started."* ]] || fail 'EOF started an update'
[[ ! -f "${ZI[UPDATE_STAMP]}" ]] || fail 'EOF changed the stamp'
pass 'timeout/EOF leaves the check due for the next shell'

# A second terminal skips before prompting while another process holds the lock.
zmodload zsh/system || fail 'zsh/system available for lock contention test'
command rm -f -- "${ZI[UPDATE_STAMP]}" "${ZI[UPDATE_LOCK]}"
: >>"${ZI[UPDATE_LOCK]}" || fail 'create update lock'
integer holder_fd
zsystem flock -f holder_fd "${ZI[UPDATE_LOCK]}" || fail 'hold update lock'
builtin print -r -- y > "$temp_root/au-held.in"
typeset held_out
held_out="$(zsh -f -i "$temp_root/au-child.zsh" < "$temp_root/au-held.in" 2>&1)"
zsystem flock -u "$holder_fd"
[[ $held_out == *"Another update is already in progress; skipping."* ]] || \
  fail 'lock contention message'
[[ $held_out != *"Update now? [y/N]"* ]] || fail 'prompt shown during active update'
[[ $held_out != *"Auto-update started."* ]] || fail 'worker started during active update'
[[ ! -f "${ZI[UPDATE_STAMP]}" ]] || fail 'lock contention changed the stamp'
pass 'active update lock prevents a second terminal from prompting'

# Answering no skips the update and defers the next check by a full interval.
command rm -f -- "${ZI[UPDATE_STAMP]}" "${ZI[UPDATE_LOCK]}"
builtin print -r -- n > "$temp_root/au-no.in"
typeset no_out
no_out="$(zsh -f -i "$temp_root/au-child.zsh" < "$temp_root/au-no.in" 2>&1)"
[[ $no_out == *"have not been checked yet"* ]] || fail 'first-run prompt text'
[[ $no_out == *"Update now? [y/N]"* ]] || fail 'prompt asks y/n'
[[ $no_out == *"Update declined; will ask again in 1 week."* ]] || fail 'decline message'
[[ $no_out == *"AU-DONE"* ]] || fail 'interactive child completed'
[[ $no_out != *"Auto-update started."* ]] || fail 'declining starts a worker'
[[ -f "${ZI[UPDATE_STAMP]}" ]] || fail 'declining does not record the stamp'
.zi-au-due && fail 'declining leaves the check due before the next interval'
pass '.zi-au prompts and skips on no, deferring to the next due'

# Answering yes runs the update synchronously with visible output.
command rm -f -- "${ZI[UPDATE_STAMP]}" "${ZI[UPDATE_LOCK]}"
builtin print -r -- y > "$temp_root/au-yes.in"
typeset yes_out
yes_out="$(zsh -f -i "$temp_root/au-child.zsh" < "$temp_root/au-yes.in" 2>&1)"
[[ $yes_out == *"Auto-update started."* ]] || fail 'yes does not run the update'
[[ $yes_out == *"Framework update failed."* ]] || fail 'yes does not show the result'
[[ -f "${ZI[UPDATE_STAMP]}" ]] || fail 'yes does not record the check'
pass '.zi-au runs synchronously after yes'

# A self-update reload re-sources zi.zsh while the approved update is active;
# the guard prevents a second prompt and a second worker from that nested source.
cat > "$temp_root/au-guard-child.zsh" <<CHILD
#!/usr/bin/env zsh
builtin emulate -R zsh
typeset -gAH ZI
ZI[AUTO_UPDATE]=1
ZI[UPDATE_STAMP]='${ZI[UPDATE_STAMP]}'
ZI[UPDATE_LOCK]='${ZI[UPDATE_LOCK]}'
typeset -g ZI_AU_ACTIVE=1
builtin source '$project_root/zi.zsh'
print 'GUARD-DONE'
CHILD
command rm -f -- "${ZI[UPDATE_STAMP]}" "${ZI[UPDATE_LOCK]}"
builtin print -r -- y > "$temp_root/au-guard.in"
typeset guard_out
guard_out="$(zsh -f -i "$temp_root/au-guard-child.zsh" < "$temp_root/au-guard.in" 2>&1)"
[[ $guard_out != *"Update now? [y/N]"* ]] || fail 'nested source prompted again'
[[ $guard_out != *"Auto-update started."* ]] || fail 'nested source started a worker'
[[ $guard_out == *"GUARD-DONE"* ]] || fail 'nested source completed'
[[ ! -f "${ZI[UPDATE_LOCK]}" ]] || fail 'nested source created the update lock'
[[ ! -f "${ZI[UPDATE_STAMP]}" ]] || fail 'nested source changed the stamp'
pass 'active update guard suppresses nested auto-update'

# The prompt reports elapsed time from the stamp, not remote status.
command rm -f -- "${ZI[UPDATE_STAMP]}" "${ZI[UPDATE_LOCK]}"
typeset old_ts
old_ts=$(strftime '%Y%m%d%H%M.%S' $(( EPOCHSECONDS - 691200 )))
command touch -t "$old_ts" -- "${ZI[UPDATE_STAMP]}" || fail 'backdate the stamp'
builtin print -r -- n > "$temp_root/au-old.in"
typeset old_out
old_out="$(zsh -f -i "$temp_root/au-child.zsh" < "$temp_root/au-old.in" 2>&1)"
[[ $old_out == *"Zi and plugins have not been checked for at least 1 week"* ]] || \
  fail 'prompt reports elapsed weeks'
pass 'prompt message reflects time since the last check'

pass 'auto-update startup wiring is functional'
