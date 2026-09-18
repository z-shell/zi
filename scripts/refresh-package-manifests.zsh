#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# refresh-package-manifests.zsh -- re-fetch the vendored package manifests.
#
# tests/package-manifest-fixtures.zsh resolves every published package.json
# through the shipped reader without the network. This script refreshes those
# fixtures from each package repository's default branch so a manifest change
# upstream becomes a reviewed diff here instead of a silent drift (#547).
#
# Usage:
#   zsh scripts/refresh-package-manifests.zsh [--owner OWNER]
#
# Exit codes:
#   0  every manifest fetched
#   1  at least one manifest could not be fetched
#   2  usage or dependency error

emulate -LR zsh
setopt errexit nounset pipefail

typeset owner=${ZI_PKG_OWNER:-z-shell}
while (( $# )); do
  case "$1" in
    --owner) owner=${2-}; shift 2 ;;
    --help|-h) print "usage: ${0:t} [--owner OWNER]"; exit 0 ;;
    *) print -u2 "refresh-package-manifests: unknown argument: $1"; exit 2 ;;
  esac
done
(( $+commands[curl] )) || { print -u2 "refresh-package-manifests: required command not found: curl"; exit 2 }

typeset fixture_dir=${0:A:h:h}/tests/fixtures/package-manifests
typeset -a repositories
repositories=( ${(f)"$(<${fixture_dir}/repositories.txt)"} )
integer failed=0
typeset repository
for repository in "${repositories[@]}"; do
  if curl -fsSL "https://raw.githubusercontent.com/${owner}/${repository}/HEAD/package.json" \
      -o "${fixture_dir}/${repository}.json"; then
    print -r -- "fetched ${repository}"
  else
    print -u2 -r -- "FAILED ${repository}"
    failed=1
  fi
done
exit failed
