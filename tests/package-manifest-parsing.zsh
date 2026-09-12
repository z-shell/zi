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

# Resolves the `default' profile of a manifest into the `ices' hash, the way
# .zi-get-package does.
resolve() {  # resolve <manifest text> <output hash name>
  local -A Strings
  .zi-parse-json "$1" "plugin-info" Strings
  local -a level1=( "${(@Q)${(@z)Strings[1/1]}}" )
  integer ipos=${level1[(I)zi-ices]}
  (( ipos )) || { builtin print -u2 -r -- "no zi-ices key at level 1"; return 1; }
  local -a profiles=( "${(@Q)${(@z)Strings[2/$(( (ipos + 1) / 2 ))]}}" )
  integer ppos=${profiles[(I)default]}
  (( ppos )) || { builtin print -u2 -r -- "no default profile"; return 1; }
  : ${(PAA)2::="${(@Q)${(@z)Strings[3/$(( (ppos + 1) / 2 ))]}}"}
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
ZSH

builtin print -r -- "ok - .zi-parse-json reads manifests independently of key order and decodes JSON escapes"
