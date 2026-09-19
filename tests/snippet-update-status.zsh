#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
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

@zi-unregister-annex test-update hook:atpull-90
_test_pre_failure() { return 23; }
zi ice atpull'!:'
zi snippet "$HOME/snippet.zsh" >/dev/null 2>&1 || exit 1
@zi-register-annex test-pre 'hook:!atpull-90' _test_pre_failure ''
zi update "$HOME/snippet.zsh" >/dev/null 2>&1
update_rc=$?
(( update_rc == 23 )) || {
  print -u2 -r -- "not ok - failed local-file pre-update hook returned $update_rc instead of 23"
  exit 1
}

# URL and SVN snippets run their pre-update hooks in a nested download
# subshell; stub the network helpers so those branches run offline.
.zi-download-file-stdout() { print -r -- 'typeset -g SNIPPET_TEST_VALUE=2'; }
.zi-get-url-mtime() { REPLY=$EPOCHSECONDS; }
.zi-mirror-directory() {
  command mkdir -p -- "$3" && print -r -- 'typeset -g SNIPPET_DIR_VALUE=1' > "$3/dir.plugin.zsh"
}
typeset url_snippet=https://example.invalid/snippet.zsh svn_snippet=https://example.invalid/dir
zi ice atpull'!:'
zi snippet "$url_snippet" >/dev/null 2>&1 || exit 1
zi ice svn atpull'!:'
zi snippet "$svn_snippet" >/dev/null 2>&1 || exit 1
@zi-unregister-annex test-pre 'hook:!atpull-90'
zi update "$url_snippet" >/dev/null 2>&1 || {
  print -u2 -r -- 'not ok - successful URL snippet update returned failure'
  exit 1
}
zi update "$svn_snippet" >/dev/null 2>&1 || {
  print -u2 -r -- 'not ok - successful SVN snippet update returned failure'
  exit 1
}
@zi-register-annex test-pre 'hook:!atpull-90' _test_pre_failure ''
zi update "$url_snippet" >/dev/null 2>&1
update_rc=$?
(( update_rc == 23 )) || {
  print -u2 -r -- "not ok - failed URL pre-update hook returned $update_rc instead of 23"
  exit 1
}
zi update "$svn_snippet" >/dev/null 2>&1
update_rc=$?
(( update_rc == 23 )) || {
  print -u2 -r -- "not ok - failed SVN pre-update hook returned $update_rc instead of 23"
  exit 1
}
@zi-unregister-annex test-pre 'hook:!atpull-90'
.zi-download-file-stdout() { return 1; }
zi update "$url_snippet" >/dev/null 2>&1
update_rc=$?
(( update_rc == 4 )) || {
  print -u2 -r -- "not ok - failed URL download returned $update_rc instead of 4"
  exit 1
}
typeset -a leftover=( "$TMPDIR"/zi-snippet-hook.*(N) )
(( ${#leftover} == 0 )) || {
  print -u2 -r -- "not ok - hook status files were left behind: $leftover"
  exit 1
}
print -r -- 'ok - snippet updates return success and preserve failure after later successful hooks'
