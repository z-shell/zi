#!/usr/bin/env zsh

emulate -L zsh
setopt err_return no_unset pipe_fail

fail() {
    print -u2 -- "release verification: $*"
    return 1
}

tag=${GITHUB_REF_NAME:-}
repository=${GITHUB_REPOSITORY:-}

[[ $repository == z-shell/zi ]] || fail "unexpected repository: ${repository:-unset}"
[[ $tag =~ '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' ]] ||
    fail "tag must match vX.Y.Z: ${tag:-unset}"

tag_ref="refs/tags/${tag}"
[[ $(git cat-file -t "$tag_ref" 2>/dev/null) == tag ]] ||
    fail "tag must be annotated: $tag"

git fetch --quiet --force --no-tags origin \
    refs/heads/main:refs/remotes/origin/main ||
    fail "could not fetch origin/main"

target=$(git rev-parse "${tag_ref}^{}") || fail "could not resolve tag target"
main=$(git rev-parse refs/remotes/origin/main) || fail "could not resolve origin/main"
[[ $target == $main ]] || fail "tag target is not the current origin/main"

tag_object=$(git rev-parse "$tag_ref") || fail "could not resolve tag object"
tag_json=$(gh api "repos/${repository}/git/tags/${tag_object}") ||
    fail "could not read tag verification"
jq -e --arg target "$target" \
    '.verification.verified == true and
     .object.type == "commit" and
     .object.sha == $target' <<<"$tag_json" >/dev/null ||
    fail "GitHub did not verify the signed tag and target"

runs_json=$(gh api --method GET "repos/${repository}/actions/runs" \
    -f branch=main -f head_sha="$target" -f per_page=100) ||
    fail "could not read workflow runs"

for workflow in Zsh 'ZD Integration' CodeQL 'Trunk Code Quality'; do
    jq -e --arg name "$workflow" --arg target "$target" \
        '.workflow_runs | any(
            .name == $name and
            .head_branch == "main" and
            .head_sha == $target and
            .status == "completed" and
            .conclusion == "success"
        )' <<<"$runs_json" >/dev/null ||
        fail "required workflow did not succeed: $workflow"
done

print -- "Release authorization verified for ${tag} at ${target}."
