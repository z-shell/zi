#!/usr/bin/env zsh

emulate -L zsh
setopt err_exit no_unset pipe_fail

root=${0:A:h:h}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/zi-release-test.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM

git init --bare "$tmp/origin.git" >/dev/null
git clone "$tmp/origin.git" "$tmp/repository" >/dev/null 2>&1
git -C "$tmp/repository" config user.email release-test@example.invalid
git -C "$tmp/repository" config user.name 'Release Test'
print test >"$tmp/repository/file"
git -C "$tmp/repository" add file
git -C "$tmp/repository" commit -m 'test: initial commit' >/dev/null
git -C "$tmp/repository" branch -M main
git -C "$tmp/repository" push -u origin main >/dev/null 2>&1

target=$(git -C "$tmp/repository" rev-parse HEAD)
git -C "$tmp/repository" tag -a v2.1.0 -m v2.1.0
git -C "$tmp/repository" tag v2.1.1

print stale >>"$tmp/repository/file"
git -C "$tmp/repository" commit -am 'test: advance main' >/dev/null
git -C "$tmp/repository" push origin main >/dev/null 2>&1
current=$(git -C "$tmp/repository" rev-parse HEAD)
git -C "$tmp/repository" tag -a v2.2.0 -m v2.2.0

mkdir "$tmp/bin"
cat >"$tmp/bin/gh" <<'FAKE_GH'
#!/usr/bin/env zsh
if [[ $* == *'/git/tags/'* ]]; then
    print -r -- "{\"verification\":{\"verified\":${FAKE_TAG_VERIFIED}},\"object\":{\"type\":\"commit\",\"sha\":\"${FAKE_TAG_TARGET}\"}}"
    exit 0
fi
conclusion=success
[[ ${FAKE_WORKFLOW_FAILURE:-false} == true ]] && conclusion=failure
print -r -- "{\"workflow_runs\":[
{\"name\":\"Zsh\",\"head_branch\":\"main\",\"head_sha\":\"${FAKE_TAG_TARGET}\",\"status\":\"completed\",\"conclusion\":\"${conclusion}\"},
{\"name\":\"ZD Integration\",\"head_branch\":\"main\",\"head_sha\":\"${FAKE_TAG_TARGET}\",\"status\":\"completed\",\"conclusion\":\"success\"},
{\"name\":\"CodeQL\",\"head_branch\":\"main\",\"head_sha\":\"${FAKE_TAG_TARGET}\",\"status\":\"completed\",\"conclusion\":\"success\"},
{\"name\":\"Trunk Code Quality\",\"head_branch\":\"main\",\"head_sha\":\"${FAKE_TAG_TARGET}\",\"status\":\"completed\",\"conclusion\":\"success\"}
]}"
FAKE_GH
chmod +x "$tmp/bin/gh"

run_verifier() {
    local tag=$1 verified=$2 api_target=$3 workflows_fail=${4:-false}
    (
        cd "$tmp/repository"
        PATH="$tmp/bin:$PATH" \
            GITHUB_REF_NAME=$tag \
            GITHUB_REPOSITORY=z-shell/zi \
            FAKE_TAG_VERIFIED=$verified \
            FAKE_TAG_TARGET=$api_target \
            FAKE_WORKFLOW_FAILURE=$workflows_fail \
            zsh -f "$root/scripts/verify-release-tag.zsh"
    )
}

expect_fail() {
    if run_verifier "$@" >/dev/null 2>&1; then
        print -u2 -- "expected verification to fail: $1"
        return 1
    fi
}

expect_fail release-2.2.0 true "$current"
expect_fail v2.1.1 true "$target"
expect_fail v2.1.0 true "$target"
expect_fail v2.2.0 false "$current"
expect_fail v2.2.0 true "$target"
expect_fail v2.2.0 true "$current" true
run_verifier v2.2.0 true "$current"

print 'release tag verification tests passed'
