#!/usr/bin/env zsh
# The roff file is the maintained offline source. Catch omitted commands and
# rendering errors without sourcing Zi or executing documentation examples.
builtin emulate -R zsh
setopt pipe_fail

fail() {
  builtin emulate -L zsh
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset manual="${project_root}/docs/man/zi.1"
typeset line inventory="" command_name headings
typeset -i reading=0

# Read the literal multiline inventory, never evaluate source text.
while IFS= read -r line; do
  if [[ $line == 'ZI[cmd-list]="'* ]]; then
    reading=1
    line=${line#'ZI[cmd-list]="'}
  fi
  (( reading )) || continue
  inventory+="${line%\\}"
  [[ $line == *'"' ]] && break
done < "${project_root}/zi.zsh"
[[ $inventory == *'"' && $inventory == *'|'* ]] ||
  fail "locate the command inventory"
inventory=${inventory%'"'}
headings=$(command sed -n 's/^\.B //p' "$manual") ||
  fail "read manual command headings"
for command_name in ${(s:|:)inventory}; do
  [[ $command_name == -* ]] && continue
  builtin print -r -- "$headings" | command grep -Fw -- "$command_name" >/dev/null ||
    fail "manual omits command: $command_name"
done

typeset diagnostics
diagnostics=$(command groff -Tutf8 -man -ww "$manual" 2>&1 >/dev/null) ||
  fail "render manual: $diagnostics"
[[ -z $diagnostics ]] || fail "manual rendering diagnostics: $diagnostics"
builtin print -r -- "ok - offline manual covers commands and renders without warnings"
