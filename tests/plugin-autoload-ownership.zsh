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
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-autoload-test.XXXXXXXX")" ||
  fail "create temporary directory"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

command mkdir -p \
  "${temp_root}/home" \
  "${temp_root}/cache" \
  "${temp_root}/config" \
  "${temp_root}/data" \
  "${temp_root}/zdotdir" \
  "${temp_root}/plugins/registrar" \
  "${temp_root}/plugins/provider/lib" \
  "${temp_root}/plugins/selfowned" \
  "${temp_root}/plugins/multidir/lib" \
  "${temp_root}/plugins/multidir/funcs" \
  "${temp_root}/plugins/symlinked/lib" \
  "${temp_root}/plugins/digest/functions" || fail "create isolated environment"
command ln -s -- "${temp_root}/plugins" "${temp_root}/plugins-link" ||
  fail "create plug-in directory symlink"

# The registrar stands in for a plug-in that runs compinit, which replays a
# bulk `autoload -Uz' for every completion function recorded in .zcompdump.
# None of those functions belong to the registrar.
builtin print -r -- 'autoload -Uz _issue_471_completion' \
  > "${temp_root}/plugins/registrar/registrar.plugin.zsh" || fail "write registrar plug-in"

# The provider owns the function and is loaded afterwards.
builtin print -rl -- \
  '0=${(%):-%N}' \
  'fpath+=( ${0:A:h}/lib )' \
  'autoload -Uz _issue_471_completion' \
  > "${temp_root}/plugins/provider/provider.plugin.zsh" || fail "write provider plug-in"
builtin print -r -- 'builtin print -r -- provider-body' \
  > "${temp_root}/plugins/provider/lib/_issue_471_completion" || fail "write provided function"

# A plug-in autoloading its own function while its directory stays out of
# $fpath. This is what the autoload substitution exists for and must keep
# working.
builtin print -r -- 'autoload -Uz _issue_471_own' \
  > "${temp_root}/plugins/selfowned/selfowned.plugin.zsh" || fail "write self-owned plug-in"
builtin print -r -- 'builtin print -r -- self-owned-body' \
  > "${temp_root}/plugins/selfowned/_issue_471_own" || fail "write self-owned function"

# A plug-in registering two $fpath subdirectories, autoloading a function from
# the second one, under blockf'' so that its $fpath additions are reverted once
# it has loaded. The function has to stay resolvable afterwards.
builtin print -rl -- \
  '0=${(%):-%N}' \
  'fpath+=( ${0:A:h}/lib ${0:A:h}/funcs )' \
  'autoload -Uz _issue_471_second_dir' \
  > "${temp_root}/plugins/multidir/multidir.plugin.zsh" || fail "write multidir plug-in"
builtin print -r -- 'builtin print -r -- second-dir-body' \
  > "${temp_root}/plugins/multidir/funcs/_issue_471_second_dir" || fail "write second-dir function"

# The same plug-in shape reached through a symlinked plug-in directory. The
# Plug Standard idiom resolves symlinks, so the registered $fpath entry does not
# share a prefix with the path zi was given. The plug-in still owns it.
builtin print -rl -- \
  '0=${(%):-%N}' \
  'fpath+=( ${0:A:h}/lib )' \
  'autoload -Uz _issue_471_symlinked' \
  > "${temp_root}/plugins/symlinked/symlinked.plugin.zsh" || fail "write symlinked plug-in"
builtin print -r -- 'builtin print -r -- symlinked-body' \
  > "${temp_root}/plugins/symlinked/lib/_issue_471_symlinked" || fail "write symlinked function"

# A plug-in whose $fpath subdirectory is backed by a `<directory>.zwc' digest
# rather than by plain files. The directory itself is removed after compiling,
# which is what such a digest allows.
builtin print -r -- 'builtin print -r -- digest-body' \
  > "${temp_root}/plugins/digest/functions/_issue_471_digest" || fail "write digest function"
zsh -fc "zcompile -U -z ${(q)temp_root}/plugins/digest/functions.zwc \
  ${(q)temp_root}/plugins/digest/functions/_issue_471_digest" || fail "compile function digest"
command rm -rf -- "${temp_root}/plugins/digest/functions" || fail "remove compiled directory"
builtin print -rl -- \
  '0=${(%):-%N}' \
  'fpath+=( ${0:A:h}/functions )' \
  'autoload -Uz _issue_471_digest' \
  > "${temp_root}/plugins/digest/digest.plugin.zsh" || fail "write digest plug-in"

env \
  HOME="${temp_root}/home" \
  XDG_CACHE_HOME="${temp_root}/cache" \
  XDG_CONFIG_HOME="${temp_root}/config" \
  XDG_DATA_HOME="${temp_root}/data" \
  ZDOTDIR="${temp_root}/zdotdir" \
  ZI_TEST_CHECKOUT="$project_root" \
  ZI_TEST_ROOT="$temp_root" \
  zsh -f <<'ZSH' || fail "autoload substitution claims functions the plug-in does not own"
builtin emulate -R zsh
setopt pipe_fail

builtin source "${ZI_TEST_CHECKOUT}/zi.zsh" || return 1
.zi-prepare-home || return 1

zi load "${ZI_TEST_ROOT}/plugins/registrar" >/dev/null || return 1

[[ ${functions[_issue_471_completion]} != *'local -a fpath'*registrar* ]] || {
  builtin print -u2 -r -- "registrar's directory was baked into a function it does not own"
  return 1
}

zi light "${ZI_TEST_ROOT}/plugins/provider" >/dev/null || return 1

typeset result
result="$(_issue_471_completion 2>&1)" || {
  builtin print -u2 -r -- "function owned by a later plug-in failed to resolve: $result"
  return 1
}
[[ $result == provider-body ]] || {
  builtin print -u2 -r -- "unexpected body resolved: $result"
  return 1
}

# The FPATH-clean autoloading that the substitution exists for must survive.
zi light "${ZI_TEST_ROOT}/plugins/selfowned" >/dev/null || return 1
[[ -z ${fpath[(r)${ZI_TEST_ROOT}/plugins/selfowned]} ]] || {
  builtin print -u2 -r -- "self-owned plug-in directory unexpectedly present in \$fpath"
  return 1
}
result="$(_issue_471_own 2>&1)" || {
  builtin print -u2 -r -- "plug-in's own function failed to autoload: $result"
  return 1
}
[[ $result == self-owned-body ]] || {
  builtin print -u2 -r -- "unexpected self-owned body resolved: $result"
  return 1
}

# Every $fpath subdirectory of the plug-in counts as the plug-in's own, not
# just the first one.
zi ice blockf
zi light "${ZI_TEST_ROOT}/plugins/multidir" >/dev/null || return 1
[[ -z ${fpath[(r)${ZI_TEST_ROOT}/plugins/multidir/funcs]} ]] || {
  builtin print -u2 -r -- "blockf did not revert the multidir plug-in's \$fpath additions"
  return 1
}
result="$(_issue_471_second_dir 2>&1)" || {
  builtin print -u2 -r -- "function in the plug-in's second \$fpath subdirectory failed to autoload: $result"
  return 1
}
[[ $result == second-dir-body ]] || {
  builtin print -u2 -r -- "unexpected second-dir body resolved: $result"
  return 1
}

# A plug-in loaded through a symlinked directory owns the $fpath entries it
# registers, even though `fpath+=( ${0:A:h}/lib )' resolves the symlink and the
# resulting path shares no prefix with the path zi was given.
zi ice blockf
zi light "${ZI_TEST_ROOT}/plugins-link/symlinked" >/dev/null || return 1
[[ -z ${fpath[(r)${ZI_TEST_ROOT:A}/plugins/symlinked/lib]} ]] || {
  builtin print -u2 -r -- "blockf did not revert the symlinked plug-in's \$fpath additions"
  return 1
}
result="$(_issue_471_symlinked 2>&1)" || {
  builtin print -u2 -r -- "function of a plug-in loaded through a symlink failed to autoload: $result"
  return 1
}
[[ $result == symlinked-body ]] || {
  builtin print -u2 -r -- "unexpected symlinked body resolved: $result"
  return 1
}

# An $fpath entry of the plug-in backed by a `<directory>.zwc' digest is the
# plug-in's own, even though no plain function file exists under it.
zi ice blockf
zi light "${ZI_TEST_ROOT}/plugins/digest" >/dev/null || return 1
[[ -z ${fpath[(r)${ZI_TEST_ROOT:A}/plugins/digest/functions]} ]] || {
  builtin print -u2 -r -- "blockf did not revert the digest plug-in's \$fpath additions"
  return 1
}
result="$(_issue_471_digest 2>&1)" || {
  builtin print -u2 -r -- "function backed by a directory digest failed to autoload: $result"
  return 1
}
[[ $result == digest-body ]] || {
  builtin print -u2 -r -- "unexpected digest body resolved: $result"
  return 1
}
ZSH

builtin print -r -- "ok - autoload substitution only claims functions the plug-in owns"
