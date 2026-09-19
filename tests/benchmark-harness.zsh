#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# The benchmark runner and comparer are themselves tested: a tiny-count run
# must produce every case with valid statistics, an A/A comparison must flag
# nothing, a synthetically slowed candidate must be flagged without failing,
# a functional failure must invalidate its case, a checkout that lacks the API
# a case exercises must be reported unsupported rather than failed unless it
# is the candidate that lost the API, and a swapped manifest inventory must be
# rejected by name (#553).

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
zsh "${project_root}/benchmarks/run.zsh" --variant c="$project_root" --output-dir "$temp_root/dup-case" \
  --case ice-200 --case ice-200 >/dev/null 2>&1 && fail "a repeated --case must be rejected"
zsh "${project_root}/benchmarks/run.zsh" --variant c="$project_root" --output-dir "$temp_root/glob-case" \
  --case 'source-*' >/dev/null 2>"$temp_root/glob-case.err" && fail "a pattern is not a case name and must be rejected"
grep -q 'unknown case: source-\*' "$temp_root/glob-case.err" || fail "a pattern --case must be a usage error, not a workload failure"

# Every row of the Markdown case table has six cells, whatever the row's
# outcome. An escaped pipe is content, not a cell boundary, so it is removed
# before counting.
table_rows_ok() { grep '^|' "$1" | sed 's/\\|//g' | awk -F'|' 'NF != 8 { bad = 1 } END { exit bad }'; }

# copy_suite <dir>: a private copy of the runner, its fixtures, and the
# vendored manifests, so a test can alter one of them without touching the
# checkout; run.zsh resolves both from its own location.
copy_suite() {
  command mkdir -p -- "$1/tests/fixtures" || fail "create a suite copy under $1"
  command cp -R -- "$project_root/benchmarks" "$1/benchmarks" || fail "copy the benchmark scripts"
  command cp -R -- "$project_root/tests/fixtures/package-manifests" "$1/tests/fixtures/package-manifests" || fail "copy the vendored manifests"
}

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
table_rows_ok "$temp_root/aa.md" || fail "the A/A Markdown table rows must have six cells"

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
  --control "$temp_root/ctl-broken.json" --output "$temp_root/ctl-cmp.json" --markdown "$temp_root/ctl.md" >/dev/null 2>&1 && fail "a control-only failure must exit 1"
jq -e '.failed == ["unload-10"]' "$temp_root/ctl-cmp.json" >/dev/null || fail "the control-only failure must be listed in failed"
grep -q '^| unload-10 .*| failure: exit 4: control-only |$' "$temp_root/ctl.md" || fail "the control failure must be rendered in its Markdown cell, not n/a"
table_rows_ok "$temp_root/ctl.md" || fail "a control failure must not misalign the Markdown table"

# Functional failure on either side invalidates the case and exits 1.
jq '.cases["unload-10"] = {"failure": "exit 4: synthetic"}' "$temp_root/a.json" > "$temp_root/broken.json"
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/a.json" --candidate "$temp_root/broken.json" \
  --output "$temp_root/broken-cmp.json" --markdown "$temp_root/broken.md" >/dev/null 2>&1 && fail "a functional failure must exit 1"
jq -e '.failed == ["unload-10"] and (.cases["unload-10"].failure.candidate | test("synthetic"))' "$temp_root/broken-cmp.json" >/dev/null ||
  fail "the failed case must be recorded with its reason"
grep -q '^| unload-10 | failure | failure | .*synthetic' "$temp_root/broken.md" || fail "the failed case must be rendered as a failure row"
table_rows_ok "$temp_root/broken.md" || fail "a failure row must not misalign the Markdown table"

# A reason that contains a pipe stays in one cell, in the case row and in the
# control column alike.
jq '.cases["unload-10"] = {"failure": "exit 4: a | b"}' "$temp_root/a.json" > "$temp_root/piped.json"
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/a.json" --candidate "$temp_root/piped.json" \
  --control "$temp_root/piped.json" --output "$temp_root/piped-cmp.json" --markdown "$temp_root/piped.md" >/dev/null 2>&1 && fail "a piped failure reason must still exit 1"
grep -q '^| unload-10 | failure | failure | .*a \\| b.* | | failure: exit 4: a \\| b |$' "$temp_root/piped.md" || fail "a pipe inside a reason must be escaped in both columns"
table_rows_ok "$temp_root/piped.md" || fail "a pipe inside a reason must not split the Markdown row"

# A health probe that fails or prints something other than four counts yields
# null counts and a report that is still valid JSON, so the case results are
# published. The copy makes the symbols probe print a diagnostic and exit 3.
copy_suite "$temp_root/probe"
command sed 's/^    print -r -- "\$f1 \$p1 \$#functions \$#parameters" ;;$/    print -r -- "zi: cannot load"; exit 3 ;;/' "$project_root/benchmarks/case.zsh" > "$temp_root/probe/benchmarks/case.zsh" || fail "break the symbols probe in the copy"
grep -q 'cannot load' "$temp_root/probe/benchmarks/case.zsh" || fail "the copy must break the symbols probe"
zsh "$temp_root/probe/benchmarks/run.zsh" --variant a="$project_root" --output-dir "$temp_root/probe-run" \
  --warmups 1 --samples 2 --case ice-200 >/dev/null 2>&1 || fail "a failed health probe must not fail the run"
jq -e '.health.functions_after_source == null and .health.parameters_after_load_10 == null and .cases["ice-200"].count == 2' "$temp_root/probe-run/a.json" >/dev/null ||
  fail "a failed health probe must record null counts beside the measured cases"

# A checkout that lacks the API a case exercises reports that case as
# unsupported, not failed, and the other cases still run. The copy below is
# this checkout with the manifest reader's definition renamed away, which is
# what a baseline older than the reader looks like to the runner.
command mkdir -p -- "$temp_root/old/lib/zsh" || fail "create the old checkout copy"
command cp -R -- "$project_root/zi.zsh" "$project_root/lib" "$temp_root/old/" || fail "copy the checkout"
command sed 's/^\.zi-read-package-manifest() {/.zi-read-package-manifest-absent() {/' "$project_root/lib/zsh/install.zsh" > "$temp_root/old/lib/zsh/install.zsh" || fail "rename the reader in the copy"
grep -q '^\.zi-read-package-manifest-absent() {' "$temp_root/old/lib/zsh/install.zsh" || fail "the copy must lack the reader definition"
zsh "${project_root}/benchmarks/run.zsh" --variant old="$temp_root/old" --variant new="$project_root" \
  --output-dir "$temp_root/unsup" --warmups 1 --samples 2 --case manifest-21 --case ice-200 >/dev/null || fail "an unsupported case must not fail the runner"
jq -e '.cases["manifest-21"].unsupported | type == "string" and test("zi-read-package-manifest")' "$temp_root/unsup/old.json" >/dev/null ||
  fail "the old checkout must report manifest-21 unsupported with the reason"
jq -e '.cases["ice-200"].count == 2' "$temp_root/unsup/old.json" >/dev/null || fail "an unsupported case must not stop the other cases"
jq -e '.cases["manifest-21"].count == 2 and .cases["ice-200"].count == 2' "$temp_root/unsup/new.json" >/dev/null || fail "the checkout with the reader must still measure manifest-21"

# Baseline without the API, candidate with it: unsupported, never failed.
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/unsup/old.json" --candidate "$temp_root/unsup/new.json" \
  --control "$temp_root/unsup/old.json" --output "$temp_root/unsup-cmp.json" --markdown "$temp_root/unsup.md" >/dev/null || fail "a baseline without the API must not fail the comparison"
jq -e '.unsupported == ["manifest-21"] and .failed == [] and .flagged == [] and .cases["manifest-21"].unsupported.candidate == null and .cases["ice-200"].flag != null' "$temp_root/unsup-cmp.json" >/dev/null ||
  fail "a baseline without the API must be listed as unsupported and nothing else"
grep -q '^| manifest-21 | unsupported | not compared | .*zi-read-package-manifest.* | | unsupported |$' "$temp_root/unsup.md" || fail "the unsupported case must be rendered with its reason and control state"
table_rows_ok "$temp_root/unsup.md" || fail "an unsupported row must not misalign the Markdown table"

# Both sides without the API: still unsupported, still exit 0.
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/unsup/old.json" --candidate "$temp_root/unsup/old.json" \
  --output "$temp_root/both-cmp.json" --markdown "$temp_root/both.md" >/dev/null || fail "two checkouts without the API must not fail the comparison"
jq -e '.unsupported == ["manifest-21"] and .failed == [] and (.cases["manifest-21"].unsupported.candidate | type) == "string"' "$temp_root/both-cmp.json" >/dev/null ||
  fail "both sides unsupported must be recorded on both sides"
grep -q '^| manifest-21 | unsupported | unsupported | ' "$temp_root/both.md" || fail "both sides unsupported must be rendered on both sides"

# Candidate without an API the baseline has: that is a removal, and it fails.
zsh "${project_root}/benchmarks/compare.zsh" --baseline "$temp_root/unsup/new.json" --candidate "$temp_root/unsup/old.json" \
  --output "$temp_root/removed-cmp.json" --markdown "$temp_root/removed.md" >/dev/null 2>&1 && fail "a candidate that lost an API must exit 1"
jq -e '.failed == ["manifest-21"] and .unsupported == [] and (.cases["manifest-21"].failure.candidate | test("^removed: "))' "$temp_root/removed-cmp.json" >/dev/null ||
  fail "a candidate that lost an API must be recorded as a removal failure"
grep -q '^| manifest-21 | failure | failure | .*removed' "$temp_root/removed.md" || fail "the removal must be rendered as a failure row"

# A case that prints its timing and then fails its postcondition must report
# a one-line reason, not a reason that starts with the discarded timing. The
# copy makes unload-10 exit 4 right after it prints.
copy_suite "$temp_root/post"
command sed 's/^    none_loaded || exit 4 ;;$/    exit 4 ;;/' "$project_root/benchmarks/case.zsh" > "$temp_root/post/benchmarks/case.zsh" || fail "break the unload-10 postcondition in the copy"
grep -q '^    exit 4 ;;$' "$temp_root/post/benchmarks/case.zsh" || fail "the copy must fail the unload-10 postcondition"
zsh "$temp_root/post/benchmarks/run.zsh" --variant a="$project_root" --output-dir "$temp_root/post-run" \
  --warmups 1 --samples 2 --case unload-10 >/dev/null 2>&1 && fail "a failed postcondition must exit 1"
jq -e '.cases["unload-10"].failure | type == "string" and startswith("exit 4:") and (contains("\n") | not)' "$temp_root/post-run/a.json" >/dev/null ||
  fail "a failed postcondition must record a one-line reason that starts with its exit status"

# The manifest inventory is pinned by name: swapping one repository for
# another keeps the count at 21 and is still rejected before any sample runs.
copy_suite "$temp_root/swap"
command mv -- "$temp_root/swap/tests/fixtures/package-manifests/zsh-bin.json" "$temp_root/swap/tests/fixtures/package-manifests/zsh-bin-other.json" || fail "rename a snapshot"
command sed 's/^zsh-bin$/zsh-bin-other/' "$project_root/tests/fixtures/package-manifests/repositories.txt" > "$temp_root/swap/tests/fixtures/package-manifests/repositories.txt" || fail "swap a listed repository"
zsh "$temp_root/swap/benchmarks/run.zsh" --variant a="$project_root" --output-dir "$temp_root/swap-run" \
  --warmups 1 --samples 2 --case ice-200 >/dev/null 2>"$temp_root/swap.err" && fail "a swapped manifest inventory must be rejected"
grep -q 'pinned' "$temp_root/swap.err" && grep -q 'not pinned: zsh-bin-other' "$temp_root/swap.err" && grep -q 'not listed: zsh-bin' "$temp_root/swap.err" ||
  fail "the rejection must name the unpinned and the missing repository"
[[ ! -e $temp_root/swap-run/a.json ]] || fail "a rejected inventory must not produce a report"

builtin print -r -- "ok - benchmark runner and comparer produce, flag, invalidate, and mark unsupported as designed"
