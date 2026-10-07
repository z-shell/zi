#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

# Classic `zi light' loads without tracking, like `zi light-mode for'; `zi
# light -b' tracks bindkey calls only; `zi load' (with or without -b) keeps
# full tracking (#586).

builtin emulate -R zsh
setopt pipe_fail

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-light-tracking-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/demo" || fail "create isolated environment"

builtin print -rl -- \
  'demo_fn() { :; }' \
  'bindkey "^X^D" demo_fn' \
  > "${temp_root}/demo/demo.plugin.zsh" || fail "write demo plug-in"

# Load the local plug-in with one command form in a fresh shell, then print
# its state, whether its function snapshot was taken and whether its bindkey
# call was recorded, as `STATE FUNCTIONS BINDKEYS'.
probe() {  # probe <load command>
  env \
    HOME="${temp_root}/home" \
    XDG_CACHE_HOME="${temp_root}/cache" \
    XDG_CONFIG_HOME="${temp_root}/config" \
    XDG_DATA_HOME="${temp_root}/data" \
    ZDOTDIR="${temp_root}/zdotdir" \
    ZI_TEST_CHECKOUT="$project_root" \
    ZI_TEST_ROOT="$temp_root" \
    ZI_TEST_LOAD="$1" \
    zsh -f <<'ZSH'
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

builtin eval "$ZI_TEST_LOAD" >/dev/null 2>&1 || return 1

typeset id="%${ZI_TEST_ROOT}/demo" functions_state=none bindkeys_state=none
[[ -n ${ZI[FUNCTIONS_BEFORE__$id]} ]] && functions_state=tracked
[[ ${ZI[BINDKEYS__$id]} == *demo_fn* ]] && bindkeys_state=tracked
builtin print -r -- "${ZI[STATES__$id]:-unset} $functions_state $bindkeys_state"
ZSH
}

typeset -i failures=0
expect() {  # expect <label> <load command> <expected STATE FUNCTIONS BINDKEYS>
  typeset actual
  actual="$(probe "$2")" || {
    builtin print -u2 -r -- "not ok - $1: the load failed"
    (( ++failures ))
    return
  }
  if [[ $actual == "$3" ]] {
    builtin print -r -- "ok - $1: $actual"
  } else {
    builtin print -u2 -r -- "not ok - $1: expected [$3], got [$actual]"
    (( ++failures ))
  }
}

typeset dir='$ZI_TEST_ROOT/demo'
expect 'zi light'            "zi light $dir"            '1 none none'
expect 'zi light-mode for'   "zi light-mode for $dir"   '1 none none'
# -b keeps the light load but still records bindkey calls; the state value
# follows the load mode passed to .zi-register-plugin and is not pinned here.
typeset b_state
b_state="$(probe "zi light -b $dir")" || fail "zi light -b: the load failed"
if [[ ${b_state#* } == 'none tracked' ]] {
  builtin print -r -- "ok - zi light -b: $b_state"
} else {
  builtin print -u2 -r -- "not ok - zi light -b: expected [* none tracked], got [$b_state]"
  (( ++failures ))
}
expect 'zi load'             "zi load $dir"             '2 tracked tracked'
expect 'zi load -b'          "zi load -b $dir"          '2 tracked tracked'

(( failures == 0 )) || fail "${failures} load form(s) track the wrong state"
builtin print -r -- "ok - zi light loads without tracking, -b tracks bindkeys only, zi load tracks fully"
