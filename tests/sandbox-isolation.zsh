#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# tests/lib/sandbox.zsh must keep a caller's environment away from the test
# process and its children (#658). Run a test that sources the sandbox under
# decoy values and check that none of them is used and nothing is written to
# them.
builtin emulate -R zsh
setopt pipe_fail

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset outer
outer=$(command mktemp -d "${TMPDIR:-/tmp}/zi-sandbox-isolation.XXXXXXXX") || fail "create decoy directory"
trap 'command chmod -R u+rwX -- "$outer" 2>/dev/null; command rm -rf -- "$outer"' EXIT INT TERM
command mkdir -p -- "$outer"/{home,config,cache,data,state,tmp,prefix,go,gobin,gomod,cargo,rustup,fpath} ||
  fail "create decoy directories"
print -r -- '[user]
  name = Decoy Caller
[commit]
  gpgsign = true' > "$outer/config/gitconfig-global" || fail "write decoy git config"
command mkdir -p -- "$outer/config/git" &&
  command cp -- "$outer/config/gitconfig-global" "$outer/config/git/config" || fail "write decoy XDG git config"
print -r -- '[user]
  email = decoy@example.invalid' > "$outer/config/gitconfig-system" || fail "write decoy system git config"

# The probe sources the sandbox, then reports what the test process, a child
# shell, Zi and Git see.
typeset probe="$outer/probe.zsh"
print -r -- 'builtin emulate -R zsh
source "$1/tests/lib/sandbox.zsh" sandbox-probe
print -r -- "root=$temp_root"
print -r -- "home=$HOME"
print -r -- "zdotdir=$ZDOTDIR"
print -r -- "tmpdir=$TMPDIR"
print -r -- "xdg=$XDG_CONFIG_HOME:$XDG_CACHE_HOME:$XDG_DATA_HOME:$XDG_STATE_HOME"
print -r -- "unset=${+ZPFX}${+GOPATH}${+GOBIN}${+GOMODCACHE}${+CARGO_HOME}${+RUSTUP_HOME}"
print -r -- "child=$(command env | command grep -E "^(FPATH|ZPFX|GOPATH)=" | command wc -l | command tr -d " ")"
print -r -- "gituser=$(command git config --get user.name)"
print -r -- "gitemail=$(command git config --get user.email)"
print -r -- "gitsign=$(command git config --get commit.gpgsign)"
print -r -- "gitdir=${+GIT_DIR}${+GIT_AUTHOR_NAME}"
command git config --list >/dev/null 2>&1
print -r -- "gitlist=$?"
typeset -gA ZI
source "$1/zi.zsh" >/dev/null 2>&1 || print -r -- "zi-source-failed"
print -r -- "zpfx=$ZPFX"
print -r -- "zihome=${ZI[HOME_DIR]}"' > "$probe" || fail "write probe"

typeset output
output=$(
  command env \
    HOME="$outer/home" ZDOTDIR="$outer/home" TMPDIR="$outer/tmp" \
    XDG_CONFIG_HOME="$outer/config" XDG_CACHE_HOME="$outer/cache" \
    XDG_DATA_HOME="$outer/data" XDG_STATE_HOME="$outer/state" \
    GIT_CONFIG_GLOBAL="$outer/config/gitconfig-global" \
    GIT_CONFIG_SYSTEM="$outer/config/gitconfig-system" \
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=true \
    GIT_DIR="$outer/not-a-repository" GIT_AUTHOR_NAME="Decoy Author" \
    ZPFX="$outer/prefix" GOPATH="$outer/go" GOBIN="$outer/gobin" \
    GOMODCACHE="$outer/gomod" CARGO_HOME="$outer/cargo" RUSTUP_HOME="$outer/rustup" \
    FPATH="$outer/fpath" \
    zsh -f "$probe" "$project_root" 2>&1
) || fail "sandbox probe exited non-zero: $output"

typeset -A seen
typeset line
for line in "${(@f)output}"; do
  [[ $line == *=* ]] && seen[${line%%=*}]=${line#*=}
done
typeset root=${seen[root]}
[[ -n $root && $root == "$outer/tmp/zi-sandbox-probe."* ]] ||
  fail "temporary root is not under the caller's TMPDIR: $root"
typeset base="$root/.sandbox"
[[ ${seen[home]} == "$base/home" && ${seen[zdotdir]} == "$base/home" ]] ||
  fail "HOME or ZDOTDIR is not private: ${seen[home]} ${seen[zdotdir]}"
[[ ${seen[tmpdir]} == "$base/tmp" ]] || fail "TMPDIR is not private: ${seen[tmpdir]}"
[[ ${seen[xdg]} == "$base/config:$base/cache:$base/data:$base/state" ]] ||
  fail "XDG directories are not private: ${seen[xdg]}"
[[ ${seen[unset]} == 000000 ]] || fail "a caller ZPFX, Go or Rust path survived: ${seen[unset]}"
[[ ${seen[child]} == 0 ]] || fail "a child shell inherited FPATH, ZPFX or GOPATH"
[[ -z ${seen[gituser]} ]] || fail "Git read the caller's configuration: user.name=${seen[gituser]}"
[[ -z ${seen[gitemail]} ]] || fail "Git read the caller's system configuration: user.email=${seen[gitemail]}"
[[ -z ${seen[gitsign]} ]] || fail "Git read configuration from the environment: commit.gpgsign=${seen[gitsign]}"
[[ ${seen[gitdir]} == 00 ]] || fail "a caller GIT_DIR or Git identity survived"
[[ ${seen[gitlist]} == 0 ]] || fail "Git cannot read its configuration in the sandbox (exit ${seen[gitlist]})"
[[ ${seen[zpfx]} == "$base/data/zi/polaris" ]] || fail "Zi derived ZPFX outside the sandbox: ${seen[zpfx]}"
[[ ${seen[zihome]} == "$base/data/zi" ]] || fail "Zi derived its home outside the sandbox: ${seen[zihome]}"
[[ ! -e $root ]] || fail "the sandbox left its temporary root behind: $root"

# A signal ends the test after cleanup instead of letting it run on against a
# removed HOME and TMPDIR.
print -r -- 'builtin emulate -R zsh
source "$1/tests/lib/sandbox.zsh" sandbox-signal
print -r -- "root=$temp_root"
builtin kill -INT $$
print -r -- "ran-after-signal"' > "$outer/signal.zsh" || fail "write signal probe"
typeset signal_output
signal_output=$(command env TMPDIR="$outer/tmp" zsh -f "$outer/signal.zsh" "$project_root" 2>&1)
integer signal_status=$?
(( signal_status == 130 )) || fail "an interrupted test exited $signal_status instead of 130"
[[ $signal_output != *ran-after-signal* ]] || fail "a test kept running after an interrupt"
typeset signal_root=${${(M)${(f)signal_output}:#root=*}#root=}
[[ -n $signal_root && ! -e $signal_root ]] || fail "an interrupted test left its temporary root: $signal_root"

typeset -a written=( "$outer"/{home,cache,data,state,prefix,go,gobin,gomod,cargo,rustup,fpath}/*(DN) )
(( ${#written} == 0 )) || fail "the sandbox wrote to the caller's directories: ${written[*]}"

print -r -- "ok - the sandbox keeps the caller's HOME, XDG, TMPDIR, Git, ZPFX, Go, Rust and FPATH away from tests and cleans up on a signal"
