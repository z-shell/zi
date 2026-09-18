#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# The benchmark runner and comparer are themselves tested: a tiny-count run
# must produce every case with valid statistics, an A/A comparison must flag
# nothing, a synthetically slowed candidate must be flagged without failing,
# and a functional failure must invalidate its case (#553).

builtin emulate -R zsh
setopt pipe_fail extended_glob

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

(( $+commands[jq] )) || fail "missing test dependency: jq"
typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-benchmark-harness.XXXXXXXX")" || fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

zsh "${project_root}/benchmarks/run.zsh" --variant a="$project_root" --variant b="$project_root" \
  --output-dir "$temp_root/run" --warmups 1 --samples 2 >/dev/null || fail "runner failed on the checkout"
[[ -s $temp_root/run/a.json && -s $temp_root/run/b.json ]] || fail "one report per variant expected"
command cp -- "$temp_root/run/a.json" "$temp_root/a.json"
zsh "${project_root}/benchmarks/run.zsh" --variant c="$project_root" --output-dir "$temp_root/subset" \
  --warmups 1 --samples 2 --case source-reused-home --case light-load-10 >/dev/null || fail "runner failed with a case subset"
command cp -- "$temp_root/subset/c.json" "$temp_root/b.json"
zsh "${project_root}/benchmarks/run.zsh" --variant a="$project_root" --variant a="$project_root" --output-dir "$temp_root/dup" >/dev/null 2>&1 &&
  fail "duplicate variant labels must be rejected"

integer cases
cases=$(jq -r '.cases | length' "$temp_root/a.json") || fail "a.json is not valid JSON"
(( cases == 8 )) || fail "expected 8 cases, got ${cases}"
jq -e '.cases | to_entries | all(.value.count == 2 and (.value.median | type) == "number" and (.value.p95 | type) == "number" and (.value.samples | length) == 2)' "$temp_root/a.json" >/dev/null ||
  fail "every case must carry two samples with numeric median and p95"
jq -e '.health | (.functions_after_source > 0) and (.parameters_after_source > 0) and (."lines:zi.zsh" > 1000) and (."zcompile_ms:zi.zsh" > 0)' "$temp_root/a.json" >/dev/null ||
  fail "health data missing or implausible"
jq -e '.cases | keys == ["light-load-10", "source-reused-home"]' "$temp_root/b.json" >/dev/null || fail "--case did not select the subset"
jq -e '.workload.variants == ["a", "b"]' "$temp_root/a.json" >/dev/null || fail "the report must list the variants measured together"

# A/A: comparing a run with itself flags nothing and fails nothing.
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/a.json" --candidate "$temp_root/a.json" \
  --control "$temp_root/a.json" --output "$temp_root/aa.json" --markdown "$temp_root/aa.md" >/dev/null || fail "A/A comparison failed"
jq -e '.flagged == [] and .failed == [] and .comparable == true' "$temp_root/aa.json" >/dev/null || fail "A/A comparison must flag and fail nothing"
[[ -s $temp_root/aa.md ]] && grep -q '^| source-fresh-home ' "$temp_root/aa.md" || fail "Markdown rendering missing the case table"

# Sensitivity: a candidate 30% slower on one case is flagged, never failed.
jq '.cases["ice-200"].median *= 1.3 | .cases["ice-200"].p95 *= 1.3' "$temp_root/a.json" > "$temp_root/slow.json"
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/a.json" --candidate "$temp_root/slow.json" \
  --output "$temp_root/slow-cmp.json" >/dev/null || fail "a flagged comparison must still exit 0"
jq -e '.flagged == ["ice-200"] and .failed == [] and .cases["ice-200"].flag == true' "$temp_root/slow-cmp.json" >/dev/null ||
  fail "a 30% regression must be flagged on exactly that case"

# Reports that are not comparable carry null flags, even with a large delta.
jq '.workload.warmups += 1 | .cases["ice-200"].median *= 1.3 | .cases["ice-200"].p95 *= 1.3' "$temp_root/a.json" > "$temp_root/other.json"
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/a.json" --candidate "$temp_root/other.json" \
  --output "$temp_root/other-cmp.json" --markdown "$temp_root/other.md" >/dev/null || fail "an incomparable comparison must still exit 0"
jq -e '.comparable == false and .flagged == [] and .cases["ice-200"].flag == null' "$temp_root/other-cmp.json" >/dev/null ||
  fail "incomparable reports must not flag"
grep -q "not comparable" "$temp_root/other.md" || fail "Markdown must say why nothing is flagged"

# Reports with different case sets are rejected up front, not deep inside jq.
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/a.json" --candidate "$temp_root/b.json" \
  --output "$temp_root/mismatch.json" >/dev/null 2>"$temp_root/mismatch.err" && fail "different case sets must be rejected"
grep -q "do not cover the same cases" "$temp_root/mismatch.err" || fail "the case-set mismatch must be named"

# A failure that appears only in the A/A control is still a failure.
jq '.cases["unload-10"] = {"failure": "exit 4: control-only"}' "$temp_root/a.json" > "$temp_root/ctl-broken.json"
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/a.json" --candidate "$temp_root/a.json" \
  --control "$temp_root/ctl-broken.json" --output "$temp_root/ctl-cmp.json" >/dev/null 2>&1 && fail "a control-only failure must exit 1"
jq -e '.failed == ["unload-10"]' "$temp_root/ctl-cmp.json" >/dev/null || fail "the control-only failure must be listed in failed"

# Functional failure on either side invalidates the case and exits 1.
jq '.cases["unload-10"] = {"failure": "exit 4: synthetic"}' "$temp_root/a.json" > "$temp_root/broken.json"
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/a.json" --candidate "$temp_root/broken.json" \
  --output "$temp_root/broken-cmp.json" >/dev/null 2>&1 && fail "a functional failure must exit 1"
jq -e '.failed == ["unload-10"] and (.cases["unload-10"].failure.candidate | test("synthetic"))' "$temp_root/broken-cmp.json" >/dev/null ||
  fail "the failed case must be recorded with its reason"

builtin print -r -- "ok - benchmark runner and comparer produce, flag, and invalidate as designed"
