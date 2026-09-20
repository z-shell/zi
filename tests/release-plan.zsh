#!/usr/bin/env zsh

emulate -L zsh
setopt err_exit no_unset pipe_fail

root=${0:A:h:h}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/zi-release-plan-test.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM

git init "$tmp/repository" >/dev/null
git -C "$tmp/repository" config user.email release-test@example.invalid
git -C "$tmp/repository" config user.name 'Release Test'
print initial > "$tmp/repository/file"
git -C "$tmp/repository" add file
git -C "$tmp/repository" commit -m 'chore: initial commit' >/dev/null
git -C "$tmp/repository" tag -a v1.2.3 -m v1.2.3

run_plan() {
  local output=$tmp/output notes=$tmp/notes body=$tmp/body
  (
    cd "$tmp/repository"
    RELEASE_PLAN_OUTPUT=$output RELEASE_NOTES_FILE=$notes \
      zsh -f "$root/scripts/release-plan.zsh" HEAD > "$body"
  )
}

value() {
  sed -n "s/^$1=//p" "$tmp/output"
}

commit() {
  print -r -- "$1" >> "$tmp/repository/file"
  git -C "$tmp/repository" commit -am "$2" >/dev/null
}

commit docs 'docs: explain releases'
run_plan
[[ $(value release) == false && -z $(value tag) ]]

commit fix 'fix(load): preserve explicit disk ices'
run_plan
[[ $(value release) == true && $(value tag) == v1.2.4 ]]
grep -q '^### Fixes$' "$tmp/notes"
grep -q 'fix(load): preserve explicit disk ices' "$tmp/notes"

commit feature 'feat: add a compatible command'
run_plan
[[ $(value tag) == v1.3.0 ]]
grep -q '^### Features$' "$tmp/notes"

commit breaking $'feat!: replace command output\n\nBREAKING CHANGE: callers must migrate'
run_plan
[[ $(value tag) == v2.0.0 ]]
grep -q '^### Breaking changes$' "$tmp/notes"
grep -q 'Candidate commit' "$tmp/body"

git -C "$tmp/repository" branch previous-next HEAD
git -C "$tmp/repository" switch -c stable v1.2.3 >/dev/null 2>&1
git -C "$tmp/repository" merge --no-ff previous-next -m 'chore: promotion merge' >/dev/null
git -C "$tmp/repository" tag -a v2.0.0 -m v2.0.0
git -C "$tmp/repository" switch -C next previous-next >/dev/null 2>&1
commit post-release-fix 'fix: change after a promotion tag'
run_plan
[[ $(value previous_tag) == v2.0.0 && $(value tag) == v2.0.1 ]]
grep -q 'fix: change after a promotion tag' "$tmp/notes"
if grep -q 'docs: explain releases' "$tmp/notes"; then
  print -u2 -- 'release notes crossed the previous promotion boundary'
  exit 1
fi

print 'release plan tests passed'
