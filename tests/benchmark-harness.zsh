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

zsh "${project_root}/benchmarks/run.zsh" --checkout "$project_root" --output "$temp_root/a.json" \
  --warmups 1 --samples 2 --label a >/dev/null || fail "runner failed on the checkout"
zsh "${project_root}/benchmarks/run.zsh" --checkout "$project_root" --output "$temp_root/b.json" \
  --warmups 1 --samples 2 --label b --case source-warm --case light-load-10 >/dev/null || fail "runner failed with a case subset"

integer cases
cases=$(jq -r '.cases | length' "$temp_root/a.json") || fail "a.json is not valid JSON"
(( cases == 8 )) || fail "expected 8 cases, got ${cases}"
jq -e '.cases | to_entries | all(.value.count == 2 and (.value.median | type) == "number" and (.value.p95 | type) == "number" and (.value.samples | length) == 2)' "$temp_root/a.json" >/dev/null ||
  fail "every case must carry two samples with numeric median and p95"
jq -e '.health | (.functions_after_source > 0) and (.parameters_after_source > 0) and (."lines:zi.zsh" > 1000) and (."zcompile_ms:zi.zsh" > 0)' "$temp_root/a.json" >/dev/null ||
  fail "health data missing or implausible"
jq -e '.cases | keys == ["light-load-10", "source-warm"]' "$temp_root/b.json" >/dev/null || fail "--case did not select the subset"

# A/A: comparing a run with itself flags nothing and fails nothing.
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/a.json" --candidate "$temp_root/a.json" \
  --control "$temp_root/a.json" --output "$temp_root/aa.json" --markdown "$temp_root/aa.md" >/dev/null || fail "A/A comparison failed"
jq -e '.flagged == [] and .failed == [] and .comparable == true' "$temp_root/aa.json" >/dev/null || fail "A/A comparison must flag and fail nothing"
[[ -s $temp_root/aa.md ]] && grep -q '^| source-cold ' "$temp_root/aa.md" || fail "Markdown rendering missing the case table"

# Sensitivity: a candidate 30% slower on one case is flagged, never failed.
jq '.cases["ice-200"].median *= 1.3 | .cases["ice-200"].p95 *= 1.3' "$temp_root/a.json" > "$temp_root/slow.json"
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/a.json" --candidate "$temp_root/slow.json" \
  --output "$temp_root/slow-cmp.json" >/dev/null || fail "a flagged comparison must still exit 0"
jq -e '.flagged == ["ice-200"] and .failed == [] and .cases["ice-200"].flag == true' "$temp_root/slow-cmp.json" >/dev/null ||
  fail "a 30% regression must be flagged on exactly that case"

# Functional failure on either side invalidates the case and exits 1.
jq '.cases["unload-10"] = {"failure": "exit 4: synthetic"}' "$temp_root/a.json" > "$temp_root/broken.json"
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/a.json" --candidate "$temp_root/broken.json" \
  --output "$temp_root/broken-cmp.json" >/dev/null 2>&1 && fail "a functional failure must exit 1"
jq -e '.failed == ["unload-10"] and (.cases["unload-10"].failure.candidate | test("synthetic"))' "$temp_root/broken-cmp.json" >/dev/null ||
  fail "the failed case must be recorded with its reason"

builtin print -r -- "ok - benchmark runner and comparer produce, flag, and invalidate as designed"
