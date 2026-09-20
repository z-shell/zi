#!/usr/bin/env zsh

emulate -L zsh
setopt err_return no_unset pipe_fail extended_glob

fail() {
  print -u2 -r -- "release plan: $*"
  return 1
}

target=${1:-HEAD}
output=${RELEASE_PLAN_OUTPUT:-}
notes_file=${RELEASE_NOTES_FILE:-}

target=$(git rev-parse --verify "${target}^{commit}") ||
  fail "could not resolve target commit: ${1:-HEAD}"

typeset previous_tag=''
typeset candidate
for candidate in ${(f)"$(git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname)"}; do
  if [[ $candidate =~ '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' ]]; then
    previous_tag=$candidate
    break
  fi
done

typeset range=$target
if [[ -n $previous_tag ]]; then
  tag_target=$(git rev-parse "${previous_tag}^{}") ||
    fail "could not resolve previous tag: $previous_tag"
  base_commit=$tag_target
  if ! git merge-base --is-ancestor "$base_commit" "$target"; then
    typeset -a tag_parents
    tag_parents=( ${(s: :)"$(git rev-list --parents -n 1 "$tag_target")"} )
    (( $#tag_parents == 3 )) ||
      fail "$previous_tag is not an ancestor or a promotion merge"
    base_commit=${tag_parents[3]}
    git merge-base --is-ancestor "$base_commit" "$target" ||
      fail "$previous_tag does not describe this promotion lineage"
  fi
  range="${base_commit}..${target}"
fi

typeset -a records breaking features fixes performance other
records=( ${(f)"$(git log --no-merges --format='%H%x09%s' "$range")"} )

typeset bump=0 record sha subject body short
for record in "${records[@]}"; do
  sha=${record%%$'\t'*}
  subject=${record#*$'\t'}
  short=${sha[1,7]}
  body=$(git show -s --format='%B' "$sha") || fail "could not read commit $sha"

  if print -r -- "$subject" | grep -qE '^[a-z]+(\([^)]*\))?!:' ||
      print -r -- "$body" | grep -qE '^BREAKING[ -]CHANGE:'; then
    (( bump < 3 )) && bump=3
    breaking+=( "- ${subject} (${short})" )
  elif print -r -- "$subject" | grep -qE '^feat(\([^)]*\))?:'; then
    (( bump < 2 )) && bump=2
    features+=( "- ${subject} (${short})" )
  elif print -r -- "$subject" | grep -qE '^fix(\([^)]*\))?:'; then
    (( bump < 1 )) && bump=1
    fixes+=( "- ${subject} (${short})" )
  elif print -r -- "$subject" | grep -qE '^perf(\([^)]*\))?:'; then
    (( bump < 1 )) && bump=1
    performance+=( "- ${subject} (${short})" )
  else
    other+=( "- ${subject} (${short})" )
  fi
done

typeset release=false version='' tag=''
if (( bump > 0 )); then
  release=true
  if [[ -z $previous_tag ]]; then
    version=0.1.0
  else
    typeset base=${previous_tag#v}
    typeset -a parts
    parts=( ${(s:.:)base} )
    (( $#parts == 3 )) || fail "invalid previous semantic tag: $previous_tag"
    case $bump in
      3) version="$(( parts[1] + 1 )).0.0" ;;
      2) version="${parts[1]}.$(( parts[2] + 1 )).0" ;;
      1) version="${parts[1]}.${parts[2]}.$(( parts[3] + 1 ))" ;;
    esac
  fi
  tag="v${version}"
fi

if [[ -n $output ]]; then
  {
    print -r -- "release=${release}"
    print -r -- "previous_tag=${previous_tag}"
    print -r -- "version=${version}"
    print -r -- "tag=${tag}"
    print -r -- "target=${target}"
  } >| "$output" || fail "could not write plan output: $output"
fi

if [[ $release == false ]]; then
  print -r -- '## Release plan'
  print
  print -r -- "No semantic release is proposed. The commits since ${previous_tag:-repository start} contain no feature, fix, performance, or breaking Conventional Commit."
  return 0
fi

typeset generated_notes
generated_notes=$(mktemp "${TMPDIR:-/tmp}/zi-release-notes.XXXXXXXX") ||
  fail 'could not create a notes file'
trap 'rm -f -- "$generated_notes"' EXIT HUP INT TERM

{
  print -r -- "## Changes since ${previous_tag:-repository start}"
  if (( $#breaking )); then
    print
    print -r -- '### Breaking changes'
    print -rl -- "${breaking[@]}"
  fi
  if (( $#features )); then
    print
    print -r -- '### Features'
    print -rl -- "${features[@]}"
  fi
  if (( $#fixes )); then
    print
    print -r -- '### Fixes'
    print -rl -- "${fixes[@]}"
  fi
  if (( $#performance )); then
    print
    print -r -- '### Performance'
    print -rl -- "${performance[@]}"
  fi
  if (( $#other )); then
    print
    print -r -- '### Other'
    print -rl -- "${other[@]}"
  fi
} >| "$generated_notes" || fail 'could not render release notes'

if [[ -n $notes_file ]]; then
  command cp -- "$generated_notes" "$notes_file" ||
    fail "could not write release notes: $notes_file"
fi

print -r -- '## Release plan'
print
print -r -- "- Proposed tag: \`${tag}\`"
print -r -- "- Previous tag: \`${previous_tag:-none}\`"
print -r -- "- Candidate commit: \`${target}\`"
print
command cat -- "$generated_notes"
