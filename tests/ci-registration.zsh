#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# Every focused test under tests/ is registered by hand as a workflow job. A
# test nobody registered never runs and nothing notices (#549), so assert that
# each tests/*.zsh is invoked by at least one workflow file.

builtin emulate -R zsh
setopt pipe_fail extended_glob

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset -a workflows tests missing
workflows=( "${project_root}"/.github/workflows/*.yml(N) )
(( $#workflows )) || fail "no workflow files under ${project_root}/.github/workflows"
tests=( "${project_root}"/tests/*.zsh(N) )
(( $#tests )) || fail "no tests under ${project_root}/tests"

typeset test_path workflow_text
workflow_text="$(command cat -- "${workflows[@]}")" || fail "read workflow files"
for test_path in "${tests[@]}"; do
  [[ $workflow_text == *"tests/${test_path:t}"* ]] || missing+=( "tests/${test_path:t}" )
done
(( $#missing == 0 )) || fail "tests invoked by no workflow: ${(j:, :)missing}"

builtin print -r -- "ok - every focused test is invoked by a workflow (${#tests} tests, ${#workflows} workflows)"
