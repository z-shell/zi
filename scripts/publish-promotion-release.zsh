#!/usr/bin/env zsh

emulate -L zsh
setopt err_return no_unset pipe_fail

fail() {
  print -u2 -r -- "promotion release publication: $*"
  return 1
}

repository=${GITHUB_REPOSITORY:-}
tag=${RELEASE_TAG:-}
target=${RELEASE_TARGET:-}
notes_file=${RELEASE_NOTES_FILE:-}

[[ $repository == z-shell/zi ]] || fail "unexpected repository: ${repository:-unset}"
[[ $tag =~ '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' ]] ||
  fail "tag must match vX.Y.Z: ${tag:-unset}"
[[ $target =~ '^[0-9a-f]{40}$' ]] || fail "invalid release target: ${target:-unset}"
[[ -r $notes_file ]] || fail "release notes are not readable: ${notes_file:-unset}"

git fetch --quiet --force --no-tags origin \
  refs/heads/main:refs/remotes/origin/main ||
  fail 'could not fetch origin/main'
current_main=$(git rev-parse refs/remotes/origin/main) || fail 'could not resolve origin/main'
[[ $current_main == $target ]] ||
  fail "main moved from $target to $current_main before publication"

if git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
  git fetch --quiet --force origin "refs/tags/${tag}:refs/tags/${tag}" ||
    fail "could not fetch existing tag: $tag"
  existing_target=$(git rev-parse "refs/tags/${tag}^{}") ||
    fail "could not resolve existing tag: $tag"
  [[ $existing_target == $target ]] ||
    fail "$tag already targets $existing_target, not $target"
  [[ $(git cat-file -t "refs/tags/${tag}") == tag ]] ||
    fail "$tag exists but is not annotated"
else
  git config user.name 'github-actions[bot]'
  git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
  git tag -a "$tag" "$target" -F "$notes_file" || fail "could not create tag: $tag"
  git push origin "refs/tags/${tag}" || fail "could not push tag: $tag"
fi

if gh release view "$tag" --repo "$repository" >/dev/null 2>&1; then
  print -r -- "Release $tag already exists at $target."
  return 0
fi

gh release create "$tag" \
  --repo "$repository" \
  --verify-tag \
  --title "Zi $tag" \
  --notes-file "$notes_file" \
  --latest || fail "could not create release: $tag"
print -r -- "Published $tag at $target."
