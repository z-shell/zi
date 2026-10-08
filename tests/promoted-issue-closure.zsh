#!/usr/bin/env zsh

emulate -L zsh
setopt err_exit no_unset pipe_fail

root=${0:A:h:h}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/zi-promoted-issue-closure-test.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM

git init --quiet "$tmp/repository"
git -C "$tmp/repository" config user.email closure-test@example.invalid
git -C "$tmp/repository" config user.name 'Closure Test'
print base > "$tmp/repository/file"
git -C "$tmp/repository" add file
git -C "$tmp/repository" commit --quiet -m 'chore: base'
git -C "$tmp/repository" branch -M main

git -C "$tmp/repository" switch --quiet -c next
typeset -a picks
for change in one two three; do
  print $change >> "$tmp/repository/file"
  git -C "$tmp/repository" commit --quiet -am "fix: $change"
  picks+=( $(git -C "$tmp/repository" rev-parse HEAD) )
done
head=$(git -C "$tmp/repository" rev-parse HEAD)
git -C "$tmp/repository" switch --quiet main
git -C "$tmp/repository" merge --quiet --no-ff next -m 'chore: promote next to main'
target=$(git -C "$tmp/repository" rev-parse HEAD)
print hotfix >> "$tmp/repository/file"
git -C "$tmp/repository" commit --quiet -am 'fix: direct hotfix'
plain=$(git -C "$tmp/repository" rev-parse HEAD)

# The fake gh answers the commit-to-pull-request and issue reads the script
# makes, and records each close in $FAKE_LOG.
mkdir "$tmp/bin"
cat > "$tmp/bin/gh" <<'FAKE_GH'
#!/usr/bin/env zsh
pr() {
  local number=$1 base=$2 sha=$3 body=$4
  jq -cn --argjson number "$number" --arg base "$base" --arg sha "$sha" --arg body "$body" \
    --arg head_sha "$FAKE_HEAD" '[{
      number: $number, merged_at: "2026-10-01T00:00:00Z", merge_commit_sha: $sha,
      base: {ref: $base, repo: {full_name: "z-shell/zi"}},
      head: {ref: (if $base == "main" then "next" else "feature-\($number)" end),
             sha: $head_sha, repo: {full_name: "z-shell/zi"}},
      body: $body}]'
}
if [[ $1 == api && $2 == graphql ]]; then
  [[ " $* " == *" number=${FAKE_EDITED:-none} "* ]] && print true || print false
  exit 0
fi
if [[ $1 == issue && $2 == close ]]; then
  [[ $3 == ${FAKE_FAIL_CLOSE:-none} ]] && exit 1
  print -r -- "$3 ${(j: :)@[4,-1]}" >> "$FAKE_LOG"
  exit 0
fi
case $* in
  (*"/commits/${FAKE_TARGET}/pulls"*)
    [[ ${FAKE_PROMOTION:-valid} == valid ]] && pr 700 main "$FAKE_TARGET" '' || print -r -- '[]' ;;
  (*"/commits/${FAKE_PICK1}/pulls"*)
    pr 701 next "$FAKE_PICK1" $'Closes #11. Refs #12\nAlso closes #17.' ;;
  (*"/commits/${FAKE_PICK2}/pulls"*)
    pr 702 next "$FAKE_PICK2" $'Fixes #13 after review\nCloses z-shell/.github#5.\n<!-- Closes #14 -->\n`closes #18`\nResolves #15, closes #16 and fixes z-shell/zi#11\nFixes https://github.com/z-shell/zi/issues/20\nFixes #16 and fixes #23 after review\ncloses #22; only on Linux\nFixes #12.5 too\n```\nCloses #24' ;;
  (*"/commits/${FAKE_PICK3}/pulls"*)
    pr 703 main "$FAKE_PICK3" 'Closes #19.' ;;
  (*"/commits/"*"/pulls"*)
    print -r -- '[]' ;;
  (*/issues/11|*/issues/15)
    print -r -- '{"number":1,"state":"open"}' ;;
  (*/issues/16)
    print -r -- '{"number":16,"state":"closed"}' ;;
  (*/issues/17)
    print -r -- '{"number":17,"state":"open","pull_request":{"url":"x"}}' ;;
  (*)
    print -u2 -r -- "fake gh: unexpected call: $*"
    exit 1 ;;
esac
FAKE_GH
chmod +x "$tmp/bin/gh"

run_closer() {
  local sha=$1; shift
  : > "$tmp/log"
  : > "$tmp/summary"
  (
    cd "$tmp/repository"
    env PATH="$tmp/bin:$PATH" \
      GITHUB_REPOSITORY=${REPOSITORY:-z-shell/zi} \
      GITHUB_STEP_SUMMARY="$tmp/summary" \
      PROMOTION_SHA=$sha \
      FAKE_LOG="$tmp/log" \
      FAKE_TARGET=$target \
      FAKE_HEAD=$head \
      FAKE_PICK1=${picks[1]} \
      FAKE_PICK2=${picks[2]} \
      FAKE_PICK3=${picks[3]} \
      "$@" \
      zsh -f "$root/scripts/close-promoted-issues.zsh"
  ) > "$tmp/output" 2>&1
}

check() {
  grep -qF -- "$1" "$2" || { print -u2 -r -- "missing '$1' in ${2:t}:"; cat "$2" >&2; return 1; }
}

refute() {
  ! grep -qF -- "$1" "$2" || { print -u2 -r -- "unexpected '$1' in ${2:t}:"; cat "$2" >&2; return 1; }
}

# A promotion closes only unqualified same-repository closing clauses.
run_closer "$target"
[[ $(<"$tmp/log") == $'11 --repo z-shell/zi --reason completed --comment Released to `main` by promotion #700; the fix merged into `next` in #701.\n15 --repo z-shell/zi --reason completed --comment Released to `main` by promotion #700; the fix merged into `next` in #702.' ]] ||
  { print -u2 -r -- 'unexpected closes:'; cat "$tmp/log" >&2; exit 1; }
check '- #11: closed (from #701)' "$tmp/summary"
check '- #15: closed (from #702)' "$tmp/summary"
check '- #16: already closed (from #702)' "$tmp/summary"
check '- #17: is a pull request, not closed (from #701)' "$tmp/summary"
check '#13 in #702: "Fixes #13 after review"' "$tmp/summary"
check 'z-shell/.github#5 in #702' "$tmp/summary"
refute 'Refs #12' "$tmp/summary"
refute '#14' "$tmp/summary"
refute '#18' "$tmp/summary"
refute '#19' "$tmp/summary"
check 'https://github.com/z-shell/zi/issues/20 in #702' "$tmp/summary"
check '#23 in #702: "fixes #23 after review"' "$tmp/summary"
check '#22 in #702: "closes #22; only on Linux"' "$tmp/summary"
check '#12 in #702: "Fixes #12.5 too"' "$tmp/summary"
refute '#24' "$tmp/summary"

# A body edited after the merge is reported, not trusted.
run_closer "$target" FAKE_EDITED=701
check '15 --repo' "$tmp/log"
check '- #11: closed (from #702)' "$tmp/summary"
check '#11 in #701: body edited after merge' "$tmp/summary"

# A dry run reports without closing.
run_closer "$target" DRY_RUN=1
[[ ! -s $tmp/log ]]
check '- #11: would close (from #701)' "$tmp/output"

# A failed close is reported and fails the run after the other issues.
run_closer "$target" FAKE_FAIL_CLOSE=11 && { print -u2 -- 'expected a failed close to fail'; exit 1; }
check '- #11: close failed (from #701)' "$tmp/summary"
check '15 --repo' "$tmp/log"

# Pushes that are not a next promotion close nothing.
run_closer "$plain"
check 'is not a merge commit' "$tmp/output"
[[ ! -s $tmp/log ]]
run_closer "$target" FAKE_PROMOTION=missing
check 'is not a merged next-to-main promotion' "$tmp/output"
[[ ! -s $tmp/log ]]

# Other repositories and malformed input are refused.
REPOSITORY=other/repo run_closer "$target" && { print -u2 -- 'expected repository mismatch to fail'; exit 1; }
run_closer not-a-sha && { print -u2 -- 'expected an invalid SHA to fail'; exit 1; }

print 'promoted issue closure tests passed'
