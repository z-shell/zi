# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# Startup auto-update helpers for Zi. Sourced only when auto-update is enabled.

# FUNCTION: .zi-au [[[
# Startup entry point called by zi.zsh after hook registration. Cheap due and
# lock checks come first, then an interactive shell is asked and the worker
# runs in the foreground. Non-interactive shells return before reading stdin,
# so scripts never block or consume input meant for their own commands.
.zi-au() {
  builtin emulate -L zsh

  # `zi self-update` re-sources zi.zsh during .zi-au-run; don't prompt again.
  [[ -z ${ZI_AU_ACTIVE:-} ]] || return 0
  [[ -o interactive ]] || return 0
  .zi-au-due || return 0
  .zi-au-lock-available || return 0

  .zi-au-confirm
  case $? in
    0) ;;                                   # yes
    1)                                      # explicit no: defer to next due
      local next stamp="${ZI[UPDATE_STAMP]}"
      next=$(.zi-au-duration "${ZI[UPDATE_INTERVAL]:-604800}")
      builtin print -r -- "Update declined; will ask again in ${next}."
      command mkdir -p -- "${stamp:h}" 2>/dev/null
      : >|"$stamp" 2>/dev/null
      return 0
      ;;
    *) return 0 ;;                          # timeout/EOF: ask again next shell
  esac

  .zi-au-run
} # ]]]

# FUNCTION: .zi-au-confirm [[[
# Ask once using only the elapsed time recorded in the stamp; no remote status
# is checked before the prompt.
# Returns 0 for yes, 1 for explicit no, 2 for timeout/EOF.
.zi-au-confirm() {
  builtin emulate -L zsh

  local stamp="${ZI[UPDATE_STAMP]}" msg ans=''
  local -i elapsed=-1 rc read_rc
  local -a st

  if [[ -f $stamp ]] \
     && zmodload zsh/datetime 2>/dev/null \
     && zmodload -F zsh/stat b:zstat 2>/dev/null \
     && zstat -A st +mtime -- "$stamp" 2>/dev/null \
     && (( st[1] > 0 )); then
    elapsed=$(( EPOCHSECONDS - st[1] ))
    (( elapsed < 0 )) && elapsed=0
  fi

  if [[ ! -f $stamp ]]; then
    msg="Zi and plugins have not been checked yet"
  elif (( elapsed >= 0 )); then
    msg="Zi and plugins have not been checked for at least $(.zi-au-duration $elapsed)"
  else
    msg="Zi and plugins are due for a check"
  fi

  builtin print -rn -- "${msg}. Update now? [y/N] "

  # `read -q` is the single-key path for a real terminal. Piped input uses a
  # raw line read, which also works in CI where stdin and stdout are not TTYs.
  if [[ -t 0 ]]; then
    builtin read -q -t 30 ans
    read_rc=$?
    rc=$read_rc
  else
    builtin read -r -t 30 ans
    read_rc=$?
    if (( read_rc == 0 )); then
      [[ $ans == [yY] ]] || rc=1
    else
      rc=$read_rc
    fi
  fi

  # EOF is not an explicit decline; only a real answer may defer the check.
  (( read_rc == 1 )) && [[ -z $ans ]] && rc=2

  builtin print -r -- ''
  return $rc
} # ]]]

# FUNCTION: .zi-au-duration [[[
# Print a coarse human duration using the largest whole unit.
# $1 - seconds to format; missing or negative values are treated as zero
.zi-au-duration() {
  builtin emulate -L zsh

  local -i secs=${1:-0}
  (( secs < 0 )) && secs=0

  local -i weeks=$(( secs / 604800 ))
  local -i days=$(( (secs % 604800) / 86400 ))
  local -i hours=$(( (secs % 86400) / 3600 ))
  local -i minutes=$(( (secs % 3600) / 60 ))

  local count unit
  if   (( weeks ));   then count=$weeks   unit=week
  elif (( days ));    then count=$days    unit=day
  elif (( hours ));   then count=$hours   unit=hour
  elif (( minutes )); then count=$minutes unit=minute
  else                     count=$secs    unit=second
  fi

  (( count == 1 )) || unit+="s"
  builtin print -r -- "${count} ${unit}"
} # ]]]

# FUNCTION: .zi-au-lock-acquire [[[
# Take the update lock without blocking, so a second terminal never queues or
# prompts behind a running worker. The fd is stored in the variable whose NAME
# is $1 (set via `zsystem flock -f`, so the caller must declare it).
# $1 - name of the caller variable that receives the lock fd
# Returns 0 when acquired, 1 when another update holds it, 2 on any error.
.zi-au-lock-acquire() {
  builtin emulate -L zsh

  zmodload zsh/system 2>/dev/null || {
    builtin print -u2 -r -- "Failed to load required Zsh modules."
    return 2
  }

  local lock="${ZI[UPDATE_LOCK]}"
  [[ -n $lock ]] || return 2

  # The lock file must exist before flock.
  command mkdir -p -- "${lock:h}" 2>/dev/null && : >>"$lock" 2>/dev/null || {
    builtin print -u2 -r -- "Failed to create update lock."
    return 2
  }

  zsystem flock -t 0 -f "$1" "$lock" 2>/dev/null
  local -i rc=$?

  case $rc in
    0) return 0 ;;
    1 | 2)
      # -t 0 reports 1 when the lock is held; a timed wait reports 2.
      builtin print -u2 -r -- "Another update is already in progress; skipping."
      return 1
      ;;
    *)
      builtin print -u2 -r -- "Failed to acquire update lock (status $rc)."
      return 2
      ;;
  esac
} # ]]]

# FUNCTION: .zi-au-lock-available [[[
# Probe the lock before prompting so a held lock produces no question. The fd
# is released immediately; the worker rechecks and takes the lock itself.
.zi-au-lock-available() {
  builtin emulate -L zsh

  local -i fd=0
  .zi-au-lock-acquire fd || return 1
  zsystem flock -u "$fd" 2>/dev/null
  return 0
} # ]]]

# FUNCTION: .zi-au-run [[[
# Foreground update worker. Output is printed live to stdout/stderr; there is
# no log file and no detached worker. zi self-update gates the plugin pass, a
# failed pass schedules a retry by backdating the stamp, and the lock is
# released in the always block on success, failure or interruption.
.zi-au-run() {
  builtin emulate -L zsh

  # Dynamic scope: a re-sourced zi.zsh called from this worker inherits this.
  local ZI_AU_ACTIVE=1

  local -i interval=${ZI[UPDATE_INTERVAL]:-604800}
  local -i retry=${ZI[UPDATE_RETRY]:-300}
  local stamp="${ZI[UPDATE_STAMP]}"
  local -i fd=0 rc=0

  [[ -n $stamp ]] || return 1
  command mkdir -p -- "${stamp:h}" 2>/dev/null || return 1

  .zi-au-lock-acquire fd
  case $? in
    0) ;;
    1) return 0 ;;                          # someone else is updating
    *) return 1 ;;
  esac

  # Git must not start its own pager or prompt for credentials; Zi's changelog
  # pager is handled separately by .zi-pager.
  local -x GIT_PAGER=cat PAGER=cat GIT_TERMINAL_PROMPT=0
  local -x GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes"

  {
    # Recheck after acquiring the lock.
    .zi-au-due || return 0

    builtin print -r -- "Auto-update started."

    # Plugins are only updated after the framework updated cleanly. Keep all
    # output visible; empty stdin prevents git/zi from prompting for input,
    # while changelog pagers still read /dev/tty.
    if ! zi self-update </dev/null; then
      builtin print -u2 -r -- "Framework update failed."
      rc=1
    elif ! zi update --parallel --all </dev/null; then
      builtin print -u2 -r -- "Plugin update failed."
      rc=1
    fi

    if (( rc == 0 )); then
      if : >|"$stamp" 2>/dev/null; then
        builtin print -r -- "Auto-update finished successfully."
      else
        builtin print -u2 -r -- "Failed to update timestamp."
        rc=1
      fi
    fi

    if (( rc != 0 )); then
      if .zi-au-schedule-retry "$stamp" "$interval" "$retry"; then
        builtin print -r -- "Retry scheduled in approximately ${retry} seconds."
      else
        builtin print -u2 -r -- "Failed to schedule retry."
      fi
    fi

    builtin print -r -- "----------------------------------------"
    return $rc
  } always {
    # Runs on normal return, error and Ctrl-C.
    if (( fd > 0 )); then
      zsystem flock -u "$fd" 2>/dev/null
    fi
  }
} # ]]]

# FUNCTION: .zi-au-due [[[
# Due when the stamp is missing or strictly older than ZI[UPDATE_INTERVAL].
# Returns 0 when due, 1 otherwise. An empty stamp path disables auto-update.
# Loads no modules: this runs on every interactive startup.
.zi-au-due() {
  builtin emulate -L zsh

  local stamp="${ZI[UPDATE_STAMP]}"
  local -i interval=${ZI[UPDATE_INTERVAL]:-604800}

  [[ -n $stamp ]] || return 1
  [[ -f $stamp ]] || return 0

  local -a stale=("$stamp"(Nms+${interval}))
  (( ${#stale} > 0 ))
} # ]]]

# FUNCTION: .zi-au-schedule-retry [[[
# Schedule a retry after failure by backdating the stamp.
# $1 - stamp path
# $2 - normal interval in seconds
# $3 - retry delay in seconds, clamped to the interval
.zi-au-schedule-retry() {
  builtin emulate -L zsh
  zmodload zsh/datetime 2>/dev/null || return 1

  local stamp="$1" retry_ts
  local -i interval=$2 retry=$3
  (( retry > interval )) && retry=interval   # never push the stamp into the future
  local -i retry_at=$(( EPOCHSECONDS - interval + retry ))

  # `touch -t` with a strftime timestamp works with both GNU and BSD touch.
  strftime -s retry_ts '%Y%m%d%H%M.%S' "$retry_at" 2>/dev/null || {
    command rm -f -- "$stamp" 2>/dev/null
    return 1
  }

  command touch -t "$retry_ts" -- "$stamp" 2>/dev/null || {
    command rm -f -- "$stamp" 2>/dev/null
    return 1
  }
} # ]]]
