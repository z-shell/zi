#!/usr/bin/env zsh

emulate -LR zsh
setopt errexit nounset pipefail extendedglob

typeset repository="."
typeset manifest_path="contracts/public-contract-v1.json"
typeset base_ref="" head_ref=""
integer enforce_policy=1

usage() {
  print "usage: ${0:t} --base REF --head REF [--repository DIR] [--manifest PATH] [--no-policy]"
}

while (( $# )); do
  case "$1" in
    --base)
      base_ref="${2-}"
      shift 2
      ;;
    --head)
      head_ref="${2-}"
      shift 2
      ;;
    --repository)
      repository="${2-}"
      shift 2
      ;;
    --manifest)
      manifest_path="${2-}"
      shift 2
      ;;
    --no-policy)
      enforce_policy=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      print -u2 "public-contract-impact: unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

[[ -n $base_ref && -n $head_ref ]] || {
  print -u2 "public-contract-impact: --base and --head are required"
  exit 2
}

for command_name in git jq sort tr; do
  (( $+commands[$command_name] )) || {
    print -u2 "public-contract-impact: required command not found: $command_name"
    exit 2
  }
done

repository="$(command git -C "$repository" rev-parse --show-toplevel)"
typeset temp_dir
temp_dir="$(command mktemp -d "${TMPDIR:-/tmp}/zi-contract.XXXXXXXX")"
trap 'command rm -rf -- "$temp_dir"' EXIT INT TERM

typeset empty_manifest='{"schema_version":1,"contract_version":0,"renames":[],"surfaces":[],"consumers":[]}'
typeset base_manifest="$temp_dir/base-manifest.json"
typeset head_manifest="$temp_dir/head-manifest.json"

materialize_manifest() {
  local ref="$1" destination="$2"
  if ! command git -C "$repository" show "${ref}:${manifest_path}" > "$destination" 2>/dev/null; then
    print -r -- "$empty_manifest" > "$destination"
  fi
}

validate_manifest() {
  local file="$1" label="$2"
  jq -e '
    . as $manifest
    | .schema_version == 1
    and (.contract_version | type == "number")
    and (.renames | type == "array")
    and (.surfaces | type == "array")
    and (.consumers | type == "array")
    and all(.surfaces[];
      (.id | type == "string" and length > 0)
      and (.kind | IN("token-set", "function", "function-region", "aliases", "path"))
      and (.description | type == "string" and length > 0)
    )
    and ([.surfaces[].id] | length == (unique | length))
    and all(.consumers[];
      . as $consumer
      | ("https://github.com/" + $consumer.repository + "/blob/") as $prefix
      | ($consumer.evidence | ltrimstr($prefix)) as $evidence_path
      | ($consumer.repository | test("^z-shell/[A-Za-z0-9_.-]+$"))
      and ($consumer.path | type == "string" and length > 0)
      and (($consumer.path | startswith("/")) | not)
      and ($consumer.surfaces | type == "array" and length > 0)
      and ($consumer.evidence | startswith($prefix))
      and ($evidence_path | test("^[0-9a-f]{40}/"))
      and ($evidence_path[41:] == $consumer.path)
    )
    and ([.consumers[].surfaces[]] - [.surfaces[].id] | length == 0)
    and ([
      .surfaces[].id
      | . as $id
      | any($manifest.consumers[]; .surfaces | index($id))
    ] | all)
  ' "$file" >/dev/null || {
    print -u2 "public-contract-impact: invalid ${label} manifest: ${manifest_path}"
    exit 2
  }
}

materialize_manifest "$base_ref" "$base_manifest"
materialize_manifest "$head_ref" "$head_manifest"
validate_manifest "$base_manifest" base
validate_manifest "$head_manifest" head

materialize_file() {
  local ref="$1" file_path="$2" destination="$3"
  command git -C "$repository" show "${ref}:${file_path}" > "$destination" 2>/dev/null
}

extract_token_set() {
  local source_file="$1" assignment="$2" output="$3"
  local line trimmed rest value="" token
  integer collecting=0

  while IFS= read -r line; do
    if (( ! collecting )); then
      trimmed="${line##[[:space:]]#}"
      [[ ${trimmed%%=*} == "$assignment" ]] || continue
      rest="${trimmed#*=}"
      rest="${rest##[[:space:]]#}"
      [[ ${rest[1]-} == '"' ]] || continue
      rest="${rest[2,-1]}"
      collecting=1
    else
      rest="$line"
    fi

    trimmed="${rest%%[[:space:]]#}"
    if [[ ${trimmed[-1]-} == '"' ]]; then
      value+="${trimmed[1,-2]}"
      collecting=0
      break
    fi
    value+="${trimmed%\\}"
  done < "$source_file"

  for token in "${(@s:|:)value}"; do
    [[ -n $token ]] && print -r -- "${token}"$'\t'"${token}"
  done | LC_ALL=C sort -u > "$output"
}

function_body_arity() {
  local source_file="$1" symbol="$2"
  local line code compact body=""
  local needle="${symbol}(){"
  integer found=0

  while IFS= read -r line; do
    code="${line%%\#*}"
    compact="${code//[ $'\t']/}"
    if (( ! found )); then
      [[ $compact == *"$needle"* ]] || continue
      found=1
    fi
    body+="${code}"$'\n'
    [[ $compact == '}' ]] && break
  done < "$source_file"

  (( found )) || return 1
  local arity
  arity="$(print -r -- "$body" |
    command grep -oE '\$\{?[0-9]+' 2>/dev/null |
    command grep -oE '[0-9]+' 2>/dev/null |
    LC_ALL=C sort -n |
    command tail -1 || true)"
  print -r -- "${arity:-0}"
}

extract_function_region() {
  local source_file="$1" start_marker="$2" end_marker="$3" output="$4"
  local line code compact name
  integer in_region=0

  while IFS= read -r line; do
    if (( ! in_region )); then
      [[ $line == *"$start_marker"* ]] && in_region=1
      continue
    fi
    [[ $line == *"$end_marker"* ]] && break
    code="${line%%\#*}"
    compact="${code//[ $'\t']/}"
    if [[ $compact == (#b)(*)'(){'* ]]; then
      name="${match[1]}"
      [[ -n $name ]] && print -r -- "${name}"$'\t'"variadic"
    fi
  done < "$source_file" | LC_ALL=C sort -u > "$output"
}

extract_aliases() {
  local source_file="$1" target="$2" output="$3"
  local line code token name alias_target

  while IFS= read -r line; do
    code="${line%%\#*}"
    [[ $code == *"builtin alias"* ]] || continue
    for token in ${(z)code}; do
      [[ $token == *=* ]] || continue
      name="${token%%=*}"
      alias_target="${token#*=}"
      [[ $alias_target == "$target" ]] || continue
      print -r -- "${name}"$'\t'"${alias_target}"
    done
  done < "$source_file" | LC_ALL=C sort -u > "$output"
}

extract_surface() {
  local ref="$1" definition="$2" output="$3"
  local kind file source_file symbol arity
  : > "$output"
  kind="$(jq -r '.kind' <<< "$definition")"

  case "$kind" in
    path)
      file="$(jq -r '.path' <<< "$definition")"
      if command git -C "$repository" cat-file -e "${ref}:${file}" 2>/dev/null; then
        print -r -- "${file}"$'\t'"exists" > "$output"
      fi
      ;;
    token-set|function|function-region|aliases)
      file="$(jq -r '.file' <<< "$definition")"
      source_file="$temp_dir/source-${RANDOM}-${RANDOM}"
      materialize_file "$ref" "$file" "$source_file" || return 0
      case "$kind" in
        token-set)
          extract_token_set "$source_file" "$(jq -r '.assignment' <<< "$definition")" "$output"
          ;;
        function)
          symbol="$(jq -r '.symbol' <<< "$definition")"
          if arity="$(function_body_arity "$source_file" "$symbol")"; then
            if [[ $(jq -r '.presence_only // false' <<< "$definition") == true ]]; then
              arity="present"
            fi
            print -r -- "${symbol}"$'\t'"${arity}" > "$output"
          fi
          ;;
        function-region)
          extract_function_region \
            "$source_file" \
            "$(jq -r '.start_marker' <<< "$definition")" \
            "$(jq -r '.end_marker' <<< "$definition")" \
            "$output"
          ;;
        aliases)
          extract_aliases "$source_file" "$(jq -r '.target' <<< "$definition")" "$output"
          ;;
      esac
      ;;
    *)
      print -u2 "public-contract-impact: unsupported surface kind: $kind"
      exit 2
      ;;
  esac
}

typeset -a impacts=()

impact_id() {
  local raw="$1"
  local id
  id="$(print -rn -- "$raw" |
    LC_ALL=C tr '[:upper:]' '[:lower:]' |
    LC_ALL=C tr -cs '[:alnum:]._/-' '-')"
  id="${id##-##}"
  id="${id%%-##}"
  print -r -- "$id"
}

record_impact() {
  local severity="$1" classification="$2" surface="$3" before="$4" after="$5" summary="$6"
  local id
  id="$(impact_id "${surface}/${classification}/${before:-none}-to-${after:-none}")"
  impacts+=( "${severity}"$'\x1f'"${id}"$'\x1f'"${classification}"$'\x1f'"${surface}"$'\x1f'"${before}"$'\x1f'"${after}"$'\x1f'"${summary}" )
}

compare_surface() {
  local surface_id="$1" kind="$2" base_snapshot="$3" head_snapshot="$4"
  typeset -A base_items=() head_items=()
  typeset -a additions=() removals=()
  local item detail

  while IFS=$'\t' read -r item detail; do
    [[ -n $item ]] && base_items[$item]="$detail"
  done < "$base_snapshot"
  while IFS=$'\t' read -r item detail; do
    [[ -n $item ]] && head_items[$item]="$detail"
  done < "$head_snapshot"

  for item in ${(ok)base_items}; do
    (( ${+head_items[$item]} )) || removals+=( "$item" )
  done
  for item in ${(ok)head_items}; do
    (( ${+base_items[$item]} )) || additions+=( "$item" )
  done

  if (( ${#removals} == 1 && ${#additions} == 1 )) &&
    jq -e \
      --arg surface "$surface_id" \
      --arg from "$removals[1]" \
      --arg to "$additions[1]" \
      'any(.renames[]?; .surface == $surface and .from == $from and .to == $to)' \
      "$head_manifest" >/dev/null; then
    record_impact breaking rename "$surface_id" "$removals[1]" "$additions[1]" \
      "\`${removals[1]}\` was replaced by \`${additions[1]}\`."
  else
    for item in "${removals[@]}"; do
      record_impact breaking removal "$surface_id" "$item" "" "\`${item}\` was removed."
    done
    for item in "${additions[@]}"; do
      record_impact info addition "$surface_id" "" "$item" "\`${item}\` was added."
    done
  fi

  for item in ${(ok)base_items}; do
    (( ${+head_items[$item]} )) || continue
    [[ ${base_items[$item]} == ${head_items[$item]} ]] && continue
    case "$kind" in
      function)
        if [[ ${base_items[$item]} == <-> && ${head_items[$item]} == <-> ]] &&
          (( head_items[$item] < base_items[$item] )); then
          record_impact breaking signature-narrowing "$surface_id" \
            "${item}/${base_items[$item]}-args" "${item}/${head_items[$item]}-args" \
            "\`${item}\` narrowed from ${base_items[$item]} to ${head_items[$item]} positional arguments."
        else
          record_impact info compatible-signature-change "$surface_id" \
            "${item}/${base_items[$item]}" "${item}/${head_items[$item]}" \
            "\`${item}\` changed from ${base_items[$item]} to ${head_items[$item]}."
        fi
        ;;
      aliases)
        record_impact breaking retargeting "$surface_id" \
          "${item}=${base_items[$item]}" "${item}=${head_items[$item]}" \
          "\`${item}\` was retargeted from \`${base_items[$item]}\` to \`${head_items[$item]}\`."
        ;;
    esac
  done
}

typeset -a surface_ids
typeset surface_id base_definition head_definition base_semantics head_semantics kind
typeset base_snapshot head_snapshot
surface_ids=( "${(@f)$(jq -r -s '[.[].surfaces[].id] | unique[]' "$base_manifest" "$head_manifest")}" )
for surface_id in "${surface_ids[@]}"; do
  [[ -n $surface_id ]] || continue
  base_definition="$(jq -c --arg id "$surface_id" '.surfaces[] | select(.id == $id)' "$base_manifest")"
  head_definition="$(jq -c --arg id "$surface_id" '.surfaces[] | select(.id == $id)' "$head_manifest")"

  if [[ -z $base_definition ]]; then
    record_impact info contract-definition-addition "$surface_id" "" "$surface_id" \
      "Monitoring for \`${surface_id}\` was added to contract version $(jq -r '.contract_version' "$head_manifest")."
    continue
  fi
  if [[ -z $head_definition ]]; then
    record_impact breaking contract-definition-removal "$surface_id" "$surface_id" "" \
      "Monitoring for \`${surface_id}\` was removed from the versioned definition."
    continue
  fi

  base_semantics="$(jq -Sc 'del(.description)' <<< "$base_definition")"
  head_semantics="$(jq -Sc 'del(.description)' <<< "$head_definition")"
  if [[ $base_semantics != "$head_semantics" ]]; then
    record_impact breaking contract-definition-change "$surface_id" \
      "base-definition" "head-definition" \
      "The extraction definition changed; this requires explicit review because it can alter monitoring coverage."
  fi

  kind="$(jq -r '.kind' <<< "$head_definition")"
  base_snapshot="$temp_dir/base-${surface_id}.tsv"
  head_snapshot="$temp_dir/head-${surface_id}.tsv"
  extract_surface "$base_ref" "$base_definition" "$base_snapshot"
  extract_surface "$head_ref" "$head_definition" "$head_snapshot"
  compare_surface "$surface_id" "$kind" "$base_snapshot" "$head_snapshot"
done

compare_consumers() {
  local base_file="$1" head_file="$2"
  typeset -A base_consumers=() head_consumers=()
  local surface repository_name consumer_path evidence key

  while IFS=$'\t' read -r surface repository_name consumer_path evidence; do
    [[ -n $surface ]] || continue
    key="${surface}"$'\t'"${repository_name}"$'\t'"${consumer_path}"
    base_consumers[$key]="$evidence"
  done < <(jq -r '
    .consumers[]
    | . as $consumer
    | .surfaces[]
    | [., $consumer.repository, $consumer.path, $consumer.evidence]
    | @tsv
  ' "$base_file")

  while IFS=$'\t' read -r surface repository_name consumer_path evidence; do
    [[ -n $surface ]] || continue
    key="${surface}"$'\t'"${repository_name}"$'\t'"${consumer_path}"
    head_consumers[$key]="$evidence"
  done < <(jq -r '
    .consumers[]
    | . as $consumer
    | .surfaces[]
    | [., $consumer.repository, $consumer.path, $consumer.evidence]
    | @tsv
  ' "$head_file")

  for key in ${(ok)base_consumers}; do
    IFS=$'\t' read -r surface repository_name consumer_path <<< "$key"
    if (( ! ${+head_consumers[$key]} )); then
      record_impact breaking consumer-evidence-removal "$surface" \
        "${repository_name}:${consumer_path}" "" \
        "Checked-in consumer evidence for \`${repository_name}:${consumer_path}\` was removed."
    elif [[ ${base_consumers[$key]} != ${head_consumers[$key]} ]]; then
      record_impact info consumer-evidence-refresh "$surface" \
        "${repository_name}:${consumer_path}" "${repository_name}:${consumer_path}" \
        "Evidence for \`${repository_name}:${consumer_path}\` was refreshed."
    fi
  done
  for key in ${(ok)head_consumers}; do
    (( ${+base_consumers[$key]} )) && continue
    IFS=$'\t' read -r surface repository_name consumer_path <<< "$key"
    record_impact info consumer-evidence-addition "$surface" "" \
      "${repository_name}:${consumer_path}" \
      "Checked-in consumer evidence for \`${repository_name}:${consumer_path}\` was added."
  done
}

if (( $(jq -r '.contract_version' "$base_manifest") > 0 )); then
  compare_consumers "$base_manifest" "$head_manifest"
fi

typeset consumers_manifest="$temp_dir/consumers.json"
jq -s '{
  consumers: ([.[].consumers[]] | unique_by([.repository, .path, .surfaces, .evidence]))
}' "$base_manifest" "$head_manifest" > "$consumers_manifest"

typeset report="$temp_dir/report.md"
typeset consumer_lines
{
  print "## Public contract impact"
  print
  print -r -- "- Base: \`${base_ref}\`"
  print -r -- "- Head: \`${head_ref}\`"
  print -r -- "- Definition: \`${manifest_path}\` (schema v1, contract v$(jq -r '.contract_version' "$head_manifest"))"
  print
  print "### Monitored contract"
  print
  jq -r '.surfaces[] | "- `\(.id)` — \(.description)"' "$head_manifest"
  print

  if (( ! ${#impacts} )); then
    print "No public-contract changes detected."
  else
    print "### Impacts"
    print
    print "| Classification | Surface | Change | Policy |"
    print "| --- | --- | --- | --- |"
    for impact in "${impacts[@]}"; do
      IFS=$'\x1f' read -r severity id classification surface before after summary <<< "$impact"
      if [[ $severity == breaking ]]; then
        policy="breaking gate"
      else
        policy="informational"
      fi
      print "| \`${classification}\` | \`${surface}\` | ${summary} | ${policy} |"
    done
    print
    print "### Likely consumers"
    print
    typeset -A reported_surfaces=()
    for impact in "${impacts[@]}"; do
      IFS=$'\x1f' read -r severity id classification surface before after summary <<< "$impact"
      (( ${+reported_surfaces[$surface]} )) && continue
      reported_surfaces[$surface]=1
      print "#### \`${surface}\`"
      consumer_lines="$(jq -r --arg surface "$surface" '
        .consumers[]
        | select(.surfaces | index($surface))
        | "- [`\(.repository):\(.path)`](\(.evidence))"
      ' "$consumers_manifest")"
      if [[ -n $consumer_lines ]]; then
        print -r -- "$consumer_lines"
      else
        print -r -- "- No checked-in consumer reference is currently recorded."
      fi
      print
    done
  fi
} > "$report"

integer policy_failures=0
typeset -a breaking_impacts=()
typeset annotation_message
for impact in "${impacts[@]}"; do
  IFS=$'\x1f' read -r severity id classification surface before after summary <<< "$impact"
  [[ $severity == breaking ]] && breaking_impacts+=( "$impact" )
  annotation_message="${surface}: ${summary}"
  annotation_message="${annotation_message//'%'/'%25'}"
  annotation_message="${annotation_message//$'\r'/'%0D'}"
  annotation_message="${annotation_message//$'\n'/'%0A'}"
  if [[ $severity == breaking ]]; then
    print "::error title=Public contract ${classification}::${annotation_message}"
  else
    print "::notice title=Public contract ${classification}::${annotation_message}"
  fi
done

if (( enforce_policy && ${#breaking_impacts} )); then
  typeset labels_json="${PR_LABELS_JSON-[]}"
  typeset pr_body="${PR_BODY-}"
  typeset marker disposition_line disposition body_line trimmed_line
  if ! jq -e 'index("breaking-change") != null' <<< "$labels_json" >/dev/null 2>&1; then
    print "::error title=Breaking-change label required::Add the breaking-change label."
    (( policy_failures += 1 ))
  fi

  typeset migration_section="" visible_migration="" migration=""
  if [[ $pr_body == *"## Migration plan"* ]]; then
    migration_section="${pr_body#*"## Migration plan"}"
    migration_section="${migration_section%%$'\n## '*}"
    visible_migration="${migration_section//<!--*-->/}"
    migration="${visible_migration//[[:space:]]/}"
  fi
  if (( ${#migration} < 20 )); then
    print "::error title=Migration plan required::Add a linked or descriptive ## Migration plan section to the PR body."
    (( policy_failures += 1 ))
  fi

  for impact in "${breaking_impacts[@]}"; do
    IFS=$'\x1f' read -r severity id classification surface before after summary <<< "$impact"
    marker="[contract-impact:${id}]"
    disposition_line=""
    for body_line in "${(@f)visible_migration}"; do
      trimmed_line="${body_line##[[:space:]]#}"
      if [[ ${trimmed_line[1,${#marker}]-} == "$marker" ]]; then
        disposition_line="${trimmed_line[${#marker}+1,-1]-}"
        break
      fi
    done
    disposition="${disposition_line##[[:space:]]#}"
    if [[ $disposition == "updated here"* ]]; then
      continue
    elif [[ $disposition == "follow-up issue linked:"*https://github.com/*/issues/<->* ]]; then
      continue
    elif [[ ${#disposition} -ge 24 && $disposition == "not affected:"?* ]]; then
      continue
    elif [[ $disposition == "deprecated with removal target:"?* ]]; then
      continue
    fi
    print "::error title=Impact disposition required::Add ${marker} followed by an allowed disposition."
    (( policy_failures += 1 ))
  done
fi

if (( ${#breaking_impacts} )); then
  {
    print
    print "### Breaking-change policy"
    print
    print "Destructive impacts require the \`breaking-change\` label, a descriptive \`## Migration plan\`, and one PR-body line per impact:"
    print
    for impact in "${breaking_impacts[@]}"; do
      IFS=$'\x1f' read -r severity id classification surface before after summary <<< "$impact"
      print -r -- "- \`[contract-impact:${id}] updated here\`"
    done
    print
    print "Allowed dispositions are \`updated here\`, \`follow-up issue linked: <issue URL>\`, \`not affected: <rationale>\`, and \`deprecated with removal target: <target>\`."
  } >> "$report"
fi

command cat "$report"
if [[ -n ${GITHUB_STEP_SUMMARY-} ]]; then
  command cat "$report" >> "$GITHUB_STEP_SUMMARY"
fi

(( policy_failures == 0 ))
