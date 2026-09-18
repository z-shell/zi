#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# promotion-smoke.zsh -- exercise real objects on a promotion candidate.
#
# The focused tests stub the network and the ZD suites install objects but
# never update, unload, or delete them, so the 2026-09-18 review found a
# package-manifest regression (#544) only by hand. This script drives the
# candidate through the paths a user hits on a normal day, against the real
# GitHub-hosted objects, in an isolated home (#548):
#
#   load an annex, install a snippet, queue a turbo plugin and run the
#   scheduler, install a package whose profile declares service'', update the
#   snippet and the plugin and everything, unload the plugin, delete the
#   snippet, and print status.
#
# Every step asserts its exit status and, where a file or registry entry is
# the observable effect, that effect. It needs network access and is meant
# for the promotion-readiness workflow, not for ordinary pull requests.
#
# Usage:
#   zsh scripts/promotion-smoke.zsh [--checkout DIR]
#
# Exit codes:
#   0  every step behaved as asserted
#   1  a step failed; the failing step's log path is printed
#   2  usage error

emulate -LR zsh
setopt extended_glob pipe_fail

typeset checkout=${0:A:h:h}
while (( $# )); do
  case "$1" in
    --checkout) checkout=${2-}; shift 2 ;;
    --help|-h) print "usage: ${0:t} [--checkout DIR]"; exit 0 ;;
    *) print -u2 "promotion-smoke: unknown argument: $1"; exit 2 ;;
  esac
done
[[ -r ${checkout}/zi.zsh ]] || { print -u2 "promotion-smoke: no zi.zsh under ${checkout}"; exit 2 }

typeset root
root=$(command mktemp -d "${TMPDIR:-/tmp}/zi-promotion-smoke.XXXXXXXX") || exit 2
command mkdir -p -- "${root}/home" "${root}/logs"
trap 'command rm -rf -- "$root"' EXIT INT TERM

env \
  HOME="${root}/home" \
  ZDOTDIR="${root}/home" \
  XDG_DATA_HOME="${root}/data" \
  XDG_CACHE_HOME="${root}/cache" \
  XDG_CONFIG_HOME="${root}/config" \
  SMOKE_CHECKOUT="$checkout" \
  SMOKE_LOGS="${root}/logs" \
  zsh -f <<'INNER'
builtin emulate -R zsh
setopt extended_glob pipe_fail

fail() {
  builtin print -u2 -r -- "not ok - $1"
  [[ -n ${2-} && -r ${SMOKE_LOGS}/$2.log ]] && {
    builtin print -u2 -r -- "--- ${2}.log (last 20 lines)"
    command tail -n 20 -- "${SMOKE_LOGS}/$2.log" >&2
  }
  exit 1
}
step() {  # step <name> <expected status> <command...>
  local name=$1; integer expected=$2; shift 2
  "$@" > "${SMOKE_LOGS}/${name}.log" 2>&1
  integer rc=$?
  (( rc == expected )) || fail "${name}: expected status ${expected}, got ${rc}" "$name"
  builtin print -r -- "ok - ${name} (status ${rc})"
}

typeset -gAH ZI
ZI[BIN_DIR]=$SMOKE_CHECKOUT
builtin source "${SMOKE_CHECKOUT}/zi.zsh" || fail "source zi.zsh"
.zi-prepare-home || fail "prepare home"
zle() { return 1; }

step annex-load 0 zi light z-shell/z-a-meta-plugins
(( ${#${(M)${(v)ZI_EXTS}:#*z-a-meta-plugins*}} )) || fail "annex-load: z-a-meta-plugins registered no hook" annex-load

step snippet-install 0 zi snippet OMZL::history.zsh
typeset -a snippet_files
snippet_files=( ${ZI[SNIPPETS_DIR]}/**/OMZL::history.zsh(.N) )
(( $#snippet_files == 1 )) || fail "snippet-install: expected one installed snippet file, found ${#snippet_files}" snippet-install

integer tasks_before=$#ZI_TASKS
step turbo-queue 0 zi wait'0' lucid for zsh-users/zsh-autosuggestions
(( $#ZI_TASKS == tasks_before + 1 )) || fail "turbo-queue: no task was queued" turbo-queue
step scheduler-burst 0 @zi-scheduler burst
(( ${ZI_REGISTERED_PLUGINS[(I)zsh-users/zsh-autosuggestions]} )) || fail "scheduler-burst: plugin not registered after the burst" scheduler-burst
(( $+functions[_zsh_autosuggest_start] )) || fail "scheduler-burst: plugin body did not run" scheduler-burst

tasks_before=$#ZI_TASKS
step pack-service-first-install 0 zi pack for @github-issues-srv
(( ${ZI_TASKS[(I)* p1 *]} )) || fail "pack-service-first-install: no service task queued (#529)" pack-service-first-install
[[ -e ${ZI[PLUGINS_DIR]}/github-issues-srv/._zi/service ]] || fail "pack-service-first-install: service disk ice not stored" pack-service-first-install

step pack-install 0 zi pack for @github-issues
(( ${ZI_REGISTERED_PLUGINS[(I)github-issues]} )) || fail "pack-install: package not registered" pack-install

step snippet-update 0 zi update OMZL::history.zsh
step plugin-update 0 zi update zsh-users/zsh-autosuggestions
step update-all 0 zi update --all

step unload 0 zi unload zsh-users/zsh-autosuggestions
(( $+functions[_zsh_autosuggest_start] == 0 )) || fail "unload: plugin function survived unload" unload

step delete 0 zi delete --yes OMZL::history.zsh
snippet_files=( ${ZI[SNIPPETS_DIR]}/**/OMZL::history.zsh(.N) )
(( $#snippet_files == 0 )) || fail "delete: snippet file still present" delete

step status 0 zi status
builtin print -r -- "ok - promotion smoke: every real-object step behaved as asserted"
INNER
