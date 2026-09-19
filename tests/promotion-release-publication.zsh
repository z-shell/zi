#!/usr/bin/env zsh

emulate -L zsh
setopt err_exit no_unset pipe_fail

root=${0:A:h:h}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/zi-promotion-publish-test.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM

typeset -a content_writers
content_writers=( ${(f)"$(grep -l '^[[:space:]]*contents:[[:space:]]*write' "$root"/.github/workflows/*.yml || true)"} )
(( $#content_writers == 1 ))
[[ ${content_writers[1]:t} == release.yml ]]
grep -q 'workflow_run:' "$root/.github/workflows/release.yml"
! grep -q 'pull_request_target:' "$root/.github/workflows/release.yml"

git init --bare "$tmp/origin.git" >/dev/null
git clone "$tmp/origin.git" "$tmp/repository" >/dev/null 2>&1
git -C "$tmp/repository" config user.email release-test@example.invalid
git -C "$tmp/repository" config user.name 'Release Test'
print base > "$tmp/repository/file"
git -C "$tmp/repository" add file
git -C "$tmp/repository" commit -m 'chore: base' >/dev/null
print release >> "$tmp/repository/file"
git -C "$tmp/repository" commit -am 'fix: candidate' >/dev/null
git -C "$tmp/repository" branch -M main
git -C "$tmp/repository" push -u origin main >/dev/null 2>&1
target=$(git -C "$tmp/repository" rev-parse HEAD)
print notes > "$tmp/notes.md"

mkdir "$tmp/bin"
cat > "$tmp/bin/gh" <<'FAKE_GH'
#!/usr/bin/env zsh
state=${FAKE_RELEASE_STATE:?}
if [[ $1 == release && $2 == view ]]; then
  [[ -e $state ]]
  exit $?
fi
if [[ $1 == release && $2 == create ]]; then
  [[ ! -e $state ]] || exit 1
  print -r -- "$3" > "$state"
  exit 0
fi
exit 2
FAKE_GH
chmod +x "$tmp/bin/gh"

publish() {
  (
    cd "$tmp/repository"
    PATH="$tmp/bin:$PATH" \
      GITHUB_REPOSITORY=z-shell/zi \
      RELEASE_TAG=v1.0.0 \
      RELEASE_TARGET=$target \
      RELEASE_NOTES_FILE=$tmp/notes.md \
      FAKE_RELEASE_STATE=$tmp/release-state \
      zsh -f "$root/scripts/publish-promotion-release.zsh"
  )
}

publish >/dev/null
[[ $(git --git-dir="$tmp/origin.git" cat-file -t refs/tags/v1.0.0) == tag ]]
[[ $(git --git-dir="$tmp/origin.git" rev-parse 'refs/tags/v1.0.0^{}') == $target ]]
[[ $(<"$tmp/release-state") == v1.0.0 ]]

first_tag=$(git --git-dir="$tmp/origin.git" rev-parse refs/tags/v1.0.0)
publish >/dev/null
[[ $(git --git-dir="$tmp/origin.git" rev-parse refs/tags/v1.0.0) == $first_tag ]]

git -C "$tmp/repository" tag -a v1.0.1 -m v1.0.1 "${target}^"
git -C "$tmp/repository" push origin refs/tags/v1.0.1 >/dev/null 2>&1
(
  cd "$tmp/repository"
  PATH="$tmp/bin:$PATH" \
    GITHUB_REPOSITORY=z-shell/zi \
    RELEASE_TAG=v1.0.1 \
    RELEASE_TARGET=$target \
    RELEASE_NOTES_FILE=$tmp/notes.md \
    FAKE_RELEASE_STATE=$tmp/other-release-state \
    zsh -f "$root/scripts/publish-promotion-release.zsh"
) >/dev/null 2>&1 && { print -u2 -- 'expected conflicting tag target to fail'; exit 1; }

print 'promotion release publication tests passed'
