#!/usr/bin/env zsh

emulate -L zsh
setopt err_exit no_unset pipe_fail

root=${0:A:h:h}
workflow=$root/.github/workflows/promotion-readiness.yml
tmp=$(mktemp -d "${TMPDIR:-/tmp}/zi-stable-gate.XXXXXXXX")
trap 'rm -rf -- "$tmp"' EXIT HUP INT TERM
fail() { print -u2 -r -- "stable qualification: $*"; exit 1; }

# Exercise the actual aggregate command rather than a second implementation.
sed -n '/      - name: Require every stable qualification/,$p' "$workflow" |
  sed '1,/        run: |/d; s/^          //' > "$tmp/gate.bash"
[[ -s $tmp/gate.bash ]] || fail 'aggregate command is missing'
command bash -n "$tmp/gate.bash"
typeset -a constituents
constituents=(ZSH_RESULT ZD_RESULT TRUNK_RESULT CODEQL_RESULT CLEAN_INSTALL_RESULT REAL_OBJECTS_RESULT)
typeset constituent result
for constituent in $constituents; do
  export "$constituent=success"
done
command bash "$tmp/gate.bash"
for constituent in $constituents; do
  for result in failure cancelled skipped; do
    if env "$constituent=$result" bash "$tmp/gate.bash" >/dev/null 2>&1; then
      fail "$constituent=$result produced a passing gate"
    fi
  done
done
grep -q 'include_compat: true' "$workflow" || fail 'ZD compatibility is not unconditional'
grep -q 'needs: \[zsh, zd, trunk, codeql, clean-install, real-objects\]' "$workflow" ||
  fail 'aggregate does not depend on every constituent'
grep -q 'if: ${{ always() }}' "$workflow" || fail 'aggregate can be skipped on failure'
grep -q '^  push:' "$workflow" || fail 'post-merge qualification is missing'
grep -q '^  pull_request:' "$workflow" || fail 'pre-merge qualification is missing'
if grep -q '^  workflow_run:' "$root/.github/workflows/release.yml"; then
  fail 'ordinary main workflow completion can publish a release'
fi
if grep -q 'pull-requests: write' "$root/.github/workflows/release-plan.yml"; then
  fail 'release planning has unnecessary write permissions'
fi
print 'stable qualification tests passed'
