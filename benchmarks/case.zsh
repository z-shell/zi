#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# case.zsh -- one benchmark sample, run by run.zsh in a fresh `zsh -f`.
# Reads BENCH_CHECKOUT, BENCH_FIXTURES, BENCH_MANIFESTS and BENCH_CASE from the
# environment and prints the elapsed milliseconds of the measured region.
# The measured region excludes process start and setup, which is why every
# case sets up in the same process it measures in. The timer is floating-point
# SECONDS, which needs no module: zi.zsh loads zsh/datetime when sourced, so a
# timer built on that module would pay for the load before the source cases
# start measuring.
#
# Exit 6 means the checkout lacks the API the case exercises; run.zsh records
# that as unsupported for the variant, not as a failure. Every other non-zero
# status is a failure of the workload.

emulate -R zsh
setopt extended_glob

typeset -gAH ZI
ZI[BIN_DIR]=$BENCH_CHECKOUT
typeset -F 6 SECONDS
typeset -F6 t0 t1
zle() { return 1; }
start() { t0=$SECONDS; }
mark()  { t1=$SECONDS; }
elapsed() { print -r -- $(( (t1 - t0) * 1000 )); }
stop()  { mark; elapsed; }
load_zi() { builtin source "$BENCH_CHECKOUT/zi.zsh" || exit 3; .zi-prepare-home || exit 3; }
plugins() { local i; for i in {1..10}; do print -r -- "$BENCH_FIXTURES/plugins/p$i"; done; }
# Every fixture plugin defines a function, an alias, and a global parameter.
# All thirty artifacts prove that every plugin ran, and that an unload
# removed every kind of state it owns; checking one kind, or only the last
# plugin, would accept a partial workload or a partial cleanup.
all_loaded() {
  local i
  for i in {1..10}; do
    (( $+functions[p${i}_fn] && $+aliases[p${i}_alias] && $+parameters[P${i}_PARAM] )) || return 1
  done
  return 0
}
none_loaded() {
  local i
  for i in {1..10}; do
    (( $+functions[p${i}_fn] || $+aliases[p${i}_alias] || $+parameters[P${i}_PARAM] )) && return 1
  done
  return 0
}

case $BENCH_CASE in
  source-fresh-home|source-reused-home)
    # Zi does not compile itself on source; the difference between these two
    # is the persisted home state (prepared directories, completion dump)
    # that the reused home carries over from the previous sample.
    # zi.zsh does not propagate a failed .zi-prepare-home, so a successful
    # source can leave the home unprepared; only a ready home is timed.
    start; builtin source "$BENCH_CHECKOUT/zi.zsh" || exit 3; mark
    [[ -n ${ZI[HOME_READY]} ]] || exit 4
    elapsed ;;
  light-load-10)
    load_zi; start; for p in $(plugins); do zi light %"$p" || exit 3; done; stop
    all_loaded || exit 4 ;;
  load-10)
    load_zi; start; for p in $(plugins); do zi load %"$p" || exit 3; done; stop
    all_loaded || exit 4 ;;
  turbo-10)
    load_zi; start; for p in $(plugins); do zi wait'0' lucid for %"$p" || exit 3; done; @zi-scheduler burst || exit 3; stop
    all_loaded || exit 4 ;;
  ice-200)
    load_zi; start; for i in {1..200}; do zi ice wait'1' lucid depth'1' atinit'true' atload'true' pick'x' as'program' from'gh-r' mv'a -> b' id-as'x' compile'y' nocompile blockf || exit 3; done; stop ;;
  manifest-21)
    load_zi; builtin source "$BENCH_CHECKOUT/lib/zsh/install.zsh" || exit 3
    # A checkout that predates the manifest reader cannot run this workload.
    # That is a capability of the checkout, not a defect in it: exit 6 tells
    # run.zsh to record the case as unsupported for this variant instead of
    # failed, and compare.zsh decides whether the asymmetry matters.
    (( $+functions[.zi-read-package-manifest] )) || { print -u2 -r -- "checkout does not define .zi-read-package-manifest"; exit 6 }
    local -a files; files=( $BENCH_MANIFESTS/*.json(N) )
    # Exactly the declared inventory, or the timing is not comparable (#555).
    (( $#files == ${BENCH_MANIFEST_COUNT:-0} )) || exit 5
    start; for f in $files; do local -A info ices; local -a names; .zi-read-package-manifest "$(<$f)" default info names ices || exit 4; unset info ices names; done; stop ;;
  unload-10)
    load_zi; for p in $(plugins); do zi load %"$p" || exit 3; done
    all_loaded || exit 4
    start; for p in $(plugins); do zi unload %"$p" -q || exit 3; done; stop
    none_loaded || exit 4 ;;
  symbols)
    builtin source "$BENCH_CHECKOUT/zi.zsh" || exit 3; .zi-prepare-home
    integer f1=$#functions p1=$#parameters
    for p in $(plugins); do zi load %"$p" || exit 3; done
    print -r -- "$f1 $p1 $#functions $#parameters" ;;
  *) exit 2 ;;
esac
