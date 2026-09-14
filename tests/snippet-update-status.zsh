#!/usr/bin/env zsh
# Verify public snippet updates without network access or caller state.
builtin emulate -R zsh
setopt pipe_fail

typeset project_root=${0:A:h:h}
typeset temp_root=$(command mktemp -d "${TMPDIR:-/tmp}/zi-snippet-status.XXXXXXXX") || exit 1
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM
export HOME=$temp_root/home ZDOTDIR=$temp_root/home TMPDIR=$temp_root/tmp
command mkdir -p -- "$HOME" "$TMPDIR" || exit 1
typeset -gA ZI=( HOME_DIR $temp_root/data CACHE_DIR $temp_root/cache CONFIG_DIR $temp_root/config )
typeset -gx ZPFX=$temp_root/prefix
source "$project_root/zi.zsh" || exit 1
.zi-prepare-home || exit 1
print -r -- 'typeset -g SNIPPET_TEST_VALUE=1' > "$HOME/snippet.zsh"
zi snippet "$HOME/snippet.zsh" >/dev/null || exit 1
zi update "$HOME/snippet.zsh" >/dev/null || {
  print -u2 -r -- 'not ok - successful snippet update returned failure'
  exit 1
}

_test_update_failure() { return 17; }
_test_update_success() { return 0; }
@zi-register-annex test-update hook:atpull-90 _test_update_failure ''
@zi-register-annex test-later hook:atpull-99 _test_update_success ''
zi update "$HOME/snippet.zsh" >/dev/null 2>&1
integer update_rc=$?
(( update_rc == 17 )) || {
  print -u2 -r -- "not ok - failed update returned $update_rc instead of 17"
  exit 1
}
print -r -- 'ok - snippet updates return success and preserve failure after later successful hooks'
