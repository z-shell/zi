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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-load-object-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" || fail "create isolated environment"

# .zi-load-object is a thin dispatcher over .zi-load and .zi-load-snippet. Stub
# both so the status it reports is unambiguously the one it was given, with no
# dependency on a real plug-in, the network, or the filesystem.
env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  zsh -f <<'ZSH' || fail ".zi-load-object does not report the status of the load it performed"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

integer stub_status=0
.zi-load()         { return $stub_status; }
.zi-load-snippet() { return $stub_status; }

check() {  # check <label> <type> <stubbed status> <expected status>
  local label="$1" type="$2"
  stub_status=$3
  local -i expected=$4 actual
  .zi-load-object "$type" some-id
  actual=$?
  [[ $actual -eq $expected ]] || {
    builtin print -u2 -r -- "${label}: expected ${expected}, got ${actual}"
    return 1
  }
}

check "plugin success"  plugin  0 0 || return 1
check "snippet success" snippet 0 0 || return 1
# The failure paths are the point. Before this was fixed the helper returned the
# undefined `__retval', which zsh evaluates arithmetically as 0, so every load
# reported success and turbo scheduling proceeded after a failed immediate load.
check "plugin failure"  plugin  7 7 || return 1
check "snippet failure" snippet 5 5 || return 1

# The caller adds the reported status to its own accumulator exactly once. The
# helper must not also add to a dynamically scoped ___retval, which would
# double-count every failure.
() {
  integer ___retval=0
  stub_status=3
  .zi-load-object plugin some-id
  integer reported=$?
  [[ $reported -eq 3 ]] || {
    builtin print -u2 -r -- "aggregation: expected a reported status of 3, got ${reported}"
    return 1
  }
  (( ___retval == 0 )) || {
    builtin print -u2 -r -- "aggregation: the helper modified the caller's \$___retval to ${___retval}"
    return 1
  }
} || return 1

# Before-load hooks can consume a request without loading an object. Exercise
# real dispatch so a blank replacement cannot become a blank object ID.
typeset -a attempted
integer hook_status=2
typeset replacement='' new_ices=''
.zi-load-object() { attempted+=( "$2" ); return 0; }
probe_replace() {
  [[ $2 == fixture ]] || return 0
  ZI[annex-before-load:new-@]="${replacement}${4:+ $4}"
  ZI[annex-before-load:new-global-ices]=$new_ices
  return $hook_status
}
@zi-register-annex probe-replace hook:before-load-2 probe_replace '' ''
zi light @fixture || { print -u2 'empty replacement failed'; return 1; }
(( $#attempted == 0 )) || return 1

hook_status=3
zi light @fixture
(( $? == 3 && $#attempted == 0 )) || {
  print -u2 'empty replacement lost the hook error'
  return 1
}
hook_status=2
zi for @fixture @example/following || return 1
[[ $#attempted == 1 && $attempted[1] == example/following ]] || return 1

replacement="@'example/with spaces'"
zi light @fixture || return 1
[[ $#attempted == 2 && $attempted[2] == 'example/with spaces' ]] || return 1

# A later empty replacement must not reuse the previous non-empty array.
replacement=''
zi light @fixture || return 1
(( $#attempted == 2 )) || return 1

# `(z)' yields one blank word for whitespace too, so it is the same consumed
# state and must not reach the loader as a blank object ID either.
replacement='   '
zi light @fixture || { print -u2 'whitespace replacement failed'; return 1; }
(( $#attempted == 2 )) || { print -u2 'whitespace replacement loaded an object'; return 1; }
replacement=''

# A blank global-ice override means "no global ices", not a malformed odd list.
hook_status=6
zi light @fixture || { print -u2 'blank global ices reported a bad ice-list'; return 1; }
(( $#attempted == 2 )) || return 1
hook_status=2
ZSH

builtin print -r -- "ok - .zi-load-object reports its own load status and leaves aggregation to the caller"
