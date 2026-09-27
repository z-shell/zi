#!/usr/bin/env zsh

# Decide whether a pull request may target main. The Main Branch Source Guard
# workflow runs this from the base branch, never from the pull request head.
# Policy: z-shell/.github runbooks/branch-protection.md, "Main-branch source guard".

emulate -L zsh
setopt err_return no_unset pipe_fail

head_ref=${HEAD_REF:-}
head_repository=${HEAD_REPOSITORY:-}
repository=${REPOSITORY:-}
author=${PR_AUTHOR:-}

if [[ -z $repository || $head_repository != "$repository" ]]; then
    print -r -- "::error::Pull requests into main must come from this repository (got '${head_repository}')."
    exit 1
fi

if [[ $head_ref == next || $head_ref == hotfix-* ]]; then
    print -r -- "Head branch '${head_ref}' is allowed to target main."
    exit 0
fi

# Dependabot security updates always target the default branch, whatever
# target-branch says. The event payload login is dependabot[bot]; gh shows the
# same account as app/dependabot, which never appears here.
if [[ $head_ref == dependabot/* && $author == 'dependabot[bot]' ]]; then
    print -r -- "Dependabot branch '${head_ref}' is allowed to target main."
    exit 0
fi

print -r -- "::error::Pull requests into main must come from 'next', a 'hotfix-*' branch, or a 'dependabot/*' branch opened by dependabot[bot] (got '${head_ref}' by '${author}'). See ADR-0019 (z-shell/.github) for the branching model."
exit 1
