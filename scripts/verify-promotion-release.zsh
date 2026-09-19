#!/usr/bin/env zsh

emulate -L zsh
setopt err_return no_unset pipe_fail

fail() {
  print -u2 -r -- "promotion release verification: $*"
  return 1
}

emit() {
  [[ -z ${GITHUB_OUTPUT:-} ]] || print -r -- "$1=$2" >> "$GITHUB_OUTPUT"
}

repository=${GITHUB_REPOSITORY:-}
target=${PROMOTION_SHA:-}

emit ready false
[[ $repository == z-shell/zi ]] || fail "unexpected repository: ${repository:-unset}"
[[ $target =~ '^[0-9a-f]{40}$' ]] || fail "invalid promotion SHA: ${target:-unset}"

git fetch --quiet --force --no-tags origin \
  refs/heads/main:refs/remotes/origin/main ||
  fail 'could not fetch origin/main'

main=$(git rev-parse refs/remotes/origin/main) || fail 'could not resolve origin/main'
[[ $target == $main ]] || fail 'promotion SHA is not the current origin/main'

typeset -a parents
parents=( ${(s: :)"$(git rev-list --parents -n 1 "$target")"} )
(( $#parents == 3 )) || fail 'promotion commit must have exactly two parents'

pulls_json=$(gh api -H 'Accept: application/vnd.github+json' \
  "repos/${repository}/commits/${target}/pulls") ||
  fail 'could not read pull requests for the promotion commit'

promotion=$(jq -c --arg repository "$repository" --arg target "$target" \
  '[.[] | select(
    .merged_at != null and
    .merge_commit_sha == $target and
    .base.ref == "main" and
    .head.ref == "next" and
    .head.repo.full_name == $repository
  )] | first // empty' <<<"$pulls_json") || fail 'could not inspect promotion pull request'
[[ -n $promotion ]] || fail 'commit is not a merged next-to-main promotion'

promotion_pr=$(jq -r '.number' <<<"$promotion")
promotion_head=$(jq -r '.head.sha' <<<"$promotion")
[[ ${parents[3]} == $promotion_head ]] ||
  fail 'promotion second parent does not match the reviewed next head'

runs_json=$(gh api --method GET "repos/${repository}/actions/runs" \
  -f branch=main -f head_sha="$target" -f per_page=100) ||
  fail 'could not read workflow runs'

typeset workflow run run_status run_conclusion
for workflow in Zsh 'ZD Integration' CodeQL 'Trunk Code Quality'; do
  run=$(jq -c --arg name "$workflow" --arg target "$target" \
    '[.workflow_runs[] | select(
      .name == $name and
      .head_branch == "main" and
      .head_sha == $target
    )] | sort_by(.id) | last // empty' <<<"$runs_json") ||
    fail "could not inspect required workflow: $workflow"

  if [[ -z $run ]]; then
    print -r -- "Waiting for required workflow: $workflow"
    emit promotion_pr "$promotion_pr"
    return 0
  fi

  run_status=$(jq -r '.status' <<<"$run")
  run_conclusion=$(jq -r '.conclusion // ""' <<<"$run")
  if [[ $run_status != completed ]]; then
    print -r -- "Waiting for required workflow: $workflow ($run_status)"
    emit promotion_pr "$promotion_pr"
    return 0
  fi
  [[ $run_conclusion == success ]] ||
    fail "required workflow did not succeed: $workflow ($run_conclusion)"
done

emit promotion_pr "$promotion_pr"
emit ready true
print -r -- "Promotion #${promotion_pr} and required workflows verified at ${target}."
