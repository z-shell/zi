#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# run.zsh -- measure Zi checkouts on deterministic, network-free workloads.
#
# Every sample starts a fresh `zsh -f` with an isolated home, so nothing leaks
# between samples or variants. Several variants (for example baseline,
# candidate, and a second baseline as the A/A control) are measured in the
# same invocation: within a round the variants alternate, and their order
# reverses on every round, so runner load, cache, and thermal drift are not
# correlated with a variant. Cases rotate in a balanced order across rounds.
# Output is one JSON document per variant; compare.zsh joins two of them.
#
# Usage:
#   zsh benchmarks/run.zsh --variant LABEL=DIR [--variant LABEL=DIR]... --output-dir DIR
#                          [--warmups N] [--samples N] [--case NAME]...
#
# Requires: zsh with zsh/datetime, jq.
#
# Exit codes:
#   0  every case produced the requested samples
#   1  a case failed functionally (its samples are discarded and the report
#      records the failure; timing of a broken behaviour is meaningless)
#   2  usage or dependency error

emulate -LR zsh
setopt extended_glob pipe_fail no_unset

typeset output_dir=''
integer warmups=5 samples=30
typeset -a wanted labels
typeset -A dirs
typeset -a all_cases
all_cases=( source-fresh-home source-reused-home light-load-10 load-10 turbo-10 ice-200 manifest-21 unload-10 )

usage() { print -r -- "usage: ${0:t} --variant LABEL=DIR [--variant LABEL=DIR]... --output-dir DIR [--warmups N] [--samples N] [--case NAME]..."; }
die() { print -u2 -r -- "run.zsh: $1"; exit ${2:-2}; }

while (( $# )); do
  case "$1" in
    --variant)
      [[ ${2-} == ?*=?* ]] || die "--variant needs LABEL=DIR"
      [[ ${2%%=*} == [[:alnum:]_-]## ]] || die "variant label must be alphanumeric: ${2%%=*}"
      (( ${+dirs[${2%%=*}]} )) && die "duplicate variant label: ${2%%=*}"
      labels+=( "${2%%=*}" ); dirs[${2%%=*}]=${${2#*=}:A}; shift 2 ;;
    --output-dir) [[ -n ${2-} ]] || die "--output-dir needs a value"; output_dir=$2; shift 2 ;;
    --warmups)  [[ ${2-} == <-> ]] || die "--warmups needs an integer"; warmups=$2; shift 2 ;;
    --samples)  [[ ${2-} == <-> && ${2-} -ge 2 ]] || die "--samples needs an integer of at least 2"; samples=$2; shift 2 ;;
    --case)     [[ -n ${2-} ]] || die "--case needs a value"; wanted+=( "$2" ); shift 2 ;;
    --help|-h)  usage; exit 0 ;;
    *) usage >&2; die "unknown argument: $1" ;;
  esac
done
(( $#labels )) || die "at least one --variant LABEL=DIR is required"
typeset label
for label in "${labels[@]}"; do [[ -r ${dirs[$label]}/zi.zsh ]] || die "variant ${label}: no zi.zsh under ${dirs[$label]}"; done
[[ -n $output_dir ]] || die "--output-dir is required"
command mkdir -p -- "$output_dir" || die "could not create $output_dir"
(( $+commands[jq] )) || die "required command not found: jq"
zmodload zsh/datetime || die "zsh/datetime is required"

typeset -a cases
if (( $#wanted )); then
  for c in "${wanted[@]}"; do (( ${all_cases[(I)$c]} )) || die "unknown case: $c"; done
  cases=( "${wanted[@]}" )
else
  cases=( "${all_cases[@]}" )
fi

typeset here=${0:A:h} fixtures=${0:A:h}/fixtures manifests=${0:A:h:h}/tests/fixtures/package-manifests
[[ -d $manifests ]] || die "vendored manifests not found at $manifests"
# The manifest workload is only comparable to earlier results when it reads
# exactly the declared inventory: every listed repository has its snapshot,
# no unlisted snapshot exists, and the case re-asserts the count.
typeset -a manifest_listed manifest_files
typeset manifest_name
while IFS= read -r manifest_name; do
  [[ -n $manifest_name ]] && manifest_listed+=( "$manifest_name" )
done < "$manifests/repositories.txt" || die "could not read $manifests/repositories.txt"
manifest_files=( "$manifests"/*.json(N) )
for manifest_name in "${manifest_listed[@]}"; do
  [[ -r $manifests/$manifest_name.json ]] || die "repositories.txt lists $manifest_name but $manifest_name.json is missing"
done
for manifest_name in "${manifest_files[@]}"; do
  (( ${manifest_listed[(I)${manifest_name:t:r}]} )) || die "${manifest_name:t} is not listed in repositories.txt"
done
integer manifest_count=$#manifest_listed

typeset work
work=$(command mktemp -d "${TMPDIR:-/tmp}/zi-benchmark.XXXXXXXX") || die "could not create a work directory"
trap 'command rm -rf -- "$work"' EXIT INT TERM
# The reused-home case keeps one home per variant across samples; every
# other case gets a fresh one.
for label in "${labels[@]}"; do command mkdir -p -- "$work/reused-$label"; done

# one_sample <variant> <case>: prints elapsed milliseconds, or "fail <reason>".
one_sample() {
  local label=$1 case=$2 home
  if [[ $case == source-reused-home ]]; then home=$work/reused-$label; else home=$(command mktemp -d "$work/s.XXXXXXXX"); fi
  command mkdir -p -- "$home"
  env -i PATH="$PATH" HOME="$home" ZDOTDIR="$home" TMPDIR="$work" \
    XDG_DATA_HOME="$home/data" XDG_CACHE_HOME="$home/cache" XDG_CONFIG_HOME="$home/config" \
    BENCH_CHECKOUT="${dirs[$label]}" BENCH_FIXTURES="$fixtures" BENCH_MANIFESTS="$manifests" \
    BENCH_MANIFEST_COUNT="$manifest_count" BENCH_CASE="$case" \
    zsh -f "$here/case.zsh" 2>"$home/stderr" | command tail -n 1
  local rc=${pipestatus[1]}
  (( rc == 0 )) || print -r -- "fail exit ${rc}: $(command tail -n 1 -- "$home/stderr" 2>/dev/null)"
  [[ $case == source-reused-home ]] || command rm -rf -- "$home"
}

# collected[label/case] and failed[label/case]
typeset -A collected failed
integer round total=$(( warmups + samples ))
typeset -a order variant_order
typeset case value
# Balanced rotation: round r starts the case list one position later than
# round r-1, so over one cycle of $#cases rounds every case occupies every
# position; every second cycle runs in reverse direction as well.
integer shift_by
for (( round = 1; round <= total; round++ )); do
  shift_by=$(( (round - 1) % $#cases ))
  order=( "${cases[@][shift_by+1,-1]}" "${cases[@][1,shift_by]}" )
  (( ((round - 1) / $#cases) % 2 )) && order=( "${(Oa)order[@]}" )
  (( round % 2 )) && variant_order=( "${labels[@]}" ) || variant_order=( "${(Oa)labels[@]}" )
  for case in "${order[@]}"; do
    for label in "${variant_order[@]}"; do
      (( ${+failed[$label/$case]} )) && continue
      value=$(one_sample "$label" "$case") || value="fail exit $?"
      if [[ $value != <->(.<->|)  ]]; then failed[$label/$case]=${value#fail }; continue; fi
      (( round > warmups )) && collected[$label/$case]+="${value} "
    done
  done
done

# Health data that costs nothing extra: sizes, compile durations, symbol
# deltas, measured once per variant outside the sampled rounds.
health_json() {  # health_json <label>
  local checkout=${dirs[$1]} f
  local -A health
  local -F3 t0 t1
  integer lines
  for f in zi.zsh lib/zsh/install.zsh lib/zsh/autoload.zsh lib/zsh/side.zsh lib/zsh/additional.zsh; do
    lines=$(wc -l < "$checkout/$f"); health[lines:$f]=$lines
  done
  t0=$EPOCHREALTIME; zsh -f -n "$checkout/zi.zsh"; t1=$EPOCHREALTIME; health[zsh_n_ms:zi.zsh]=$(( (t1 - t0) * 1000 ))
  local scratch; scratch=$(command mktemp -d "$work/c.XXXXXXXX")
  t0=$EPOCHREALTIME; ( cd "$scratch" && cp "$checkout/zi.zsh" zi.zsh && zsh -fc 'zcompile zi.zsh' ); t1=$EPOCHREALTIME; health[zcompile_ms:zi.zsh]=$(( (t1 - t0) * 1000 ))
  command rm -rf -- "$scratch"
  local -a shipped_zwc; shipped_zwc=( "$checkout"/**/*.zwc(N) )
  health[zwc_shipped]=$(( $#shipped_zwc > 0 ))
  local symbols home=$work/reused-$1
  symbols=$(env -i PATH="$PATH" HOME="$home" ZDOTDIR="$home" TMPDIR="$work" XDG_DATA_HOME="$home/data" XDG_CACHE_HOME="$home/cache" XDG_CONFIG_HOME="$home/config" \
    BENCH_CHECKOUT="$checkout" BENCH_FIXTURES="$fixtures" BENCH_MANIFESTS="$manifests" BENCH_MANIFEST_COUNT="$manifest_count" BENCH_CASE=symbols zsh -f "$here/case.zsh" 2>/dev/null)
  health[functions_after_source]=${${(s: :)symbols}[1]:-0}
  health[parameters_after_source]=${${(s: :)symbols}[2]:-0}
  health[functions_after_load_10]=${${(s: :)symbols}[3]:-0}
  health[parameters_after_load_10]=${${(s: :)symbols}[4]:-0}
  local -a hk; hk=( ${(ok)health} ); integer i
  print -r -- '{'
  for (( i = 1; i <= $#hk; i++ )); do print -r -- "    $(jq -Rn --arg k "${hk[i]}" '$k'): ${health[${hk[i]}]}$( (( i < $#hk )) && print , )"; done
  print -r -- '  }'
}

# Statistics per case: median, p95, min, count, plus the raw samples.
stats_json() {  # stats_json <space separated samples>
  local -a a; a=( ${(n)=1} )
  local -i k=$#a
  (( k )) || { print -r -- 'null'; return }
  local -F3 med p95
  (( k % 2 )) && med=${a[(k+1)/2]} || med=$(( (a[k/2] + a[k/2+1]) / 2.0 ))
  p95=${a[$(( (k * 95 + 99) / 100 ))]}
  print -r -- "{\"median\":${med},\"p95\":${p95},\"min\":${a[1]},\"count\":${k},\"samples\":[${(j:,:)a}]}"
}

typeset zsh_version cpu captured
zsh_version=$(zsh --version)
cpu=$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo 2>/dev/null | head -n 1)
captured=$(date -u +%Y-%m-%dT%H:%M:%SZ)
integer failures=0 i
for label in "${labels[@]}"; do
  local revision output=$output_dir/$label.json
  revision=$(git -C "${dirs[$label]}" rev-parse HEAD 2>/dev/null || print unknown)
  {
    print -r -- '{'
    print -r -- "  \"schema_version\": 1,"
    print -r -- "  \"captured_at\": \"$captured\","
    print -r -- "  \"label\": $(jq -Rn --arg v "$label" '$v'),"
    print -r -- "  \"source_revision\": \"$revision\","
    print -r -- "  \"environment\": {\"os\": \"$(uname -s)\", \"architecture\": \"$(uname -m)\", \"zsh_version\": $(jq -Rn --arg v "$zsh_version" '$v'), \"cpu\": $(jq -Rn --arg v "${cpu:-unknown}" '$v'), \"runner_image\": $(jq -Rn --arg v "${ImageOS:-}${ImageVersion:+ $ImageVersion}" '$v')},"
    print -r -- "  \"workload\": {\"warmups\": $warmups, \"samples\": $samples, \"variants\": $(print -r -- "${(j:,:)labels}" | jq -Rc 'split(",")'), \"timer\": \"zsh EPOCHREALTIME elapsed milliseconds inside the sampled process\", \"order\": \"variants alternate within a round and reverse every round; the case list starts one position later each round, every case taking every position per cycle, and alternate cycles run reversed\"},"
    print -r -- "  \"health\": $(health_json "$label"),"
    print -r -- "  \"cases\": {"
    for (( i = 1; i <= $#cases; i++ )); do
      case=${cases[i]}
      if (( ${+failed[$label/$case]} )); then
        failures+=1
        print -r -- "    \"$case\": {\"failure\": $(jq -Rn --arg v "${failed[$label/$case]}" '$v')}$( (( i < $#cases )) && print , )"
      else
        print -r -- "    \"$case\": $(stats_json "${collected[$label/$case]}")$( (( i < $#cases )) && print , )"
      fi
    done
    print -r -- "  }"
    print -r -- '}'
  } > "$output"
  jq -e . "$output" >/dev/null || die "generated $output is not valid JSON" 1
  print -r -- "wrote $output: ${#cases} cases"
done
(( failures == 0 )) || { print -u2 -r -- "run.zsh: $failures failed case(s); see the failure fields"; exit 1 }
