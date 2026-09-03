#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -R zsh
setopt pipe_fail

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

pass() {
  builtin print -r -- "ok - $1"
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-disk-ice-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" || fail "create isolated environment"

# .zi-load-ices resolves an already-installed object's metadata directory. The
# plugin root flattens `/' to `---'; the snippet root keeps the slashes. The
# object's type is not always known at the call site, because a disk-stored
# `is-snippet' ice is one of the values the read itself supplies.
env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  zsh -f <<'ZSH' || fail "disk-ice resolution"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" >/dev/null 2>&1 || return 1

typeset -gA ICE
typeset -g captured

die() {
  builtin print -u2 -r -- "not ok - $1"
  builtin exit 1
}

assert_equal() {
  [[ $1 == "$2" ]] || die "$3: expected ${(qqq)2}, got ${(qqq)1}"
}

write_ices() {
  local dir="$1"; shift
  command mkdir -p -- "$dir" || die "create $dir"
  local pair
  for pair; do
    builtin print -r -- "${pair#*=}" >! "$dir/${pair%%=*}" || die "write ${pair%%=*}"
  done
}

# The snippet root layout is whatever .zi-get-object-path computes, because
# that is what .zi-load-snippet uses when it writes these directories.
snippet_dir() {
  local -A ICE
  .zi-get-object-path snippet "$1"
  builtin print -r -- "${reply[-3]}${reply[-2]:+/${reply[-2]}}/._zi"
}

plugin_dir() {
  builtin print -r -- "${ZI[PLUGINS_DIR]}/${1//\//---}/._zi"
}

# Runs .zi-load-ices in this shell, so ICE survives, while capturing anything
# the call reports.
load_ices() {
  ICE=()
  { .zi-load-ices "$@" } >| "${TMPDIR:-/tmp}/zi-disk-ice-out.$$" 2>&1
  local rc=$?
  captured="$(<"${TMPDIR:-/tmp}/zi-disk-ice-out.$$")"
  command rm -f -- "${TMPDIR:-/tmp}/zi-disk-ice-out.$$"
  return $rc
}

# 1. A plain plugin ID reads the plugin's ices.
write_ices "$(plugin_dir plain-plugin)" 'atload=PLUGIN_ATLOAD' 'as=null'
load_ices plain-plugin || die "plain plugin: non-zero return"
assert_equal "${ICE[atload]}" PLUGIN_ATLOAD "plain plugin atload"

# 2. A plain snippet ID reads the snippet's ices, including is-snippet.
write_ices "$(snippet_dir plain-snippet)" 'atload=SNIPPET_ATLOAD' 'is-snippet='
load_ices plain-snippet || die "plain snippet: non-zero return"
assert_equal "${ICE[atload]}" SNIPPET_ATLOAD "plain snippet atload"
assert_equal "${+ICE[is-snippet]}" 1 "plain snippet is-snippet"

# 3. A slash-bearing ID must resolve to the directory .zi-load-snippet writes,
#    not to the plugin root's `---' flattening of it.
assert_equal "$(snippet_dir user/name)" "${ZI[SNIPPETS_DIR]}/user/name/._zi" "slashed snippet layout"
write_ices "${ZI[SNIPPETS_DIR]}/user/name/._zi" 'atload=SLASHED_ATLOAD' 'is-snippet='
load_ices user/name || die "slashed snippet: non-zero return"
assert_equal "${ICE[atload]}" SLASHED_ATLOAD "slashed snippet atload"
[[ -d ${ZI[SNIPPETS_DIR]}/user---name ]] && die "slashed snippet: probed the flattened path"

# 4. A colliding ID with an undetermined type is reported, not resolved
#    silently. The plugin stays the documented choice.
write_ices "$(plugin_dir collide-id)"  'atload=COLLIDE_PLUGIN'
write_ices "$(snippet_dir collide-id)" 'atload=COLLIDE_SNIPPET' 'is-snippet='
load_ices collide-id || die "collision: non-zero return"
assert_equal "${ICE[atload]}" COLLIDE_PLUGIN "collision resolves to the plugin"
[[ -n $captured ]] || die "collision: resolved silently"
[[ $captured == *collide-id* ]] || die "collision: report does not name the ID"

# 5. Only `snippet' is accepted as settled knowledge. A caller cannot claim
#    the object is a plugin, so a collision under any other value is still
#    reported rather than resolved silently.
load_ices collide-id plugin || die "collision under a non-snippet type: non-zero return"
assert_equal "${ICE[atload]}" COLLIDE_PLUGIN "collision under a non-snippet type resolves to the plugin"
[[ -n $captured ]] || die "collision under a non-snippet type: resolved silently"

# 6. A caller that knows the object is a snippet reaches the snippet's ices,
#    and is not told about a collision it has already resolved.
load_ices collide-id snippet || die "typed collision: non-zero return"
assert_equal "${ICE[atload]}" COLLIDE_SNIPPET "typed collision resolves to the snippet"
assert_equal "$captured" "" "typed collision reports nothing"

# 7. An empty plugin metadata directory is a leftover, not an object. It must
#    not shadow the snippet, and it is not a collision.
write_ices "$(snippet_dir leftover-id)" 'atload=LEFTOVER_SNIPPET' 'as=command'
command mkdir -p -- "$(plugin_dir leftover-id)" || die "create leftover"
load_ices leftover-id || die "leftover: non-zero return"
assert_equal "${ICE[atload]}" LEFTOVER_SNIPPET "leftover does not shadow the snippet"
assert_equal "${ICE[as]}" command "leftover: snippet ices are complete"
assert_equal "$captured" "" "leftover is not reported as a collision"

# 8. An ID present in neither root fails.
load_ices absent-id && die "absent ID: reported success"

# 9. Resolution runs with the user's shell options. The root probe must not
#    depend on any of them.
() {
  builtin setopt local_options sh_glob no_bare_glob_qual no_extended_glob no_null_glob
  load_ices plain-plugin  || die "sh_glob: plain plugin non-zero return"
  assert_equal "${ICE[atload]}" PLUGIN_ATLOAD "sh_glob plain plugin atload"
  assert_equal "$captured" "" "sh_glob plain plugin reports nothing"
  load_ices plain-snippet || die "sh_glob: plain snippet non-zero return"
  assert_equal "${ICE[atload]}" SNIPPET_ATLOAD "sh_glob plain snippet atload"
}

builtin exit 0
ZSH
pass "disk-ice resolution honours the object type and both root layouts"

# The unit checks above call .zi-load-ices directly. This drives the only
# caller instead: a `pack'"'"'' load of an already-installed object, which is the
# situation the disk-ice read exists for. .zi-load-object is the seam where the
# resolved type and the assembled ICE hash meet, so stub it and read both off.
command mkdir -p "${temp_root}/e2e" || fail "create end-to-end environment"
env \
  HOME="${temp_root}/e2e" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  zsh -f <<'ZSH' || fail "pack loads resolve their disk-ices"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" >/dev/null 2>&1 || return 1
.zi-prepare-home || return 1

die() {
  builtin print -u2 -r -- "not ok - $1"
  builtin exit 1
}

typeset -g loaded_type loaded_id loaded_atload
# Stubbed at the point where zi() hands the classified object over, so nothing
# is installed, downloaded, or sourced.
.zi-load-object() {
  loaded_type="$1" loaded_id="$2" loaded_atload="${ICE[atload]}"
  return 0
}

install_snippet() {  # install_snippet <id> <atload>
  local -A ICE
  .zi-get-object-path snippet "$1"
  local dir="${reply[-3]}${reply[-2]:+/${reply[-2]}}/._zi"
  command mkdir -p -- "$dir" || die "create $dir"
  builtin print -r -- "$2" >! "$dir/atload" || die "write atload"
  builtin print -r --    >! "$dir/is-snippet" || die "write is-snippet"
}

install_plugin() {  # install_plugin <id> <atload>
  local dir="${ZI[PLUGINS_DIR]}/${1//\//---}/._zi"
  command mkdir -p -- "$dir" || die "create $dir"
  builtin print -r -- "$2" >! "$dir/atload" || die "write atload"
}

check() {  # check <label> <id> <expected type> <expected atload>
  loaded_type= loaded_id= loaded_atload=
  zi for pack "$2" >/dev/null 2>&1
  [[ $loaded_id == "$2" ]] || die "$1: loaded ${(qqq)loaded_id}, expected ${(qqq)2}"
  [[ $loaded_type == "$3" ]] || die "$1: classified as ${(qqq)loaded_type}, expected ${(qqq)3}"
  [[ $loaded_atload == "$4" ]] || die "$1: atload was ${(qqq)loaded_atload}, expected ${(qqq)4}"
}

# A package installed into the snippet root loads as a snippet, with its ices.
install_snippet e2e-snippet SNIPPET_ATLOAD
check "snippet package" e2e-snippet snippet SNIPPET_ATLOAD

# An empty leftover in the plugin root must not shadow it. Before this was
# fixed the load found no ices at all and ran as a plug-in.
install_snippet e2e-leftover LEFTOVER_ATLOAD
command mkdir -p -- "${ZI[PLUGINS_DIR]}/e2e-leftover/._zi" || die "create leftover"
check "leftover in the plugin root" e2e-leftover snippet LEFTOVER_ATLOAD

# A package installed into the plugin root is unaffected.
install_plugin e2e-plugin PLUGIN_ATLOAD
check "plugin package" e2e-plugin plugin PLUGIN_ATLOAD

# A slash-bearing ID reaches the snippet path that holds it, rather than the
# plugin root's `---' flattening of the same ID.
install_snippet user/e2e-name SLASHED_ATLOAD
check "slash-bearing ID" user/e2e-name snippet SLASHED_ATLOAD

builtin exit 0
ZSH
pass "a pack load resolves its disk-ices from the root that holds them"

# The type passed to .zi-load-ices can only be as complete as what is known
# before the read. Guard the ordering that makes it non-empty at all: $___etid
# and the classification test must precede the call, and the second pass that
# folds in a disk-stored `is-snippet' must follow it.
first_line() {
  local -a matched
  matched=( ${(f)"$(command grep -n -- "$1" "${project_root}/zi.zsh")"} )
  builtin print -r -- "${matched[1]%%:*}"
}

typeset -i etid_line class_line call_line second_line
etid_line=$(first_line '^ *___etid="\${ICE\[teleid\]')
class_line=$(first_line 'ICE\[is-snippet\]+1} || \$___etid = ')
call_line=$(first_line '^ *\.zi-load-ices "\$___ehid"')
second_line=$(first_line '___is_snippet >= 0 )) && \[\[ -n \${ICE\[is-snippet\]+1} \]\]')

(( etid_line > 0 ))   || fail "the effective remote-ID assignment was not found"
(( class_line > 0 ))  || fail "the snippet classification test was not found"
(( call_line > 0 ))   || fail "the .zi-load-ices call site was not found"
(( second_line > 0 )) || fail "the disk-ice classification pass was not found"
(( etid_line < class_line )) || fail "the classification test must follow the effective remote-ID"
(( class_line < call_line )) || fail "the classification test must precede .zi-load-ices"
(( call_line < second_line )) || fail "the disk-ice classification pass must follow .zi-load-ices"
pass "the call site classifies before the disk-ice read and refines after it"

builtin exit 0
