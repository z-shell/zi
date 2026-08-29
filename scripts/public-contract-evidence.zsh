#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# public-contract-evidence.zsh -- report stale consumer evidence pins.
#
# Every entry in contracts/public-contract-v1.json cites a consumer file at a
# fixed commit. Nothing detects when that consumer file moves on, so an
# evidence URL can silently describe a version that no longer exists. This
# script compares the Git blob object of each pinned path against the blob
# currently on the consumer repository's default branch.
#
# A stale pin is a review signal, not automatically a contract break: the
# consumer may have changed lines unrelated to the surfaces it claims. Re-read
# the consumer, then bump the pin when the claim still holds.
#
# Usage:
#   zsh scripts/public-contract-evidence.zsh [--manifest PATH] [--quiet]
#
# Exit codes:
#   0  every pin resolves and matches the consumer default branch
#   1  at least one pin is stale or unresolvable
#   2  usage or dependency error

emulate -LR zsh
setopt errexit nounset pipefail

typeset manifest_path="contracts/public-contract-v1.json"
integer quiet=0

usage() {
  print "usage: ${0:t} [--manifest PATH] [--quiet]"
}

while (( $# )); do
  case "$1" in
    --manifest)
      manifest_path="${2-}"
      shift 2
      ;;
    --quiet)
      quiet=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      print -u2 "public-contract-evidence: unknown argument: $1"
      usage >&2
      exit 2
      ;;
  esac
done

for command_name in gh jq; do
  (( $+commands[$command_name] )) || {
    print -u2 "public-contract-evidence: required command not found: ${command_name}"
    exit 2
  }
done

[[ -r $manifest_path ]] || {
  print -u2 "public-contract-evidence: cannot read manifest: ${manifest_path}"
  exit 2
}

# Resolve a path's blob object id. With a ref, read that exact commit;
# without one, read the repository default branch.
blob_at() {
  local repository="$1" file_path="$2" ref="${3-}" endpoint
  endpoint="repos/${repository}/contents/${file_path}"
  [[ -n $ref ]] && endpoint+="?ref=${ref}"
  command gh api "$endpoint" --jq '.sha' 2>/dev/null
}

typeset -a stale=() unresolved=()
typeset line repository file_path evidence commit pinned_blob head_blob
integer checked=0

while IFS=$'\t' read -r repository file_path evidence; do
  [[ -n $repository ]] || continue
  (( checked += 1 ))
  commit="${${evidence#*/blob/}%%/*}"

  pinned_blob="$(blob_at "$repository" "$file_path" "$commit")" || pinned_blob=""
  head_blob="$(blob_at "$repository" "$file_path")" || head_blob=""

  if [[ -z $pinned_blob || -z $head_blob ]]; then
    unresolved+=( "${repository}/${file_path}" )
    continue
  fi
  if [[ $pinned_blob != $head_blob ]]; then
    stale+=( "${repository}/${file_path}"$'\t'"${commit}"$'\t'"${pinned_blob}"$'\t'"${head_blob}" )
    continue
  fi
  (( quiet )) || print -r -- "current   ${repository}/${file_path}"
done < <(jq -r '.consumers[] | [.repository, .path, .evidence] | @tsv' "$manifest_path")

if (( ${#unresolved} )); then
  print -u2 -r -- ""
  print -u2 -r -- "Unresolvable evidence (moved, renamed, or private):"
  for line in "${unresolved[@]}"; do
    print -u2 -r -- "  ${line}"
  done
fi

if (( ${#stale} )); then
  print -u2 -r -- ""
  print -u2 -r -- "Stale evidence pins (consumer file changed since the pinned commit):"
  for line in "${stale[@]}"; do
    print -u2 -r -- "  ${${(s:	:)line}[1]}"
    print -u2 -r -- "    pinned commit : ${${(s:	:)line}[2]}"
    print -u2 -r -- "    pinned blob   : ${${(s:	:)line}[3]}"
    print -u2 -r -- "    current blob  : ${${(s:	:)line}[4]}"
  done
  print -u2 -r -- ""
  print -u2 -r -- "Re-read each consumer, confirm the claimed surfaces still apply,"
  print -u2 -r -- "then bump its evidence commit and evidence_reviewed."
fi

if (( ${#stale} || ${#unresolved} )); then
  exit 1
fi

(( quiet )) || print -r -- ""
print -r -- "public-contract-evidence: ${checked} consumer pins current"
