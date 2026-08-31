#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -LR zsh
setopt err_exit pipe_fail

typeset project_root="${0:A:h:h}"
typeset temp_root
temp_root="$(command mktemp -d "${TMPDIR:-/tmp}/zi-path-resolution.XXXXXXXX")"
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

zmodload zsh/stat

fail() {
  builtin print -u2 -r -- "not ok - $1"
  exit 1
}

pass() {
  builtin print -r -- "ok - $1"
}

assert_equal() {
  [[ $1 == "$2" ]] || fail "$3: expected ${(qqq)2}, got ${(qqq)1}"
}

assert_private() {
  local -A path_stat
  zstat -H path_stat +mode -- "$1" || fail "$2: stat failed"
  (( (path_stat[mode] & 8#77) == 0 )) || fail "$2: group or other permissions are set"
}

assert_mode() {
  local -A path_stat
  zstat -H path_stat +mode -- "$1" || fail "$2: stat failed"
  (( (path_stat[mode] & 8#777) == $3 )) || fail "$2: mode changed"
}

assert_paths() {
  local label="$1" expected_home="$2" expected_cache="$3" expected_config="$4"
  local expected_layout="$5" expected_log="${6:-${expected_cache}/log}"
  local expected_zcompdump="${7:-${expected_cache}/.zcompdump}"
  local expected_zpfx="${8:-${expected_home}/polaris}"

  assert_equal "${ZI[HOME_DIR]}" "$expected_home" "$label home"
  assert_equal "${ZI[CACHE_DIR]}" "$expected_cache" "$label cache"
  assert_equal "${ZI[CONFIG_DIR]}" "$expected_config" "$label config"
  assert_equal "${ZI[LOG_DIR]}" "$expected_log" "$label log"
  assert_equal "${ZI[ZCOMPDUMP_PATH]}" "$expected_zcompdump" "$label zcompdump"
  assert_equal "$ZPFX" "$expected_zpfx" "$label ZPFX"
  assert_equal "${ZI[PLUGINS_DIR]}" "${expected_home}/plugins" "$label plugins"
  assert_equal "${ZI[SNIPPETS_DIR]}" "${expected_home}/snippets" "$label snippets"
  assert_equal "${ZI[COMPLETIONS_DIR]}" "${expected_home}/completions" "$label completions"
  assert_equal "${ZI[ZMODULES_DIR]}" "${expected_home}/zmodules" "$label zmodules"
  assert_equal "$XDG_ZI_HOME" "$expected_home" "$label XDG_ZI_HOME output"
  assert_equal "$XDG_ZI_CACHE" "$expected_cache" "$label XDG_ZI_CACHE output"
  assert_equal "$XDG_ZI_CONFIG" "$expected_config" "$label XDG_ZI_CONFIG output"
  assert_equal "${ZI[HOME_LAYOUT]}" "$expected_layout" "$label layout"
}

run_case() (
  builtin emulate -LR zsh
  setopt err_exit pipe_fail

  local label="$1" case_root="${temp_root}/$1"
  local source_path="$project_root/zi.zsh"
  local expected_home expected_cache expected_config expected_layout
  local expected_log expected_zcompdump expected_zpfx status_output

  command mkdir -p -- "$case_root/home" "$case_root/zdotdir" "$case_root/tmp"
  builtin cd -q -- "$case_root"

  typeset -gx HOME="$case_root/home"
  typeset -gx ZDOTDIR="$case_root/zdotdir"
  typeset -gx TMPDIR="$case_root/tmp"
  unset XDG_DATA_HOME XDG_CACHE_HOME XDG_CONFIG_HOME
  unset ZPFX XDG_ZI_HOME XDG_ZI_CACHE XDG_ZI_CONFIG
  typeset -gAH ZI
  ZI=()
  ZI[BIN_DIR]="$project_root"

  case "$label" in
    explicit)
      typeset -gx XDG_DATA_HOME="$case_root/xdg-data"
      typeset -gx XDG_CACHE_HOME="$case_root/xdg-cache"
      typeset -gx XDG_CONFIG_HOME="$case_root/xdg-config"
      typeset -gx XDG_ZI_HOME="$case_root/ignored-input"
      ZI[HOME_DIR]="$case_root/explicit data"
      ZI[CACHE_DIR]="$case_root/explicit cache"
      ZI[CONFIG_DIR]="$case_root/explicit config"
      ZI[LOG_DIR]="$case_root/explicit log"
      ZI[ZCOMPDUMP_PATH]="$case_root/explicit cache/custom-zcompdump"
      typeset -gx ZPFX="$case_root/explicit prefix"
      expected_home="${ZI[HOME_DIR]}"
      expected_cache="${ZI[CACHE_DIR]}"
      expected_config="${ZI[CONFIG_DIR]}"
      expected_layout=explicit
      expected_log="${ZI[LOG_DIR]}"
      expected_zcompdump="${ZI[ZCOMPDUMP_PATH]}"
      expected_zpfx="$ZPFX"
      ;;
    xdg-absolute)
      typeset -gx XDG_DATA_HOME="$case_root/data with spaces"
      typeset -gx XDG_CACHE_HOME="$case_root/cache with spaces"
      typeset -gx XDG_CONFIG_HOME="$case_root/config with spaces"
      expected_home="$XDG_DATA_HOME/zi"
      expected_cache="$XDG_CACHE_HOME/zi"
      expected_config="$XDG_CONFIG_HOME/zi"
      expected_layout=xdg
      ;;
    xdg-existing-bases)
      typeset -gx XDG_DATA_HOME="$case_root/existing data"
      typeset -gx XDG_CACHE_HOME="$case_root/existing cache"
      typeset -gx XDG_CONFIG_HOME="$case_root/existing config"
      command mkdir -p -- "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
      command chmod 755 -- "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
      expected_home="$XDG_DATA_HOME/zi"
      expected_cache="$XDG_CACHE_HOME/zi"
      expected_config="$XDG_CONFIG_HOME/zi"
      expected_layout=xdg
      ;;
    xdg-unset)
      command mkdir -p -- "$ZDOTDIR/.zi/plugins"
      expected_home="$HOME/.local/share/zi"
      expected_cache="$HOME/.cache/zi"
      expected_config="$HOME/.config/zi"
      expected_layout=xdg
      ;;
    xdg-empty)
      typeset -gx XDG_DATA_HOME=''
      typeset -gx XDG_CACHE_HOME=''
      typeset -gx XDG_CONFIG_HOME=''
      expected_home="$HOME/.local/share/zi"
      expected_cache="$HOME/.cache/zi"
      expected_config="$HOME/.config/zi"
      expected_layout=xdg
      ;;
    xdg-relative)
      typeset -gx XDG_DATA_HOME='relative data'
      typeset -gx XDG_CACHE_HOME='relative cache'
      typeset -gx XDG_CONFIG_HOME='relative config'
      expected_home="$HOME/.local/share/zi"
      expected_cache="$HOME/.cache/zi"
      expected_config="$HOME/.config/zi"
      expected_layout=xdg
      ;;
    legacy-only)
      command mkdir -p -- "$HOME/.zi/plugins"
      command chmod 755 -- "$HOME/.zi"
      expected_home="$HOME/.zi"
      expected_cache="$HOME/.cache/zi"
      expected_config="$HOME/.config/zi"
      expected_layout=legacy
      ;;
    xdg-only)
      typeset -gx XDG_DATA_HOME="$case_root/data"
      command mkdir -p -- "$XDG_DATA_HOME/zi/plugins"
      expected_home="$XDG_DATA_HOME/zi"
      expected_cache="$HOME/.cache/zi"
      expected_config="$HOME/.config/zi"
      expected_layout=xdg
      ;;
    both-external)
      typeset -gx XDG_DATA_HOME="$case_root/data"
      command mkdir -p -- "$HOME/.zi/plugins" "$XDG_DATA_HOME/zi/plugins"
      expected_home="$HOME/.zi"
      expected_cache="$HOME/.cache/zi"
      expected_config="$HOME/.config/zi"
      expected_layout=ambiguous-legacy
      ;;
    both-legacy-source)
      typeset -gx XDG_DATA_HOME="$case_root/data"
      command mkdir -p -- "$HOME/.zi/bin" "$HOME/.zi/plugins" "$XDG_DATA_HOME/zi/plugins"
      command ln -s -- "$project_root/zi.zsh" "$HOME/.zi/bin/zi.zsh"
      command ln -s -- "$project_root/lib" "$HOME/.zi/bin/lib"
      ZI[BIN_DIR]="$HOME/.zi/bin"
      source_path="$HOME/.zi/bin/zi.zsh"
      expected_home="$HOME/.zi"
      expected_cache="$HOME/.cache/zi"
      expected_config="$HOME/.config/zi"
      expected_layout=ambiguous-legacy
      ;;
    both-xdg-source)
      typeset -gx XDG_DATA_HOME="$case_root/data"
      command mkdir -p -- "$HOME/.zi/plugins" "$XDG_DATA_HOME/zi/bin" "$XDG_DATA_HOME/zi/plugins"
      command ln -s -- "$project_root/zi.zsh" "$XDG_DATA_HOME/zi/bin/zi.zsh"
      command ln -s -- "$project_root/lib" "$XDG_DATA_HOME/zi/bin/lib"
      ZI[BIN_DIR]="$XDG_DATA_HOME/zi/bin"
      source_path="$XDG_DATA_HOME/zi/bin/zi.zsh"
      expected_home="$XDG_DATA_HOME/zi"
      expected_cache="$HOME/.cache/zi"
      expected_config="$HOME/.config/zi"
      expected_layout=ambiguous-xdg
      ;;
    *)
      fail "unknown case: $label"
      ;;
  esac

  builtin source "$source_path" >/dev/null || fail "$label source"
  assert_paths "$label" "$expected_home" "$expected_cache" "$expected_config" \
    "$expected_layout" "$expected_log" "$expected_zcompdump" "$expected_zpfx"

  if [[ $label == xdg-absolute ]]; then
    builtin source "$source_path" >/dev/null || fail "$label reload"
    assert_paths "$label reload" "$expected_home" "$expected_cache" "$expected_config" \
      "$expected_layout" "$expected_log" "$expected_zcompdump" "$expected_zpfx"
  fi

  case "$label" in
    explicit|xdg-absolute|xdg-unset|xdg-empty|xdg-relative)
      assert_private "$expected_home" "$label home permissions"
      assert_private "$expected_cache" "$label cache permissions"
      assert_private "$expected_config" "$label config permissions"
      assert_private "${expected_log:-${expected_cache}/log}" "$label log permissions"
      ;;
    xdg-existing-bases)
      assert_private "$expected_home" "$label home permissions"
      assert_private "$expected_cache" "$label cache permissions"
      assert_private "$expected_config" "$label config permissions"
      assert_private "${expected_log:-${expected_cache}/log}" "$label log permissions"
      assert_mode "$XDG_DATA_HOME" "$label data base" 8#755
      assert_mode "$XDG_CACHE_HOME" "$label cache base" 8#755
      assert_mode "$XDG_CONFIG_HOME" "$label config base" 8#755
      ;;
    legacy-only)
      assert_mode "$expected_home" "$label pre-existing legacy home" 8#755
      builtin source "$project_root/lib/zsh/autoload.zsh" >/dev/null || fail "$label autoload"
      status_output="$(.zi-show-zstatus)" || fail "$label zstatus"
      [[ $status_output == *'Legacy Zi home retained'* ]] || fail "$label migration hint"
      ;;
    both-*)
      builtin source "${ZI[BIN_DIR]}/lib/zsh/autoload.zsh" >/dev/null || fail "$label autoload"
      status_output="$(.zi-show-zstatus)" || fail "$label zstatus"
      [[ $status_output == *'Both legacy and XDG Zi homes were detected'* ]] || fail "$label ambiguity report"
      ;;
  esac

  if [[ $label == xdg-relative ]]; then
    [[ ! -e "$case_root/relative data" ]] || fail "$label created relative data root"
    [[ ! -e "$case_root/relative cache" ]] || fail "$label created relative cache root"
    [[ ! -e "$case_root/relative config" ]] || fail "$label created relative config root"
  fi
)

run_manpath_case() (
  builtin emulate -LR zsh
  setopt err_exit pipe_fail

  local label="$1" case_root="${temp_root}/manpath-$1"
  local custom_manpath="$case_root/custom-man" expected_manpath
  integer expected_count expected_export

  command mkdir -p -- \
    "$case_root/home" \
    "$case_root/zdotdir" \
    "$case_root/tmp" \
    "$case_root/zi-home/prefix/man/man1" \
    "$case_root/cache" \
    "$case_root/config"

  case "$label" in
    unset)
      expected_manpath="${case_root}/zi-home/prefix/man:"
      expected_count=2
      expected_export=0
      ;;
    export-only)
      expected_manpath="${case_root}/zi-home/prefix/man:"
      expected_count=2
      expected_export=1
      ;;
    assigned-empty)
      expected_manpath="${case_root}/zi-home/prefix/man:"
      expected_count=2
      expected_export=1
      ;;
    custom)
      expected_manpath="${case_root}/zi-home/prefix/man:${custom_manpath}"
      expected_count=2
      expected_export=1
      ;;
    default-first)
      expected_manpath="${case_root}/zi-home/prefix/man::${custom_manpath}"
      expected_count=3
      expected_export=1
      ;;
    default-last)
      expected_manpath="${case_root}/zi-home/prefix/man:${custom_manpath}:"
      expected_count=3
      expected_export=1
      ;;
    *)
      fail "unknown manpath case: $label"
      ;;
  esac

  command env -u MANPATH zsh -f -c '
    local project_root="$1" case_root="$2" label="$3"
    local expected_manpath="$4" custom_manpath="$case_root/custom-man"
    integer expected_count="$5" expected_export="$6"

    typeset -gx HOME="$case_root/home"
    typeset -gx ZDOTDIR="$case_root/zdotdir"
    typeset -gx TMPDIR="$case_root/tmp"
    unset XDG_DATA_HOME XDG_CACHE_HOME XDG_CONFIG_HOME
    unset ZPFX XDG_ZI_HOME XDG_ZI_CACHE XDG_ZI_CONFIG

    case "$label" in
      unset) ;;
      export-only) export MANPATH ;;
      assigned-empty) typeset -gx MANPATH="" ;;
      custom) typeset -gx MANPATH="$custom_manpath" ;;
      default-first) typeset -gx MANPATH=":${custom_manpath}" ;;
      default-last) typeset -gx MANPATH="${custom_manpath}:" ;;
    esac

    typeset -gAH ZI
    ZI=()
    ZI[BIN_DIR]="$project_root"
    ZI[HOME_DIR]="$case_root/zi-home"
    ZI[CACHE_DIR]="$case_root/cache"
    ZI[CONFIG_DIR]="$case_root/config"
    typeset -gx ZPFX="$case_root/zi-home/prefix"

    builtin source "$project_root/zi.zsh" >/dev/null || exit 11
    [[ $MANPATH == "$expected_manpath" ]] || {
      builtin print -u2 -r -- "not ok - $label MANPATH: expected ${(qqq)expected_manpath}, got ${(qqq)MANPATH}"
      exit 12
    }
    (( $#manpath == expected_count )) || {
      builtin print -u2 -r -- "not ok - $label manpath element count: expected $expected_count, got $#manpath"
      exit 13
    }
    if (( expected_export )); then
      [[ ${(t)MANPATH} == *export* ]] || exit 14
    else
      [[ ${(t)MANPATH} != *export* ]] || exit 15
    fi

    builtin source "$project_root/zi.zsh" >/dev/null || exit 16
    [[ $MANPATH == "$expected_manpath" ]] || exit 17
    (( $#manpath == expected_count )) || exit 18
  ' _ "$project_root" "$case_root" "$label" "$expected_manpath" "$expected_count" "$expected_export" || \
    fail "$label manpath resolution"
)

typeset case_name
for case_name in \
  explicit \
  xdg-absolute \
  xdg-existing-bases \
  xdg-unset \
  xdg-empty \
  xdg-relative \
  legacy-only \
  xdg-only \
  both-external \
  both-legacy-source \
  both-xdg-source; do
  run_case "$case_name"
  pass "$case_name path resolution"
done

for case_name in \
  unset \
  export-only \
  assigned-empty \
  custom \
  default-first \
  default-last; do
  run_manpath_case "$case_name"
  pass "$case_name manpath resolution"
done
