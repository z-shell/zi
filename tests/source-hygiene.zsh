#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# Structural checks over the shipped sources. Neither can be caught by a
# behavioural test: a duplicate definition whose copies agree behaves correctly
# until they drift, and a wrong header misleads only the next reader. Both are
# cheap to assert and expensive to rediscover.

builtin emulate -R zsh
setopt extended_glob pipe_fail

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
builtin cd -q "$project_root" || fail "enter the project root"

typeset -a sources
sources=( zi.zsh lib/zsh/*.zsh(N) )
(( ${#sources} )) || fail "locate the shipped sources"

# A top-level definition: a name in column one followed by `()'. Indented
# definitions are anonymous or nested helpers and are deliberately not counted.
typeset -r name_class='[A-Za-z_@.:+][A-Za-z0-9_@.:+-]#'

typeset -A seen_in
typeset -a duplicates mismatches
typeset src name header defined
typeset -a lines
typeset -i i j

for src in "${sources[@]}"; do
  lines=( "${(@f)$(<$src)}" )

  for (( i = 1; i <= ${#lines}; i++ )); do
    # Every function is defined exactly once across the shipped sources. Both
    # libraries are sourced conditionally and in different orders depending on
    # the command, so a second definition does not reliably override the first:
    # which one wins varies by code path. `.zi-at-eval' was defined in both
    # lib/zsh/autoload.zsh and lib/zsh/install.zsh with matching behaviour and
    # different wording, exactly the shape that becomes a heisenbug once the
    # two drift.
    if [[ ${lines[i]} == (#b)(${~name_class})[[:space:]]#'()'* ]]; then
      name="${match[1]}"
      if [[ -n ${seen_in[$name]} ]]; then
        duplicates+=( "${name}: ${seen_in[$name]} and ${src}:${i}" )
      else
        seen_in[$name]="${src}:${i}"
      fi
      continue
    fi

    # Every `# FUNCTION: <name>' header names the function it precedes.
    if [[ ${lines[i]} == (#b)'#'[[:space:]]#'FUNCTION:'[[:space:]]#(${~name_class})* ]]; then
      header="${match[1]%.}"
      for (( j = i + 1; j <= i + 6 && j <= ${#lines}; j++ )); do
        [[ ${lines[j]} == (#b)(${~name_class})[[:space:]]#'()'* ]] || continue
        defined="${match[1]}"
        [[ $header == $defined ]] ||
          mismatches+=( "${src}:${i} header '${header}' precedes '${defined}'" )
        break
      done
    fi
  done
done

if (( ${#duplicates} )); then
  builtin print -u2 -rl -- "functions defined more than once:" "${duplicates[@]}"
  fail "a function is defined in more than one shipped source"
fi

if (( ${#mismatches} )); then
  builtin print -u2 -rl -- "FUNCTION headers naming a different function:" "${mismatches[@]}"
  fail "a FUNCTION header does not match the function it precedes"
fi

builtin print -r -- "ok - every function is defined once and every FUNCTION header matches (${#seen_in} functions)"
