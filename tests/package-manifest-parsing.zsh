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
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-package-manifest-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" || fail "create isolated environment"

# `.zi-parse-json' reads package manifests, whose ice values are executed later.
# JSON objects are unordered and JSON strings carry escapes, so neither the key
# order nor a backslash may change which ices a profile resolves to.
env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  zsh -f <<'ZSH' || fail ".zi-parse-json does not read manifests independently of key order and escapes"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
builtin source "${ZI_TEST_CHECKOUT}/lib/zsh/install.zsh" || return 1

# Exercise the shipped lookup, not a copy of it: .zi-read-package-manifest is
# exactly what .zi-get-package uses to turn a manifest into a profile's ices.
resolve() {  # resolve <manifest text> <output hash name> [profile]
  local -A info
  local -a names
  .zi-read-package-manifest "$1" "${3:-default}" info names "$2" || {
    builtin print -u2 -r -- "profile '${3:-default}' not resolved; available: ${names[*]}"
    return 1
  }
}

local canonical='{"zsh-data":{"plugin-info":{"user":"u","plugin":"p"},
  "zi-ices":{"default":{"as":"program","pick":"x"},"bgn":{"as":"null"}}}}'
# The same document with the two `zsh-data' members written the other way round.
local reordered='{"zsh-data":{"zi-ices":{"default":{"as":"program","pick":"x"},
  "bgn":{"as":"null"}},"plugin-info":{"user":"u","plugin":"p"}}}'

local -A a b
resolve "$canonical" a || return 1
[[ ${a[as]} == program && ${a[pick]} == x ]] || {
  builtin print -u2 -r -- "canonical order resolved as='${a[as]}' pick='${a[pick]}'"
  return 1
}
resolve "$reordered" b || { builtin print -u2 -r -- "reordered manifest failed to parse"; return 1; }
[[ ${b[as]} == ${a[as]} && ${b[pick]} == ${a[pick]} ]] || {
  builtin print -u2 -r -- "key order changed the result: as='${b[as]}' pick='${b[pick]}'"
  return 1
}

# The pre-rename member name `zplugin-ices' still ships in published packages
# (z-shell/github-issues, z-shell/github-issues-srv). The reader that replaced
# the positional parser must accept it when `zi-ices' is absent, and prefer
# `zi-ices' when a manifest carries both (#544).
local legacy='{"name":"zsh-github-issues-srv","zsh-data":{"plugin-info":{"user":"z-shell","plugin":"zsh-github-issues"},
  "zplugin-ices":{"default":{"id-as":"github-issues-srv","service":"gh-issues","pick":"zsh-github-issues.service.zsh"}}}}'
local -A l
resolve "$legacy" l || { builtin print -u2 -r -- "legacy zplugin-ices manifest failed to resolve"; return 1; }
[[ ${l[service]} == gh-issues && ${l[id-as]} == github-issues-srv ]] || {
  builtin print -u2 -r -- "legacy zplugin-ices resolved service='${l[service]}' id-as='${l[id-as]}'"
  return 1
}
local both='{"zsh-data":{"plugin-info":{"user":"u","plugin":"p"},
  "zplugin-ices":{"default":{"as":"old"}},"zi-ices":{"default":{"as":"new"}}}}'
local -A bb
resolve "$both" bb || return 1
[[ ${bb[as]} == new ]] || { builtin print -u2 -r -- "zi-ices must win over zplugin-ices, got as='${bb[as]}'"; return 1; }

# Escapes. Build every backslash at run time so no quoting layer can eat one.
local bs=$'\134' nl=$'\n' tab=$'\t'
local escaped='{"zsh-data":{"plugin-info":{"user":"u","plugin":"p"},"zi-ices":{"default":{
  "atclone":"a'$bs$bs'b",
  "atpull":"say '$bs'"hi'$bs'"",
  "mv":"p'$bs'tq",
  "sbin":"l1'$bs'nl2",
  "pick":"a'$bs'/b",
  "src":"x'$bs'u0041y",
  "as":"a'$bs$bs$bs'"b",
  "ver":"a'$bs'qb"}}}}'

local -A e
resolve "$escaped" e || return 1
check() {  # check <key> <expected>
  [[ ${e[$1]} == $2 ]] || {
    builtin print -u2 -r -- "escape ${1}: got '${e[$1]}', expected '$2'"
    return 1
  }
}
check atclone "a${bs}b"   || return 1
check atpull 'say "hi"'   || return 1
check mv     "p${tab}q"   || return 1
check sbin   "l1${nl}l2"  || return 1
check pick   'a/b'        || return 1
check src    'xAy'        || return 1
# JSON "a\\\"b" denotes the literal a\"b, not a"b.
check as     "a${bs}\"b"  || return 1
# An unknown escape is not JSON; leave it exactly as written.
check ver    "a${bs}qb"   || return 1

# Preserve surrogate escapes and malformed Unicode escapes through the shipped
# manifest lookup, while continuing to decode ordinary BMP characters.
local unicode='{"zsh-data":{"plugin-info":{"user":"u"},"zi-ices":{"default":{
  "src":"'$bs'uD834'$bs'uDD1E",
  "pick":"'$bs'u12",
  "ver":"'$bs'uZZZZ",
  "atclone":"'$bs'uD800'$bs'u0041'$bs'uDFFF"}}}}'
resolve "$unicode" e || return 1
check src "${bs}uD834${bs}uDD1E" || return 1
check pick "${bs}u12" || return 1
check ver "${bs}uZZZZ" || return 1
check atclone "${bs}uD800A${bs}uDFFF" || return 1

# A quoted value containing key-like text must not become the selected object.
local decoy='{"decoy":{"text":"literal '$bs'"plugin-info'$bs'": text"},
  "zsh-data":{"plugin-info":{"user":"u","plugin":"p"},
  "zi-ices":{"default":{"as":"program","pick":"real"}}}}'
resolve "$decoy" e || return 1
check pick real || return 1

# Keys themselves may carry JSON escapes; a quoted value is still not a key.
local encoded='{"decoy":{"text":"plugin-info"},"zsh-data":{
  "plugin-'$bs'u0069nfo":{"user":"u"},"zi-ices":{"default":{"pick":"encoded"}}}}'
resolve "$encoded" e || return 1
check pick encoded || return 1

# The other production caller searches for _from with the same parser.
local -A from_data
.zi-parse-json '{"decoy":{"text":"'$bs'"_from'$bs'": fake"},"_from":"real"}' _from from_data
local -a from_fields=( "${(@Q)${(@z)from_data[1/1]}}" )
[[ ${from_fields[-2]} == _from && ${from_fields[-1]} == real ]] || {
  builtin print -u2 -r -- "key-like text diverted the _from lookup"
  return 1
}

local -A n c l

# Profile bodies are numbered across the whole subtree, so an object nested in an
# earlier member must not shift which profile is resolved. Ice values are
# executed, so picking the wrong one runs the wrong commands.
resolve '{"zsh-data":{"plugin-info":{"user":"u","plugin":"p","bugs":{"url":"decoy"}},
  "zi-ices":{"default":{"as":"program","pick":"x"},"bgn":{"as":"null"}}}}' n || return 1
[[ ${n[as]} == program && ${n[pick]} == x ]] || {
  builtin print -u2 -r -- "nested member shifted the profile: as='${n[as]}' pick='${n[pick]}' url='${n[url]}'"
  return 1
}

# A profile name reused as a key elsewhere must not divert the lookup.
resolve '{"zsh-data":{"plugin-info":{"user":"u","default":"decoy"},
  "zi-ices":{"default":{"as":"program","pick":"x"},"bgn":{"as":"null"}}}}' c || return 1
[[ ${c[as]} == program && ${c[pick]} == x ]] || {
  builtin print -u2 -r -- "name collision diverted the lookup: as='${c[as]}' pick='${c[pick]}'"
  return 1
}

# A later profile, so the offset is exercised with a non-first slot.
resolve '{"zsh-data":{"plugin-info":{"user":"u","bugs":{"url":"decoy"}},
  "zi-ices":{"first":{"as":"null"},"default":{"as":"program","pick":"late"}}}}' l || return 1
[[ ${l[pick]} == late ]] || {
  builtin print -u2 -r -- "later profile resolved wrong: pick='${l[pick]}'"
  return 1
}
ZSH

builtin print -r -- "ok - .zi-parse-json reads manifests independently of key order and decodes JSON escapes"
