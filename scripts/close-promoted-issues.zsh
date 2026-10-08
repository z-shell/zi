#!/usr/bin/env zsh
# Close the issues a next-to-main promotion delivers. GitHub runs closing
# keywords only for pull requests into the default branch, so `Closes #N` in a
# pull request merged into next has no effect until next reaches main.
#
# Only the pull request body is read, and only an unqualified closing clause counts: a keyword and a same-repository
# reference that ends the sentence or the line, or is followed by another
# closing clause. A body edited after the merge is not trusted: its references
# are reported instead, since GitHub reads closing keywords only at merge. `Refs #N`, `Closes #N after ...`, and references inside
# comments or code are reported, never closed (z-shell/.github#523).

emulate -L zsh
setopt err_return no_unset pipe_fail

fail() {
  print -u2 -r -- "promotion issue closure: $*"
  return 1
}

report() {
  print -r -- "$1"
  [[ -z ${GITHUB_STEP_SUMMARY:-} ]] || print -r -- "$1" >> "$GITHUB_STEP_SUMMARY"
}

repository=${GITHUB_REPOSITORY:-}
target=${PROMOTION_SHA:-}
dry_run=${DRY_RUN:-0}

[[ $repository == z-shell/zi ]] || fail "unexpected repository: ${repository:-unset}"
[[ $target =~ '^[0-9a-f]{40}$' ]] || fail "invalid promotion SHA: ${target:-unset}"

typeset -a parents
parents=( ${(s: :)"$(git rev-list --parents -n 1 "$target")"} ) ||
  fail 'could not read the promotion commit'
if (( $#parents != 3 )); then
  print -r -- "Commit ${target} is not a merge commit; nothing to close."
  return 0
fi

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
if [[ -z $promotion ]]; then
  print -r -- "Commit ${target} is not a merged next-to-main promotion; nothing to close."
  return 0
fi

promotion_pr=$(jq -r '.number' <<<"$promotion")
[[ ${parents[3]} == $(jq -r '.head.sha' <<<"$promotion") ]] ||
  fail 'promotion second parent does not match the reviewed next head'

# The jq program reads one pull request body and prints the issue numbers it
# closes, then a tab-separated line for each closing-looking reference skipped.
references_jq='
def keyword: "(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)";
def clean:
  gsub("<!--[\\s\\S]*?(?:-->|\\z)"; "")
  | gsub("```[\\s\\S]*?(?:```|\\z)"; "")
  | gsub("~~~[\\s\\S]*?(?:~~~|\\z)"; "")
  | gsub("`[^`\\n]*`"; "");
($repository | gsub("\\."; "\\.")) as $repo
| (. // "" | clean) as $body
| [ $body | scan("(?i)(?:\\A|[^\\w/-])" + keyword + ":?[ \\t]+(?:" + $repo
      + ")?#([0-9]+)(?![\\w-]|\\.\\w)(?=[ \\t]*(?:\\r?\\n|\\z|[.)]|,[ \\t]*(?:and[ \\t]+)?"
      + keyword + "\\b|[ \\t]+and[ \\t]+" + keyword + "\\b))")
    | .[0] | tonumber ] | unique as $closes
| ($closes[] | "close\t\(.)"),
  ( $body
    | match("(?i)(?:\\A|[^\\w/-])(" + keyword + ":?[ \\t]+((?:[\\w.-]+/[\\w.-]+)?#([0-9]+)|https?://github\\.com/[\\w.-]+/[\\w.-]+/issues/([0-9]+)))"; "g")
    | .captures as [$clause, $ref, $short, $url]
    | select(($ref.string | test("^#|^" + $repo + "#"; "i") | not)
        or (($short.string // $url.string | tonumber) as $n | $closes | index($n) | not))
    | "skip\t\($ref.string)\t\($body[$clause.offset:$clause.offset + 60]
        | split("\n")[0] | gsub("[\\t\\r]"; " "))")
'

# Oldest first, so an issue is credited to the first pull request that closed it.
typeset -a commits
commits=( ${(f)"$(git rev-list --reverse --first-parent "${parents[2]}..${parents[3]}")"} ) ||
  fail 'could not list the promoted commits'

typeset -A closed_by
typeset -a skipped
typeset commit pr_json pr pr_number edited references line kind rest
for commit in $commits; do
  pr_json=$(gh api -H 'Accept: application/vnd.github+json' \
    "repos/${repository}/commits/${commit}/pulls") ||
    fail "could not read pull requests for commit ${commit}"
  pr=$(jq -c --arg repository "$repository" --arg commit "$commit" \
    '[.[] | select(
      .merged_at != null and
      .merge_commit_sha == $commit and
      .base.ref == "next" and
      .base.repo.full_name == $repository
    )] | first // empty' <<<"$pr_json") || fail "could not inspect commit ${commit}"
  [[ -n $pr ]] || continue
  pr_number=$(jq -r '.number' <<<"$pr")

  edited=$(gh api graphql -F number="$pr_number" -f owner="${repository%%/*}" \
    -f name="${repository#*/}" -f query='
      query($owner: String!, $name: String!, $number: Int!) {
        repository(owner: $owner, name: $name) {
          pullRequest(number: $number) { lastEditedAt mergedAt }
        }
      }' --jq '.data.repository.pullRequest
        | (.lastEditedAt // "") > .mergedAt') ||
    fail "could not read the edit history of #${pr_number}"

  references=$(jq -r --arg repository "$repository" \
    ".body | ${references_jq}" <<<"$pr") ||
    fail "could not parse the body of #${pr_number}"
  for line in ${(f)references}; do
    kind=${line%%$'\t'*}
    rest=${line#*$'\t'}
    if [[ $kind == close && $edited == true ]]; then
      skipped+=( "#${rest} in #${pr_number}: body edited after merge" )
    elif [[ $kind == close ]]; then
      [[ -n ${closed_by[$rest]:-} ]] || closed_by[$rest]=$pr_number
    else
      skipped+=( "${rest%%$'\t'*} in #${pr_number}: \"${rest#*$'\t'}\"" )
    fi
  done
done

report "## Issues delivered by promotion #${promotion_pr}"
report ''

integer failures=0
typeset issue issue_json state verb
for issue in ${(on)${(k)closed_by}}; do
  if ! issue_json=$(gh api "repos/${repository}/issues/${issue}"); then
    report "- #${issue}: could not be read (from #${closed_by[$issue]})"
    (( failures += 1 ))
    continue
  fi
  if [[ $(jq -r 'has("pull_request") and .pull_request != null' <<<"$issue_json") == true ]]; then
    report "- #${issue}: is a pull request, not closed (from #${closed_by[$issue]})"
    continue
  fi
  state=$(jq -r '.state' <<<"$issue_json")
  if [[ $state != open ]]; then
    report "- #${issue}: already ${state} (from #${closed_by[$issue]})"
    continue
  fi
  if (( dry_run )); then
    report "- #${issue}: would close (from #${closed_by[$issue]})"
    continue
  fi
  if gh issue close "$issue" --repo "$repository" --reason completed \
      --comment "Released to \`main\` by promotion #${promotion_pr}; the fix merged into \`next\` in #${closed_by[$issue]}."; then
    report "- #${issue}: closed (from #${closed_by[$issue]})"
  else
    report "- #${issue}: close failed (from #${closed_by[$issue]})"
    (( failures += 1 ))
  fi
done
(( ${#closed_by} )) || report '- No promoted pull request carries an unqualified closing keyword.'

if (( $#skipped )); then
  report ''
  report 'Closing-style references left open (qualified, another repository, not a closing clause, or edited after merge); check them by hand:'
  report ''
  for line in $skipped; do
    report "- ${line}"
  done
fi

(( failures == 0 )) || fail "${failures} issue(s) could not be processed"
