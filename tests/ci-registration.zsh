#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# Every focused test under tests/ is registered by hand as a workflow job. A
# test nobody registered never runs and nothing notices (#549). Each check
# reads one specific workflow, so a test mentioned by an unrelated workflow
# cannot satisfy a requirement that belongs to another:
#
#   1. every tests/*.zsh is invoked by zsh-n.yml, except the tests owned by
#      another workflow, which must be invoked by that workflow;
#   2. the promotion set below is invoked by promotion-readiness.yml;
#   3. every tests/*.zsh a workflow invokes exists.

builtin emulate -R zsh
setopt pipe_fail extended_glob

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

typeset project_root="${ZI_TEST_CHECKOUT:-${0:A:h:h}}"
typeset workflow_dir="${project_root}/.github/workflows"

# Tests whose owning workflow is not zsh-n.yml.
typeset -A owner
owner=(
  public-contract-impact.zsh public-contract-impact.yml
)
# Tests the promotion workflow must keep running on the exact candidate head.
typeset -a promotion_set
promotion_set=(
  version-reporting.zsh
  self-update-reload.zsh
  path-resolution.zsh
  archive-extraction.zsh
  completion-refresh.zsh
  snippet-directory-mirror.zsh
)

# A test is invoked only by an executable `run:` step. The scanner reads the
# workflow as YAML text: a `run:` key (optionally as a list item) starts a
# step command, a `|` or `>` value continues on the more-indented lines that
# follow, and a line whose first non-blank character is `#` is a comment and
# never a key. A mention in a `paths:` filter, a `hashFiles()` condition, or a
# commented-out step is therefore not an invocation.
invokes() {  # invokes <workflow file> <test basename>
  local line command indent block_indent=-1
  local pattern="(^|[[:space:]])zsh([[:space:]]+-[[:alnum:]]+)*[[:space:]]+tests/${2//./\\.}([[:space:]]|$)"
  while IFS= read -r line; do
    if (( block_indent >= 0 )); then
      indent=${#${line%%[^ ]*}}
      if [[ -n ${line//[[:space:]]/} ]] && (( indent <= block_indent )); then
        block_indent=-1
      else
        [[ $line =~ $pattern ]] && return 0
        continue
      fi
    fi
    [[ $line =~ '^([[:space:]]*)(-[[:space:]]+)?run:[[:space:]]*(.*)$' ]] || continue
    command=${match[3]}
    if [[ $command == [\|\>]* ]]; then
      block_indent=${#match[1]}
      (( ${+match[2]} )) && [[ -n ${match[2]} ]] && block_indent=$(( block_indent + ${#match[2]} ))
      continue
    fi
    [[ $command =~ $pattern ]] && return 0
  done < "${workflow_dir}/$1"
  return 1
}

typeset -a tests missing
tests=( "${project_root}"/tests/*.zsh(N) )
(( $#tests )) || fail "no tests under ${project_root}/tests"
[[ -r ${workflow_dir}/zsh-n.yml && -r ${workflow_dir}/promotion-readiness.yml ]] ||
  fail "zsh-n.yml or promotion-readiness.yml is missing"

typeset test_path name
for test_path in "${tests[@]}"; do
  name=${test_path:t}
  invokes "${owner[$name]:-zsh-n.yml}" "$name" || missing+=( "${name} (${owner[$name]:-zsh-n.yml})" )
done
(( $#missing == 0 )) || fail "tests invoked by no workflow: ${(j:, :)missing}"

for name in "${promotion_set[@]}"; do
  invokes promotion-readiness.yml "$name" || missing+=( "$name" )
done
(( $#missing == 0 )) || fail "promotion set missing from promotion-readiness.yml: ${(j:, :)missing}"

typeset -a referenced
referenced=( ${(u)${(M)${=$(command cat -- "${workflow_dir}"/*.yml)}:#tests/[a-z0-9-]##.zsh}} )
for name in "${referenced[@]}"; do
  [[ -r ${project_root}/$name ]] || missing+=( "$name" )
done
(( $#missing == 0 )) || fail "workflows invoke tests that do not exist: ${(j:, :)missing}"

builtin print -r -- "ok - every focused test is registered where it belongs (${#tests} tests, promotion set ${#promotion_set})"
