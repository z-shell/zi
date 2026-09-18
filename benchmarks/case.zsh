#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# case.zsh -- one benchmark sample, run by run.zsh in a fresh `zsh -f`.
# Reads BENCH_CHECKOUT, BENCH_FIXTURES, BENCH_MANIFESTS and BENCH_CASE from the
# environment and prints the elapsed milliseconds of the measured region.
# The measured region excludes process start and setup, which is why every
# case sets up in the same process it measures in.

emulate -R zsh
zmodload zsh/datetime || exit 2
setopt extended_glob

typeset -gAH ZI
ZI[BIN_DIR]=$BENCH_CHECKOUT
typeset -F6 t0 t1
zle() { return 1; }
start() { t0=$EPOCHREALTIME; }
stop()  { t1=$EPOCHREALTIME; print -r -- $(( (t1 - t0) * 1000 )); }
load_zi() { builtin source "$BENCH_CHECKOUT/zi.zsh" || exit 3; .zi-prepare-home || exit 3; }
plugins() { local i; for i in {1..10}; do print -r -- "$BENCH_FIXTURES/plugins/p$i"; done; }

case $BENCH_CASE in
  source-cold|source-warm)
    # cold: fresh cache each sample (compiles); warm: the cache persists.
    start; builtin source "$BENCH_CHECKOUT/zi.zsh" || exit 3; stop ;;
  light-load-10)
    load_zi; start; for p in $(plugins); do zi light %"$p" || exit 3; done; stop ;;
  load-10)
    load_zi; start; for p in $(plugins); do zi load %"$p" || exit 3; done; stop ;;
  turbo-10)
    load_zi; start; for p in $(plugins); do zi wait'0' lucid for %"$p" || exit 3; done; @zi-scheduler burst || exit 3; stop
    (( $+functions[p10_fn] )) || exit 4 ;;
  ice-200)
    load_zi; start; for i in {1..200}; do zi ice wait'1' lucid depth'1' atinit'true' atload'true' pick'x' as'program' from'gh-r' mv'a -> b' id-as'x' compile'y' nocompile blockf || exit 3; done; stop ;;
  manifest-21)
    load_zi; builtin source "$BENCH_CHECKOUT/lib/zsh/install.zsh" || exit 3
    (( $+functions[.zi-read-package-manifest] )) || exit 5
    local -a files; files=( $BENCH_MANIFESTS/*.json(N) ); (( $#files )) || exit 5
    start; for f in $files; do local -A info ices; local -a names; .zi-read-package-manifest "$(<$f)" default info names ices || exit 4; unset info ices names; done; stop ;;
  unload-10)
    load_zi; for p in $(plugins); do zi load %"$p" || exit 3; done
    start; for p in $(plugins); do zi unload %"$p" -q || exit 3; done; stop
    (( $+functions[p10_fn] == 0 )) || exit 4 ;;
  symbols)
    builtin source "$BENCH_CHECKOUT/zi.zsh" || exit 3; .zi-prepare-home
    integer f1=$#functions p1=$#parameters
    for p in $(plugins); do zi load %"$p" || exit 3; done
    print -r -- "$f1 $p1 $#functions $#parameters" ;;
  *) exit 2 ;;
esac
