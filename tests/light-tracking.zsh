#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

# Classic `zi light' loads without tracking, like `zi light-mode for'; `zi
# light -b' tracks bindkey calls only, also after a `light-mode' ice; `zi load'
# (with or without -b) keeps full tracking (#586).

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
  "${temp_root}/zpfx" \
  "${temp_root}/demo" || fail "create isolated environment"

builtin print -rl -- \
  'demo_fn() { :; }' \
  'bindkey "^X^D" demo_fn' \
  > "${temp_root}/demo/demo.plugin.zsh" || fail "write demo plug-in"

# Load the local plug-in with one command form in a fresh shell. The probe
# fails unless the plug-in was sourced (demo_fn defined), then prints the
# state, whether its function snapshot was taken, whether its bindkey call was
# recorded, and the widgets bound to ^X^D and ^X^E, as
# `STATE FUNCTIONS BINDKEYS ^X^D-WIDGET ^X^E-WIDGET'.
probe() {  # probe <load command>
  env \
    HOME="${temp_root}/home" \
    XDG_CACHE_HOME="${temp_root}/cache" \
    XDG_CONFIG_HOME="${temp_root}/config" \
    XDG_DATA_HOME="${temp_root}/data" \
    ZDOTDIR="${temp_root}/zdotdir" \
    ZPFX="${temp_root}/zpfx" \
    ZI_TEST_CHECKOUT="$project_root" \
    ZI_TEST_ROOT="$temp_root" \
    ZI_TEST_LOAD="$1" \
    zsh -f <<'ZSH'
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

builtin eval "$ZI_TEST_LOAD" >/dev/null 2>&1 || return 1
(( ${+functions[demo_fn]} )) || return 1

typeset id="%${ZI_TEST_ROOT}/demo" functions_state=none bindkeys_state=none
[[ -n ${ZI[FUNCTIONS_BEFORE__$id]} ]] && functions_state=tracked
[[ ${ZI[BINDKEYS__$id]} == *demo_fn* ]] && bindkeys_state=tracked
typeset -a xd xe
xd=( ${(z)"$(bindkey '^X^D')"} ) xe=( ${(z)"$(bindkey '^X^E')"} )
builtin print -r -- "${ZI[STATES__$id]:-unset} $functions_state $bindkeys_state ${xd[2]} ${xe[2]}"
ZSH
}

typeset -i failures=0
expect() {  # expect <label> <load command> <expected pattern>
  typeset actual
  actual="$(probe "$2")" || {
    builtin print -u2 -r -- "not ok - $1: the load failed or did not source the plug-in"
    (( ++failures ))
    return
  }
  if [[ $actual == ${~3} ]] {
    builtin print -r -- "ok - $1: $actual"
  } else {
    builtin print -u2 -r -- "not ok - $1: expected [$3], got [$actual]"
    (( ++failures ))
  }
}

typeset dir='$ZI_TEST_ROOT/demo'
expect 'zi light'          "zi light $dir"          '1 none none demo_fn undefined-key'
expect 'zi light-mode for' "zi light-mode for $dir" '1 none none demo_fn undefined-key'
# -b keeps the light load but still records bindkey calls; the state value
# follows the load mode passed to .zi-register-plugin and is not pinned here.
expect 'zi light -b'       "zi light -b $dir"       '<-> none tracked demo_fn undefined-key'
# An explicit -b wins over a light-mode ice, so bindmap'' still applies.
expect 'zi light -b after a light-mode ice' \
  "zi ice light-mode bindmap'^X^D -> ^X^E'; zi light -b $dir" \
  '<-> none tracked undefined-key demo_fn'
expect 'zi load'           "zi load $dir"           '2 tracked tracked demo_fn undefined-key'
expect 'zi load -b'        "zi load -b $dir"        '2 tracked tracked demo_fn undefined-key'
# Ices given with `zi ice' before a classic command select the mode as they do
# when passed to the for-syntax.
expect 'zi load after a light-mode ice' \
  "zi ice light-mode; zi load $dir" \
  '1 none none demo_fn undefined-key'
expect 'zi light after a trackbinds ice' \
  "zi ice trackbinds; zi light $dir" \
  '1 none tracked demo_fn undefined-key'
# Without -b or trackbinds a light load does not track bindkeys, so bindmap''
# has nothing to remap.
expect 'zi light with bindmap but no -b' \
  "zi ice bindmap'^X^D -> ^X^E'; zi light $dir" \
  '1 none none demo_fn undefined-key'
# A light load leaves nothing for zi unload to revert; light -b reverts only
# the binding.
expect 'zi unload after zi light' \
  "zi light $dir; zi unload $dir" \
  '0 none none demo_fn undefined-key'
expect 'zi unload after zi light -b' \
  "zi light -b $dir; zi unload $dir" \
  '0 none none undefined-key undefined-key'
# -b tracks bindkeys only, also for as''command'': no PATH snapshot is taken.
# The command is not sourced, so the row defines demo_fn itself once the
# snapshot is confirmed absent.
expect 'zi light -b with as command' \
  "zi ice as'command' pick'demo.plugin.zsh'; zi light -b $dir; [[ -z \${ZI[PATH_BEFORE__%\$ZI_TEST_ROOT/demo]} ]] && demo_fn() { :; }" \
  '<-> none none undefined-key undefined-key'

(( failures == 0 )) || fail "${failures} load form(s) track the wrong state"
builtin print -r -- "ok - zi light loads without tracking, -b tracks bindkeys only, zi load tracks fully"
