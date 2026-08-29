#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -R zsh
setopt pipe_fail

typeset project_root="${0:A:h:h}"
typeset real_git="${commands[git]}"
typeset real_mv="${commands[mv]}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-mirror-test.XXXXXXXX")" || exit 1
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

fail() {
  builtin emulate -L zsh
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

pass() {
  builtin emulate -L zsh
  builtin print -r -- "ok - $1"
}

for dependency in git mktemp; do
  (( ${+commands[$dependency]} )) || fail "missing test dependency: $dependency"
done

typeset source_repo="$temp_root/source"
typeset remote_repo="$temp_root/remote.git"
typeset shim_dir="$temp_root/shims"
typeset install_parent="$temp_root/snippets"
typeset svn_log="$temp_root/svn.log"

command mkdir -p -- \
  "$source_repo/plugins/example" \
  "$source_repo/plugins/sibling" \
  "$source_repo/modules/archive/functions" \
  "$source_repo/modules/directory" \
  "$source_repo/modules/utility" \
  "$shim_dir" \
  "$install_parent" \
  "$temp_root/home" \
  "$temp_root/zdotdir" \
  "$temp_root/data" \
  "$temp_root/cache" \
  "$temp_root/config" || fail "create fixture directories"

builtin print -r -- v1 >| "$source_repo/plugins/example/example.plugin.zsh"
builtin print -r -- sibling >| "$source_repo/plugins/sibling/ignored.plugin.zsh"
builtin print -r -- 'builtin print -r -- archive' >| "$source_repo/modules/archive/functions/archive"
builtin print -r -- directory >| "$source_repo/modules/directory/init.zsh"
builtin print -r -- utility >| "$source_repo/modules/utility/init.zsh"
"$real_git" -C "$source_repo" init -q --initial-branch=main || fail "initialize source repository"
"$real_git" -C "$source_repo" config user.name "Snippet Mirror Test"
"$real_git" -C "$source_repo" config user.email "snippet-mirror@example.invalid"
"$real_git" -C "$source_repo" config commit.gpgsign false
"$real_git" -C "$source_repo" add .
"$real_git" -C "$source_repo" commit -qm "test: add initial directory snippet" || fail "commit initial fixture"
"$real_git" clone -q --bare "$source_repo" "$remote_repo" || fail "create fixture remote"
"$real_git" -C "$remote_repo" config uploadpack.allowFilter true

{
  builtin print -r -- '#!/bin/sh'
  builtin print -r -- 'if [ "$1" = clone ]; then'
  builtin print -r -- '  [ "${ZI_TEST_FAIL_CLONE:-0}" = 1 ] && exit 42'
  builtin print -r -- '  for last_arg do :; done'
  builtin print -r -- '  exec "$ZI_TEST_REAL_GIT" clone --quiet --depth=1 --filter=blob:none --sparse --single-branch "$ZI_TEST_REMOTE" "$last_arg"'
  builtin print -r -- 'fi'
  builtin print -r -- 'if [ "$1" = ls-remote ]; then'
  builtin print -r -- '  exec "$ZI_TEST_REAL_GIT" ls-remote --exit-code "$ZI_TEST_REMOTE" HEAD'
  builtin print -r -- 'fi'
  builtin print -r -- 'exec "$ZI_TEST_REAL_GIT" "$@"'
} >| "$shim_dir/git" || fail "write Git shim"

{
  builtin print -r -- '#!/bin/sh'
  builtin print -r -- 'if [ "${ZI_TEST_FAIL_ACTIVATION:-0}" = 1 ] && [ "$1" = -- ]; then'
  builtin print -r -- '  case "$2" in */payload) exit 42 ;; esac'
  builtin print -r -- 'fi'
  builtin print -r -- 'exec "$ZI_TEST_REAL_MV" "$@"'
} >| "$shim_dir/mv" || fail "write move shim"

{
  builtin print -r -- '#!/bin/sh'
  builtin print -r -- 'printf "%s\n" "$*" >> "$ZI_TEST_SVN_LOG"'
  builtin print -r -- 'if [ "$1" = checkout ]; then'
  builtin print -r -- '  mkdir -p "$5/.svn"'
  builtin print -r -- '  printf "%s\n" svn > "$5/from-svn.txt"'
  builtin print -r -- 'fi'
  builtin print -r -- 'exit 0'
} >| "$shim_dir/svn" || fail "write Subversion shim"

{
  builtin print -r -- '#!/bin/sh'
  builtin print -r -- 'printf "%s\n" https--github.com--sorin-ionescu--prezto--trunk--modules--archive'
} >| "$shim_dir/tree" || fail "write tree shim"

command chmod +x -- "$shim_dir/git" "$shim_dir/mv" "$shim_dir/svn" "$shim_dir/tree" || \
  fail "make command shims executable"

typeset -gx HOME="$temp_root/home"
typeset -gx ZDOTDIR="$temp_root/zdotdir"
typeset -gx XDG_DATA_HOME="$temp_root/data"
typeset -gx XDG_CACHE_HOME="$temp_root/cache"
typeset -gx XDG_CONFIG_HOME="$temp_root/config"
typeset -gx ZI_TEST_REAL_GIT="$real_git"
typeset -gx ZI_TEST_REAL_MV="$real_mv"
typeset -gx ZI_TEST_REMOTE="file://$remote_repo"
typeset -gx ZI_TEST_SVN_LOG="$svn_log"
path=( "$shim_dir" "${path[@]}" )
rehash

typeset -gAH ZI OPTS
ZI[BIN_DIR]="$project_root"
builtin source "$project_root/zi.zsh" >/dev/null || fail "source Zi"
builtin source "$project_root/lib/zsh/install.zsh" >/dev/null || fail "source install library"

typeset github_url=https://github.com/example/project/trunk/plugins/example

mirror() {
  builtin emulate -L zsh
  (
    builtin cd -q -- "$install_parent" || return 1
    .zi-mirror-directory "$@"
  )
}

# The legacy PZTM shorthand still selects the GitHub directory URL when the
# svn compatibility ice is present, then exposes the selected module's
# functions from the Git sparse-checkout snapshot.
typeset saved_snippets_dir=${ZI[SNIPPETS_DIR]}
ZI[SNIPPETS_DIR]="$install_parent/prezto-objects"
zi ice svn silent nocompile
zi snippet PZTM::archive >/dev/null || fail "load PZTM archive directory snippet"
.zi-get-object-path snippet PZTM::archive 2>/dev/null
typeset prezto_local_dir=$reply[-3] prezto_dirname=$reply[-2]
typeset prezto_object="$prezto_local_dir/$prezto_dirname"
[[ $(<"$prezto_object/._zi/mirror-backend") = git-sparse ]] || fail "record PZTM Git backend"
[[ -n ${fpath[(r)$prezto_object/functions]} ]] || fail "add PZTM functions directory to fpath"
(( ${+functions[archive]} )) || fail "autoload PZTM archive function"
[[ ! -e "$prezto_object/directory/init.zsh" ]] || fail "exclude sibling Prezto module"
builtin source "$project_root/lib/zsh/autoload.zsh" >/dev/null || fail "source autoload library"
typeset list_output
list_output="$(.zi-ls)" || fail "list Git sparse directory snippet"
[[ $list_output = *"(Git sparse)"* ]] || fail "label PZTM Git sparse backend"
[[ $list_output != *"(SVN)"* ]] || fail "avoid stale PZTM Subversion label"
ZI[SNIPPETS_DIR]=$saved_snippets_dir
pass "load PZTM directory snippet through Git sparse checkout"

# A fresh GitHub directory install contains only the selected subtree and
# records enough metadata for later update and status checks.
mirror "$github_url" "" installed || fail "install GitHub directory snippet"
[[ $(<"$install_parent/installed/example.plugin.zsh") = v1 ]] || fail "install selected subtree content"
[[ ! -e "$install_parent/installed/ignored.plugin.zsh" ]] || fail "exclude sibling subtree"
[[ ! -e "$install_parent/installed/.git" ]] || fail "do not expose staging repository"
[[ $(<"$install_parent/installed/._zi/mirror-backend") = git-sparse ]] || fail "record Git backend"
typeset initial_revision="$(<"$install_parent/installed/._zi/mirror-revision")"
[[ -n $initial_revision ]] || fail "record installed revision"
pass "install selected GitHub directory"

# Zi's object-path and status layers recognize the new metadata marker instead
# of treating the copied snapshot as either a single file or an SVN checkout.
typeset status_output
ZI[SNIPPETS_DIR]="$install_parent/object-paths"
.zi-get-object-path snippet "$github_url" 2>/dev/null
typeset object_local_dir=$reply[-3] object_dirname=$reply[-2]
command mkdir -p -- "$object_local_dir" || fail "create integration object parent"
(
  builtin cd -q -- "$object_local_dir" || return 1
  .zi-mirror-directory "$github_url" "" "$object_dirname"
) || fail "install integration directory snippet"
typeset -A stored_ice=( svn "" )
.zi-store-ices "$object_local_dir/$object_dirname/._zi" stored_ice "" "" "$github_url" 1
.zi-two-paths "$github_url" 2>/dev/null
[[ $reply[-3] = ._zi/mirror-backend ]] || fail "recognize Git mirror object path"
ICE=()
status_output="$(.zi-update-or-status-snippet status "$github_url" 2>/dev/null)" || fail "run integrated status"
[[ $status_output = *"Directory snapshot is up to date."* ]] || fail "report integrated Git mirror status"
ZI[SNIPPETS_DIR]=$saved_snippets_dir
pass "integrate object-path and status detection"

if mirror "$github_url" -t installed; then
  fail "unchanged directory reports an update"
else
  (( $? == 1 )) || fail "unchanged directory returns no-update status"
fi
status_output="$(mirror "$github_url" -s installed)" || fail "query Git directory status"
[[ $status_output = *"Directory snapshot is up to date."* ]] || fail "report up-to-date status"
pass "detect unchanged GitHub directory"

# A remote change is detected, replaces the payload, removes stale payload
# files, and preserves Zi-owned metadata.
builtin print -r -- v2 >| "$source_repo/plugins/example/example.plugin.zsh"
builtin print -r -- added >| "$source_repo/plugins/example/added.zsh"
"$real_git" -C "$source_repo" add .
"$real_git" -C "$source_repo" commit -qm "test: update directory snippet" || fail "commit updated fixture"
"$real_git" -C "$source_repo" push -q "$remote_repo" main || fail "publish updated fixture"

builtin print -r -- stale >| "$install_parent/installed/stale.zsh"
builtin print -r -- keep >| "$install_parent/installed/._zi/custom-metadata"
mirror "$github_url" -t installed || fail "detect remote update"
mirror "$github_url" -u installed || fail "update GitHub directory snippet"
[[ $(<"$install_parent/installed/example.plugin.zsh") = v2 ]] || fail "activate updated content"
[[ -f "$install_parent/installed/added.zsh" ]] || fail "activate added content"
[[ ! -e "$install_parent/installed/stale.zsh" ]] || fail "remove stale payload"
[[ $(<"$install_parent/installed/._zi/custom-metadata") = keep ]] || fail "preserve Zi metadata"
typeset updated_revision="$(<"$install_parent/installed/._zi/mirror-revision")"
[[ $updated_revision != $initial_revision ]] || fail "advance installed revision"
pass "update GitHub directory snapshot"

# A staging failure leaves the previously activated directory untouched.
builtin print -r -- v3 >| "$source_repo/plugins/example/example.plugin.zsh"
"$real_git" -C "$source_repo" add .
"$real_git" -C "$source_repo" commit -qm "test: publish failing update" || fail "commit failing-update fixture"
"$real_git" -C "$source_repo" push -q "$remote_repo" main || fail "publish failing-update fixture"

builtin print -r -- local >| "$install_parent/installed/local-sentinel"
typeset -gx ZI_TEST_FAIL_ACTIVATION=1
if mirror "$github_url" -u installed >/dev/null 2>&1; then
  fail "failed activation reports success"
fi
unset ZI_TEST_FAIL_ACTIVATION
[[ $(<"$install_parent/installed/example.plugin.zsh") = v2 ]] || fail "preserve old payload after failure"
[[ -f "$install_parent/installed/local-sentinel" ]] || fail "preserve local file after failure"
[[ $(<"$install_parent/installed/._zi/mirror-revision") = $updated_revision ]] || fail "preserve revision after failure"
pass "roll back failed GitHub directory update"

# An existing GitHub Subversion working copy migrates only after the Git
# snapshot has staged successfully.
command mkdir -p -- "$install_parent/legacy/.svn" "$install_parent/legacy/._zi" || fail "create migration fixture"
builtin print -r -- legacy >| "$install_parent/legacy/old.zsh"
builtin print -r -- keep >| "$install_parent/legacy/._zi/custom-metadata"
mirror "$github_url" -u legacy || fail "migrate GitHub Subversion working copy"
[[ $(<"$install_parent/legacy/example.plugin.zsh") = v3 ]] || fail "activate migrated content"
[[ ! -e "$install_parent/legacy/.svn" ]] || fail "remove obsolete Subversion metadata"
[[ $(<"$install_parent/legacy/._zi/custom-metadata") = keep ]] || fail "preserve migration metadata"
[[ $(<"$install_parent/legacy/._zi/mirror-backend") = git-sparse ]] || fail "record migrated backend"
pass "migrate existing GitHub Subversion directory"

# Nested metadata symlinks are rejected before staging so metadata copying
# cannot preserve a user-controlled link into a newly activated snapshot.
command mkdir -p -- "$temp_root/external-metadata" || fail "create nested metadata symlink target"
command ln -s -- "$temp_root/external-metadata" "$install_parent/installed/._zi/linked-entry" || \
  fail "create nested metadata symlink fixture"
if mirror "$github_url" -u installed >/dev/null 2>&1; then
  fail "nested metadata symlink reports success"
fi
[[ -L "$install_parent/installed/._zi/linked-entry" ]] || fail "nested metadata symlink was replaced"
[[ $(<"$install_parent/installed/example.plugin.zsh") = v2 ]] || fail "replace payload with unsafe metadata"
command rm -f -- "$install_parent/installed/._zi/linked-entry" || fail "remove nested metadata symlink fixture"
pass "reject nested metadata symlinks"

# Repository-controlled symlinks are rejected before activation because a
# sourced or executed link could escape the selected directory snapshot.
command ln -s -- ../../modules/utility/init.zsh "$source_repo/plugins/example/unsafe-link" || \
  fail "create source symlink fixture"
"$real_git" -C "$source_repo" add plugins/example/unsafe-link
"$real_git" -C "$source_repo" commit -qm "test: add unsafe directory symlink" || fail "commit source symlink fixture"
"$real_git" -C "$source_repo" push -q "$remote_repo" main || fail "publish source symlink fixture"

typeset migration_revision="$(<"$install_parent/legacy/._zi/mirror-revision")"
if mirror "$github_url" -u legacy >/dev/null 2>&1; then
  fail "source symlink reports success"
fi
[[ $(<"$install_parent/legacy/example.plugin.zsh") = v3 ]] || fail "preserve payload after source symlink rejection"
[[ ! -e "$install_parent/legacy/unsafe-link" && ! -L "$install_parent/legacy/unsafe-link" ]] || \
  fail "activate repository-controlled symlink"
[[ $(<"$install_parent/legacy/._zi/mirror-revision") = $migration_revision ]] || \
  fail "preserve revision after source symlink rejection"
pass "reject repository-controlled symlinks"

# GitHub URLs outside the supported legacy trunk shape fail closed instead of
# falling through to Subversion, while other hosts retain Subversion behavior.
if mirror https://github.com/example/project/tree/main/plugins/example "" unsupported >/dev/null 2>&1; then
  fail "unsupported GitHub URL reports success"
fi
[[ ! -e $svn_log ]] || fail "unsupported GitHub URL falls through to Subversion"

mirror https://svn.example.invalid/repository/path "" svn-target || fail "retain non-GitHub Subversion backend"
[[ $(<"$install_parent/svn-target/from-svn.txt") = svn ]] || fail "install through Subversion backend"
[[ $(<$svn_log) = checkout* ]] || fail "record Subversion checkout"
pass "preserve non-GitHub Subversion boundary"

# Path traversal in a legacy GitHub URL is rejected before any filesystem
# activation occurs.
if mirror https://github.com/example/project/trunk/plugins/../private "" traversal >/dev/null 2>&1; then
  fail "path traversal URL reports success"
fi
[[ ! -e "$install_parent/traversal" ]] || fail "path traversal URL creates a target"
pass "reject unsafe GitHub directory path"

# Symlinked targets and metadata directories are rejected before staging so a
# user-controlled link cannot redirect metadata writes or replacement.
command ln -s -- installed "$install_parent/linked-target" || fail "create symlink target fixture"
if mirror "$github_url" -u linked-target >/dev/null 2>&1; then
  fail "symlinked target reports success"
fi
[[ -L "$install_parent/linked-target" ]] || fail "symlinked target was replaced"

command mkdir -p -- "$install_parent/linked-metadata" "$temp_root/external-metadata" || fail "create metadata link fixture"
command ln -s -- "$temp_root/external-metadata" "$install_parent/linked-metadata/._zi" || fail "create metadata symlink"
if mirror "$github_url" -u linked-metadata >/dev/null 2>&1; then
  fail "symlinked metadata directory reports success"
fi
[[ -L "$install_parent/linked-metadata/._zi" ]] || fail "metadata symlink was replaced"
pass "reject symlinked activation targets"
