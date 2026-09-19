#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# Every published package manifest, vendored under
# tests/fixtures/package-manifests/, must resolve through the shipped reader
# for every profile it declares, and the resolved plugin-info and ices must
# match what an independent JSON parser reads (#547). The reader regression in
# #544 was reachable from these manifests and no synthetic fixture caught it.

builtin emulate -R zsh
setopt pipe_fail extended_glob

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

(( $+commands[jq] )) || fail "missing test dependency: jq"

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset fixture_dir="${project_root}/tests/fixtures/package-manifests"
typeset -a fixtures listed
fixtures=( "${fixture_dir}"/*.json(N) )
(( $#fixtures )) || fail "no fixtures under ${fixture_dir}"

# repositories.txt is the declared inventory the refresh script uses; the
# snapshots on disk must match it exactly, or a removed or unlisted manifest
# would silently change what the reader is proven against.
[[ -r ${fixture_dir}/repositories.txt ]] || fail "repositories.txt is missing"
# A read loop, not $(<file) in an array assignment: the syntax sweep's zsh -n
# evaluates that substitution and fails on the runner (see the refresh script).
typeset name
while IFS= read -r name; do
  [[ -n $name ]] && listed+=( "$name" )
done < "${fixture_dir}/repositories.txt"
for name in "${listed[@]}"; do
  [[ -r ${fixture_dir}/${name}.json ]] || fail "repositories.txt lists ${name} but ${name}.json is missing"
done
for name in "${fixtures[@]}"; do
  (( ${listed[(I)${name:t:r}]} )) || fail "${name:t} is not listed in repositories.txt"
done
(( $#listed == $#fixtures )) || fail "inventory mismatch: ${#listed} listed, ${#fixtures} snapshots"

typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-manifest-fixtures.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

# A clean environment: an exported absolute XDG_* value would make zi.zsh
# read or write state outside the temporary directory.
env -i \
  PATH="$PATH" \
  HOME="$temp_root" \
  ZDOTDIR="$temp_root" \
  XDG_DATA_HOME="$temp_root/data" \
  XDG_CACHE_HOME="$temp_root/cache" \
  XDG_CONFIG_HOME="$temp_root/config" \
  TMPDIR="$temp_root" \
  ZI_TEST_CHECKOUT="$project_root" \
  FIXTURE_DIR="$fixture_dir" \
  zsh -f <<'ZSH' || fail "a vendored manifest does not resolve through .zi-read-package-manifest"
builtin emulate -R zsh
setopt pipe_fail extended_glob
typeset -gAH ZI
ZI[BIN_DIR]=$ZI_TEST_CHECKOUT
builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1

integer manifests=0 profiles_checked=0
typeset fixture text ices_key profile key expected actual
typeset -a profile_names ice_keys info_keys
for fixture in "${FIXTURE_DIR}"/*.json; do
  text="$(<$fixture)"
  # The reader accepts the legacy spelling; the oracle must read the same member.
  ices_key=$(jq -r '.["zsh-data"] | if has("zi-ices") then "zi-ices" else "zplugin-ices" end' <<< "$text")
  profile_names=( ${(f)"$(jq -r --arg k "$ices_key" '.["zsh-data"][$k] | keys_unsorted[]' <<< "$text")"} )
  (( $#profile_names )) || { builtin print -u2 -r -- "${fixture:t}: no profiles"; return 1; }
  manifests+=1
  for profile in "${profile_names[@]}"; do
    local -A info ices
    local -a names
    .zi-read-package-manifest "$text" "$profile" info names ices || {
      builtin print -u2 -r -- "${fixture:t}: profile '${profile}' did not resolve; reader offers: ${(j:,:)names}"
      return 1
    }
    # The reader promises the whole plugin-info hash, not just the identity
    # fields, so compare every member the manifest declares and nothing more.
    info_keys=( ${(f)"$(jq -r '.["zsh-data"]["plugin-info"] | keys_unsorted[]' <<< "$text")"} )
    (( $#info_keys == $#info )) || {
      builtin print -u2 -r -- "${fixture:t}: plugin-info resolved ${#info} members, manifest declares ${#info_keys}: ${(k)info}"
      return 1
    }
    for key in "${info_keys[@]}"; do
      expected=$(jq -r --arg k "$key" '.["zsh-data"]["plugin-info"][$k] | tostring' <<< "$text")
      (( ${+info[$key]} )) || { builtin print -u2 -r -- "${fixture:t}: plugin-info lacks '${key}'"; return 1; }
      [[ ${info[$key]} == "$expected" ]] || {
        builtin print -u2 -r -- "${fixture:t}: plugin-info.${key} resolved to '${info[$key]}', expected '${expected}'"
        return 1
      }
    done
    ice_keys=( ${(f)"$(jq -r --arg k "$ices_key" --arg p "$profile" '.["zsh-data"][$k][$p] | keys_unsorted[]' <<< "$text")"} )
    (( $#ice_keys == $#ices )) || {
      builtin print -u2 -r -- "${fixture:t}: profile '${profile}' resolved ${#ices} ices, manifest declares ${#ice_keys}: ${(k)ices}"
      return 1
    }
    for key in "${ice_keys[@]}"; do
      expected=$(jq -r --arg k "$ices_key" --arg p "$profile" --arg i "$key" '.["zsh-data"][$k][$p][$i] | tostring' <<< "$text")
      (( ${+ices[$key]} )) || { builtin print -u2 -r -- "${fixture:t}: profile '${profile}' lacks ice '${key}'"; return 1; }
      actual=${ices[$key]}
      [[ $actual == "$expected" ]] || {
        builtin print -u2 -r -- "${fixture:t}: profile '${profile}' ice '${key}' resolved to '${actual}', expected '${expected}'"
        return 1
      }
    done
    profiles_checked+=1
    unset info ices names
  done
done
builtin print -r -- "resolved ${profiles_checked} profiles across ${manifests} manifests"
ZSH

builtin print -r -- "ok - every vendored package manifest resolves through the shipped reader"
