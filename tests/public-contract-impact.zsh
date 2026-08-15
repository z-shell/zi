#!/usr/bin/env zsh

emulate -LR zsh
setopt errexit nounset pipefail

typeset project_root="${0:A:h:h}"
typeset fixture_root="${project_root}/tests/fixtures/public-contract"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-contract-test.XXXXXXXX")"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

fail() {
  print -u2 "not ok - $1"
  exit 1
}

assert_contains() {
  local output="$1" expected="$2"
  [[ $output == *"$expected"* ]] || fail "expected output to contain: $expected"
}

assert_not_contains() {
  local output="$1" unexpected="$2"
  [[ $output != *"$unexpected"* ]] || fail "expected output not to contain: $unexpected"
}

new_case_repository() {
  local name="$1"
  local repository="${temp_root}/${name}"
  command mkdir -p "$repository/contracts" "$repository/lib/zsh"
  command cp "$project_root/contracts/public-contract-v1.json" "$repository/contracts/"
  command cp "$fixture_root/base/zi.zsh" "$repository/zi.zsh"
  command cp "$fixture_root/base/lib/zsh/git-process-output.zsh" "$repository/lib/zsh/"
  command git -C "$repository" init -q
  command git -C "$repository" config user.name "Contract Test"
  command git -C "$repository" config user.email "contract-test@example.invalid"
  command git -C "$repository" add .
  command git -C "$repository" commit -qm "test: base contract"
  command git -C "$repository" tag base
  print -r -- "$repository"
}

run_detector() {
  local repository="$1"
  shift
  zsh "$project_root/scripts/public-contract-impact.zsh" \
    --repository "$repository" \
    --base base \
    --head HEAD \
    "$@"
}

typeset repository output

repository="$(new_case_repository refactor)"
command cp "$fixture_root/refactor/zi.zsh" "$repository/zi.zsh"
command git -C "$repository" add .
command git -C "$repository" commit -qm "refactor: reformat internals"
output="$(run_detector "$repository" --no-policy)"
assert_contains "$output" "No public-contract changes detected."
print "ok - comments, formatting, ordering, and internal refactors are ignored"

repository="$(new_case_repository conditional)"
command cp "$fixture_root/conditional/zi.zsh" "$repository/zi.zsh"
command git -C "$repository" add .
command git -C "$repository" commit -qm "test: guard compatibility function with false"
output="$(run_detector "$repository" --no-policy)"
assert_contains "$output" '`zpcdclear` was removed'
assert_contains "$output" '`pmodload` was removed'
assert_not_contains "$output" 'false&&zpcdclear'
print "ok - dead conditional function definitions are unavailable across logical lines"

repository="$(new_case_repository addition)"
command cp "$fixture_root/addition/zi.zsh" "$repository/zi.zsh"
command git -C "$repository" add .
command git -C "$repository" commit -qm "feat: add contracts"
output="$(run_detector "$repository")"
assert_contains "$output" '`addition`'
assert_contains "$output" '`doctor` was added'
assert_contains "$output" '`debug` was added'
assert_contains "$output" '`zplegacy` was added'
print "ok - additions are informational"

repository="$(new_case_repository replacement)"
command cp "$fixture_root/breaking/zi.zsh" "$repository/zi.zsh"
command git -C "$repository" add .
command git -C "$repository" commit -qm "feat: remove and add independently"
output="$(run_detector "$repository" --no-policy)"
assert_contains "$output" '`load` was removed'
assert_contains "$output" '`fetch` was added'
assert_not_contains "$output" '`rename`'
print "ok - independent removals and additions are not inferred as renames"

repository="$(new_case_repository breaking)"
command cp "$fixture_root/breaking/zi.zsh" "$repository/zi.zsh"
command rm "$repository/lib/zsh/git-process-output.zsh"
changed_manifest="${repository}/contracts/public-contract-v1.json.new"
jq '.renames += [{"surface":"commands","from":"load","to":"fetch"}]' \
  "$repository/contracts/public-contract-v1.json" > "$changed_manifest"
command mv "$changed_manifest" "$repository/contracts/public-contract-v1.json"
command git -C "$repository" add -A
command git -C "$repository" commit -qm "feat!: alter contracts"
if output="$(run_detector "$repository" 2>&1)"; then
  fail "breaking changes passed without policy metadata"
fi
assert_contains "$output" '`rename`'
assert_contains "$output" '`signature-narrowing`'
assert_contains "$output" '`removal`'
assert_contains "$output" "Breaking-change label required"
assert_contains "$output" "Migration plan required"

typeset -a impact_markers
impact_markers=( "${(@f)$(print -r -- "$output" | command grep -o '\[contract-impact:[^]]*\]' | LC_ALL=C sort -u)}" )
typeset pr_body="## Migration plan
Consumers migrate using https://github.com/z-shell/zi/issues/376."
typeset marker
for marker in "${impact_markers[@]}"; do
  pr_body+=$'\n'"${marker} updated here"
done

typeset marker_only_body="## Migration plan"
for marker in "${impact_markers[@]}"; do
  marker_only_body+=$'\n'"${marker} updated here"
done
if output="$(
  PR_LABELS_JSON='["breaking-change"]' \
  PR_BODY="$marker_only_body" \
    run_detector "$repository" 2>&1
)"; then
  fail "dispositions without migration guidance passed the breaking-change gate"
fi
assert_contains "$output" "Migration plan required"

typeset commented_body="## Migration plan
Consumers migrate using https://github.com/z-shell/zi/issues/376."
for marker in "${impact_markers[@]}"; do
  commented_body+=$'\n'"<!-- ${marker} updated here -->"
done
if output="$(
  PR_LABELS_JSON='["breaking-change"]' \
  PR_BODY="$commented_body" \
    run_detector "$repository" 2>&1
)"; then
  fail "hidden disposition comments passed the breaking-change gate"
fi
assert_contains "$output" "Impact disposition required"

output="$(
  PR_LABELS_JSON='["breaking-change"]' \
  PR_BODY="$pr_body" \
    run_detector "$repository"
)"
assert_contains "$output" "Breaking-change policy"
print "ok - destructive changes require label, migration plan, and dispositions"

repository="$(new_case_repository manifest-tampering)"
typeset changed_manifest="${repository}/contracts/public-contract-v1.json.new"
jq '(.surfaces[] | select(.id == "annex-registration")).presence_only = true' \
  "$repository/contracts/public-contract-v1.json" > "$changed_manifest"
command mv "$changed_manifest" "$repository/contracts/public-contract-v1.json"
command git -C "$repository" add .
command git -C "$repository" commit -qm "test: weaken contract definition"
output="$(run_detector "$repository" --no-policy)"
assert_contains "$output" '`contract-definition-change`'
print "ok - extraction-definition changes are destructive impacts"

typeset malformed_id malformed_field
for malformed_id malformed_field in \
  commands assignment \
  annex-registration symbol \
  hook-registration file \
  compatibility-functions start_marker \
  compatibility-aliases target \
  installer-git-output path; do
  repository="$(new_case_repository "malformed-${malformed_id}-${malformed_field}")"
  changed_manifest="${repository}/contracts/public-contract-v1.json.new"
  jq --arg id "$malformed_id" --arg field "$malformed_field" \
    'del((.surfaces[] | select(.id == $id))[$field])' \
    "$repository/contracts/public-contract-v1.json" > "$changed_manifest"
  command mv "$changed_manifest" "$repository/contracts/public-contract-v1.json"
  command git -C "$repository" add .
  command git -C "$repository" commit -qm "test: remove required surface field"
  if output="$(run_detector "$repository" --no-policy 2>&1)"; then
    fail "malformed ${malformed_id}.${malformed_field} passed manifest validation"
  fi
  assert_contains "$output" "invalid head manifest"
done
print "ok - each surface kind requires its extraction fields"

repository="$(new_case_repository unsafe-surface-id)"
changed_manifest="${repository}/contracts/public-contract-v1.json.new"
jq '.surfaces[0].id = "unsafe/id"' \
  "$repository/contracts/public-contract-v1.json" > "$changed_manifest"
command mv "$changed_manifest" "$repository/contracts/public-contract-v1.json"
command git -C "$repository" add .
command git -C "$repository" commit -qm "test: add unsafe surface id"
if output="$(run_detector "$repository" --no-policy 2>&1)"; then
  fail "unsafe surface ID passed manifest validation"
fi
assert_contains "$output" "invalid head manifest"
print "ok - surface IDs are safe for deterministic snapshot paths"

repository="$(new_case_repository invalid-evidence)"
changed_manifest="${repository}/contracts/public-contract-v1.json.new"
jq '.consumers[0].evidence = "https://github.com/z-shell/wiki/blob/main/example"' \
  "$repository/contracts/public-contract-v1.json" > "$changed_manifest"
command mv "$changed_manifest" "$repository/contracts/public-contract-v1.json"
command git -C "$repository" add .
command git -C "$repository" commit -qm "test: unpin evidence"
if output="$(run_detector "$repository" --no-policy 2>&1)"; then
  fail "mutable consumer evidence passed manifest validation"
fi
assert_contains "$output" "invalid head manifest"
print "ok - consumer evidence must be complete and SHA-pinned"

repository="$(new_case_repository mismatched-evidence)"
changed_manifest="${repository}/contracts/public-contract-v1.json.new"
jq '.consumers[0].repository = "z-shell/zd" | .consumers[0].path = "tests/helpers.zsh"' \
  "$repository/contracts/public-contract-v1.json" > "$changed_manifest"
command mv "$changed_manifest" "$repository/contracts/public-contract-v1.json"
command git -C "$repository" add .
command git -C "$repository" commit -qm "test: mismatch evidence identity"
if output="$(run_detector "$repository" --no-policy 2>&1)"; then
  fail "consumer evidence for another repo and path passed validation"
fi
assert_contains "$output" "invalid head manifest"
print "ok - evidence URLs must match their declared repository and path"

repository="$(new_case_repository consumer-removal)"
changed_manifest="${repository}/contracts/public-contract-v1.json.new"
jq 'del(.consumers[] | select(.repository == "z-shell/pm-perf-test"))' \
  "$repository/contracts/public-contract-v1.json" > "$changed_manifest"
command mv "$changed_manifest" "$repository/contracts/public-contract-v1.json"
command git -C "$repository" add .
command git -C "$repository" commit -qm "test: remove consumer evidence"
output="$(run_detector "$repository" --no-policy)"
assert_contains "$output" '`consumer-evidence-removal`'
print "ok - removing consumer evidence is a destructive impact"
