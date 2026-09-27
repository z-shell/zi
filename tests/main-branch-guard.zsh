#!/usr/bin/env zsh

emulate -L zsh
setopt err_exit no_unset pipe_fail

root=${0:A:h:h}
repo=z-shell/zi
failures=0

# expect STATUS HEAD_REF HEAD_REPOSITORY PR_AUTHOR
expect() {
  local want=$1 ref=$2 head_repo=$3 author=$4 got=0
  HEAD_REF=$ref HEAD_REPOSITORY=$head_repo REPOSITORY=$repo PR_AUTHOR=$author \
    zsh -f "$root/scripts/main-branch-guard.zsh" >/dev/null || got=$?
  if (( got != want )); then
    print -u2 -- "guard returned $got, want $want: ref='$ref' repo='$head_repo' author='$author'"
    failures=$(( failures + 1 ))
  fi
}

expect 0 next "$repo" ss-o
expect 0 hotfix-571 "$repo" ss-o
expect 0 dependabot/npm_and_yarn/lodash-4.17.21 "$repo" 'dependabot[bot]'
expect 0 dependabot/github_actions/actions/checkout-5 "$repo" 'dependabot[bot]'

# A person can open a pull request from a dependabot/ branch name.
expect 1 dependabot/npm_and_yarn/lodash-4.17.21 "$repo" ss-o
# gh reports the author as app/dependabot; the event payload never does.
expect 1 dependabot/npm_and_yarn/lodash-4.17.21 "$repo" app/dependabot
expect 1 dependabot/npm_and_yarn/lodash-4.17.21 "$repo" ''
# The bot author alone does not allow an arbitrary branch.
expect 1 renovate/lodash "$repo" 'dependabot[bot]'
# Fork heads never pass, whatever their name or author.
expect 1 next someone/zi ss-o
expect 1 dependabot/npm_and_yarn/lodash-4.17.21 someone/zi 'dependabot[bot]'
expect 1 feature-571 "$repo" ss-o
expect 1 '' "$repo" ss-o

(( failures == 0 )) || exit 1
print 'main branch guard tests passed'
