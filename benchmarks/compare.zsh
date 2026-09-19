#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# compare.zsh -- join two run.zsh reports into a baseline-versus-candidate
# report, flag regressions above the thresholds, and render Markdown.
#
# Timing never fails the comparison: a flag marks a case for review, which is
# the organization's stance for hosted-runner evidence (observed, not gated).
# A functional failure on either side does invalidate that case.
#
# A case a checkout cannot run because it lacks the API the case exercises is
# reported by run.zsh as unsupported for that variant. A baseline without the
# API is expected when the candidate adds it, so that row is unsupported, not
# failed, and does not exit 1. A candidate without an API the baseline has is
# a removal, and that row is a failure.
#
# Usage:
#   zsh benchmarks/compare.zsh --baseline FILE --candidate FILE --output FILE
#                              [--markdown FILE] [--control FILE]
#                              [--median-threshold PERCENT] [--p95-threshold PERCENT]
#
# --control is a second run of the baseline (an A/A sample) whose deltas show
# the noise floor next to the real comparison.
#
# Exit codes:
#   0  comparison written (flags, if any, are in the report)
#   1  a case failed functionally on either side
#   2  usage or dependency error

emulate -LR zsh
setopt extended_glob pipe_fail no_unset

typeset baseline='' candidate='' control='' output='' markdown=''
typeset -F1 median_threshold=10 p95_threshold=15
die() { print -u2 -r -- "compare.zsh: $1"; exit ${2:-2}; }
while (( $# )); do
  case "$1" in
    --baseline)  [[ -n ${2-} ]] || die "--baseline needs a value"; baseline=$2; shift 2 ;;
    --candidate) [[ -n ${2-} ]] || die "--candidate needs a value"; candidate=$2; shift 2 ;;
    --control)   [[ -n ${2-} ]] || die "--control needs a value"; control=$2; shift 2 ;;
    --output)    [[ -n ${2-} ]] || die "--output needs a value"; output=$2; shift 2 ;;
    --markdown)  [[ -n ${2-} ]] || die "--markdown needs a value"; markdown=$2; shift 2 ;;
    --median-threshold) [[ ${2-} == <->(.<->|) ]] || die "--median-threshold needs a number"; median_threshold=$2; shift 2 ;;
    --p95-threshold)    [[ ${2-} == <->(.<->|) ]] || die "--p95-threshold needs a number"; p95_threshold=$2; shift 2 ;;
    --help|-h) print -r -- "usage: ${0:t} --baseline FILE --candidate FILE --output FILE [--markdown FILE] [--control FILE]"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ -r $baseline && -r $candidate && -n $output ]] || die "--baseline, --candidate and --output are required"
(( $+commands[jq] )) || die "required command not found: jq"

# The three reports must describe the same case set, or a missing case would
# be silently dropped (candidate-only) or fail deep inside jq (baseline-only).
typeset -a case_sets
case_sets=( "$(jq -c '.cases | keys' "$baseline")" "$(jq -c '.cases | keys' "$candidate")" )
[[ -n $control ]] && case_sets+=( "$(jq -c '.cases | keys' "$control")" )
[[ ${#${(u)case_sets}} -eq 1 ]] || die "the reports do not cover the same cases: ${(j: versus :)case_sets}"

# The control is the baseline measured again, so it must come from the same
# settings; the control rows reuse the baseline-versus-candidate comparability
# and would otherwise show an incompatible run as the noise floor.
if [[ -n $control ]]; then
  typeset baseline_settings control_settings
  baseline_settings=$(jq -c '[.environment.zsh_version, .environment.architecture, .workload.samples, .workload.warmups]' "$baseline")
  control_settings=$(jq -c '[.environment.zsh_version, .environment.architecture, .workload.samples, .workload.warmups]' "$control")
  [[ $baseline_settings == "$control_settings" ]] || die "the control was not measured under the baseline's settings (Zsh version, architecture, samples, warmups): ${baseline_settings} versus ${control_settings}"
fi

# jq does the arithmetic so the report is one deterministic document.
typeset -a control_args
[[ -n $control ]] && control_args=( --slurpfile control "$control" ) || control_args=( --argjson control '[null]' )
jq -n --slurpfile b "$baseline" --slurpfile c "$candidate" "${control_args[@]}" \
   --argjson mt "$median_threshold" --argjson pt "$p95_threshold" '
  def pct(a; b): if a == null or b == null or b == 0 then null else ((a - b) * 100 / b) end;
  ($b[0]) as $B | ($c[0]) as $C | ($control[0]) as $K |
  ($B.environment.zsh_version == $C.environment.zsh_version
   and $B.environment.architecture == $C.environment.architecture
   and $B.workload.samples == $C.workload.samples
   and $B.workload.warmups == $C.workload.warmups) as $comparable |
  # Flags are meaningful only between comparable reports; otherwise every
  # flag is null and the summary says why.
  def row(base; cand):
    # A baseline that lacks the API is unsupported (with or without the
    # candidate); a candidate that lacks an API the baseline runs is a removal
    # and therefore a failure. A candidate failure always stays a failure.
    if (base.unsupported? // null) != null and (cand.failure? // null) == null then
      {unsupported: {baseline: base.unsupported, candidate: (cand.unsupported? // null)}}
    elif (cand.unsupported? // null) != null then
      {failure: {baseline: (base.failure? // null), candidate: ("removed: " + cand.unsupported)}}
    elif (base.failure? // null) != null or (cand.failure? // null) != null then
      {failure: {baseline: (base.failure? // null), candidate: (cand.failure? // null)}}
    else
      {results: {baseline: base, candidate: cand},
       change: {median_delta_ms: (cand.median - base.median), median_delta_percent: pct(cand.median; base.median),
                p95_delta_ms: (cand.p95 - base.p95), p95_delta_percent: pct(cand.p95; base.p95)}}
      | .flag = (if $comparable then ((.change.median_delta_percent > $mt) or (.change.p95_delta_percent > $pt)) else null end)
    end;
  {schema_version: 1,
   captured_at: (now | todate),
   thresholds: {median_percent: $mt, p95_percent: $pt, policy: "flag for review, never fail on timing; flags are null when the reports are not comparable"},
   baseline: {label: $B.label, source_revision: $B.source_revision, environment: $B.environment, workload: $B.workload},
   candidate: {label: $C.label, source_revision: $C.source_revision, environment: $C.environment, workload: $C.workload},
   comparable: $comparable,
   health: {baseline: $B.health, candidate: $C.health},
   cases: ($B.cases | keys | map(. as $k | {($k): row($B.cases[$k]; $C.cases[$k])}) | add),
   control: (if $K == null then null else ($B.cases | keys | map(. as $k | {($k): row($B.cases[$k]; $K.cases[$k])}) | add) end)}
  | .flagged = [.cases | to_entries[] | select(.value.flag == true) | .key]
  | .unsupported = [.cases | to_entries[] | select(.value.unsupported != null) | .key]
  | .failed = ([.cases | to_entries[] | select(.value.failure != null) | .key]
               + (if .control == null then [] else [.control | to_entries[] | select(.value.failure != null) | .key] end) | unique)
' > "$output" || die "could not build the comparison" 1
jq -e . "$output" >/dev/null || die "comparison is not valid JSON" 1

if [[ -n $markdown ]]; then
  {
    print -r -- "## Zi benchmark: candidate versus baseline"
    print
    print -r -- "Baseline \`$(jq -r .baseline.source_revision "$output" | cut -c1-7)\` ($(jq -r .baseline.label "$output")) versus candidate \`$(jq -r .candidate.source_revision "$output" | cut -c1-7)\` ($(jq -r .candidate.label "$output")); $(jq -r .baseline.workload.samples "$output") samples after $(jq -r .baseline.workload.warmups "$output") warmups; $(jq -r .candidate.environment.zsh_version "$output") on $(jq -r .candidate.environment.cpu "$output"). Comparable: $(jq -r .comparable "$output"). Flags mark a median regression over $(jq -r .thresholds.median_percent "$output")% or a p95 regression over $(jq -r .thresholds.p95_percent "$output")%; they never fail the job.$( [[ $(jq -r .comparable "$output") == true ]] || print -n " The reports are not comparable (Zsh version, architecture, sample or warmup counts differ), so no case is flagged." )"
    print
    print -r -- "| Case | Baseline median / p95 ms | Candidate median / p95 ms | Median delta | p95 delta | A/A control median delta |"
    print -r -- "| --- | --- | --- | --- | --- | --- |"
    # A reason is child output and may contain a pipe; escaped, it stays in
    # its own cell instead of splitting the row.
    jq -r 'def cell: tojson | gsub("\\|"; "\\|"); .cases | to_entries[] | . as $e | if .value.failure then "| \(.key) | failure | failure | \(.value.failure | cell) | | " elif .value.unsupported then "| \(.key) | unsupported | \(if .value.unsupported.candidate != null then "unsupported" else "not compared" end) | \(.value.unsupported.baseline | cell) | | " else "| \(.key)\(if .value.flag then " (flag)" else "" end) | \(.value.results.baseline.median) / \(.value.results.baseline.p95) | \(.value.results.candidate.median) / \(.value.results.candidate.p95) | \(.value.change.median_delta_percent | . * 10 | round / 10)% | \(.value.change.p95_delta_percent | . * 10 | round / 10)% | " end' "$output" | while IFS= read -r line; do
      case_name=${${line#| }%% *}
      ctrl=$(jq -r --arg k "$case_name" '.control[$k] | if . == null then "n/a" elif .failure != null then "failure: \(.failure.candidate // .failure.baseline | gsub("\\|"; "\\|"))" elif .unsupported != null then "unsupported" elif (.change.median_delta_percent | type) == "number" then (.change.median_delta_percent * 10 | round / 10 | tostring) + "%" else "n/a" end' "$output")
      print -r -- "${line}${ctrl} |"
    done
    print
    print -r -- "Health (baseline to candidate): functions after source $(jq -r .health.baseline.functions_after_source "$output") to $(jq -r .health.candidate.functions_after_source "$output"), parameters $(jq -r .health.baseline.parameters_after_source "$output") to $(jq -r .health.candidate.parameters_after_source "$output"), zi.zsh $(jq -r '.health.baseline["lines:zi.zsh"]' "$output") to $(jq -r '.health.candidate["lines:zi.zsh"]' "$output") lines, zcompile $(jq -r '.health.baseline["zcompile_ms:zi.zsh"] | . * 10 | round / 10' "$output") to $(jq -r '.health.candidate["zcompile_ms:zi.zsh"] | . * 10 | round / 10' "$output") ms."
  } > "$markdown"
fi
print -r -- "wrote $output: $(jq -r '.flagged | length' "$output") flagged, $(jq -r '.failed | length' "$output") failed, $(jq -r '.unsupported | length' "$output") unsupported"
(( $(jq -r '.failed | length' "$output") == 0 ))
