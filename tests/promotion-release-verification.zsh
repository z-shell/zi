#!/usr/bin/env zsh

emulate -L zsh
setopt err_exit no_unset pipe_fail

root=${0:A:h:h}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/zi-promotion-release-test.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM

git init --bare "$tmp/origin.git" >/dev/null
git clone "$tmp/origin.git" "$tmp/repository" >/dev/null 2>&1
git -C "$tmp/repository" config user.email release-test@example.invalid
git -C "$tmp/repository" config user.name 'Release Test'
print base > "$tmp/repository/file"
git -C "$tmp/repository" add file
git -C "$tmp/repository" commit -m 'chore: base' >/dev/null
git -C "$tmp/repository" branch -M main
git -C "$tmp/repository" push -u origin main >/dev/null 2>&1
base=$(git -C "$tmp/repository" rev-parse HEAD)

git -C "$tmp/repository" switch -c next >/dev/null 2>&1
print feature >> "$tmp/repository/file"
git -C "$tmp/repository" commit -am 'fix: release candidate' >/dev/null
head=$(git -C "$tmp/repository" rev-parse HEAD)
git -C "$tmp/repository" push -u origin next >/dev/null 2>&1
git -C "$tmp/repository" switch main >/dev/null 2>&1
git -C "$tmp/repository" merge --no-ff next -m 'chore: promote next to main' >/dev/null
target=$(git -C "$tmp/repository" rev-parse HEAD)
git -C "$tmp/repository" push origin main >/dev/null 2>&1

mkdir "$tmp/bin"
cat > "$tmp/bin/gh" <<'FAKE_GH'
#!/usr/bin/env zsh
if [[ $* == *'/commits/'*'/pulls'* ]]; then
  if [[ ${FAKE_PR_MODE:-valid} == missing ]]; then
    print -r -- '[]'
    exit 0
  fi
  source=${FAKE_PR_SOURCE:-next}
  print -r -- "[{\"number\":600,\"merged_at\":\"2026-09-20T00:00:00Z\",\"merge_commit_sha\":\"${FAKE_TARGET}\",\"base\":{\"ref\":\"main\"},\"head\":{\"ref\":\"${source}\",\"sha\":\"${FAKE_HEAD}\",\"repo\":{\"full_name\":\"z-shell/zi\"}}}]"
  exit 0
fi

mode=${FAKE_WORKFLOW_MODE:-success}
names=( Zsh 'ZD Integration' CodeQL 'Trunk Code Quality' )
print -n -r -- '{"workflow_runs":['
separator=''
id=10
for name in "${names[@]}"; do
  [[ $mode == missing && $name == 'ZD Integration' ]] && continue
  run_status=completed
  run_conclusion=success
  [[ $mode == pending && $name == CodeQL ]] && { run_status=in_progress; run_conclusion=''; }
  [[ $mode == failure && $name == 'Trunk Code Quality' ]] && run_conclusion=failure
  print -n -r -- "${separator}{\"id\":${id},\"name\":\"${name}\",\"head_branch\":\"main\",\"head_sha\":\"${FAKE_TARGET}\",\"status\":\"${run_status}\",\"conclusion\":\"${run_conclusion}\"}"
  separator=,
  (( id += 1 ))
done
print -r -- ']}'
FAKE_GH
chmod +x "$tmp/bin/gh"

run_verifier() {
  local mode=${1:-success} source=${2:-next} pr_mode=${3:-valid}
  local output=$tmp/output
  : > "$output"
  (
    cd "$tmp/repository"
    PATH="$tmp/bin:$PATH" \
      GITHUB_OUTPUT=$output \
      GITHUB_REPOSITORY=z-shell/zi \
      PROMOTION_SHA=$target \
      FAKE_TARGET=$target \
      FAKE_HEAD=$head \
      FAKE_WORKFLOW_MODE=$mode \
      FAKE_PR_SOURCE=$source \
      FAKE_PR_MODE=$pr_mode \
      zsh -f "$root/scripts/verify-promotion-release.zsh"
  )
}

expect_fail() {
  if run_verifier "$@" >/dev/null 2>&1; then
    print -u2 -- "expected promotion verification to fail: $*"
    return 1
  fi
}

expect_fail success feature valid
expect_fail success next missing
expect_fail failure next valid
run_verifier missing >/dev/null
grep -q '^ready=false$' "$tmp/output"
run_verifier pending >/dev/null
grep -q '^ready=false$' "$tmp/output"
run_verifier success >/dev/null
grep -q '^ready=true$' "$tmp/output"
grep -q '^promotion_pr=600$' "$tmp/output"

print moved >> "$tmp/repository/file"
git -C "$tmp/repository" commit -am 'chore: move main' >/dev/null
git -C "$tmp/repository" push origin main >/dev/null 2>&1
expect_fail success next valid

GITHUB_REPOSITORY=other/repo PROMOTION_SHA=$target \
  PATH="$tmp/bin:$PATH" zsh -f "$root/scripts/verify-promotion-release.zsh" \
  >/dev/null 2>&1 && { print -u2 -- 'expected repository mismatch to fail'; exit 1; }

[[ $(git -C "$tmp/repository" rev-parse "${target}^1") == $base ]]
print 'promotion release verification tests passed'
