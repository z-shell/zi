#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# run.zsh -- measure Zi checkouts on deterministic, network-free workloads.
#
# Every sample starts a fresh `zsh -f` with an isolated home, so nothing leaks
# between samples or variants. Several variants (for example baseline,
# candidate, and a second baseline as the A/A control) are measured in the
# same invocation: within a round the variants run in a rotating order, with
# alternate rotation cycles reversed, so every variant takes every position
# equally often and runner load, cache, and thermal drift are not correlated
# with a variant. Cases rotate the same way across rounds. Output is one JSON
# document per variant; compare.zsh joins two of them.
#
# Usage:
#   zsh benchmarks/run.zsh --variant LABEL=DIR [--variant LABEL=DIR]... --output-dir DIR
#                          [--warmups N] [--samples N] [--case NAME]...
#
# Requires: zsh with zsh/datetime, jq.
#
# Exit codes:
#   0  every case produced the requested samples, or a variant reported a case
#      unsupported because its checkout lacks the API the case exercises (the
#      report records that per case; compare.zsh decides whether it matters)
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
  # (Ie) matches the requested name literally: a pattern such as source-*
  # is not a case name and must be a usage error here, not a workload failure
  # in case.zsh.
  for c in "${wanted[@]}"; do (( ${all_cases[(Ie)$c]} )) || die "unknown case: $c"; done
  # A repeated selection would run the case twice per round and write the
  # same report key twice, so the sample count would no longer be the truth.
  typeset -a seen
  for c in "${wanted[@]}"; do
    (( ${seen[(Ie)$c]} )) && die "--case $c given more than once"
    seen+=( "$c" )
  done
  cases=( "${wanted[@]}" )
else
  cases=( "${all_cases[@]}" )
fi
# The reused-home case times a home the previous sample sourced. Without a
# warmup its first measured sample would be a fresh-home timing mixed into the
# reused-home statistics; other cases are indifferent to zero warmups.
(( warmups >= 1 || ${cases[(Ie)source-reused-home]} == 0 )) || die "source-reused-home needs at least one warmup: its first sample would time a home no sample has sourced"

typeset here=${0:A:h} fixtures=${0:A:h}/fixtures manifests=${0:A:h:h}/tests/fixtures/package-manifests
[[ -d $manifests ]] || die "vendored manifests not found at $manifests"
# The manifest workload is only comparable to earlier results when it reads
# exactly the inventory the case was named for: the 21 repositories pinned
# below, each with its snapshot, and no unlisted snapshot. The names are
# pinned, not only the count, because replacing one repository with another
# keeps the count and still changes the workload. A different inventory is a
# different workload: rename or version the case and its baseline, and update
# this list with it, instead of letting the contents drift under one name.
# Snapshot contents are not pinned; refreshing a vendored manifest verbatim
# keeps the inventory.
typeset -a manifest_inventory
manifest_inventory=( any-gem any-node apr asciidoctor brew-completions dircolors-material doctoc ecs-cli firefox-dev fzf fzy github-issues github-issues-srv ls_colors nb pyenv remark subversion system-completions zsh zsh-bin )
typeset -a manifest_listed manifest_files unpinned unlisted
typeset manifest_name
while IFS= read -r manifest_name; do
  [[ -n $manifest_name ]] && manifest_listed+=( "$manifest_name" )
done < "$manifests/repositories.txt" || die "could not read $manifests/repositories.txt"
# (Ie) matches the name literally; a repository name is data, not a pattern.
for manifest_name in "${manifest_listed[@]}"; do
  (( ${manifest_inventory[(Ie)$manifest_name]} )) || unpinned+=( "$manifest_name" )
done
for manifest_name in "${manifest_inventory[@]}"; do
  (( ${manifest_listed[(Ie)$manifest_name]} )) || unlisted+=( "$manifest_name" )
done
[[ $#unpinned -eq 0 && $#unlisted -eq 0 && ${(j:,:)${(o)manifest_listed}} == ${(j:,:)${(o)manifest_inventory}} ]] ||
  die "manifest-21 is pinned to a fixed inventory and repositories.txt differs (listed but not pinned: ${(j:, :)unpinned:-none}; pinned but not listed: ${(j:, :)unlisted:-none}). A changed inventory is a different workload: rename or version the case and update the pinned list in run.zsh with it."
manifest_files=( "$manifests"/*.json(N) )
for manifest_name in "${manifest_inventory[@]}"; do
  [[ -r $manifests/$manifest_name.json ]] || die "repositories.txt lists $manifest_name but $manifest_name.json is missing"
done
for manifest_name in "${manifest_files[@]}"; do
  (( ${manifest_inventory[(Ie)${manifest_name:t:r}]} )) || die "${manifest_name:t} is not listed in repositories.txt"
done
integer manifest_count=$#manifest_inventory

typeset work
work=$(command mktemp -d "${TMPDIR:-/tmp}/zi-benchmark.XXXXXXXX") || die "could not create a work directory"
trap 'command rm -rf -- "$work"' EXIT INT TERM
# The reused-home case keeps one home per variant across samples; every
# other case gets a fresh one.
for label in "${labels[@]}"; do command mkdir -p -- "$work/reused-$label"; done

# reason <status> <stderr-file>: the child's last stderr line, or what its exit
# status means when it wrote nothing. case.zsh exits 3 when setup or load
# fails, 4 when the workload ran but left the wrong state, and 5 when the
# manifest inventory did not match the declared count; a bare "exit 4:" in
# a report would say nothing about the failed workload.
reason() {
  local line
  line=$(command tail -n 1 -- "$2" 2>/dev/null)
  if [[ -n $line ]]; then print -r -- "$line"; return; fi
  case $1 in
    2) print -r -- "unknown case or missing dependency" ;;
    3) print -r -- "setup or load failed" ;;
    4) print -r -- "postcondition failed: the workload did not leave the expected state" ;;
    5) print -r -- "manifest inventory did not match the declared count" ;;
    *) print -r -- "no diagnostic" ;;
  esac
}

# one_sample <variant> <case>: prints elapsed milliseconds, "fail <reason>", or
# "unsupported <reason>" when the checkout lacks the API the case exercises
# (case.zsh exit 6).
one_sample() {
  local label=$1 case=$2 home out rc
  if [[ $case == source-reused-home ]]; then home=$work/reused-$label; else home=$(command mktemp -d "$work/s.XXXXXXXX"); fi
  command mkdir -p -- "$home"
  out=$(env -i PATH="$PATH" HOME="$home" ZDOTDIR="$home" TMPDIR="$work" \
    XDG_DATA_HOME="$home/data" XDG_CACHE_HOME="$home/cache" XDG_CONFIG_HOME="$home/config" \
    BENCH_CHECKOUT="${dirs[$label]}" BENCH_FIXTURES="$fixtures" BENCH_MANIFESTS="$manifests" \
    BENCH_MANIFEST_COUNT="$manifest_count" BENCH_CASE="$case" \
    zsh -f "$here/case.zsh" 2>"$home/stderr"); rc=$?
  # Only a successful sample reports its timing. A case prints the elapsed
  # time before checking its postcondition, so on failure stdout can hold a
  # number that must not reach the report as the start of the reason.
  if (( rc == 6 )); then
    print -r -- "unsupported $(command tail -n 1 -- "$home/stderr" 2>/dev/null)"
  elif (( rc != 0 )); then
    print -r -- "fail exit ${rc}: $(reason "$rc" "$home/stderr")"
  else
    print -r -- "${out##*$'\n'}"
  fi
  [[ $case == source-reused-home ]] || command rm -rf -- "$home"
}

# collected[label/case], failed[label/case] and unsupported[label/case]
typeset -A collected failed unsupported
integer round total=$(( warmups + samples ))
typeset -a order variant_order
typeset case value
# Balanced rotation: round r starts the case list one position later than
# round r-1, so over one cycle of $#cases rounds every case occupies every
# position; every second cycle runs in reverse direction as well. Variants
# rotate the same way. A plain reversal every round is not enough for three
# variants: the middle one would be measured second in every round and take
# every first-position warm-up effect for granted.
integer shift_by
for (( round = 1; round <= total; round++ )); do
  shift_by=$(( (round - 1) % $#cases ))
  order=( "${cases[@][shift_by+1,-1]}" "${cases[@][1,shift_by]}" )
  (( ((round - 1) / $#cases) % 2 )) && order=( "${(Oa)order[@]}" )
  shift_by=$(( (round - 1) % $#labels ))
  variant_order=( "${labels[@][shift_by+1,-1]}" "${labels[@][1,shift_by]}" )
  (( ((round - 1) / $#labels) % 2 )) && variant_order=( "${(Oa)variant_order[@]}" )
  for case in "${order[@]}"; do
    for label in "${variant_order[@]}"; do
      (( ${+failed[$label/$case]} || ${+unsupported[$label/$case]} )) && continue
      value=$(one_sample "$label" "$case") || value="fail exit $?"
      # An unsupported case is settled on its first sample for that variant and
      # is not retried; it is not a failure and does not count toward exit 1.
      if [[ $value == unsupported* ]]; then unsupported[$label/$case]=${value#unsupported }; continue; fi
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
  # The copy is setup; only the compilation is timed.
  command cp -- "$checkout/zi.zsh" "$scratch/zi.zsh"
  t0=$EPOCHREALTIME; ( cd "$scratch" && zsh -fc 'zcompile zi.zsh' ); t1=$EPOCHREALTIME; health[zcompile_ms:zi.zsh]=$(( (t1 - t0) * 1000 ))
  command rm -rf -- "$scratch"
  local -a shipped_zwc; shipped_zwc=( "$checkout"/**/*.zwc(N) )
  health[zwc_shipped]=$(( $#shipped_zwc > 0 ))
  local symbols counts home=$work/reused-$1
  integer probe_status=0
  symbols=$(env -i PATH="$PATH" HOME="$home" ZDOTDIR="$home" TMPDIR="$work" XDG_DATA_HOME="$home/data" XDG_CACHE_HOME="$home/cache" XDG_CONFIG_HOME="$home/config" \
    BENCH_CHECKOUT="$checkout" BENCH_FIXTURES="$fixtures" BENCH_MANIFESTS="$manifests" BENCH_MANIFEST_COUNT="$manifest_count" BENCH_CASE=symbols zsh -f "$here/case.zsh" 2>/dev/null) || probe_status=$?
  # Only a probe that exited 0 and ended with four counts is trusted. A load
  # failure can print a diagnostic to stdout, and that text must not be
  # interpolated into the report as JSON; the counts are null instead, so the
  # case results and failures collected earlier are still published.
  counts=${symbols##*$'\n'}
  if (( probe_status == 0 )) && [[ $counts == <->' '<->' '<->' '<-> ]]; then
    health[functions_after_source]=${${(s: :)counts}[1]}
    health[parameters_after_source]=${${(s: :)counts}[2]}
    health[functions_after_load_10]=${${(s: :)counts}[3]}
    health[parameters_after_load_10]=${${(s: :)counts}[4]}
  else
    health[functions_after_source]=null
    health[parameters_after_source]=null
    health[functions_after_load_10]=null
    health[parameters_after_load_10]=null
  fi
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
typeset revision output
for label in "${labels[@]}"; do
  output=$output_dir/$label.json
  revision=$(git -C "${dirs[$label]}" rev-parse HEAD 2>/dev/null || print unknown)
  {
    print -r -- '{'
    print -r -- "  \"schema_version\": 1,"
    print -r -- "  \"captured_at\": \"$captured\","
    print -r -- "  \"label\": $(jq -Rn --arg v "$label" '$v'),"
    print -r -- "  \"source_revision\": \"$revision\","
    print -r -- "  \"environment\": {\"os\": \"$(uname -s)\", \"architecture\": \"$(uname -m)\", \"zsh_version\": $(jq -Rn --arg v "$zsh_version" '$v'), \"cpu\": $(jq -Rn --arg v "${cpu:-unknown}" '$v'), \"runner_image\": $(jq -Rn --arg v "${ImageOS:-}${ImageVersion:+ $ImageVersion}" '$v')},"
    print -r -- "  \"workload\": {\"warmups\": $warmups, \"samples\": $samples, \"variants\": $(print -r -- "${(j:,:)labels}" | jq -Rc 'split(",")'), \"timer\": \"zsh floating-point SECONDS elapsed milliseconds inside the sampled process\", \"order\": \"within a round the variant list starts one position later than in the previous round, every variant taking every position per cycle, and alternate cycles run reversed; the case list rotates the same way across rounds\"},"
    print -r -- "  \"health\": $(health_json "$label"),"
    print -r -- "  \"cases\": {"
    for (( i = 1; i <= $#cases; i++ )); do
      case=${cases[i]}
      if (( ${+unsupported[$label/$case]} )); then
        print -r -- "    \"$case\": {\"unsupported\": $(jq -Rn --arg v "${unsupported[$label/$case]}" '$v')}$( (( i < $#cases )) && print , )"
      elif (( ${+failed[$label/$case]} )); then
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
