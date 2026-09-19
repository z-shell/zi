#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# .zi-ice splits a for-syntax word list into ice modifiers and stops at the
# first word that is not an ice; that word is the plugin or snippet ID. A word
# whose prefix spells a no-value ice used to be consumed as that ice with the
# rest as its value, so `sharkdp/hexyl` tokenized as `sh` + `arkdp/hexyl` and
# the ID was never found.

builtin emulate -LR zsh
builtin setopt pipe_fail extended_glob

typeset project_root=${0:A:h:h}
typeset temp_root
temp_root=$(command mktemp -d "${TMPDIR:-/tmp}/zi-ice-tokenizer.XXXXXXXX")
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

typeset -gx HOME=$temp_root/home
typeset -gx ZDOTDIR=$temp_root/zdotdir
typeset -gx XDG_CACHE_HOME=$temp_root/cache
typeset -gx XDG_CONFIG_HOME=$temp_root/config
typeset -gx XDG_DATA_HOME=$temp_root/data
typeset -gx TERM=xterm-256color
command mkdir -p -- "$HOME" "$ZDOTDIR"

typeset -gAH ZI
ZI[BIN_DIR]=$project_root
builtin source "$project_root/zi.zsh" >/dev/null
builtin setopt err_exit pipe_fail extended_glob

fail() {
  builtin print -ru2 -- "not ok - $1"
  exit 1
}

pass() {
  builtin print -r -- "ok - $1"
}

assert_equal() {
  [[ $1 == "$2" ]] || fail "$3: expected ${(qqq)2}, got ${(qqq)1}"
}

# tokenize <label> <expected-count> <words...>
# Runs .zi-ice on the words and checks how many it consumed as ices.
tokenize() {
  local label=$1 expected=$2
  # zi's entry point declares these before calling .zi-ice; mirror it so the
  # (#b) captures do not trip warn_create_global here.
  local -a match mbegin mend
  shift 2
  ZI_ICES=()
  integer consumed=0
  .zi-ice "$@" || consumed=$?
  assert_equal "$consumed" "$expected" "$label: consumed ices"
}

# The reported bug: a plugin ID whose prefix is a no-value ice name.
tokenize 'bare sharkdp/hexyl is an ID' 0 sharkdp/hexyl
assert_equal "${#ZI_ICES}" 0 'bare sharkdp/hexyl leaves no ice'
pass 'a bare ID starting with a no-value ice name is not an ice'

tokenize 'ices then sharkdp/hexyl' 2 lucid fromgh-r sharkdp/hexyl
assert_equal "${ZI_ICES[from]}" gh-r 'from ice keeps its value'
assert_equal "${+ZI_ICES[lucid]}" 1 'lucid ice is recorded'
assert_equal "${+ZI_ICES[sh]}" 0 'sh ice is not invented from the ID'
pass 'ices before the ID are consumed and the ID stops tokenizing'

tokenize 'bash-prefixed ID' 1 light-mode bashtop/plugin
assert_equal "${+ZI_ICES[bash]}" 0 'bash ice is not invented from the ID'
pass 'other no-value ice prefixes are treated the same'

# `svn` is a flag kept outside ZI[nval-ice-list]; it gets the same treatment.
tokenize 'svn-prefixed ID' 1 lucid svnfoo/plugin
assert_equal "${+ZI_ICES[svn]}" 0 'svn ice is not invented from the ID'
tokenize 'bare svn flag' 2 svn lucid
assert_equal "${+ZI_ICES[svn]}" 1 'bare svn is still an ice'
pass 'the svn flag follows the no-value rule'

# No-value ices on their own still work, including the empty-quote spelling
# the shell reduces to the bare name and the `--` prefix form.
tokenize 'bare no-value ices' 3 sh light-mode null
assert_equal "${+ZI_ICES[sh]}${+ZI_ICES[light-mode]}${+ZI_ICES[null]}" 111 'bare no-value ices recorded'
pass 'no-value ices without a remainder are still ices'

tokenize 'double-dash no-value ice' 1 --lucid
assert_equal "${+ZI_ICES[lucid]}" 1 'double-dash lucid recorded'
pass 'the -- prefix form is unchanged'

# Valued ices keep every remainder, including ones that contain a slash or
# look like an ID, because their value is arbitrary text.
tokenize 'valued ices with remainders' 3 wait0a 'pickbin/*' 'mvhexyl* hexyl'
assert_equal "${ZI_ICES[wait]}" 0a 'wait keeps its value'
assert_equal "${ZI_ICES[pick]}" 'bin/*' 'pick keeps a slash in its value'
assert_equal "${ZI_ICES[mv]}" 'hexyl* hexyl' 'mv keeps a value with a space and a glob'
pass 'valued ices are untouched'

# `reset` is a no-value ice and a prefix of the valued `reset-prompt`; the
# alternation must still select the longer name.
tokenize 'reset-prompt stays valued' 1 'reset-prompt!'
assert_equal "${ZI_ICES[reset-prompt]}" '!' 'reset-prompt keeps its value'
assert_equal "${+ZI_ICES[reset]}" 0 'reset is not selected over reset-prompt'
pass 'a no-value ice that prefixes a valued ice does not shadow it'

# The @ prefix remains an explicit ID marker and is never an ice.
tokenize 'explicit @ ID' 1 lucid @sharkdp/hexyl
pass 'the @ prefix still marks an ID'
