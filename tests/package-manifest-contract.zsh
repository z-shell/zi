#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -R zsh
setopt pipe_fail

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset validator="${project_root}/scripts/validate-package-manifest.py"
typeset schema="${project_root}/contracts/package-manifest-v1.json"

[[ -r $validator ]] || fail "validator missing at ${validator}"
[[ -r $schema ]] || fail "schema missing at ${schema}"
command python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$schema" >/dev/null 2>&1 ||
  fail "contracts/package-manifest-v1.json is not valid JSON"

typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-package-contract.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

# accepts <label> <json>  -- the manifest must validate cleanly
accepts() {
  local label=$1 file="${temp_root}/ok.json"
  builtin print -r -- "$2" > $file
  command python3 "$validator" "$file" >/dev/null 2>&1 ||
    { command python3 "$validator" "$file" 2>&1 | sed 's/^/    /' >&2
      fail "${label}: expected to validate, but did not" }
}

# rejects <label> <expected substring> <json>
rejects() {
  local label=$1 expect=$2 file="${temp_root}/bad.json" out
  builtin print -r -- "$3" > $file
  out="$(command python3 "$validator" "$file" 2>&1)" &&
    fail "${label}: expected rejection, but it validated"
  [[ $out == *"$expect"* ]] ||
    fail "${label}: rejected for the wrong reason: ${out}"
}

# The three source modes, which are what decides the identity fields Zi reads.
accepts 'github via git' '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r"},
  "zi-ices":{"default":{"git":"","as":"program"}}}}'
accepts 'github release via from' '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r"},
  "zi-ices":{"default":{"from":"gh-r","bpick":"*.tar.gz"}}}}'
accepts 'non-github via is-snippet' '{"name":"p","zsh-data":{"plugin-info":{"url":"https://example.invalid/x"},
  "zi-ices":{"default":{"is-snippet":"","as":"command"}}}}'
accepts 'several profiles and an optional schema pin' '{"name":"p","zsh-data":{"schema":1,
  "plugin-info":{"user":"u","plugin":"r","message":"hi","requires":"cc;make;bgn"},
  "zi-ices":{"default":{"git":""},"bgn":{"git":"","sbin":"x"}}}}'

# A profile with no source mode reaches the npm _from tarball branch, which no
# manifest populates, so it would download an empty URL.
rejects 'no source mode' 'exactly one of is-snippet, git or from' \
  '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r"},"zi-ices":{"default":{"as":"program"}}}}'
rejects 'two source modes' 'declares 2 source modes' \
  '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r"},"zi-ices":{"default":{"git":"","from":"gh-r"}}}}'

# The mode decides which identity fields must exist, and which are dead data.
rejects 'is-snippet without url' "has no 'url'" \
  '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r"},"zi-ices":{"default":{"is-snippet":""}}}}'
rejects 'git without user' "has no 'user'" \
  '{"name":"p","zsh-data":{"plugin-info":{"plugin":"r"},"zi-ices":{"default":{"git":""}}}}'
rejects 'identity no mode reads' 'no profile declares a mode that reads it' \
  '{"name":"p","zsh-data":{"plugin-info":{"url":"https://example.invalid/x","user":"u","plugin":"r"},
    "zi-ices":{"default":{"is-snippet":""}}}}'

# Fields Zi never reads, and spellings it only tolerates.
rejects 'plugin-info.version' 'never read by Zi' \
  '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r","version":"1.0.0"},"zi-ices":{"default":{"git":""}}}}'
rejects 'legacy required in plugin-info' "use 'requires'" \
  '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r","required":"bgn"},"zi-ices":{"default":{"git":""}}}}'
rejects 'legacy required ice' "use 'requires'" \
  '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r"},"zi-ices":{"default":{"git":"","required":"bgn"}}}}'

# Ice values become shell strings, so a JSON number is not the same thing.
rejects 'numeric ice value' 'ice values are shell strings' \
  '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r"},"zi-ices":{"default":{"git":"","depth":1}}}}'

# `default` is what `zi pack` selects when no profile is named.
rejects 'no default profile' "no 'default' profile" \
  '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r"},"zi-ices":{"bgn":{"git":""}}}}'
rejects 'unknown zsh-data member' 'not part of the contract' \
  '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r"},"zi-ices":{"default":{"git":""}},"extra":{}}}'

# The contract is only enforced if the validator actually applies it. These are
# rejections that live in the schema alone, with no cross-member rule behind
# them, so they pass only when the schema is being read and used.
rejects 'non-string name' 'expected string' \
  '{"name":123,"zsh-data":{"plugin-info":{"user":"u","plugin":"r"},"zi-ices":{"default":{"git":""}}}}'
rejects 'malformed requires' 'contract pattern' \
  '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r","requires":"cc;"},"zi-ices":{"default":{"git":""}}}}'
rejects 'wrong schema version' 'expected 1' \
  '{"name":"p","zsh-data":{"schema":2,"plugin-info":{"user":"u","plugin":"r"},"zi-ices":{"default":{"git":""}}}}'
rejects 'keywords not a string array' 'expected string' \
  '{"name":"p","keywords":[1],"zsh-data":{"plugin-info":{"user":"u","plugin":"r"},"zi-ices":{"default":{"git":""}}}}'

# A manifest that is not valid UTF-8 must be reported, not crash the run and
# abandon every file after it.
typeset badenc="${temp_root}/badenc.json"
builtin printf '\xff\xfe{"name":"x"}' > $badenc
if command python3 "$validator" "$badenc" >/dev/null 2>&1; then
  fail 'non-UTF-8 manifest: expected rejection, but it validated'
fi
# Captured rather than piped: `pipe_fail` would otherwise surface the
# validator's own non-zero exit and mask what grep found.
typeset badenc_out
badenc_out="$(command python3 "$validator" "$badenc" 2>&1 || true)"
[[ $badenc_out == *'unreadable or invalid JSON'* ]] ||
  fail "non-UTF-8 manifest: not reported as unreadable: ${badenc_out}"

# A contract keyword the checker does not implement must stop the run rather
# than pass quietly, since silent under-enforcement is the failure this whole
# arrangement exists to prevent.
typeset faked="${temp_root}/faked-contract"
command mkdir -p "${faked}/contracts" "${faked}/scripts"
command cp "$validator" "${faked}/scripts/"
command python3 -c '
import json, sys
schema = json.load(open(sys.argv[1]))
schema["properties"]["name"]["maxLength"] = 4
json.dump(schema, open(sys.argv[2], "w"))' "$schema" "${faked}/contracts/package-manifest-v1.json"
builtin print -r -- '{"name":"p","zsh-data":{"plugin-info":{"user":"u","plugin":"r"},"zi-ices":{"default":{"git":""}}}}' > "${temp_root}/ok2.json"
typeset faked_out
faked_out="$(command python3 "${faked}/scripts/${validator:t}" "${temp_root}/ok2.json" 2>&1 || true)"
[[ $faked_out == *'does not implement'* ]] ||
  fail "an unimplemented contract keyword did not stop the run: ${faked_out}"

# Drift check. The contract is only worth having if it still describes the
# parser, so derive both sides from source and compare rather than restating
# either by hand. This fails when .zi-get-package starts or stops reading a
# plugin-info field, or when a source mode is added or removed, until the
# contract is updated to match.
typeset resolver="${project_root}/lib/zsh/install.zsh"
[[ -r $resolver ]] || fail "resolver missing at ${resolver}"

typeset -a code_reads schema_reads
code_reads=( ${(f)"$(command grep -o 'jsondata1\[[a-z-]*\]' $resolver | command sed 's/jsondata1\[//; s/\]//' | command sort -u)"} )
schema_reads=( ${(f)"$(command python3 -c '
import json, sys
schema = json.load(open(sys.argv[1]))
print("\n".join(sorted(schema["$defs"]["pluginInfo"]["properties"])))' "$schema")"} )

# Zi also honours the legacy `required` spelling as a fallback for `requires`.
# The contract permits only `requires`, so `required` is expected in the code
# and deliberately absent from the schema.
typeset -a expected=( ${(o)schema_reads} required )
expected=( ${(o)expected} )
[[ "${code_reads[*]}" == "${expected[*]}" ]] || fail \
  "plugin-info drift: .zi-get-package reads (${code_reads[*]}), contract plus the legacy spelling is (${expected[*]})"

typeset -a code_modes schema_modes
code_modes=( ${(f)"$(command grep -o 'ICE\[\(is-snippet\|git\|from\)\]' $resolver | command sed 's/ICE\[//; s/\]//' | command sort -u)"} )
schema_modes=( ${(f)"$(command python3 -c '
import json, sys
schema = json.load(open(sys.argv[1]))
modes = [b["required"][0] for b in schema["$defs"]["profile"]["oneOf"]]
print("\n".join(sorted(modes)))' "$schema")"} )
[[ "${(o)code_modes[*]}" == "${(o)schema_modes[*]}" ]] || fail \
  "source-mode drift: resolver branches on (${code_modes[*]}), contract declares (${schema_modes[*]})"

builtin print -r -- "ok - package manifests validate against contracts/package-manifest-v1.json"
