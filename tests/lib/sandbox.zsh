# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# Shared test sandbox (#658). Every tests/*.zsh sources this file first:
#
#   source "${0:A:h}/lib/sandbox.zsh" NAME
#
# It creates $temp_root, removed on exit, and gives the test process and every
# child it starts a private HOME, XDG directories and TMPDIR under
# $temp_root/.sandbox, an empty Git global and system configuration, and none
# of the caller's ZPFX, Go or Rust paths. That is the environment CI provides;
# a contributor's shell usually exports more, and those values otherwise reach
# Zi and Git. FPATH stays in this shell but is no longer exported to children.
#
# Nothing here seeds the ZI array: tests that check how Zi derives its
# directories from XDG_DATA_HOME or HOME still observe that derivation. The
# directories a test creates under $temp_root are its own; the sandbox keeps
# to $temp_root/.sandbox. The cleanup trap is set at this file's top level
# because a trap set inside a function fires when that function returns.

() {
  builtin emulate -L zsh
  local name=${1:-zi-test}
  typeset -g temp_root
  temp_root=$(command mktemp -d "${TMPDIR:-/tmp}/zi-${name}.XXXXXXXX") || {
    builtin print -u2 -r -- "not ok - sandbox: create temporary directory"
    return 1
  }
  local base=${temp_root}/.sandbox
  command mkdir -p -- "${base}"/{home,config,cache,data,state,tmp} || {
    builtin print -u2 -r -- "not ok - sandbox: create isolated environment"
    return 1
  }
  export HOME=${base}/home ZDOTDIR=${base}/home TMPDIR=${base}/tmp
  export XDG_CONFIG_HOME=${base}/config XDG_CACHE_HOME=${base}/cache
  export XDG_DATA_HOME=${base}/data XDG_STATE_HOME=${base}/state
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  # Git also takes configuration, identity and a repository from the
  # environment, for example inside a hook; drop all of it.
  builtin unset -m 'GIT_CONFIG_KEY_*' 'GIT_CONFIG_VALUE_*' 'GIT_AUTHOR_*' 'GIT_COMMITTER_*'
  builtin unset GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS GIT_CONFIG \
    GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  builtin unset ZPFX GOPATH GOBIN GOMODCACHE CARGO_HOME RUSTUP_HOME
  builtin typeset +x FPATH
} "$@" || builtin exit 1

# Removes $temp_root, including read-only directories a test or a Go module
# download left behind.
zi_sandbox_cleanup() {
  builtin emulate -L zsh
  [[ -n ${temp_root} && -d ${temp_root} ]] || return 0
  command chmod -R u+rwX -- "${temp_root}" 2>/dev/null
  command rm -rf -- "${temp_root}"
}

# A signal ends the test after cleanup; it must not go on against a removed
# HOME and TMPDIR.
trap zi_sandbox_cleanup EXIT
trap 'zi_sandbox_cleanup; builtin exit 129' HUP
trap 'zi_sandbox_cleanup; builtin exit 130' INT
trap 'zi_sandbox_cleanup; builtin exit 143' TERM
