
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# Copyright (c) 2021 Salvydas Lukosius and Z-Shell Community.
# Distributed under the terms of the MIT License.

typeset -gx ZPFX PMSPEC=0fuUpiPsX
typeset -gaH ZI_REGISTERED_PLUGINS ZI_TASKS ZI_RUN
typeset -ga zsh_loaded_plugins
if (( !${#ZI_TASKS} )) { ZI_TASKS=( "<no-data>" ); }

# Rename snippets URL -> NAME.
typeset -gAH ZI ZI_SNIPPETS ZI_REPORTS ZI_ICES ZI_SICE ZI_CUR_BIND_MAP ZI_EXTS ZI_EXTS2
typeset -gaH ZI_COMPDEF_REPLAY

# Compatibility for previous versions.
typeset -gAH ZINIT
ZI=( "${(kv)ZINIT[@]}" "${(kv)ZI[@]}" )
unset ZINIT

# An ice-modifiers list.
ZI[ice-list]="svn|proto|from|teleid|bindmap|cloneopts|id-as|depth|if|wait|load|unload|blockf|pick|bpick|src|as|\
ver|silent|lucid|notify|mv|cp|atinit|atclone|atload|atpull|nocd|run-atpull|has|cloneonly|make|service|trackbinds|\
multisrc|compile|nocompile|nocompletions|reset-prompt|wrap|reset|sh|\!sh|bash|\!bash|ksh|\!ksh|csh|\!csh|aliases|\
countdown|ps-on-unload|ps-on-update|trigger-load|light-mode|is-snippet|atdelete|pack|git|verbose|on-update-of|\
subscribe|extract|param|opts|autoload|subst|install|pullopts|debug|null|binary"

# In no value value, i.e. not designed to hold value.
ZI[nval-ice-list]="blockf|silent|lucid|trackbinds|cloneonly|nocd|run-atpull|nocompletions|sh|\!sh|bash|\!bash|\
ksh|\!ksh|csh|\!csh|aliases|countdown|light-mode|is-snippet|git|verbose|cloneopts|pullopts|debug|null|binary|make|\
nocompile|reset"

# Subcommands list
ZI[cmd-list]="-h|--help|help|subcmds|icemods|analytics|man|self-update|times|zstatus|load|light|unload|\
snippet|ls|ice|update|status|report|delete|loaded|list|cd|create|edit|glance|stress|changes|recently|clist|completions|\
cclear|cdisable|cenable|creinstall|cuninstall|csearch|compinit|dtrace|dstart|dstop|dunload|dreport|dclear|compile|\
uncompile|compiled|cdlist|cdreplay|cdclear|srv|recall|env-whitelist|bindkeys|module|add-fpath|run"

# Establish ZI[BIN_DIR]
[[ ! -e ${ZI[BIN_DIR]}/zi.zsh ]] && ZI[BIN_DIR]=
ZI[ZERO]="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"

[[ ! -o functionargzero || ${options[posixargzero]} = on || ${ZI[ZERO]} != */* ]] && ZI[ZERO]="${(%):-%N}"
: ${ZI[BIN_DIR]:="${ZI[ZERO]:h}"}

[[ ${ZI[BIN_DIR]} = \~* ]] && ZI[BIN_DIR]=${~ZI[BIN_DIR]}
ZI[BIN_DIR]="${${(M)ZI[BIN_DIR]:#/*}:-$PWD/${ZI[BIN_DIR]}}"

# Check if ZI[BIN_DIR] is established correctly.
if [[ ! -e ${ZI[BIN_DIR]}/zi.zsh ]]; then
  builtin print -P "%F{196}Could not establish ZI[BIN_DIR] hash field. It should point where ❮ ZI ❯ Git repository is.%f"
  return 1
fi

# Establish ZI[HOME_DIR]
if [[ -z $ZI[HOME_DIR] ]]; then
  if [[ -d $HOME ]]; then
    ZI[HOME_DIR]="${HOME}/.zi"
  elif [[ -d $ZDOTDIR ]]; then
    ZI[HOME_DIR]="${ZDOTDIR}/.zi"
  elif [[ -d $XDG_DATA_HOME ]]; then
    ZI[HOME_DIR]="${XDG_DATA_HOME}/.zi"
  else
    ZI[HOME_DIR]="${HOME}/.zi"
  fi
fi

# Establish ZI[CACHE_DIR]
if [[ -z $ZI[CACHE_DIR] ]]; then
  if [[ -d ${HOME}/.cache ]]; then
    ZI[CACHE_DIR]="${HOME}/.cache/zi"
  elif [[ -d $XDG_CACHE_HOME ]]; then
    ZI[CACHE_DIR]="${XDG_CACHE_HOME}/zi"
  elif [[ -d ${ZDOTDIR}/.cache ]]; then
    ZI[CACHE_DIR]="${ZDOTDIR}/.cache/zi"
  elif [[ -d ${XDG_DATA_HOME}/.cache ]]; then
    ZI[CACHE_DIR]="${XDG_DATA_HOME}/.cache/zi"
  else
    ZI[CACHE_DIR]="${HOME}/.cache/zi"
  fi
fi

# Establish ZI[CONFIG_DIR]
if [[ -z $ZI[CONFIG_DIR] ]]; then
  if [[ -d ${HOME}/.config ]]; then
    ZI[CONFIG_DIR]="${HOME}/.config/zi"
  elif [[ -d $XDG_CONFIG_HOME ]]; then
    ZI[CONFIG_DIR]="${XDG_CONFIG_HOME}/zi"
  elif [[ -d ${XDG_DATA_HOME}/.config ]]; then
    ZI[CONFIG_DIR]="${XDG_DATA_HOME}/.config/zi"
  else
    ZI[CONFIG_DIR]="${HOME}/.config/zi"
  fi
fi

# Base Directory Specification
: ${ZPFX:=${ZI[HOME_DIR]}/polaris}
: ${ZI[MAN_DIR]:=${ZPFX}/man}
: ${ZI[LOG_DIR]:=${ZI[CACHE_DIR]}/log}
: ${ZI[THEMES_DIR]:=${ZI[HOME_DIR]}/themes}
: ${ZI[PLUGINS_DIR]:=${ZI[HOME_DIR]}/plugins}
: ${ZI[SNIPPETS_DIR]:=${ZI[HOME_DIR]}/snippets}
: ${ZI[SERVICES_DIR]:=${ZI[HOME_DIR]}/services}
: ${ZI[ZMODULES_DIR]:=${ZI[HOME_DIR]}/zmodules}
: ${ZI[ZCOMPDUMP_PATH]:=${ZI[CACHE_DIR]}/.zcompdump}
: ${ZI[COMPLETIONS_DIR]:=${ZI[HOME_DIR]}/completions}

# Base Directory Specification (XDG)
: ${XDG_ZI_HOME:=${ZI[HOME_DIR]}}
: ${XDG_ZI_CACHE:=${ZI[CACHE_DIR]}}
: ${XDG_ZI_CONFIG:=${ZI[CONFIG_DIR]}}

# Options Specification
: ${ZI[ALIASES_OPT]:=${${options[aliases]:#off}:+1}}
: ${ZI[PKG_OWNER]:=z-shell}

ZI[HOME_DIR]=${~ZI[HOME_DIR]}
ZI[MAN_DIR]=${~ZI[MAN_DIR]}
ZI[LOG_DIR]=${~ZI[LOG_DIR]}
ZI[CACHE_DIR]=${~ZI[CACHE_DIR]}
ZI[THEMES_DIR]=${~ZI[THEMES_DIR]}
ZI[CONFIG_DIR]=${~ZI[CONFIG_DIR]}
ZI[PLUGINS_DIR]=${~ZI[PLUGINS_DIR]}
ZI[SNIPPETS_DIR]=${~ZI[SNIPPETS_DIR]}
ZI[SERVICES_DIR]=${~ZI[SERVICES_DIR]}
ZI[ZMODULES_DIR]=${~ZI[ZMODULES_DIR]}
ZI[ZCOMPDUMP_PATH]=${~ZI[ZCOMPDUMP_PATH]}
ZI[COMPLETIONS_DIR]=${~ZI[COMPLETIONS_DIR]}

typeset -gx XDG_ZI_HOME=${~ZI[HOME_DIR]} ZPFX=${~ZPFX}
typeset -gx XDG_ZI_CACHE=${~ZI[CACHE_DIR]} XDG_ZI_CONFIG=${~ZI[CONFIG_DIR]}

[[ -z ${manpath[(re)${ZI[MAN_DIR]}]} ]] && manpath=( "${ZI[MAN_DIR]}" "${manpath[@]}" )
[[ -z ${path[(re)${ZPFX}/bin]} ]] && [[ -d "${ZPFX}/bin" ]] && path=( "${ZPFX}/bin" "${path[@]}" )
[[ -z ${path[(re)${ZPFX}/sbin]} ]] && [[ -d "${ZPFX}/sbin" ]] && path=( "${ZPFX}/sbin" "${path[@]}" )
[[ -z ${fpath[(re)${ZI[COMPLETIONS_DIR]}]} ]] && fpath=( "${ZI[COMPLETIONS_DIR]}" "${fpath[@]}" )

typeset -gU PATH path

ZI[UPAR]=";:^[[A;:^[OA;:\\e[A;:\\eOA;:${termcap[ku]/$'\e'/^\[};:${terminfo[kcuu1]/$'\e'/^\[};:"
ZI[DOWNAR]=";:^[[B;:^[OB;:\\e[B;:\\eOB;:${termcap[kd]/$'\e'/^\[};:${terminfo[kcud1]/$'\e'/^\[};:"
ZI[RIGHTAR]=";:^[[C;:^[OC;:\\e[C;:\\eOC;:${termcap[kr]/$'\e'/^\[};:${terminfo[kcuf1]/$'\e'/^\[};:"
ZI[LEFTAR]=";:^[[D;:^[OD;:\\e[D;:\\eOD;:${termcap[kl]/$'\e'/^\[};:${terminfo[kcub1]/$'\e'/^\[};:"

builtin autoload -Uz is-at-least
is-at-least 5.1 && ZI[NEW_AUTOLOAD]=1 || ZI[NEW_AUTOLOAD]=0
#is-at-least 5.4 && ZI[NEW_AUTOLOAD]=2

# Parameters - temporary substituting of functions. [[[
ZI[TMP_SUBST]=inactive   ZI[DTRACE]=0    ZI[CUR_PLUGIN]=
# ]]]
# Parameters - ICE. [[[
declare -gA ZI_1MAP ZI_2MAP
ZI_1MAP=(
  OMZ:: https://github.com/ohmyzsh/ohmyzsh/trunk/
  OMZP:: https://github.com/ohmyzsh/ohmyzsh/trunk/plugins/
  OMZT:: https://github.com/ohmyzsh/ohmyzsh/trunk/themes/
  OMZL:: https://github.com/ohmyzsh/ohmyzsh/trunk/lib/
  PZT:: https://github.com/sorin-ionescu/prezto/trunk/
  PZTM:: https://github.com/sorin-ionescu/prezto/trunk/modules/
)
ZI_2MAP=(
  OMZ:: https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/
  OMZP:: https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/
  OMZT:: https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/themes/
  OMZL:: https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/lib/
  PZT:: https://raw.githubusercontent.com/sorin-ionescu/prezto/master/
  PZTM:: https://raw.githubusercontent.com/sorin-ionescu/prezto/master/modules/
)
# ]]]
# Initiate. [[[
zmodload zsh/zutil || { builtin print -P "%F{196}zsh/zutil module is required, aborting ❮ ZI ❯ set up.%f"; return 1; }
zmodload zsh/parameter || { builtin print -P "%F{196}zsh/parameter module is required, aborting ❮ ZI ❯ set up.%f"; return 1; }
zmodload zsh/terminfo 2>/dev/null
zmodload zsh/termcap 2>/dev/null

# Terminal color codes.
if [[ -z $SOURCED && ( ${+terminfo} -eq 1 && -n ${terminfo[colors]} ) || ( ${+termcap} -eq 1 && -n ${termcap[Co]} ) ]] {
  ZI+=(
  col-annex   $'\e[38;5;165m'      col-info    $'\e[38;5;82m'       col-p       $'\e[38;5;81m'
  col-apo     $'\e[1;38;5;220m'    col-info2   $'\e[38;5;220m'      col-pkg     $'\e[1;3;38;5;27m'
  col-b       $'\e[1m'             col-info3   $'\e[1m\e[38;5;220m' col-pname   $'\e[1;4m\e[32m'
  col-aps     $'\e[38;5;117m'      col-baps    $'\e[1;38;5;82m'     col-pre     $'\e[38;5;93m'
  col-bar     $'\e[38;5;82m'       col-bcmd    $'\e[38;5;220m'      col-profile $'\e[38;5;201m'
  col-bspc    $'\b'                col-bapo    $'\e[1;39;5;220m'    col-keyword $'\e[32m'
  col-b-lhi   $'\e[1m\e[38;5;27m'  col-lhi     $'\e[38;5;33m'       col-slight  $'\e[38;5;230m'
  col-b-warn  $'\e[1;38;5;214m'    col-msg     $'\e[0m'             col-st      $'\e[9m'
  col-cmd     $'\e[38;5;82m'       col-msg2    $'\e[38;5;172m'      col-tab     $' \t '
  col-data    $'\e[38;5;82m'       col-msg3    $'\e[38;5;238m'      col-term    $'\e[38;5;190m'
  col-data2   $'\e[38;5;39m'       col-meta    $'\e[38;5;50m'       col-th-bar  $'\e[38;5;82m'
  col-dir     $'\e[3;38;5;135m'    col-meta2   $'\e[38;5;135m'      col-txt     $'\e[38;5;254m'
  col-ehi     $'\e[1m\e[38;5;210m' col-nb      $'\e[22m'            col-u       $'\e[4m'
  col-error   $'\e[1m\e[38;5;204m' col-nit     $'\e[23m'            col-uname   $'\e[1;4m\e[35m'
  col-failure $'\e[38;5;204m'      col-nl      $'\n'                col-uninst  $'\e[38;5;118m'
  col-faint   $'\e[38;5;240m'      col-note    $'\e[38;5;148m'      col-url     $'\e[38;5;33m'
  col-file    $'\e[3;38;5;39m'     col-nst     $'\e[29m'            col-u-warn  $'\e[4;38;5;214m'
  col-func    $'\e[38;5;135m'      col-nu      $'\e[24m'            col-var     $'\e[38;5;39m'
  col-flag    $'\e[1;3;38;5;79m'   col-it      $'\e[3m'             col-quo     $'\e[1;38;5;33m'
  col-glob    $'\e[38;5;226m'      col-num     $'\e[3;38;5;154m'    col-version $'\e[3;38;5;46m'
  col-happy   $'\e[1m\e[38;5;82m'  col-obj     $'\e[38;5;218m'      col-warn    $'\e[38;5;214m'
  col-hi      $'\e[1m\e[38;5;165m' col-obj2    $'\e[38;5;118m'      col-dbg     $'\e[90m'
  col-ice     $'\e[38;5;39m'       col-ok      $'\e[38;5;220m'      col-rst     $'\e[0m'
  col-id-as   $'\e[4;38;5;220m'    col-opt     $'\e[38;5;82m'       col-time    $'\e[38;5;220m'
  col-quos    $'\e[1;38;5;160m'
  col-mdsh    $'\e[1;38;5;220m'"${${${(M)LANG:#*UTF-8*}:+–}:--}"$'\e[0m'
  col-mmdsh   $'\e[1;38;5;220m'"${${${(M)LANG:#*UTF-8*}:+――}:--}"$'\e[0m'
  col-↔     ${${${(M)LANG:#*UTF-8*}:+$'\e[38;5;82m↔\e[0m'}:-$'\e[38;5;82m«-»\e[0m'}
  col-…     "${${${(M)LANG:#*UTF-8*}:+…}:-...}"  col-ndsh  "${${${(M)LANG:#*UTF-8*}:+–}:-}"
  col--…    "${${${(M)LANG:#*UTF-8*}:+⋯⋯}:-···}" col-lr    "${${${(M)LANG:#*UTF-8*}:+↔}:-"«-»"}"
  )
  if [[ ( ${+terminfo} -eq 1 && ${terminfo[colors]} -ge 256 ) || ( ${+termcap} -eq 1 && ${termcap[Co]} -ge 256 ) ]] {
    ZI+=( col-pname $'\e[1;4m\e[38;5;39m' col-uname  $'\e[1;4m\e[38;5;207m' )
  }
}

# List of hooks.
typeset -gAH ZI_ZLE_HOOKS_LIST
ZI_ZLE_HOOKS_LIST=(
  zle-isearch-exit 1
  zle-isearch-update 1
  zle-line-pre-redraw 1
  zle-line-init 1
  zle-line-finish 1
  zle-history-line-set 1
  zle-keymap-select 1
  paste-insert 1
)

builtin setopt noaliases

# ]]]

#
# Temporary substituting of functions-related functions.
#

# FUNCTION: :zi-reload-and-run. [[[
# Marks given function ($3) for autoloading, and executes it triggering the load.
# $1 is the fpath dedicated  to the function, $2 are autoload options. This function replaces "autoload -X",
# because using that on older Zsh versions causes problems with traps.
#
# So basically one creates function stub that calls :zi-reload-and-run() instead of "autoload -X".
#
# $1 - FPATH dedicated to function
# $2 - autoload options
# $3 - function name (one that needs autoloading)
#
# Author: Bart Schaefer
:zi-reload-and-run () {
  local fpath_prefix="$1" autoload_opts="$2" func="$3"
  shift 3
  # Unfunction caller function (its name is given).
  unfunction -- "$func"
  local -a ___fpath
  ___fpath=( ${fpath[@]} )
  local -a +h fpath
  [[ $FPATH != *${${(@0)fpath_prefix}[1]}* ]] && fpath=( ${(@0)fpath_prefix} ${___fpath[@]} )
  # After this the function exists again.
  builtin autoload ${(s: :)autoload_opts} -- "$func"
  # User wanted to call the function, not only load it.
  "$func" "$@"
} # ]]]
# FUNCTION: :zi-tmp-subst-autoload. [[[
# Function defined to hijack plugin's calls to the `autoload' builtin.
#
# The hijacking is not only to gather report data, but also to.
# run custom `autoload' function, that doesn't need FPATH.
:zi-tmp-subst-autoload () {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal typesetsilent rcquotes

  local -a opts opts2 custom reply
  local func

  zparseopts -D -E -M -a opts ${(s::):-RTUXdkmrtWzwC} I+=opts2 S+:=custom

  builtin set -- ${@:#--}

  # Process the id-as''/teleid'' to get the plugin dir.
  .zi-any-to-user-plugin $ZI[CUR_USPL2]
  [[ $reply[1] = % ]] && local PLUGIN_DIR="$reply[2]" || \
  local PLUGIN_DIR="$ZI[PLUGINS_DIR]/${reply[1]:+$reply[1]---}${reply[2]//\//---}"
  # "Fpath elements" - ie those elements that are inside the plug-in directory.
  # The name comes from the fact that they are the selected fpath elements → so just "items".
  local -a fpath_elements
  fpath_elements=( ${fpath[(r)$PLUGIN_DIR/*]} )
  # Add a function subdirectory to items, if any (this action is according to the Plug Standard version 1.07 and later).
  [[ -d $PLUGIN_DIR/functions ]] && fpath_elements+=( "$PLUGIN_DIR"/functions )
  if (( ${+opts[(r)-X]} )); then
    .zi-add-report "${ZI[CUR_USPL2]}" "Warning: Failed autoload ${(j: :)opts[@]} $*"
    +zi-message -u2 "{error}builtin autoload required for {obj}${(j: :)opts[@]}{error} option(s)"
    return 1
  fi
  if (( ${+opts[(r)-w]} )); then
    .zi-add-report "${ZI[CUR_USPL2]}" "-w-Autoload ${(j: :)opts[@]} ${(j: :)@}"
    fpath+=( $PLUGIN_DIR )
    builtin autoload ${opts[@]} "$@"
    return $?
  fi
  if [[ -n ${(M)@:#+X} ]]; then
    .zi-add-report "${ZI[CUR_USPL2]}" "Autoload +X ${opts:+${(j: :)opts[@]} }${(j: :)${@:#+X}}"
    local +h FPATH=$PLUGINS_DIR${fpath_elements:+:${(j.:.)fpath_elements[@]}}:$FPATH
    local +h -a fpath
    fpath=( $PLUGIN_DIR $fpath_elements $fpath )
    builtin autoload +X ${opts[@]} "${@:#+X}"
    return $?
  fi
  for func; do
    .zi-add-report "${ZI[CUR_USPL2]}" "Autoload $func${opts:+ with options ${(j: :)opts[@]}}"
  done

  integer count retval
  for func; do
    # Real autoload doesn't touch function if it already exists.
    # Author of the idea of FPATH-clean autoloading: Bart Schaefer.
    if (( ${+functions[$func]} != 1 )) {
      builtin setopt noaliases
      if [[ $func == /* ]] && is-at-least 5.4; then
        builtin autoload ${opts[@]} $func
        return $?
      elif [[ $func == /* ]]; then
        if [[ $ZI[MUTE_WARNINGS] != (1|true|on|yes) && -z $ZI[WARN_SHOWN_FOR_$ZI[CUR_USPL2]] ]]; then
          +zi-message "{u-warn}Warning{b-warn}: {rst}the plugin {pid}$ZI[CUR_USPL2]" \
            "{rst}is using autoload functions specified by their absolute path," \
            "which is not supported by this Zsh version ({↔} {version}$ZSH_VERSION{rst}," \
            "required is Zsh >= {version}5.4{rst})." "{nl}A fallback mechanism has been applied, which works well only" \
            "for functions in the plugin {u}{slight}main{rst} directory." "{nl}(To mute this message, set" \
            "{var}\$ZI[MUTE_WARNINGS]{rst} to a truth value.)"
          ZI[WARN_SHOWN_FOR_$ZI[CUR_USPL2]]=1
        fi
        # Apply workaround
        func=$func:t
      fi
      if [[ ${ZI[NEW_AUTOLOAD]} = 2 ]]; then
        builtin autoload ${opts[@]} "$PLUGIN_DIR/$func"
        retval=$?
      elif [[ ${ZI[NEW_AUTOLOAD]} = 1 ]]; then
        if (( ${+opts[(r)-C]} )) {
          local pth nl=$'\n' sel=""
          for pth ( $PLUGIN_DIR $fpath_elements $fpath ) {
            [[ -f $pth/$func ]] && { sel=$pth; break; }
          }
          if [[ -z $sel ]] {
            +zi-message "{u-warn}zi{b-warn}:{error} Couldn't find autoload function{ehi}:" \
            "{apo}\`{file}${func}{apo}\`{error} anywhere in {var}\$fpath{error}."
            retval=1
          } else {
            eval "function ${(q)${custom[++count*2]}:-$func} {
              local body=\"\$(<${(qqq)sel}/${(qqq)func})\" body2
              () { builtin setopt localoptions extendedglob
                body2=\"\${body##[[:space:]]#${func}[[:blank:]]#\(\)[[:space:]]#\{}\"
                [[ \$body2 != \$body ]] && body2=\"\${body2%\}[[:space:]]#([$nl]#([[:blank:]]#\#[^$nl]#((#e)|[$nl]))#)#}\"
              }
              functions[${${(q)custom[count*2]}:-$func}]=\"\$body2\"
              ${(q)${custom[count*2]}:-$func} \"\$@\"
            }"
            retval=$?
          }
        } else {
          eval "function ${(q)func} {
            local -a fpath
            fpath=( ${(qqq)PLUGIN_DIR} ${(qqq@)fpath_elements} ${(qqq@)fpath} )
            builtin autoload -X ${(j: :)${(q-)opts[@]}}
          }"
          retval=$?
        }
      else
        eval "function ${(q)func} {
          :zi-reload-and-run ${(qqq)PLUGIN_DIR}"$'\0'"${(pj,\0,)${(qqq)fpath_elements[@]}} ${(qq)opts[*]} ${(q)func} "'"$@"
        }'
        retval=$?
      fi
      (( ZI[ALIASES_OPT] )) && builtin setopt aliases
    }
    if (( ${+opts2[(r)-I]} )) {
      ${custom[count*2]:-$func}
      retval=$?
    }
  done

  return $retval
} # ]]]
# FUNCTION: :zi-tmp-subst-bindkey. [[[
# Function defined to hijack plugin's calls to the `bindkey' builtin.
#
# The hijacking is to gather report data (which is used in unload).
:zi-tmp-subst-bindkey() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal typesetsilent noshortloops

  is-at-least 5.3 && .zi-add-report "${ZI[CUR_USPL2]}" "Bindkey ${(j: :)${(q+)@}}" || .zi-add-report "${ZI[CUR_USPL2]}" "Bindkey ${(j: :)${(q)@}}"

  # Remember to perform the actual bindkey call.
  typeset -a pos
  pos=( "$@" )

  # Check if we have regular bindkey call, i.e. with no options or with -s, plus possible -M option.
  local -A opts
  zparseopts -A opts -D ${(s::):-lLdDAmrsevaR} M: N:

  if (( ${#opts} == 0 || ( ${#opts} == 1 && ${+opts[-M]} ) || ( ${#opts} == 1 && ${+opts[-R]} ) || ( ${#opts} == 1 && ${+opts[-s]} ) || ( ${#opts} <= 2 && ${+opts[-M]} && ${+opts[-s]} ) || ( ${#opts} <= 2 && ${+opts[-M]} && ${+opts[-R]} ) )); then
    local string="${(q)1}" widget="${(q)2}"
    local quoted

    if [[ -n ${ICE[bindmap]} && ${ZI_CUR_BIND_MAP[empty]} -eq 1 ]]; then
      local -a pairs
      pairs=( "${(@s,;,)ICE[bindmap]}" )
      if [[ -n ${(M)pairs:#*\\(#e)} ]] {
        local prev
        pairs=( ${pairs[@]//(#b)((*)\\(#e)|(*))/${match[3]:+${prev:+$prev\;}}${match[3]}${${prev::=${match[2]:+${prev:+$prev\;}}${match[2]}}:+}} )
      }
      pairs=( "${(@)${(@)${(@s:->:)pairs}##[[:space:]]##}%%[[:space:]]##}" )
      ZI_CUR_BIND_MAP=( empty 0 )
      (( ${#pairs} > 1 && ${#pairs[@]} % 2 == 0 )) && ZI_CUR_BIND_MAP+=( "${pairs[@]}" )
    fi

    local bmap_val="${ZI_CUR_BIND_MAP[${1}]}"
    if (( !ZI_CUR_BIND_MAP[empty] )) {
      [[ -z $bmap_val ]] && bmap_val="${ZI_CUR_BIND_MAP[${(qqq)1}]}"
      [[ -z $bmap_val ]] && bmap_val="${ZI_CUR_BIND_MAP[${(qqq)${(Q)1}}]}"
      [[ -z $bmap_val ]] && { bmap_val="${ZI_CUR_BIND_MAP[!${(qqq)1}]}"; integer val=1; }
      [[ -z $bmap_val ]] && bmap_val="${ZI_CUR_BIND_MAP[!${(qqq)${(Q)1}}]}"
    }
    if [[ -n $bmap_val ]]; then
      string="${(q)bmap_val}"
      if (( val )) {
        [[ ${pos[1]} = "-M" ]] && pos[4]="$bmap_val" || pos[2]="$bmap_val"
      } else {
        [[ ${pos[1]} = "-M" ]] && pos[3]="${(Q)bmap_val}" || pos[1]="${(Q)bmap_val}"
      }
      .zi-add-report "${ZI[CUR_USPL2]}" ":::Bindkey: combination <$1> changed to <$bmap_val>${${(M)bmap_val:#hold}:+, i.e. ${ZI[col-error]}unmapped${ZI[col-rst]}}"
      ((1))
    elif [[ ( -n ${bmap_val::=${ZI_CUR_BIND_MAP[UPAR]}} && -n ${${ZI[UPAR]}[(r);:${(q)1};:]} ) || \
    ( -n ${bmap_val::=${ZI_CUR_BIND_MAP[DOWNAR]}} && -n ${${ZI[DOWNAR]}[(r);:${(q)1};:]} ) || \
    ( -n ${bmap_val::=${ZI_CUR_BIND_MAP[RIGHTAR]}} && -n ${${ZI[RIGHTAR]}[(r);:${(q)1};:]} ) || \
    ( -n ${bmap_val::=${ZI_CUR_BIND_MAP[LEFTAR]}} && -n ${${ZI[LEFTAR]}[(r);:${(q)1};:]} )
    ]]; then
      string="${(q)bmap_val}"
      if (( val )) {
        [[ ${pos[1]} = "-M" ]] && pos[4]="$bmap_val" || pos[2]="$bmap_val"
      } else {
        [[ ${pos[1]} = "-M" ]] && pos[3]="${(Q)bmap_val}" || pos[1]="${(Q)bmap_val}"
      }
      .zi-add-report "${ZI[CUR_USPL2]}" ":::Bindkey: combination <$1> recognized as cursor-key and changed to <${bmap_val}>${${(M)bmap_val:#hold}:+, i.e. ${ZI[col-error]}unmapped${ZI[col-rst]}}"
    fi
    [[ $bmap_val = hold ]] && return 0

    local prev="${(q)${(s: :)$(builtin bindkey ${(Q)string})}[-1]#undefined-key}"

  # "-M map" given?
  if (( ${+opts[-M]} )); then
      local Mopt=-M
      local Marg="${opts[-M]}"
      Mopt="${(q)Mopt}"
      Marg="${(q)Marg}"
      quoted="$string $widget $prev $Mopt $Marg"
    else
      quoted="$string $widget $prev"
    fi
    # -R given?
    if (( ${+opts[-R]} )); then
      local Ropt=-R
      Ropt="${(q)Ropt}"
      if (( ${+opts[-M]} )); then
        quoted="$quoted $Ropt"
      else
        # Two empty fields for non-existent -M arg.
        local space=_
        space="${(q)space}"
        quoted="$quoted $space $space $Ropt"
      fi
    fi
    quoted="${(q)quoted}"
    # Remember the bindkey, only when load is in progress (it can be dstart that leads execution here).
    [[ -n ${ZI[CUR_USPL2]} ]] && ZI[BINDKEYS__${ZI[CUR_USPL2]}]+="$quoted "
    # Remember for dtrace.
    [[ ${ZI[DTRACE]} = 1 ]] && ZI[BINDKEYS___dtrace/_dtrace]+="$quoted "
  else
    # bindkey -A newkeymap main?
    # Negative indices for KSH_ARRAYS immunity.
    if [[ ${#opts} -eq 1 && ${+opts[-A]} = 1 && ${#pos} = 3 && ${pos[-1]} = main && ${pos[-2]} != -A ]]; then
      # Save a copy of main keymap.
      (( ZI[BINDKEY_MAIN_IDX] = ${ZI[BINDKEY_MAIN_IDX]:-0} + 1 ))
      local pname="${ZI[CUR_PLUGIN]:-_dtrace}"
      local name="${(q)pname}-main-${ZI[BINDKEY_MAIN_IDX]}"
      builtin bindkey -N "$name" main
      # Remember occurence of main keymap substitution, to revert on unload.
      local keys=_ widget=_ prev= optA=-A mapname="${name}" optR=_
      local quoted="${(q)keys} ${(q)widget} ${(q)prev} ${(q)optA} ${(q)mapname} ${(q)optR}"
      quoted="${(q)quoted}"
      # Remember the bindkey, only when load is in progress (it can be dstart that leads execution here).
      [[ -n ${ZI[CUR_USPL2]} ]] && ZI[BINDKEYS__${ZI[CUR_USPL2]}]+="$quoted "
      [[ ${ZI[DTRACE]} = 1 ]] && ZI[BINDKEYS___dtrace/_dtrace]+="$quoted "
      .zi-add-report "${ZI[CUR_USPL2]}" "Warning: keymap \`main' copied to \`${name}' because of \`${pos[-2]}' substitution"
    # bindkey -N newkeymap [other].
    elif [[ ${#opts} -eq 1 && ${+opts[-N]} = 1 ]]; then
      local Nopt=-N
      local Narg="${opts[-N]}"
      local keys=_ widget=_ prev= optN=-N mapname="${Narg}" optR=_
      local quoted="${(q)keys} ${(q)widget} ${(q)prev} ${(q)optN} ${(q)mapname} ${(q)optR}"
      quoted="${(q)quoted}"
      # Remember the bindkey, only when load is in progress (it can be dstart that leads execution here).
      [[ -n ${ZI[CUR_USPL2]} ]] && ZI[BINDKEYS__${ZI[CUR_USPL2]}]+="$quoted "
      [[ ${ZI[DTRACE]} = 1 ]] && ZI[BINDKEYS___dtrace/_dtrace]+="$quoted "
    else
      .zi-add-report "${ZI[CUR_USPL2]}" "Warning: last bindkey used non-typical options: ${(kv)opts[*]}"
    fi
  fi
  # Actual bindkey.
  builtin bindkey "${pos[@]}"
  return $? # testable
} # ]]]
# FUNCTION: :zi-tmp-subst-zstyle. [[[
# Function defined to hijack plugin's calls to the `zstyle' builtin.
#
# The hijacking is to gather report data (which is used in unload).
:zi-tmp-subst-zstyle() {
  builtin setopt localoptions noerrreturn noerrexit extendedglob nowarncreateglobal typesetsilent noshortloops unset
  .zi-add-report "${ZI[CUR_USPL2]}" "Zstyle $*"
  # Remember in order to perform the actual zstyle call.
  typeset -a pos
  pos=( "$@" )
  # Check if we have regular zstyle call, i.e. with no options or with -e.
  local -a opts
  zparseopts -a opts -D ${(s::):-eLdgabsTtm}
  if [[ ${#opts} -eq 0 || ( ${#opts} -eq 1 && ${+opts[(r)-e]} = 1 ) ]]; then
    # Have to quote $1, then $2, then concatenate them, then quote them again.
    local pattern="${(q)1}" style="${(q)2}"
    local ps="$pattern $style"
    ps="${(q)ps}"
    # Remember the zstyle, only when load is in progress (it can be dstart that leads execution here).
    [[ -n ${ZI[CUR_USPL2]} ]] && ZI[ZSTYLES__${ZI[CUR_USPL2]}]+="$ps "
    # Remember for dtrace.
    [[ ${ZI[DTRACE]} = 1 ]] && ZI[ZSTYLES___dtrace/_dtrace]+=$ps
  else
    if [[ ! ${#opts[@]} = 1 && ( ${+opts[(r)-s]} = 1 || ${+opts[(r)-b]} = 1 || ${+opts[(r)-a]} = 1 || ${+opts[(r)-t]} = 1 || ${+opts[(r)-T]} = 1 || ${+opts[(r)-m]} = 1 ) ]]; then
      .zi-add-report "${ZI[CUR_USPL2]}" "Warning: last zstyle used non-typical options: ${opts[*]}"
    fi
  fi
  # Actual zstyle.
  builtin zstyle "${pos[@]}"
  return $? # testable
} # ]]]
# FUNCTION: :zi-tmp-subst-alias. [[[
# Function defined to hijack plugin's calls to the `alias' builtin.
#
# The hijacking is to gather report data (which is used in unload).
:zi-tmp-subst-alias() {
  builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset
  .zi-add-report "${ZI[CUR_USPL2]}" "Alias $*"
  # Remember to perform the actual alias call.
  typeset -a pos
  pos=( "$@" )
  local -a opts
  zparseopts -a opts -D ${(s::):-gs}
  local a quoted tmp
  for a in "$@"; do
    local aname="${a%%[=]*}"
    local avalue="${a#*=}"
    # Check if alias is to be redefined.
    (( ${+aliases[$aname]} )) && .zi-add-report "${ZI[CUR_USPL2]}" "Warning: redefining alias \`${aname}', previous value: ${aliases[$aname]}"
    local bname=${(q)aliases[$aname]}
    aname="${(q)aname}"
    if (( ${+opts[(r)-s]} )); then
      tmp=-s
      tmp="${(q)tmp}"
      quoted="$aname $bname $tmp"
    elif (( ${+opts[(r)-g]} )); then
      tmp=-g
      tmp="${(q)tmp}"
      quoted="$aname $bname $tmp"
    else
      quoted="$aname $bname"
    fi
    quoted="${(q)quoted}"
    # Remember the alias, only when load is in progress (it can be dstart that leads execution here).
    [[ -n ${ZI[CUR_USPL2]} ]] && ZI[ALIASES__${ZI[CUR_USPL2]}]+="$quoted "
    # Remember for dtrace.
    [[ ${ZI[DTRACE]} = 1 ]] && ZI[ALIASES___dtrace/_dtrace]+="$quoted "
  done
  # Actual alias.
  builtin alias "${pos[@]}"
  return $? # testable
} # ]]]
# FUNCTION: :zi-tmp-subst-zle. [[[.
# Function defined to hijack plugin's calls to the `zle' builtin.
#
# The hijacking is to gather report data (which is used in unload).
:zi-tmp-subst-zle() {
  builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset
  .zi-add-report "${ZI[CUR_USPL2]}" "Zle $*"
  # Remember to perform the actual zle call.
  typeset -a pos
  pos=( "$@" )
  builtin set -- "${@:#--}"
  # Try to catch game-changing "-N".
  if [[ ( $1 = -N && ( $# = 2 || $# = 3 ) ) || ( $1 = -C && $# = 4 ) ]]; then
    # Hooks.
    if [[ ${ZI_ZLE_HOOKS_LIST[$2]} = 1 ]]; then
      local quoted="$2"
      quoted="${(q)quoted}"
      # Remember only when load is in progress (it can be dstart that leads execution here).
      [[ -n ${ZI[CUR_USPL2]} ]] && ZI[WIDGETS_DELETE__${ZI[CUR_USPL2]}]+="$quoted "
      # Remember for dtrace.
      [[ ${ZI[DTRACE]} = 1 ]] && ZI[WIDGETS_DELETE___dtrace/_dtrace]+="$quoted "
    # These will be saved and restored.
    elif (( ${+widgets[$2]} )); then
      # Have to remember original widget "$2" and the copy that it's going to be done.
      local widname="$2" targetfun="${${${(M)1:#-C}:+$4}:-$3}"
      local completion_widget="${${(M)1:#-C}:+$3}"
      local saved_widcontents="${widgets[$widname]}"
      widname="${(q)widname}"
      completion_widget="${(q)completion_widget}"
      targetfun="${(q)targetfun}"
      saved_widcontents="${(q)saved_widcontents}"
      local quoted="$1 $widname $completion_widget $targetfun $saved_widcontents"
      quoted="${(q)quoted}"
      # Remember only when load is in progress (it can be dstart that leads execution here).
      [[ -n ${ZI[CUR_USPL2]} ]] && ZI[WIDGETS_SAVED__${ZI[CUR_USPL2]}]+="$quoted "
      # Remember for dtrace.
      [[ ${ZI[DTRACE]} = 1 ]] && ZI[WIDGETS_SAVED___dtrace/_dtrace]+="$quoted "
    # These will be deleted.
    else
      .zi-add-report "${ZI[CUR_USPL2]}" "Note: a new widget created via zle -N: \`$2'"
      local quoted="$2"
      quoted="${(q)quoted}"
      # Remember only when load is in progress (it can be dstart that leads execution here).
      [[ -n ${ZI[CUR_USPL2]} ]] && ZI[WIDGETS_DELETE__${ZI[CUR_USPL2]}]+="$quoted "
      # Remember for dtrace.
      [[ ${ZI[DTRACE]} = 1 ]] && ZI[WIDGETS_DELETE___dtrace/_dtrace]+="$quoted "
    fi
  fi

  # Actual zle.
  builtin zle "${pos[@]}"
  return $? # testable
} # ]]]
# FUNCTION: :zi-tmp-subst-compdef. [[[
# Function defined to hijack plugin's calls to the `compdef' function.
# The hijacking is not only for reporting, but also to save compdef
# calls so that `compinit' can be called after loading plugins.
:zi-tmp-subst-compdef() {
  builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset
  .zi-add-report "${ZI[CUR_USPL2]}" "Saving \`compdef $*' for replay"
  ZI_COMPDEF_REPLAY+=( "${(j: :)${(q)@}}" )

  return 0 # testable
} # ]]]
# FUNCTION: .zi-tmp-subst-on. [[[
# Turn on temporary substituting of functions of builtins and functions according to passed
# mode ("load", "light", "light-b" or "compdef"). The temporary substituting of functions is
# to gather report data, and to hijack `autoload', `bindkey' and `compdef' calls.
.zi-tmp-subst-on() {
  local mode="$1"
  # Enable temporary substituting of functions only once.
  #
  # One could expect possibility of widening of temporary substituting of functions, however
  # such sequence doesn't exist, e.g. "light" then "load"/"dtrace", "compdef" then "load"/
  # "dtrace", "light" then "compdef", "compdef" then "light".
  #
  # It is always "dtrace" then "load" (i.e. dtrace then load) "dtrace" then "light" (i.e.:
  # dtrace then light load) "dtrace" then "compdef" (i.e.: dtrace then snippet).
  [[ ${ZI[TMP_SUBST]} != inactive ]] && builtin return 0
  ZI[TMP_SUBST]="$mode"
  # The point about backuping is: does the key exist in functions array.
  # If it does exist, then it will also exist as ZI[bkp-*]. Defensive code, shouldn't be needed.
  builtin unset "ZI[bkp-autoload]" "ZI[bkp-compdef]"  # 0, E.
  if [[ $mode != compdef ]]; then
    # 0. Used, but not in temporary restoration, which doesn't happen for autoload.
    (( ${+functions[autoload]} )) && ZI[bkp-autoload]="${functions[autoload]}"
    functions[autoload]=':zi-tmp-subst-autoload "$@";'
  fi
  # E. Always shade compdef.
  (( ${+functions[compdef]} )) && ZI[bkp-compdef]="${functions[compdef]}"
  functions[compdef]=':zi-tmp-subst-compdef "$@";'
  # Temporarily replace `source' if subst'' given.
  if [[ -n ${ICE[subst]} ]] {
    (( ${+functions[source]} )) && ZI[bkp-source]="${functions[source]}"
    (( ${+functions[.]} )) && ZI[bkp-.]="${functions[.]}"
    (( ${+functions[.zi-service]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/additional.zsh"
    functions[source]=':zi-tmp-subst-source "$@";'
    functions[.]=':zi-tmp-subst-source "$@";'
  }
  # Light and compdef temporary substituting of functions stops here. Dtrace and load go on.
  [[ ( $mode = light && ${+ICE[trackbinds]} -eq 0 ) || $mode = compdef ]] && return 0
  # Defensive code, shouldn't be needed. A, B, C, D.
  builtin unset "ZI[bkp-bindkey]" "ZI[bkp-zstyle]" "ZI[bkp-alias]" "ZI[bkp-zle]"
  # A.
  (( ${+functions[bindkey]} )) && ZI[bkp-bindkey]="${functions[bindkey]}"
  functions[bindkey]=':zi-tmp-subst-bindkey "$@";'
  # B, when `zi light -b ...' or when `zi ice trackbinds ...; zi light ...'.
  [[ $mode = light-b || ( $mode = light && ${+ICE[trackbinds]} -eq 1 ) ]] && return 0
  # B.
  (( ${+functions[zstyle]} )) && ZI[bkp-zstyle]="${functions[zstyle]}"
  functions[zstyle]=':zi-tmp-subst-zstyle "$@";'
  # C.
  (( ${+functions[alias]} )) && ZI[bkp-alias]="${functions[alias]}"
  functions[alias]=':zi-tmp-subst-alias "$@";'
  # D.
  (( ${+functions[zle]} )) && ZI[bkp-zle]="${functions[zle]}"
  functions[zle]=':zi-tmp-subst-zle "$@";'
  builtin return 0
} # ]]]
# FUNCTION: .zi-tmp-subst-off. [[[
# Turn off temporary substituting of functions completely for a given mode ("load", "light",
# "light-b" (i.e. the `trackbinds' mode) or "compdef").
.zi-tmp-subst-off() {
  builtin setopt localoptions noerrreturn noerrexit extendedglob warncreateglobal typesetsilent noshortloops unset noaliases
  local mode="$1"
  # Disable temporary substituting of functions only once.
  # Disable temporary substituting of functions only the way it was enabled first.
  [[ ${ZI[TMP_SUBST]} = inactive || ${ZI[TMP_SUBST]} != $mode ]] && return 0
  ZI[TMP_SUBST]=inactive
  if [[ $mode != compdef ]]; then
    # 0. Unfunction autoload.
    (( ${+ZI[bkp-autoload]} )) && functions[autoload]="${ZI[bkp-autoload]}" || unfunction autoload
  fi
  # E. Restore original compdef if it existed.
  (( ${+ZI[bkp-compdef]} )) && functions[compdef]="${ZI[bkp-compdef]}" || unfunction compdef
  # Restore the possible source function.
  (( ${+ZI[bkp-source]} )) && functions[source]="${ZI[bkp-source]}" || unfunction source 2>/dev/null
  (( ${+ZI[bkp-.]} )) && functions[.]="${ZI[bkp-.]}" || unfunction . 2> /dev/null
  # Light and compdef temporary substituting of functions stops here.
  [[ ( $mode = light && ${+ICE[trackbinds]} -eq 0 ) || $mode = compdef ]] && return 0
  # Unfunction temporary substituting of functions functions.
  # A.
  (( ${+ZI[bkp-bindkey]} )) && functions[bindkey]="${ZI[bkp-bindkey]}" || unfunction bindkey
  # When `zi light -b ...' or when `zi ice trackbinds ...; zi light ...'.
  [[ $mode = light-b || ( $mode = light && ${+ICE[trackbinds]} -eq 1 ) ]] && return 0
  # B.
  (( ${+ZI[bkp-zstyle]} )) && functions[zstyle]="${ZI[bkp-zstyle]}" || unfunction zstyle
  # C.
  (( ${+ZI[bkp-alias]} )) && functions[alias]="${ZI[bkp-alias]}" || unfunction alias
  # D.
  (( ${+ZI[bkp-zle]} )) && functions[zle]="${ZI[bkp-zle]}" || unfunction zle
  return 0
} # ]]]
# FUNCTION: pmodload. [[[
# {function:pmodload} Compatibility with Prezto. Calls can be recursive.
(( ${+functions[pmodload]} )) || pmodload() {
  local -A ices
  (( ${+ICE} )) && ices=( "${(kv)ICE[@]}" teleid '' )
  local -A ICE ZI_ICE
  ICE=( "${(kv)ices[@]}" ) ZI_ICE=( "${(kv)ices[@]}" )
  while (( $# )); do
    ICE[teleid]="PZT::modules/$1${ICE[svn]-/init.zsh}"
    ZI_ICE[teleid]="PZT::modules/$1${ICE[svn]-/init.zsh}"
    if zstyle -t ":prezto:module:$1" loaded 'yes' 'no'; then
      shift
      continue
    else
      [[ -z ${ZI_SNIPPETS[PZT::modules/$1${ICE[svn]-/init.zsh}]} && -z ${ZI_SNIPPETS[https://github.com/sorin-ionescu/prezto/trunk/modules/$1${ICE[svn]-/init.zsh}]} ]] && .zi-load-snippet PZT::modules/"$1${ICE[svn]-/init.zsh}"
      shift
    fi
  done
} # ]]]

#
# Diff functions.
#

# FUNCTION: .zi-diff-functions. [[[
# Implements detection of newly created functions. Performs data gathering, computation is done in *-compute().
#
# $1 - user/plugin (i.e. uspl2 format)
# $2 - command, can be "begin" or "end"
.zi-diff-functions() {
  local uspl2="$1"
  local cmd="$2"
  [[ $cmd = begin ]] && { [[ -z ${ZI[FUNCTIONS_BEFORE__$uspl2]} ]] && ZI[FUNCTIONS_BEFORE__$uspl2]="${(j: :)${(qk)functions[@]}}" } || ZI[FUNCTIONS_AFTER__$uspl2]+=" ${(j: :)${(qk)functions[@]}}"
} # ]]]
# FUNCTION: .zi-diff-options. [[[
# Implements detection of change in option state. Performs data gathering, computation is done in *-compute().
#
# $1 - user/plugin (i.e. uspl2 format)
# $2 - command, can be "begin" or "end"
.zi-diff-options() {
  local IFS=" "
  [[ $2 = begin ]] && { [[ -z ${ZI[OPTIONS_BEFORE__$uspl2]} ]] && ZI[OPTIONS_BEFORE__$1]="${(kv)options[@]}" } || ZI[OPTIONS_AFTER__$1]+=" ${(kv)options[@]}"
} # ]]]
# FUNCTION: .zi-diff-env. [[[
# Implements detection of change in PATH and FPATH.
#
# $1 - user/plugin (i.e. uspl2 format)
# $2 - command, can be "begin" or "end"
.zi-diff-env() {
  typeset -a tmp
  local IFS=" "
  [[ $2 = begin ]] && {
    { [[ -z ${ZI[PATH_BEFORE__$uspl2]} ]] && tmp=( "${(q)path[@]}" )
      ZI[PATH_BEFORE__$1]="${tmp[*]}"
    }
    { [[ -z ${ZI[FPATH_BEFORE__$uspl2]} ]] && tmp=( "${(q)fpath[@]}" )
      ZI[FPATH_BEFORE__$1]="${tmp[*]}"
    }
  } || {
    tmp=( "${(q)path[@]}" )
    ZI[PATH_AFTER__$1]+=" ${tmp[*]}"
    tmp=( "${(q)fpath[@]}" )
    ZI[FPATH_AFTER__$1]+=" ${tmp[*]}"
  }
} # ]]]
# FUNCTION: .zi-diff-parameter. [[[
# Implements detection of change in any parameter's existence and type.
# Performs data gathering, computation is done in *-compute().
#
# $1 - user/plugin (i.e. uspl2 format)
# $2 - command, can be "begin" or "end"
.zi-diff-parameter() {
  typeset -a tmp
  [[ $2 = begin ]] && {
  { [[ -z ${ZI[PARAMETERS_BEFORE__$uspl2]} ]] && ZI[PARAMETERS_BEFORE__$1]="${(j: :)${(qkv)parameters[@]}}"; }
  } || {
    ZI[PARAMETERS_AFTER__$1]+=" ${(j: :)${(qkv)parameters[@]}}"
  }
} # ]]]
# FUNCTION: .zi-diff. [[[
# Performs diff actions of all types
.zi-diff() {
  .zi-diff-functions "$1" "$2"
  .zi-diff-options "$1" "$2"
  .zi-diff-env "$1" "$2"
  .zi-diff-parameter "$1" "$2"
} # ]]]

#
# Utility functions.
#

# FUNCTION: .zi-get-mtime-into. [[[
.zi-get-mtime-into() {
  if (( ZI[HAVE_ZSTAT] )) {
    local -a arr
    { zstat +mtime -A arr "$1"; } 2>/dev/null
    : ${(P)2::="${arr[1]}"}
  } else {
    { : ${(P)2::="$(stat -c %Y "$1")"}; } 2>/dev/null
  }
} # ]]]
# FUNCTION: .zi-any-to-user-plugin. [[[
# Allows elastic plugin-spec across the code.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
#
# Returns user and plugin in $reply.
#
.zi-any-to-user-plugin() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob typesetsilent noshortloops rcquotes ${${${+reply}:#0}:+warncreateglobal}
  # Two components given?
  # That's a pretty fast track to call this function this way.
  if [[ -n $2 ]]; then
    2=${~2}
    reply=( ${1:-${${(M)2#/}:+%}} ${${${(M)1#%}:+$2}:-${2//---//}} )
    return 0
  fi
  # Is it absolute path?
  if [[ $1 = /* ]]; then
    reply=( % $1 )
    return 0
  fi
  # Is it absolute path in zi format?
  if [[ $1 = %* ]]; then
    local -A map
    map=( ZPFX "$ZPFX" HOME $HOME SNIPPETS $ZI[SNIPPETS_DIR] PLUGINS $ZI[PLUGINS_DIR] )
    reply=( % ${${1/(#b)(#s)%(${(~j:|:)${(@k)map}}|)/$map[$match[1]]}} )
    reply[2]=${~reply[2]}
    return 0
  fi
  # Rest is for single component given.
  # It doesn't touch $2
  1=${1//---//}
  if [[ $1 = */* ]]; then
    reply=( ${1%%/*} ${1#*/} )
    return 0
  fi
  reply=( "" "${1:-_unknown}" )
  return 0
} # ]]]
# FUNCTION: .zi-any-to-pid. [[[
.zi-any-to-pid() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob typesetsilent noshortloops rcquotes ${${${+REPLY}:#0}:+warncreateglobal}

  1=${~1} 2=${~2}

  # Two components given?
  if [[ -n $2 ]] {
  if [[ $1 == (%|/)* || ( -z $1 && $2 == /* ) ]] {
    .zi-util-shands-path $1${${(M)1#(%/?|%[^/]|/?)}:+/}$2
    REPLY=${${REPLY:#%*}:+%}$REPLY
  } else {
    REPLY=$1${1:+/}$2
  }
    return 0
  }
  # Is it absolute path?
  if [[ $1 = (%|/|\~)* ]] {
    .zi-util-shands-path $1
    REPLY=${${REPLY:#%*}:+%}$REPLY
    return 0
  }
  # Single component given.
  REPLY=${1//---//}

  return 0
} # ]]]
# FUNCTION: .zi-util-shands-path. [[[
# Replaces parts of path with %HOME, etc.
.zi-util-shands-path() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob typesetsilent noshortloops rcquotes ${${${+REPLY}:#0}:+warncreateglobal}

  local -A map
  map=( \~ %HOME $HOME %HOME $ZI[SNIPPETS_DIR] %SNIPPETS $ZI[PLUGINS_DIR] %PLUGINS
    "$ZPFX" %ZPFX HOME %HOME SNIPPETS %SNIPPETS PLUGINS %PLUGINS "" "" )
  REPLY=${${1/(#b)(#s)(%|)(${(~j:|:)${(@k)map:#$HOME}}|$HOME|)/$map[$match[2]]}}
  return 0
} # ]]]
# FUNCTION: .zi-find-other-matches. [[[
# Plugin's main source file is in general `name.plugin.zsh'. However,
# there can be different conventions, if that file is not found, then
# this functions examines other conventions in the most sane order.
.zi-find-other-matches() {
  local pdir_path="$1" pbase="$2"

  if [[ -e $pdir_path/init.zsh ]] {
    reply=( "$pdir_path"/init.zsh )
  } elif [[ -e $pdir_path/$pbase.zsh-theme ]] {
    reply=( "$pdir_path/$pbase".zsh-theme )
  } elif [[ -e $pdir_path/$pbase.theme.zsh ]] {
    reply=( "$pdir_path/$pbase".theme.zsh )
  } else {
    reply=(
      "$pdir_path"/*.plugin.zsh(DN) "$pdir_path"/*.zsh-theme(DN) "$pdir_path"/*.lib.zsh(DN)
      "$pdir_path"/*.zsh(DN) "$pdir_path"/*.sh(DN) "$pdir_path"/.zshrc(DN)
    )
  }
  reply=( "${(u)reply[@]}" )

  return $(( ${#reply} > 0 ? 0 : 1 ))
} # ]]]
# FUNCTION: .zi-register-plugin. [[[
# Adds the plugin to ZI_REGISTERED_PLUGINS array and to the
# zsh_loaded_plugins array (managed according to the plugin standard:
# https://z.digitalclouds.dev/community/zsh_plugin_standard).
.zi-register-plugin() {
  local uspl2="$1" mode="$2" teleid="$3"
  integer ret=0
  if [[ -z ${ZI_REGISTERED_PLUGINS[(r)$uspl2]} ]]; then
    ZI_REGISTERED_PLUGINS+=( "$uspl2" )
  else
    # Allow overwrite-load, however warn about it.
    [[ -z ${ZI[TEST]}${${+ICE[wait]}:#0}${ICE[load]}${ICE[subscribe]} && ${ZI[MUTE_WARNINGS]} != (1|true|on|yes) ]] && +zi-message "{u-warn}Warning{b-warn}:{rst} plugin {apo}\`{pid}${uspl2}{apo}\`{rst} already registered, will overwrite-load."
    ret=1
  fi
  # Support Zsh plugin standard.
  zsh_loaded_plugins+=( "$teleid" )
  # Full or light load?
  [[ $mode == light ]] && ZI[STATES__$uspl2]=1 || ZI[STATES__$uspl2]=2
  ZI_REPORTS[$uspl2]=             ZI_CUR_BIND_MAP=( empty 1 )
  # Functions.
  ZI[FUNCTIONS_BEFORE__$uspl2]=  ZI[FUNCTIONS_AFTER__$uspl2]=
  ZI[FUNCTIONS__$uspl2]=
  # Objects.
  ZI[ZSTYLES__$uspl2]=           ZI[BINDKEYS__$uspl2]=
  ZI[ALIASES__$uspl2]=
  # Widgets.
  ZI[WIDGETS_SAVED__$uspl2]=     ZI[WIDGETS_DELETE__$uspl2]=
  # Rest (options and (f)path).
  ZI[OPTIONS__$uspl2]=           ZI[PATH__$uspl2]=
  ZI[OPTIONS_BEFORE__$uspl2]=    ZI[OPTIONS_AFTER__$uspl2]=
  ZI[FPATH__$uspl2]=
  return ret
} # ]]]
# FUNCTION: .zi-get-object-path. [[[
.zi-get-object-path() {
  local type="$1" id_as="$2" local_dir dirname
  integer exists
  id_as="${ICE[id-as]:-$id_as}"
  # Remove leading whitespace and trailing /.
  id_as="${${id_as#"${id_as%%[! $'\t']*}"}%/}"
  for type ( ${=${${(M)type:#AUTO}:+snippet plugin}:-$type} ) {
    if [[ $type == snippet ]] {
      dirname="${${id_as%%\?*}:t}"
      local_dir="${${${id_as%%\?*}/:\/\//--}:h}"
      [[ $local_dir = . ]] && local_dir= || local_dir="${${${${${local_dir#/}//\//--}//=/-EQ-}//\?/-QM-}//\&/-AMP-}"
      local_dir="${ZI[SNIPPETS_DIR]}${local_dir:+/$local_dir}"
    } else {
      .zi-any-to-user-plugin "$id_as"
      local_dir=${${${(M)reply[-2]:#%}:+${reply[2]}}:-${ZI[PLUGINS_DIR]}/${id_as//\//---}}
      [[ $id_as == _local/* && -d $local_dir && ! -d $local_dir/._zi ]] && command mkdir -p "$local_dir"/._zi
      dirname=""
    }
    [[ -e $local_dir/${dirname:+$dirname/}._zi || -e $local_dir/${dirname:+$dirname/}._zplugin ]] && exists=1
    (( exists )) && break
  }
  reply=( "$local_dir" "$dirname" "$exists" )
  REPLY="$local_dir${dirname:+/$dirname}"

  return $(( 1 - exists ))
} # ]]]
# FUNCTION: @zi-substitute. [[[
@zi-substitute() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal typesetsilent noshortloops
  local -A ___subst_map
  ___subst_map=(
    "%ID%"   "${id_as_clean:-$id_as}"
    "%USER%" "$user"
    "%PLUGIN%" "${plugin:-$save_url}"
    "%URL%" "${save_url:-${user:+$user/}$plugin}"
    "%DIR%" "${local_path:-$local_dir${dirname:+/$dirname}}"
    '$ZPFX' "$ZPFX"
    '${ZPFX}' "$ZPFX"
    '%OS%' "${OSTYPE%(-gnu|[0-9]##)}" '%MACH%' "$MACHTYPE" '%CPU%' "$CPUTYPE"
    '%VENDOR%' "$VENDOR" '%HOST%' "$HOST" '%UID%' "$UID" '%GID%' "$GID"
  )
  if [[ -n ${ICE[param]} && ${ZI[SUBST_DONE_FOR]} != ${ICE[param]} ]] {
    ZI[SUBST_DONE_FOR]=${ICE[param]}
    ZI[PARAM_SUBST]=
    local -a ___params
    ___params=( ${(s.;.)ICE[param]} )
    local ___param ___from ___to
    for ___param ( ${___params[@]} ) {
      local ___from=${${___param%%([[:space:]]|)(->|→)*}##[[:space:]]##} ___to=${${___param#*(->|→)([[:space:]]|)}%[[:space:]]}
      ___from=${___from//((#s)[[:space:]]##|[[:space:]]##(#e))/}
      ___to=${___to//((#s)[[:space:]]##|[[:space:]]##(#e))/}
      ZI[PARAM_SUBST]+="%${(q)___from}% ${(q)___to} "
    }
  }
  local -a ___add
  ___add=( "${ICE[param]:+${(@Q)${(@z)ZI[PARAM_SUBST]}}}" )
  (( ${#___add} % 2 == 0 )) && ___subst_map+=( "${___add[@]}" )
  local ___var_name
  for ___var_name; do
    local ___value=${(P)___var_name}
    ___value=${___value//(#m)(%[a-zA-Z0-9]##%|\$ZPFX|\$\{ZPFX\})/${___subst_map[$MATCH]}}
    : ${(P)___var_name::=$___value}
  done
} # ]]]
# FUNCTION: @zi-register-annex. [[[
# Registers the z-annex inside ZI – i.e. an ZI extension
@zi-register-annex() {
  local name="$1" type="$2" handler="$3" helphandler="$4" icemods="$5" key="z-annex ${(q)2}"
  ZI_EXTS[seqno]=$(( ${ZI_EXTS[seqno]:-0} + 1 ))
  ZI_EXTS[$key${${(M)type#hook:}:+ ${ZI_EXTS[seqno]}}]="${ZI_EXTS[seqno]} z-annex-data: ${(q)name} ${(q)type} ${(q)handler} ${(q)helphandler} ${(q)icemods}"
  () {
    builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
    integer index="${type##[%a-zA-Z:_!-]##}"
    ZI_EXTS[ice-mods]="${ZI_EXTS[ice-mods]}${icemods:+|}${(j:|:)${(@)${(@s:|:)icemods}/(#b)(#s)(?)/$index-$match[1]}}"
  }
} # ]]]
# FUNCTION: @zi-register-hook. [[[
# Registers the z-annex inside Zi.
@zi-register-hook() {
    builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
    builtin setopt extendedglob nobanghist noshortloops typesetsilent warncreateglobal
  local name="$1" type="$2" handler="$3" icemods="$4" key="zi ${(q)2}"
  ZI_EXTS2[seqno]=$(( ${ZI_EXTS2[seqno]:-0} + 1 ))
  ZI_EXTS2[$key${${(M)type#hook:}:+ ${ZI_EXTS2[seqno]}}]="${ZI_EXTS2[seqno]} z-annex-data: ${(q)name} ${(q)type} ${(q)handler} '' ${(q)icemods}"
  ZI_EXTS2[ice-mods]="${ZI_EXTS2[ice-mods]}${icemods:+|}$icemods"
} # ]]]
# FUNCTION: @zsh-plugin-run-on-update. [[[
# The Plugin Standard required mechanism, see:
# https://z.digitalclouds.dev/community/zsh_plugin_standard
@zsh-plugin-run-on-unload() {
  ICE[ps-on-unload]="${(j.; .)@}"
  .zi-pack-ice "$id_as" ""
} # ]]]
# FUNCTION: @zsh-plugin-run-on-update. [[[
# The Plugin Standard required mechanism
@zsh-plugin-run-on-update() {
  ICE[ps-on-update]="${(j.; .)@}"
  .zi-pack-ice "$id_as" ""
} # ]]]

# Remaining functions.

# FUNCTION: .zi-prepare-home. [[[
# Establish all required directories.
.zi-prepare-home() {
  [[ -n ${ZI[HOME_READY]} ]] && return
  ZI[HOME_READY]=1
  if [[ ! -d ${ZI[HOME_DIR]} ]]; then
    command mkdir -p "${ZI[HOME_DIR]}"
    command chmod go-w "${ZI[HOME_DIR]}"
  fi
  # Set up $ZPFX
  if [[ ! -d ${ZPFX}/bin ]]; then
    command mkdir -p "${ZPFX}/bin"
  fi
  if [[ ! -d ${ZPFX}/sbin ]]; then
    command mkdir -p "${ZPFX}/sbin"
  fi
  if [[ ! -d ${ZPFX}/lib ]]; then
    command mkdir -p "${ZPFX}/lib"
    command chmod go-w "${ZPFX}/lib"
  fi
  if [[ ! -d ${ZPFX}/share ]]; then
    command mkdir -p "${ZPFX}/share"
    command chmod go-w "${ZPFX}/share"
  fi
  if [[ ! -d ${ZI[MAN_DIR]} ]]; then
    command mkdir 2>/dev/null -p ${~ZI[MAN_DIR]}/man{1..9}
    command chmod -R go-w "${ZI[MAN_DIR]}"
  fi
  if [[ ! -d ${ZI[CACHE_DIR]} ]]; then
    command mkdir -p "${ZI[CACHE_DIR]}"
    command chmod go-w "${ZI[CACHE_DIR]}"
  fi
  if [[ ! -d ${ZI[CONFIG_DIR]} ]]; then
    command mkdir -p "${ZI[CONFIG_DIR]}"
    command chmod go-w "${ZI[CONFIG_DIR]}"
  fi
  if [[ ! -d ${ZI[LOG_DIR]} ]]; then
    command mkdir -p "${ZI[LOG_DIR]}"
    command chmod go-w "${ZI[LOG_DIR]}"
  fi
  if [[ ! -d ${ZI[ZMODULES_DIR]} ]]; then
    command mkdir -p "${ZI[ZMODULES_DIR]}"
    command chmod go-w "${ZI[ZMODULES_DIR]}"
  fi
  if [[ ! -d ${ZI[PLUGINS_DIR]}/_local---zi ]]; then
    command rm -rf "${ZI[PLUGINS_DIR]:-${TMPDIR:-/tmp}/132bcaCAB}/_local---zi"
    command mkdir -p "${ZI[PLUGINS_DIR]}/_local---zi"
    command chmod go-w "${ZI[PLUGINS_DIR]}"
    command ln -s "${ZI[BIN_DIR]}/lib/_zi" "${ZI[PLUGINS_DIR]}/_local---zi"
    (( ${+functions[.zi-setup-plugin-dir]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
    (( ${+functions[.zi-confirm]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/autoload.zsh" || return 1
    .zi-clear-completions &>/dev/null
    .zi-compinit &>/dev/null
  fi
  if [[ ! -d ${ZI[COMPLETIONS_DIR]} ]]; then
    command mkdir "${ZI[COMPLETIONS_DIR]}"
    command chmod go-w "${ZI[COMPLETIONS_DIR]}"
    # Symlink _zi completion into _local---zi directory.
    command ln -s "${ZI[PLUGINS_DIR]}/_local---zi/_zi" "${ZI[COMPLETIONS_DIR]}"
    (( ${+functions[.zi-setup-plugin-dir]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
    .zi-compinit &>/dev/null
  fi
  if [[ ! -d ${ZI[SNIPPETS_DIR]} ]]; then
    command mkdir -p "${ZI[SNIPPETS_DIR]}/OMZ::plugins"
    command chmod go-w "${ZI[SNIPPETS_DIR]}"
    ( builtin cd ${ZI[SNIPPETS_DIR]}; command ln -s OMZ::plugins plugins; )
    command mkdir -p "${ZI[SERVICES_DIR]}"
    command chmod go-w "${ZI[SERVICES_DIR]}"
  fi
} # ]]]
# FUNCTION: .zi-load-object. [[[
.zi-load-object() {
  local ___type="$1" ___id=$2
  local -a ___opt
  ___opt=( ${@[3,-1]} )
  if [[ $___type == snippet ]] {
    .zi-load-snippet $___opt "$___id"
  } elif [[ $___type == plugin ]] {
    .zi-load "$___id" "" $___opt
  }
  ___retval+=$?
  return __retval
} # ]]]
# FUNCTION:.zi-set-m-func() [[[
# Sets and withdraws the temporary, atclone/atpull time function `m`.
.zi-set-m-func() {
  if [[ $1 == set ]]; then
    ZI[___m_bkp]="${functions[m]}"
    builtin setopt noaliases
    functions[m]="${functions[+zi-message]}"
    builtin setopt aliases
  elif [[ $1 == unset ]]; then
    if [[ -n ${ZI[___m_bkp]} ]]; then
      builtin setopt noaliases
      functions[m]="${ZI[___m_bkp]}"
      builtin setopt aliases
    else
      noglob unset functions[m]
    fi
  else
    +zi-message "{error}ERROR #1"
    return 1
  fi
} # ]]]
# FUNCTION: .zi-load-snippet. [[[
# Implements the exposed-to-user action of loading a snippet.
#
# $1 - url (can be local, absolute path).
.zi-load-snippet() {
  typeset -F 3 SECONDS=0
  local -a opts
  zparseopts -E -D -a opts f -command || { +zi-message "{u-warn}Error{b-warn}:{rst} Incorrect options (accepted ones: {opt}-f{rst}, {opt}--command{rst})."; return 1; }
  local url="$1"
  [[ -n ${ICE[teleid]} ]] && url="${ICE[teleid]}"
  # Hide arguments from sourced scripts. Without this calls our "$@" are visible as "$@" within scripts that we `source`.
  builtin set --
  integer correct retval exists
  [[ -o ksharrays ]] && correct=1
  [[ -n ${ICE[(i)(\!|)(sh|bash|ksh|csh)]}${ICE[opts]} ]] && {
    local -a precm
    precm=(
      builtin emulate
      ${${(M)${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:+-R}
      ${${${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:-zsh}
      ${${ICE[(i)(\!|)bash]}:+-${(s: :):-o noshglob -o braceexpand -o kshglob}}
      ${(s: :):-${${:-${(@s: :):--o}" "${(s: :)^ICE[opts]}}:#-o }}
      -c
    )
  }
  # Remove leading whitespace and trailing /.
  url="${${url#"${url%%[! $'\t']*}"}%/}"
  ICE[teleid]="${ICE[teleid]:-$url}"
  [[ ${ICE[as]} = null || ${+ICE[null]} -eq 1 || ${+ICE[binary]} -eq 1 ]] && ICE[pick]="${ICE[pick]:-/dev/null}"
  local local_dir dirname filename save_url="$url"
  # Allow things like $OSTYPE in the URL.
  eval "url=\"$url\""
  local id_as="${ICE[id-as]:-$url}"
  .zi-set-m-func set
  # Set up param'' objects (parameters).
  if [[ -n ${ICE[param]} ]] {
    .zi-setup-params && local ${(Q)reply[@]}
  }
  .zi-pack-ice "$id_as" ""
  # Oh-My-Zsh, Prezto and manual shorthands.
  [[ $url = *(${(~kj.|.)${(Mk)ZI_1MAP:#OMZ*}}|robbyrussell*oh-my-zsh|ohmyzsh/ohmyzsh)* ]] && local ZSH="${ZI[SNIPPETS_DIR]}"
  # Construct containing directory, extract final directory
  # into handy-variable $dirname.
  .zi-get-object-path snippet "$id_as"
  filename="${reply[-2]}" dirname="${reply[-2]}"
  local_dir="${reply[-3]}" exists=${reply[-1]}
  local -a arr
  local key
  reply=(
    ${(on)ZI_EXTS2[(I)zi hook:preinit-pre <->]}
    ${(on)ZI_EXTS[(I)z-annex hook:preinit-<-> <->]}
    ${(on)ZI_EXTS2[(I)zi hook:preinit-post <->]}
  )
  for key in "${reply[@]}"; do
    arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
    "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zi|z-annex) hook:}%% <->}" load || return $(( 10 - $? ))
  done
  # Download or copy the file.
  if [[ -n ${opts[(r)-f]} || $exists -eq 0 ]] {
    (( ${+functions[.zi-download-snippet]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
    .zi-download-snippet "$save_url" "$url" "$id_as" "$local_dir" "$dirname" "$filename"
    retval=$?
  }
  (( ${+ICE[cloneonly]} || retval )) && return 0
  ZI_SNIPPETS[$id_as]="$id_as <${${ICE[svn]+svn}:-single file}>"
  ZI[CUR_USPL2]="$id_as" ZI_REPORTS[$id_as]=
  reply=( ${(on)ZI_EXTS[(I)z-annex hook:\!atinit-<-> <->]} )
  for key in "${reply[@]}"; do
    arr=( "${(Q)${(z@)ZI_EXTS[$key]}[@]}" )
    "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" \!atinit || return $(( 10 - $? ))
  done
  (( ${+ICE[atinit]} )) && { local ___oldcd="$PWD"; (( ${+ICE[nocd]} == 0 )) && { () { builtin setopt localoptions noautopushd; builtin cd -q "$local_dir/$dirname"; } && eval "${ICE[atinit]}"; ((1)); } || eval "${ICE[atinit]}"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; }
  reply=( ${(on)ZI_EXTS[(I)z-annex hook:atinit-<-> <->]} )
  for key in "${reply[@]}"; do
    arr=( "${(Q)${(z@)ZI_EXTS[$key]}[@]}" )
    "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" atinit || \
      return $(( 10 - $? ))
  done
  local -a list
  local ZERO
  if [[ -z ${opts[(r)--command]} && ( -z ${ICE[as]} || ${ICE[as]} = null || ${+ICE[null]} -eq 1 || ${+ICE[binary]} -eq 1 ) ]]; then
    # Source the file with compdef temporary substituting of functions.
    if [[ ${ZI[TMP_SUBST]} = inactive ]]; then
      # Temporary substituting of functions code is inlined from .zi-tmp-subst-on.
      (( ${+functions[compdef]} )) && ZI[bkp-compdef]="${functions[compdef]}" || builtin unset "ZI[bkp-compdef]"
      functions[compdef]=':zi-tmp-subst-compdef "$@";'
      ZI[TMP_SUBST]=1
    else
      (( ++ ZI[TMP_SUBST] ))
    fi

    # Add to fpath.
    if [[ -d $local_dir/$dirname/functions ]] {
      [[ -z ${fpath[(r)$local_dir/$dirname/functions]} ]] && fpath+=( "$local_dir/$dirname/functions" )
      () {
        builtin setopt localoptions extendedglob
        autoload $local_dir/$dirname/functions/^([_.]*|prompt_*_setup|README*)(D-.N:t)
      }
    }
    # Source.
    if (( ${+ICE[svn]} == 0 )) {
      [[ ${+ICE[pick]} = 0 ]] && list=( "$local_dir/$dirname/$filename" )
      [[ -n ${ICE[pick]} ]] && list=( ${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN) )
    } else {
      if [[ -n ${ICE[pick]} ]]; then
        list=( ${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN) )
      elif (( ${+ICE[pick]} == 0 )); then
        .zi-find-other-matches "$local_dir/$dirname" "$filename"
        list=( ${reply[@]} )
      fi
    }
    if [[ -f ${list[1-correct]} ]] {
      ZERO="${list[1-correct]}"
      (( ${+ICE[silent]} )) && { { [[ -n $precm ]] && { builtin ${precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); builtin source "$ZERO"; }; } 2>/dev/null 1>&2; (( retval += $? )); ((1)); } || { ((1)); { [[ -n $precm ]] && { builtin ${precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); builtin source "$ZERO"; }; }; (( retval += $? )); }
      (( 0 == retval )) && [[ $url = PZT::* || $url = https://github.com/sorin-ionescu/prezto/* ]] && zstyle ":prezto:module:${${id_as%/init.zsh}:t}" loaded 'yes'
    } else { [[ ${+ICE[silent]} -eq 1 || ${+ICE[pick]} -eq 1 && -z ${ICE[pick]} || ${ICE[pick]} = /dev/null ]] || { +zi-message "Snippet not loaded ({url}${id_as}{rst})"; retval=1; } }
    [[ -n ${ICE[src]} ]] && { ZERO="${${(M)ICE[src]##/*}:-$local_dir/$dirname/${ICE[src]}}"; (( ${+ICE[silent]} )) && { { [[ -n $precm ]] && { builtin ${precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); builtin source "$ZERO"; }; } 2>/dev/null 1>&2; (( retval += $? )); ((1)); } || { ((1)); { [[ -n $precm ]] && { builtin ${precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); builtin source "$ZERO"; }; }; (( retval += $? )); }; }
    [[ -n ${ICE[multisrc]} ]] && { local ___oldcd="$PWD"; () { builtin setopt localoptions noautopushd; builtin cd -q "$local_dir/$dirname"; }; eval "reply=(${ICE[multisrc]})"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; local fname; for fname in "${reply[@]}"; do ZERO="${${(M)fname:#/*}:-$local_dir/$dirname/$fname}"; (( ${+ICE[silent]} )) && { { [[ -n $precm ]] && { builtin ${precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); builtin source "$ZERO"; }; } 2>/dev/null 1>&2; (( retval += $? )); ((1)); } || { ((1)); { [[ -n $precm ]] && { builtin ${precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); builtin source "$ZERO"; }; }; (( retval += $? )); }; done; }
    # Run the atload hooks right before atload ice.
    reply=( ${(on)ZI_EXTS[(I)z-annex hook:\!atload-<-> <->]} )
    for key in "${reply[@]}"; do
      arr=( "${(Q)${(z@)ZI_EXTS[$key]}[@]}" )
      "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" \!atload
    done
    # Run the functions' wrapping & tracking requests.
    if [[ -n ${ICE[wrap]} ]] {
      (( ${+functions[.zi-service]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/additional.zsh"
      .zi-wrap-functions "$save_url" "" "$id_as"
    }
    [[ ${ICE[atload][1]} = "!" ]] && { .zi-add-report "$id_as" "Note: Starting to track the atload'!…' ice…"; ZERO="$local_dir/$dirname/-atload-"; local ___oldcd="$PWD"; (( ${+ICE[nocd]} == 0 )) && { () { builtin setopt localoptions noautopushd; builtin cd -q "$local_dir/$dirname"; } && builtin eval "${ICE[atload]#\!}"; ((1)); } || eval "${ICE[atload]#\!}"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; }
    (( -- ZI[TMP_SUBST] == 0 )) && { ZI[TMP_SUBST]=inactive; builtin setopt noaliases; (( ${+ZI[bkp-compdef]} )) && functions[compdef]="${ZI[bkp-compdef]}" || unfunction compdef; (( ZI[ALIASES_OPT] )) && builtin setopt aliases; }
  elif [[ -n ${opts[(r)--command]} || ${ICE[as]} = command ]]; then
    [[ ${+ICE[pick]} = 1 && -z ${ICE[pick]} ]] && ICE[pick]="${id_as:t}"
    # Subversion - directory and multiple files possible.
    if (( ${+ICE[svn]} )); then
      if [[ -n ${ICE[pick]} ]]; then
        list=( ${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN) )
        [[ -n ${list[1-correct]} ]] && local xpath="${list[1-correct]:h}" xfilepath="${list[1-correct]}"
      else
        local xpath="$local_dir/$dirname"
      fi
    else
      local xpath="$local_dir/$dirname" xfilepath="$local_dir/$dirname/$filename"
      # This doesn't make sense, but users may come up with something.
      [[ -n ${ICE[pick]} ]] && {
        list=( ${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN) )
        [[ -n ${list[1-correct]} ]] && xpath="${list[1-correct]:h}" xfilepath="${list[1-correct]}"
      }
    fi
    [[ -n $xpath && -z ${path[(er)$xpath]} ]] && path=( "${xpath%/}" ${path[@]} )
    [[ -n $xfilepath && -f $xfilepath && ! -x "$xfilepath" ]] && command chmod a+x "$xfilepath" ${list[@]:#$xfilepath}
    [[ -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
      if [[ ${ZI[TMP_SUBST]} = inactive ]]; then
        # Temporary substituting of functions code is inlined from .zi-tmp-subst-on.
        (( ${+functions[compdef]} )) && ZI[bkp-compdef]="${functions[compdef]}" || builtin unset "ZI[bkp-compdef]"
        functions[compdef]=':zi-tmp-subst-compdef "$@";'
        ZI[TMP_SUBST]=1
      else
        (( ++ ZI[TMP_SUBST] ))
      fi
    }
    if [[ -n ${ICE[src]} ]]; then
      ZERO="${${(M)ICE[src]##/*}:-$local_dir/$dirname/${ICE[src]}}"
      (( ${+ICE[silent]} )) && { { [[ -n $precm ]] && { builtin ${precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); builtin source "$ZERO"; }; } 2>/dev/null 1>&2; (( retval += $? )); ((1)); } || { ((1)); { [[ -n $precm ]] && { builtin ${precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); builtin source "$ZERO"; }; }; (( retval += $? )); }
    fi
    [[ -n ${ICE[multisrc]} ]] && { local ___oldcd="$PWD"; () { builtin setopt localoptions noautopushd; builtin cd -q "$local_dir/$dirname"; }; eval "reply=(${ICE[multisrc]})"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; local fname; for fname in "${reply[@]}"; do ZERO="${${(M)fname:#/*}:-$local_dir/$dirname/$fname}"; (( ${+ICE[silent]} )) && { { [[ -n $precm ]] && { builtin ${precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); builtin source "$ZERO"; }; } 2>/dev/null 1>&2; (( retval += $? )); ((1)); } || { ((1)); { [[ -n $precm ]] && { builtin ${precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); builtin source "$ZERO"; }; }; (( retval += $? )); }; done; }
    # Run the atload hooks right before atload ice.
    reply=( ${(on)ZI_EXTS[(I)z-annex hook:\!atload-<-> <->]} )
    for key in "${reply[@]}"; do
      arr=( "${(Q)${(z@)ZI_EXTS[$key]}[@]}" )
      "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" \!atload
    done
    # Run the functions' wrapping & tracking requests.
    if [[ -n ${ICE[wrap]} ]] {
      (( ${+functions[.zi-service]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/additional.zsh"
      .zi-wrap-functions "$save_url" "" "$id_as"
    }
    [[ ${ICE[atload][1]} = "!" ]] && { .zi-add-report "$id_as" "Note: Starting to track the atload'!…' ice…"; ZERO="$local_dir/$dirname/-atload-"; local ___oldcd="$PWD"; (( ${+ICE[nocd]} == 0 )) && { () { builtin setopt localoptions noautopushd; builtin cd -q "$local_dir/$dirname"; } && builtin eval "${ICE[atload]#\!}"; ((1)); } || eval "${ICE[atload]#\!}"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; }
    [[ -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
      (( -- ZI[TMP_SUBST] == 0 )) && { ZI[TMP_SUBST]=inactive; builtin setopt noaliases; (( ${+ZI[bkp-compdef]} )) && functions[compdef]="${ZI[bkp-compdef]}" || unfunction compdef; (( ZI[ALIASES_OPT] )) && builtin setopt aliases; }
    }
  elif [[ ${ICE[as]} = completion ]]; then
    ((1))
  fi
  (( ${+ICE[atload]} )) && [[ ${ICE[atload][1]} != "!" ]] && { ZERO="$local_dir/$dirname/-atload-"; local ___oldcd="$PWD"; (( ${+ICE[nocd]} == 0 )) && { () { builtin setopt localoptions noautopushd; builtin cd -q "$local_dir/$dirname"; } && builtin eval "${ICE[atload]}"; ((1)); } || eval "${ICE[atload]}"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; }
  reply=( ${(on)ZI_EXTS[(I)z-annex hook:atload-<-> <->]} )
  for key in "${reply[@]}"; do
    arr=( "${(Q)${(z@)ZI_EXTS[$key]}[@]}" )
    "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" atload
  done
  (( ${+ICE[notify]} == 1 )) && { [[ $retval -eq 0 || -n ${(M)ICE[notify]#\!} ]] && { local msg; eval "msg=\"${ICE[notify]#\!}\""; +zi-deploy-message @msg "$msg" } || +zi-deploy-message @msg "notify: Plugin not loaded / loaded with problem, the return code: $retval"; }
  (( ${+ICE[reset-prompt]} == 1 )) && +zi-deploy-message @rst
  ZI[CUR_USPL2]=
  ZI[TIME_INDEX]=$(( ${ZI[TIME_INDEX]:-0} + 1 ))
  ZI[TIME_${ZI[TIME_INDEX]}_${id_as}]=$SECONDS
  ZI[AT_TIME_${ZI[TIME_INDEX]}_${id_as}]=$EPOCHREALTIME
  .zi-set-m-func unset
  return retval
} # ]]]
# FUNCTION: .zi-load. [[[
# Implements the exposed-to-user action of loading a plugin.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin name, if the third format is used
.zi-load () {
  typeset -F 3 SECONDS=0
  local ___mode="$3" ___rst=0 ___retval=0 ___key
  .zi-any-to-user-plugin "$1" "$2"
  local ___user="${reply[-2]}" ___plugin="${reply[-1]}" ___id_as="${ICE[id-as]:-${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]}}"
  local ___pdir_path="${${${(M)___user:#%}:+$___plugin}:-${ZI[PLUGINS_DIR]}/${___id_as//\//---}}"
  local ___pdir_orig="$___pdir_path"
  ZI[CUR_USR]="$___user" ZI[CUR_PLUGIN]="$___plugin" ZI[CUR_USPL2]="$___id_as"
  if [[ -n ${ICE[teleid]} ]] {
    .zi-any-to-user-plugin "${ICE[teleid]}"
    ___user="${reply[-2]}" ___plugin="${reply[-1]}"
  } else {
    ICE[teleid]="$___user${${___user:#%}:+/}$___plugin"
  }
  .zi-set-m-func set
  local -a ___arr
  reply=(
    ${(on)ZI_EXTS2[(I)zi hook:preinit-pre <->]}
    ${(on)ZI_EXTS[(I)z-annex hook:preinit-<-> <->]}
    ${(on)ZI_EXTS2[(I)zi hook:preinit-post <->]}
  )
  for ___key in "${reply[@]}"; do
    ___arr=( "${(Q)${(z@)ZI_EXTS[$___key]:-$ZI_EXTS2[$___key]}[@]}" )
    "${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" "${${___key##(zi|z-annex) hook:}%% <->}" load || return $(( 10 - $? ))
  done
  if [[ $___user != % && ! -d ${ZI[PLUGINS_DIR]}/${___id_as//\//---} ]] {
    (( ${+functions[.zi-setup-plugin-dir]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
    reply=( "$___user" "$___plugin" ) REPLY=github
    if (( ${+ICE[pack]} )) {
      if ! .zi-get-package "$___user" "$___plugin" "$___id_as" "${ZI[PLUGINS_DIR]}/${___id_as//\//---}" "${ICE[pack]:-default}"
      then
        zle && { builtin print; zle .reset-prompt; }
        return 1
      fi
      ___id_as="${ICE[id-as]:-${___user}${${___user:#(%|/)*}:+/}$___plugin}"
    }
    ___user="${reply[-2]}" ___plugin="${reply[-1]}"
    ICE[teleid]="$___user${${___user:#(%|/)*}:+/}$___plugin"
    [[ $REPLY = snippet ]] && {
      ICE[id-as]="${ICE[id-as]:-$___id_as}"
      .zi-load-snippet $___plugin && return
      zle && { builtin print; zle .reset-prompt; }
      return 1
    }
    .zi-setup-plugin-dir "$___user" "$___plugin" "$___id_as" "$REPLY"
    local rc="$?"
    if [[ "$rc" -ne 0 ]]; then
      zle && { builtin print; zle .reset-prompt; }
    return "$rc"
  fi
    zle && ___rst=1
  }
  ZI_SICE[$___id_as]=
  .zi-pack-ice "$___id_as"
  (( ${+ICE[cloneonly]} )) && return 0
  .zi-register-plugin "$___id_as" "$___mode" "${ICE[teleid]}"
  # Set up param'' objects (parameters).
  if [[ -n ${ICE[param]} ]] {
    .zi-setup-params && local ${(Q)reply[@]}
  }
  reply=( ${(on)ZI_EXTS[(I)z-annex hook:\!atinit-<-> <->]} )
  for ___key in "${reply[@]}"; do
    ___arr=( "${(Q)${(z@)ZI_EXTS[$___key]}[@]}" )
    "${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "${${${(M)___user:#%}:+$___plugin}:-${ZI[PLUGINS_DIR]}/${___id_as//\//---}}" \!atinit || return $(( 10 - $? ))
  done
  [[ ${+ICE[atinit]} = 1 && $ICE[atinit] != '!'*   ]] && { local ___oldcd="$PWD"; (( ${+ICE[nocd]} == 0 )) && { () { builtin setopt localoptions noautopushd; builtin cd -q "${${${(M)___user:#%}:+$___plugin}:-${ZI[PLUGINS_DIR]}/${___id_as//\//---}}"; } && eval "${ICE[atinit]}"; ((1)); } || eval "${ICE[atinit]}"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; }
  reply=( ${(on)ZI_EXTS[(I)z-annex hook:atinit-<-> <->]} )
  for ___key in "${reply[@]}"; do
    ___arr=( "${(Q)${(z@)ZI_EXTS[$___key]}[@]}" )
    "${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "${${${(M)___user:#%}:+$___plugin}:-${ZI[PLUGINS_DIR]}/${___id_as//\//---}}" atinit || return $(( 10 - $? ))
  done
  .zi-load-plugin "$___user" "$___plugin" "$___id_as" "$___mode" "$___rst"; ___retval=$?
  (( ${+ICE[notify]} == 1 )) && { [[ $___retval -eq 0 || -n ${(M)ICE[notify]#\!} ]] && { local msg; eval "msg=\"${ICE[notify]#\!}\""; +zi-deploy-message @msg "$msg" } || +zi-deploy-message @msg "notify: Plugin not loaded / loaded with problem, the return code: $___retval"; }
  (( ${+ICE[reset-prompt]} == 1 )) && +zi-deploy-message @___rst
  # Unset the `m` function.
  .zi-set-m-func unset
  # Mark no load is in progress.
  ZI[CUR_USR]= ZI[CUR_PLUGIN]= ZI[CUR_USPL2]=
  ZI[TIME_INDEX]=$(( ${ZI[TIME_INDEX]:-0} + 1 ))
  ZI[TIME_${ZI[TIME_INDEX]}_${___id_as//\//---}]=$SECONDS
  ZI[AT_TIME_${ZI[TIME_INDEX]}_${___id_as//\//---}]=$EPOCHREALTIME
  return ___retval
} # ]]]
# FUNCTION: .zi-load-plugin. [[[
# Lower-level function for loading a plugin.
#
# $1 - user
# $2 - plugin
# $3 - mode (light or load)
.zi-load-plugin() {
  local ___user="$1" ___plugin="$2" ___id_as="$3" ___mode="$4" ___rst="$5" ___correct=0 ___retval=0
  local ___pbase="${${___plugin:t}%(.plugin.zsh|.zsh|.git)}" ___key
  # Hide arguments from sourced scripts. Without this calls our "$@" are visible as "$@" within scripts that we `source`.
  builtin set --
  [[ -o ksharrays ]] && ___correct=1
  [[ -n ${ICE[(i)(\!|)(sh|bash|ksh|csh)]}${ICE[opts]} ]] && {
    local -a ___precm
    ___precm=(
      builtin emulate
      ${${(M)${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:+-R}
      ${${${ICE[(i)(\!|)(sh|bash|ksh|csh)]}#\!}:-zsh}
      ${${ICE[(i)(\!|)bash]}:+-${(s: :):-o noshglob -o braceexpand -o kshglob}}
      ${(s: :):-${${:-${(@s: :):--o}" "${(s: :)^ICE[opts]}}:#-o }}
      -c
    )
  }
  [[ -z ${ICE[subst]} ]] && local ___builtin=builtin
  [[ ${ICE[as]} = null || ${+ICE[null]} -eq 1 || ${+ICE[binary]} -eq 1 ]] && ICE[pick]="${ICE[pick]:-/dev/null}"
  if [[ -n ${ICE[autoload]} ]] {
    :zi-tmp-subst-autoload -Uz \
      ${(s: :)${${${(s.;.)ICE[autoload]#[\!\#]}#[\!\#]}//(#b)((*)(->|=>|→)(*)|(*))/${match[2]:+$match[2] -S $match[4]}${match[5]:+${match[5]} -S ${match[5]}}}} \
      ${${(M)ICE[autoload]:#*(->|=>|→)*}:+-C} ${${(M)ICE[autoload]#(?\!|\!)}:+-C} ${${(M)ICE[autoload]#(?\#|\#)}:+-I}
  }
  if [[ ${ICE[as]} = command ]]; then
    [[ ${+ICE[pick]} = 1 && -z ${ICE[pick]} ]] && ICE[pick]="${___id_as:t}"
    reply=()
    if [[ -n ${ICE[pick]} && ${ICE[pick]} != /dev/null ]]; then
      reply=( ${(M)~ICE[pick]##/*}(DN) $___pdir_path/${~ICE[pick]}(DN) )
      [[ -n ${reply[1-correct]} ]] && ___pdir_path="${reply[1-correct]:h}"
    fi
    [[ -z ${path[(er)$___pdir_path]} ]] && {
      [[ $___mode != light ]] && .zi-diff-env "${ZI[CUR_USPL2]}" begin
      path=( "${___pdir_path%/}" ${path[@]} )
      [[ $___mode != light ]] && .zi-diff-env "${ZI[CUR_USPL2]}" end
      .zi-add-report "${ZI[CUR_USPL2]}" "$ZI[col-info2]$___pdir_path$ZI[col-rst] added to \$PATH"
    }
    [[ -n ${reply[1-correct]} && ! -x ${reply[1-correct]} ]] && command chmod a+x ${reply[@]}
    [[ ${ICE[atinit]} = '!'* || -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
      if [[ ${ZI[TMP_SUBST]} = inactive ]]; then
        (( ${+functions[compdef]} )) && ZI[bkp-compdef]="${functions[compdef]}" || builtin unset "ZI[bkp-compdef]"
        functions[compdef]=':zi-tmp-subst-compdef "$@";'
        ZI[TMP_SUBST]=1
      else
        (( ++ ZI[TMP_SUBST] ))
      fi
    }
    local ZERO
    [[ $ICE[atinit] = '!'* ]] && { local ___oldcd="$PWD"; (( ${+ICE[nocd]} == 0 )) && { () { builtin setopt localoptions noautopushd; builtin cd -q "${${${(M)___user:#%}:+$___plugin}:-${ZI[PLUGINS_DIR]}/${___id_as//\//---}}"; } && eval "${ICE[atinit#!]}"; ((1)); } || eval "${ICE[atinit]#!}"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; }
    [[ -n ${ICE[src]} ]] && { ZERO="${${(M)ICE[src]##/*}:-$___pdir_orig/${ICE[src]}}"; (( ${+ICE[silent]} )) && { { [[ -n $___precm ]] && { builtin ${___precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); $___builtin source "$ZERO"; }; } 2>/dev/null 1>&2; (( ___retval += $? )); ((1)); } || { ((1)); { [[ -n $___precm ]] && { builtin ${___precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); $___builtin source "$ZERO"; }; }; (( ___retval += $? )); }; }
    [[ -n ${ICE[multisrc]} ]] && { local ___oldcd="$PWD"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___pdir_orig"; }; eval "reply=(${ICE[multisrc]})"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; local ___fname; for ___fname in "${reply[@]}"; do ZERO="${${(M)___fname:#/*}:-$___pdir_orig/$___fname}"; (( ${+ICE[silent]} )) && { { [[ -n $___precm ]] && { builtin ${___precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); $___builtin source "$ZERO"; }; } 2>/dev/null 1>&2; (( ___retval += $? )); ((1)); } || { ((1)); { [[ -n $___precm ]] && { builtin ${___precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); $___builtin source "$ZERO"; }; }; (( ___retval += $? )); }; done; }
    # Run the atload hooks right before atload ice.
    reply=( ${(on)ZI_EXTS[(I)z-annex hook:\!atload-<-> <->]} )
    for ___key in "${reply[@]}"; do
      ___arr=( "${(Q)${(z@)ZI_EXTS[$___key]}[@]}" )
      "${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" \!atload
    done
    # Run the functions' wrapping & tracking requests.
    if [[ -n ${ICE[wrap]} ]] {
      (( ${+functions[.zi-service]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/additional.zsh"
      .zi-wrap-functions "$___user" "$___plugin" "$___id_as"
    }
    [[ ${ICE[atload][1]} = "!" ]] && { .zi-add-report "$___id_as" "Note: Starting to track the atload'!…' ice…"; ZERO="$___pdir_orig/-atload-"; local ___oldcd="$PWD"; (( ${+ICE[nocd]} == 0 )) && { () { builtin setopt localoptions noautopushd; builtin cd -q "$___pdir_orig"; } && builtin eval "${ICE[atload]#\!}"; } || eval "${ICE[atload]#\!}"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; }
    [[ -n ${ICE[src]} || -n ${ICE[multisrc]} || ${ICE[atload][1]} = "!" ]] && {
      (( -- ZI[TMP_SUBST] == 0 )) && { ZI[TMP_SUBST]=inactive; builtin setopt noaliases; (( ${+ZI[bkp-compdef]} )) && functions[compdef]="${ZI[bkp-compdef]}" || unfunction compdef; (( ZI[ALIASES_OPT] )) && builtin setopt aliases; }
    }
  elif [[ ${ICE[as]} = completion ]]; then
    ((1))
  else
    if [[ -n ${ICE[pick]} ]]; then
      [[ ${ICE[pick]} = /dev/null ]] && reply=( /dev/null ) || reply=( ${(M)~ICE[pick]##/*}(DN) $___pdir_path/${~ICE[pick]}(DN) )
    elif [[ -e $___pdir_path/$___pbase.plugin.zsh ]]; then
      reply=( "$___pdir_path/$___pbase".plugin.zsh )
    else
      .zi-find-other-matches "$___pdir_path" "$___pbase"
    fi
    #[[ ${#reply} -eq 0 ]] && return 1
    # Get first one.
    local ___fname="${reply[1-correct]:t}"
    ___pdir_path="${reply[1-correct]:h}"
    .zi-add-report "${ZI[CUR_USPL2]}" "Source $___fname ${${${(M)___mode:#light}:+(no reporting)}:-$ZI[col-info2](reporting enabled)$ZI[col-rst]}"
    # Light and compdef ___mode doesn't do diffs and temporary substituting of functions.
    [[ $___mode != light(|-b) ]] && .zi-diff "${ZI[CUR_USPL2]}" begin
    .zi-tmp-subst-on "${___mode:-load}"
    # We need some state, but ___user wants his for his plugins.
    (( ${+ICE[blockf]} )) && { local -a fpath_bkp; fpath_bkp=( "${fpath[@]}" ); }
    local ZERO="$___pdir_path/$___fname"
    (( ${+ICE[aliases]} )) || builtin setopt noaliases
    [[ $ICE[atinit] = '!'* ]] && { local ___oldcd="$PWD"; (( ${+ICE[nocd]} == 0 )) && { () { builtin setopt localoptions noautopushd; builtin cd -q "${${${(M)___user:#%}:+$___plugin}:-${ZI[PLUGINS_DIR]}/${___id_as//\//---}}"; } && eval "${ICE[atinit]#!}"; ((1)); } || eval "${ICE[atinit]#1}"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; }
    (( ${+ICE[silent]} )) && { { [[ -n $___precm ]] && { builtin ${___precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); $___builtin source "$ZERO"; }; } 2>/dev/null 1>&2; (( ___retval += $? )); ((1)); } || { ((1)); { [[ -n $___precm ]] && { builtin ${___precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); $___builtin source "$ZERO"; }; }; (( ___retval += $? )); }
    [[ -n ${ICE[src]} ]] && { ZERO="${${(M)ICE[src]##/*}:-$___pdir_orig/${ICE[src]}}"; (( ${+ICE[silent]} )) && { { [[ -n $___precm ]] && { builtin ${___precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); $___builtin source "$ZERO"; }; } 2>/dev/null 1>&2; (( ___retval += $? )); ((1)); } || { ((1)); { [[ -n $___precm ]] && { builtin ${___precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); $___builtin source "$ZERO"; }; }; (( ___retval += $? )); }; }
    [[ -n ${ICE[multisrc]} ]] && { local ___oldcd="$PWD"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___pdir_orig"; }; eval "reply=(${ICE[multisrc]})"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; for ___fname in "${reply[@]}"; do ZERO="${${(M)___fname:#/*}:-$___pdir_orig/$___fname}"; (( ${+ICE[silent]} )) && { { [[ -n $___precm ]] && { builtin ${___precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); $___builtin source "$ZERO"; }; } 2>/dev/null 1>&2; (( ___retval += $? )); ((1)); } || { { [[ -n $___precm ]] && { builtin ${___precm[@]} 'source "$ZERO"'; ((1)); } || { ((1)); $___builtin source "$ZERO"; }; }; (( ___retval += $? )); } done; }
    # Run the atload hooks right before atload ice.
    reply=( ${(on)ZI_EXTS[(I)z-annex hook:\!atload-<-> <->]} )
    for ___key in "${reply[@]}"; do
      ___arr=( "${(Q)${(z@)ZI_EXTS[$___key]}[@]}" )
      "${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" \!atload
    done
    # Run the functions' wrapping & tracking requests.
    if [[ -n ${ICE[wrap]} ]] {
      (( ${+functions[.zi-service]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/additional.zsh"
      .zi-wrap-functions "$___user" "$___plugin" "$___id_as"
    }
    [[ ${ICE[atload][1]} = "!" ]] && { .zi-add-report "$___id_as" "Note: Starting to track the atload'!…' ice…"; ZERO="$___pdir_orig/-atload-"; local ___oldcd="$PWD"; (( ${+ICE[nocd]} == 0 )) && { () { builtin setopt localoptions noautopushd; builtin cd -q "$___pdir_orig"; } && builtin eval "${ICE[atload]#\!}"; ((1)); } || eval "${ICE[atload]#\!}"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; }
    (( ZI[ALIASES_OPT] )) && builtin setopt aliases
    (( ${+ICE[blockf]} )) && { fpath=( "${fpath_bkp[@]}" ); }
    .zi-tmp-subst-off "${___mode:-load}"
    [[ $___mode != light(|-b) ]] && .zi-diff "${ZI[CUR_USPL2]}" end
  fi
  [[ ${+ICE[atload]} = 1 && ${ICE[atload][1]} != "!" ]] && { ZERO="$___pdir_orig/-atload-"; local ___oldcd="$PWD"; (( ${+ICE[nocd]} == 0 )) && { () { builtin setopt localoptions noautopushd; builtin cd -q "$___pdir_orig"; } && builtin eval "${ICE[atload]}"; ((1)); } || eval "${ICE[atload]}"; () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }; }
  reply=( ${(on)ZI_EXTS[(I)z-annex hook:atload-<-> <->]} )
  for ___key in "${reply[@]}"; do
    ___arr=( "${(Q)${(z@)ZI_EXTS[$___key]}[@]}" )
    "${___arr[5]}" plugin "$___user" "$___plugin" "$___id_as" "$___pdir_orig" atload
  done
  (( ___rst )) && { builtin print; zle .reset-prompt; }
  return ___retval
} # ]]]
# FUNCTION: .zi-compdef-replay. [[[
# Runs gathered compdef calls. This allows to run `compinit' after loading plugins.
.zi-compdef-replay() {
  local quiet="$1"
  typeset -a pos
  # Check if compinit was loaded.
  if [[ ${+functions[compdef]} = 0 ]]; then
    +zi-message "{u-warn}Error{b-warn}:{rst} The {func}compinit{rst}" \
      "function hasn't been loaded, cannot do {it}{cmd}compdef replay{rst}."
    return 1
  fi
  # In the same order.
  local cdf
  for cdf in "${ZI_COMPDEF_REPLAY[@]}"; do
    pos=( "${(z)cdf}" )
    # When ZI_COMPDEF_REPLAY empty (also when only white spaces).
    [[ ${#pos[@]} = 1 && -z ${pos[-1]} ]] && continue
    pos=( "${(Q)pos[@]}" )
    [[ $quiet = -q ]] || +zi-message "Running compdef: {cmd}${pos[*]}{rst}"
    compdef "${pos[@]}"
  done
  return 0
} # ]]]
# FUNCTION: .zi-compdef-clear. [[[
# Implements user-exposed functionality to clear gathered compdefs.
.zi-compdef-clear() {
  local quiet="$1" count="${#ZI_COMPDEF_REPLAY}"
  ZI_COMPDEF_REPLAY=( )
  [[ $quiet = -q ]] || +zi-message "Compdef-replay cleared (it had {num}${count}{rst} entries)."
} # ]]]
# FUNCTION: .zi-add-report. [[[
# Adds a report line for given plugin.
#
# $1 - uspl2, i.e. user/plugin
# $2, ... - the text
.zi-add-report() {
  # Use zi binary module if available.
  [[ -n $1 ]] && { (( ${+builtins[zpmod]} && 0 )) && zpmod report-append "$1" "$2"$'\n' || ZI_REPORTS[$1]+="$2"$'\n'; }
  [[ ${ZI[DTRACE]} = 1 ]] && { (( ${+builtins[zpmod]} )) && zpmod report-append _dtrace/_dtrace "$2"$'\n' || ZI_REPORTS[_dtrace/_dtrace]+="$2"$'\n'; }
  return 0
} # ]]]
# FUNCTION: .zi-add-fpath. [[[
.zi-add-fpath() {
  [[ $1 = (-f|--front) ]] && { shift; integer front=1; }
  .zi-any-to-user-plugin "$1" ""
  local id_as="$1" add_dir="$2" user="${reply[-2]}" plugin="${reply[-1]}"
  if (( front )) {
    fpath[1,0]=${${${(M)user:#%}:+$plugin}:-${ZI[PLUGINS_DIR]}/${id_as//\//---}}${add_dir:+/$add_dir}
  } else {
    fpath+=(
      ${${${(M)user:#%}:+$plugin}:-${ZI[PLUGINS_DIR]}/${id_as//\//---}}${add_dir:+/$add_dir}
    )
  }
} # ]]]
# FUNCTION: .zi-run. [[[
# Run code inside plugin's folder
# It uses the `correct' parameter from upper's scope zi().
.zi-run() {
  if [[ $1 = (-l|--last) ]]; then
    { set -- "${ZI[last-run-plugin]:-$(<${ZI[BIN_DIR]}/last-run-object.txt)}" "${@[2-correct,-1]}"; } &>/dev/null
    [[ -z $1 ]] && { +zi-message "{u-warn}Error{b-warn}:{rst} No recent plugin-ID saved on the disk yet, please specify" \
    "it as the first argument, i.e.{ehi}: {cmd}zi run {pid}usr/plg{slight} {…}the code to run{…} "; return 1; }
  else
    integer ___nolast=1
  fi
  .zi-any-to-user-plugin "$1" ""
  local ___id_as="$1" ___user="${reply[-2]}" ___plugin="${reply[-1]}" ___oldpwd="$PWD"
  () {
    builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
    builtin cd &>/dev/null -q ${${${(M)___user:#%}:+$___plugin}:-${ZI[PLUGINS_DIR]}/${___id_as//\//---}} || {
      .zi-get-object-path snippet "$___id_as"
      builtin cd &>/dev/null -q $REPLY
    }
  }
  if (( $? == 0 )); then
    (( ___nolast )) && { builtin print -r "$1" >! ${ZI[BIN_DIR]}/last-run-object.txt; }
    ZI[last-run-plugin]="$1"
    eval "${@[2-correct,-1]}"
    () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldpwd"; }
  else
    +zi-message "{u-warn}Error{b-warn}:{rst} no such plugin or snippet."
  fi
} # ]]]
# FUNCTION: +zi-deploy-message. [[[
# Deploys a sub-prompt message to be displayed OR a `zle
# .reset-prompt' call to be invoked
+zi-deploy-message() {
  [[ $1 = <-> && ( ${#} = 1 || ( $2 = (hup|nval|err) && ${#} = 2 ) ) ]] && { zle && {
    local alltext text IFS=$'\n' nl=$'\n'
    repeat 25; do read -r -u"$1" text; alltext+="${text:+$text$nl}"; done
    [[ $alltext = @rst$nl ]] && { builtin zle reset-prompt; ((1)); } || \
      { [[ -n $alltext ]] && builtin zle -M "$alltext"; }
  }
  builtin zle -F "$1"; exec {1}<&-
  return 0
  }
  local THEFD=13371337 hasw
  # The expansion is: if there is @sleep: pfx, then use what's after. it, otherwise substitute 0
  exec {THEFD} < <(LANG=C sleep $(( 0.01 + ${${${(M)1#@sleep:}:+${1#@sleep:}}:-0} )); builtin print -r -- ${1:#(@msg|@sleep:*)} "${@[2,-1]}"; )
  command true # workaround a Zsh bug, see: http://www.zsh.org/mla/workers/2018/msg00966.html
  builtin zle -F "$THEFD" +zi-deploy-message
} # ]]]
# FUNCTION: .zi-formatter-auto[[[
# The automatic message formatting tool automatically detects,
# formats, and colorizes the following pieces of text:
# [URLs], [plugin IDs (user/repo) if exists on the disk], [numbers], [time], [single-word id-as plugins],
# [single word commands], [single word functions], [zi commands], [ice modifiers (e.g: mv'a -> b')],
# [single-char bits and quoted strings (`...', ,'...', "...")].
.zi-formatter-auto() {
  builtin emulate -L zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal typesetsilent
  local out in=$1 i rwmsg match spaces rest
  integer mbegin mend
  local -a ice_order ecmds
  ice_order=( ${(As:|:)ZI[ice-list]} ${(@)${(@Akons:|:u)${ZI_EXTS[ice-mods]//\'\'/}}/(#s)<->-/} )
  ecmds=( ${ZI_EXTS[(I)z-annex subcommand:*]#z-annex subcommand:} )
  in=${(j: :)${${(Z+Cn+)in}//[$'\t ']/$'\u00a0'}}
  rwmsg=$in
  while [[ $in == (#b)([[:space:]]#)([^[:space:]]##)(*) ]]; do
    spaces=$match[1]
    rest=$match[3]
    rwmsg=${match[2]//---//}
    REPLY=$rwmsg
    if [[ $rwmsg == ([[:space:]]##|(#s))[0-9.]##([[:space:]]##|(#e)) && \
      $rest == ([[:space:]]#|(#s))[sm]([[:space:]]##*|(#e)) || $rwmsg == ([[:space:]]##|(#s))[0-9.]##[sm]([[:space:]]##|(#e)) ]]; then
      REPLY=${ZI[col-time]}$rwmsg${ZI[col-rst]}
      if [[ $rwmsg != *[sm]* ]]; then
        rest=$ZI[col-time]${(M)rest##[[:space:]]#[sm]}$ZI[col-rst]${rest##[[:space:]]#[sm]}
      fi
    elif [[ $rwmsg == ([[:space:]]##|(#s))[0-9.]##([[:space:]]##|(#e)) ]]; then
      REPLY=${ZI[col-num]}$rwmsg${ZI[col-rst]}
    elif [[ $rwmsg == (#b)((http(s|)|ftp(s|)|rsync|ssh|scp|ntp|file)://[[:alnum:].:+/]##) ]]; then
      .zi-formatter-url $rwmsg
    elif [[ $rwmsg == (--|)(${(~j:|:)ice_order})[:=\"\'\!a-zA-Z0-9-]* ]]; then
      REPLY=${ZI[col-ice]}$rwmsg${ZI[col-rst]}
    elif [[ $rwmsg == (OMZ|PZT|PZTM|OMZP|OMZT|OMZL)::* || $rwmsg == [^/]##/[^/]## || -d ${ZI[PLUGINS_DIR]}/${rwmsg//\//---} ]]; then
      .zi-formatter-pid $rwmsg
    elif [[ $rwmsg == (${~ZI[cmd-list]}|${(~j:|:)ecmds}) ]]; then
      REPLY=${ZI[col-cmd]}$rwmsg${ZI[col-rst]}
    elif (( $+commands[$1] )); then
      REPLY=${ZI[col-bcmd]}$rwmsg${ZI[col-rst]}
    elif (( $+functions[$1] )); then
      REPLY=${ZI[col-func]}$rwmsg${ZI[col-rst]}
    elif [[ $rwmsg == (#b)(*)('<->'|'<–>'|'<—>')(*) || $rwmsg == (#b)(*)(…|–|—|↔|...)(*) ]]; then
      local -A map=( … … - dsh – ndsh — mdsh '<->' ↔ '<–>' ↔ '<—>' ↔ ↔ ↔ ... …)
      REPLY=$match[1]$ZI[col-$map[$rwmsg]]$match[3]
    # \1 - preceding \2 - open, \3 - string, \4 - close, \5 - following
    elif [[ $rwmsg == (#b)(*)([\'\`\"])([^\'\`\"]##)([\'\`\"])(*) ]]; then
      local -A map=( \` bapo \' apo \" quo x\` baps x\' aps x\" quos )
      local openq=$match[2] str=$match[3] closeq=$match[4] RST=$ZI[col-rst]
      REPLY=$match[1]$ZI[col-$map[$openq]]$openq$RST$ZI[col-$map[x$openq]]$str$RST$ZI[col-$map[$closeq]]$closeq$RST$match[5]
    fi
    in=$rest
    out+=${spaces//$'\n'/$'\013\015'}$REPLY
  done
  REPLY=${out//$'\u00a0'/ }
} # ]]]
# FUNCTION: .zi-formatter-pid. [[[
.zi-formatter-pid() {
  builtin emulate -L zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
  # Save whitespace location
  local pbz=${(M)1##(#s)[[:space:]]##}
  local kbz=${(M)1%%[[:space:]]##(#e)}
  # Trim leading/trailing whitespace
  1=${1//((#s)[[:space:]]##|[[:space:]]##(#e))/}
  ((${+functions[.zi-first]})) || source ${ZI[BIN_DIR]}/lib/zsh/side.zsh
  .zi-any-colorify-as-uspl2 "$1";
  # Replace at least one character with an unbreakable space,
  # because extreme whitespace is lost due to implementation problems ...
  pbz=${pbz/[[:blank:]]/ }
  local kbz_rev="${(j::)${(@Oas::)kbz}}"
  kbz="${(j::)${(@Oas::)${kbz_rev/[[:blank:]]/ }}}"
  # Restore whitespace location
  REPLY=$pbz$REPLY$kbz
} # ]]]
# FUNCTION: .zi-formatter-bar. [[[
.zi-formatter-bar() {
  .zi-formatter-bar-util ─ bar
} # ]]]
# FUNCTION: .zi-formatter-th-bar. [[[
.zi-formatter-th-bar() {
  .zi-formatter-bar-util ━ th-bar
}
# FUNCTION: .zi-formatter-bar-util. [[[
.zi-formatter-bar-util() {
  if [[ $LANG == (#i)*utf-8* ]]; then
    ch=$1
  else
    ch=-
  fi
  REPLY=$ZI[col-$2]${(pl:COLUMNS-1::$ch:):-}$ZI[col-rst]
} # ]]]
# FUNCTION: .zi-formatter-url. [[[
.zi-formatter-url() {
  builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
  #              1:proto        3:domain/5:start      6:end-of-it         7:no-dot-domain        9:file-path
  if [[ $1 = (#b)([^:]#)(://|::)((([[:alnum:]._+-]##).([[:alnum:]_+-]##))|([[:alnum:].+_-]##))(|/(*)) ]] {
    # The advanced coloring if recognized the format…
    match[9]=${match[9]//\//"%F{227}%B"/"%F{81}%b"}
    if [[ -n $match[4] ]]; then
      # … this ·case· ends at: trailing component of the with-dot domain …
      REPLY="$(builtin print -Pr -- %F{220}$match[1]%F{227}$match[2]%B%F{82}$match[5]%B%F{227}.%B%F{183}$match[6]%f%b)"
    else
      # … this ·case· ends at: no-dot domain …
      REPLY="$(builtin print -Pr -- %F{220}$match[1]%F{227}$match[2]%B%F{82}$match[7]%f%b)"
    fi
    # Is there any file-path part in the URL?
    if [[ -n $match[9] ]]; then
      # … append it. This ends the URL.
      REPLY+="$(print -Pr -- %F{227}%B/%F{81}%b$match[9]%f%b)"
    fi
  #endif
  } else {
    # …revert to the basic if not…
    REPLY=$ZI[col-url]$1$ZI[col-rst]
  }
} # ]]]
# FUNCTION: +zi-message-formatter [[[
.zi-main-message-formatter() {
  if [[ -z $1 && -z $2 && -z $3 ]]; then
    REPLY=""
    return
  fi
  local append influx in_prepend
  if [[ $2 == (b|u|it|st|nb|nu|nit|nst) ]]; then
    # Code repetition to preserve any leading/trailing whitespace and to allow accumulation of this code with others.
    append=$ZI[col-$2]
  elif [[ $2 == (…|ndsh|mdsh|mmdsh|-…|lr|) || -z $2 || -z $ZI[col-$2] ]]; then
    # Resume previous escape code, if stored.
    if [[ $ZI[__last-formatter-code] != (…|ndsh|mdsh|mmdsh|-…|lr|rst|nl|) ]]; then
      in_prepend=$ZI[col-$ZI[__last-formatter-code]]
      influx=$ZI[col-$ZI[__last-formatter-code]]
    fi
  else
    # End of escaping logic
    append=$ZI[col-rst]
  fi
  # Construct the text.
  REPLY=$in_prepend${ZI[col-$2]:-$1}$influx$3$append
  # Replace new lines with characters that work the same but are not deleted in the substitution
  # $ (...) - vertical tab 0xB ↔ 13 in the system octagonal connected back carriage (015).
  local nl=$'\n' vertical=$'\013' carriager=$'\015'
  REPLY=${REPLY//$nl/$vertical$carriager}
} # ]]]
# FUNCTION: +zi-message. [[[
+zi-message() {
  builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
  local opt msg
  [[ $1 = -* ]] && { local opt=$1; shift; }

  ZI[__last-formatter-code]=
  msg=${${(j: :)${@:#--}}//\%/%%}

  # First try a dedicated formatter, marking its empty output with ←→, then
  # the general formatter and in the end filter-out the ←→ from the message.
  msg=${${msg//(#b)(([\\]|(%F))([\{]([^\}]##)[\}])|([\{]([^\}]##)[\}])([^\%\{\\]#))/${match[4]:+${${match[3]:-$ZI[col-${ZI[__last-formatter-code]}]}:#%F}}$match[3]$match[4]${${functions[.zi-formatter-$match[7]]:+${$(.zi-formatter-$match[7] "$match[8]"; builtin print -rn -- $REPLY):-←→}}:-$(.zi-main-message-formatter "$match[6]" "$match[7]" "$match[8]"; builtin print -rn -- "$REPLY"
  )${${ZI[__last-formatter-code]::=${${${match[7]:#(…|ndsh|mdsh|mmdsh|-…|lr)}:+$match[7]}:-${ZI[__last-formatter-code]}}}:+}}}//←→}
  # Reset color attributes at the end of the message.
  msg=$msg$ZI[col-rst]
  # Output the processed message:
  builtin print -Pr ${opt:#--} -- $msg

  # Needed to properly end a message with {nl}.
  if [[ -n ${opt:#*n*} || -z $opt ]]; then
    print -n $'\015'
  fi
} # ]]]
# FUNCTION: +zi-prehelp-usage-message. [[[
# Prints the usage message.
+zi-prehelp-usage-message() {
  builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}

  local cmd=$1 allowed=$2 sep="$ZI[col-msg2], $ZI[col-ehi]" sep2="$ZI[col-msg2], $ZI[col-opt]" bcol

  # -h/--help given?
  if (( OPTS[opt_-h,--help] )) {
    # Yes – a help message:
+zi-message "{lhi}HELP FOR {apo}\`{cmd}$cmd{apo}\`{lhi} subcommand {mdsh}" "the available {b-lhi}options{ehi}:{rst}"
    local opt
    for opt ( ${(kos:|:)allowed} ) {
      [[ $opt == --* ]] && continue
      local msg=${___opt_map[$opt]#*:} txt=${___opt_map[(r)opt_$opt,--[^:]##]}
      if [[ $msg == *":["* ]] {
        msg=${${(MS)msg##$cmd:\[[^]]##}:-${(MS)msg##\*:\[[^]]##}}
        msg=${msg#($cmd|\*):\[}
      }
      local pre_msg=`+zi-message -n {opt}${(r:14:)${txt#opt_}}`
      +zi-message ${(r:35:: :)pre_msg}{rst}{ehi}→{rst}"  $msg"
    }
  } elif [[ -n $allowed ]] {
    shift 2
    # No – an error message:
    +zi-message "{b}{u-warn}ERROR{b-warn}:{rst}{msg2} Incorrect options given{ehi}:" "${(Mpj:$sep:)@:#-*}{rst}{msg2}. Allowed for the subcommand{ehi}:{rst}" \
    "{apo}\`{cmd}$cmd{apo}\`{msg2} are{ehi}:{rst}" "{nl}{mmdsh} {opt}${allowed//\|/$sep2}{msg2}." "{nl}{…} Aborting.{rst}"
  } else {
    local -a cmds
    cmds=( load snippet update delete )
    local bcol="{$cmd}" sep="${ZI[col-rst]}${ZI[col-$cmd]}\`, \`${ZI[col-cmd]}"
    +zi-message "$bcol(it should be one of, e.g.{ehi}:" \
    "{nb}$bcol\`{cmd}${(pj:$sep:)cmds}$bcol\`," \
    "{cmd}{…}$bcol, e.g.{ehi}: {nb}$bcol\`{lhi}zi {b}{cmd}load" \
    "{pid}username/reponame$bcol\`) or a {b}{hi}for{nb}$bcol-based" \
    "command body (i.e.{ehi}:{rst}$bcol e.g.{ehi}: {rst}$bcol\`{lhi}zi" \
      "{…}{b}ice-spec{nb}{…} {hi}for{nb}{lhi} {…}({b}plugin" \
      "{nb}or{b} snippet) {pname}ID-1 ID-2 {-…} {lhi}{…}$bcol\`)." \
    "See \`{cmd}help$bcol\` for a more detailed usage information and" \
    "the list of the {cmd}subcommands$bcol.{rst}"
  }
}
# ]]]
# FUNCTION: +zi-parse-opts. [[[
.zi-parse-opts() {
  builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
  reply=( "${(@)${@[2,-1]//([  $'\t']##|(#s))(#b)(${(~j.|.)${(@s.|.)___opt_map[$1]}})(#B)([  $'\t']##|(#e))/${OPTS[${___opt_map[${match[1]}]%%:*}]::=1}ß←↓→}:#1ß←↓→}" )
} # ]]]

#
# Ice support.
#

# FUNCTION: .zi-ice. [[[
# Parses ICE specification, puts the result into ICE global hash. The ice-spec is valid for
# next command only (i.e. it "melts"), but it can then stick to plugin and activate e.g. at update.
.zi-ice() {
  builtin setopt localoptions noksharrays extendedglob warncreateglobal typesetsilent noshortloops
  integer retval
  local bit exts="${(j:|:)${(@)${(@Akons:|:u)${ZI_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}}"
  for bit; do
  [[ $bit = (#b)(--|)(${~ZI[ice-list]}${~exts})(*) ]] && ZI_ICES[${match[2]}]+="${ZI_ICES[${match[2]}]:+;}${match[3]#(:|=)}" || break
    retval+=1
  done
  [[ ${ZI_ICES[as]} = program ]] && ZI_ICES[as]=command
  [[ -n ${ZI_ICES[on-update-of]} ]] && ZI_ICES[subscribe]="${ZI_ICES[subscribe]:-${ZI_ICES[on-update-of]}}"
  [[ -n ${ZI_ICES[pick]} ]] && ZI_ICES[pick]="${ZI_ICES[pick]//\$ZPFX/${ZPFX%/}}"

return retval
} # ]]]
# FUNCTION: .zi-pack-ice. [[[
# Remembers all ice-mods, assigns them to concrete plugin. Ice spec is in general forgotten for
# second-next command (that's why it's called "ice" - it melts), however they glue to the object (plugin
# or snippet) mentioned in the next command – for later use with e.g. `zi update ...'.
.zi-pack-ice() {
  ZI_SICE[$1${1:+${2:+/}}$2]+="${(j: :)${(qkv)ICE[@]}} "
  ZI_SICE[$1${1:+${2:+/}}$2]="${ZI_SICE[$1${1:+${2:+/}}$2]# }"
  return 0
} # ]]]
# FUNCTION: .zi-load-ices. [[[
.zi-load-ices() {
  local id_as="$1" ___key ___path
  local -a ice_order
  ice_order=(
    ${(As:|:)ZI[ice-list]}
    ${(@)${(@Akons:|:u)${ZI_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}
  )
  ___path="${ZI[PLUGINS_DIR]}/${id_as//\//---}"/._zi
  # TODO Snippet's dir computation…
  if [[ ! -d $___path ]] {
    if ! .zi-get-object-path snippet "${id_as//\//---}"; then
      return 1
    fi
    ___path="$REPLY"/._zi
  }
  for ___key ( "${ice_order[@]}" ) {
    (( ${+ICE[$___key]} )) && [[ ${ICE[$___key]} != +* ]] && continue
    [[ -e $___path/$___key ]] && ICE[$___key]="$(<$___path/$___key)"
  }
  [[ -n ${ICE[on-update-of]} ]] && ICE[subscribe]="${ICE[subscribe]:-${ICE[on-update-of]}}"
  [[ ${ICE[as]} = program ]] && ICE[as]=command
  [[ -n ${ICE[pick]} ]] && ICE[pick]="${ICE[pick]//\$ZPFX/${ZPFX%/}}"

  return 0
} # ]]]
# FUNCTION: .zi-setup-params. [[[
.zi-setup-params() {
  builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
  reply=( ${(@)${(@s.;.)ICE[param]}/(#m)*/${${MATCH%%(-\>|→|=\>)*}//((#s)[[:space:]]##|[[:space:]]##(#e))}${${(M)MATCH#*(-\>|→|=\>)}:+\=${${MATCH#*(-\>|→|=\>)}//((#s)[[:space:]]##|[[:space:]]##(#e))}}} )
  (( ${#reply} )) && return 0 || return 1
} # ]]]

#
# Turbo.
#

# FUNCTION: .zi-run-task. [[[
# A backend, worker function of .zi-scheduler. It obtains the tasks
# index and a few of its properties (like the type: plugin, snippet,
# service plugin, service snippet) and executes it first checking for
# additional conditions (like non-numeric wait'' ice).
#
# $1 - the pass number, either 1st or 2nd pass
# $2 - the time assigned to the task
# $3 - type: plugin, snippet, service plugin, service snippet
# $4 - task's index in the ZI[WAIT_ICE_...] fields
# $5 - mode: load or light
# $6 - the plugin-spec or snippet URL or alias name (from id-as'')
.zi-run-task() {
  local ___pass="$1" ___t="$2" ___tpe="$3" ___idx="$4" ___mode="$5" ___id="${(Q)6}" ___opt="${(Q)7}" ___action ___s=1 ___retval=0

  local -A ICE ZI_ICE
  ICE=( "${(@Q)${(z@)ZI[WAIT_ICE_${___idx}]}}" )
  ZI_ICE=( "${(kv)ICE[@]}" )

  local ___id_as=${ICE[id-as]:-$___id}

  if [[ $___pass = 1 && ${${ICE[wait]#\!}%%[^0-9]([^0-9]|)([^0-9]|)([^0-9]|)} = <-> ]]; then
    ___action="${(M)ICE[wait]#\!}load"
  elif [[ $___pass = 1 && -n ${ICE[wait]#\!} ]] && { eval "${ICE[wait]#\!}" || [[ $(( ___s=0 )) = 1 ]]; }; then
    ___action="${(M)ICE[wait]#\!}load"
  elif [[ -n ${ICE[load]#\!} && -n $(( ___s=0 )) && $___pass = 3 && -z ${ZI_REGISTERED_PLUGINS[(r)$___id_as]} ]] && eval "${ICE[load]#\!}"; then
    ___action="${(M)ICE[load]#\!}load"
  elif [[ -n ${ICE[unload]#\!} && -n $(( ___s=0 )) && $___pass = 2 && -n ${ZI_REGISTERED_PLUGINS[(r)$___id_as]} ]] && eval "${ICE[unload]#\!}"; then
    ___action="${(M)ICE[unload]#\!}remove"
  elif [[ -n ${ICE[subscribe]#\!} && -n $(( ___s=0 )) && $___pass = 3 ]] && \
    { local -a fts_arr
    eval "fts_arr=( ${ICE[subscribe]}(DNms-$(( EPOCHSECONDS - ZI[fts-${ICE[subscribe]}] ))) ); (( \${#fts_arr} ))" && \
      { ZI[fts-${ICE[subscribe]}]="$EPOCHSECONDS"; ___s=${+ICE[once]}; } || \
      (( 0 ))
    }
  then
    ___action="${(M)ICE[subscribe]#\!}load"
  fi

  if [[ $___action = *load ]]; then
    if [[ $___tpe = p ]]; then
      .zi-load "${(@)=___id}" "" "$___mode"; (( ___retval += $? ))
    elif [[ $___tpe = s ]]; then
      .zi-load-snippet $___opt "$___id"; (( ___retval += $? ))
    elif [[ $___tpe = p1 || $___tpe = s1 ]]; then
      (( ${+functions[.zi-service]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/additional.zsh"
      zpty -b "${___id//\//:} / ${ICE[service]}" '.zi-service '"${(M)___tpe#?}"' "$___mode" "$___id"'
    fi
    (( ${+ICE[silent]} == 0 && ${+ICE[lucid]} == 0 && ___retval == 0 )) && zle && zle -M "Loaded $___id"
  elif [[ $___action = *remove ]]; then
    (( ${+functions[.zi-confirm]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/autoload.zsh" || return 1
    [[ $___tpe = p ]] && .zi-unload "$___id_as" "" -q
    (( ${+ICE[silent]} == 0 && ${+ICE[lucid]} == 0 && ___retval == 0 )) && zle && zle -M "Unloaded $___id_as"
  fi

  [[ ${REPLY::=$___action} = \!* ]] && zle && zle .reset-prompt

  return ___s
} # ]]]

# FUNCTION: .zi-submit-turbo. [[[
# If `zi load`, `zi light` or `zi snippet`  will be
# preceded with `wait', `load', `unload' or `on-update-of`/`subscribe'
# ice-mods then the plugin or snipped is to be loaded in turbo-mode,
# and this function adds it to internal data structures, so that
# @zi-scheduler can run (load, unload) this as a task.
.zi-submit-turbo() {
  local tpe="$1" mode="$2" opt_uspl2="$3" opt_plugin="$4"

  ICE[wait]="${ICE[wait]%%.[0-9]##}"
  ZI[WAIT_IDX]=$(( ${ZI[WAIT_IDX]:-0} + 1 ))
  ZI[WAIT_ICE_${ZI[WAIT_IDX]}]="${(j: :)${(qkv)ICE[@]}}"
  ZI[fts-${ICE[subscribe]}]="${ICE[subscribe]:+$EPOCHSECONDS}"

  [[ $tpe = s* ]] && \
    local id="${${opt_plugin:+$opt_plugin}:-$opt_uspl2}" || \
    local id="${${opt_plugin:+$opt_uspl2${${opt_uspl2:#%*}:+/}$opt_plugin}:-$opt_uspl2}"

  if [[ ${${ICE[wait]}%%[^0-9]([^0-9]|)([^0-9]|)([^0-9]|)} = (\!|.|)<-> ]]; then
    ZI_TASKS+=( "$EPOCHSECONDS+${${ICE[wait]#(\!|.)}%%[^0-9]([^0-9]|)([^0-9]|)([^0-9]|)}+${${${(M)ICE[wait]%a}:+1}:-${${${(M)ICE[wait]%b}:+2}:-${${${(M)ICE[wait]%c}:+3}:-1}}} $tpe ${ZI[WAIT_IDX]} ${mode:-_} ${(q)id} ${opt_plugin:+${(q)opt_uspl2}}" )
  elif [[ -n ${ICE[wait]}${ICE[load]}${ICE[unload]}${ICE[subscribe]} ]]; then
    ZI_TASKS+=( "${${ICE[wait]:+0}:-1}+0+1 $tpe ${ZI[WAIT_IDX]} ${mode:-_} ${(q)id} ${opt_plugin:+${(q)opt_uspl2}}" )
  fi
} # ]]]
# FUNCTION: -zi_scheduler_add_sh. [[[
# Copies task into ZI_RUN array, called when a task timeouts.
# A small function ran from pattern in /-substitution as a math
# function.
-zi_scheduler_add_sh() {
  local idx="$1" in_wait="$___ar2" in_abc="$___ar3" ver_wait="$___ar4" ver_abc="$___ar5"
  if [[ ( $in_wait = $ver_wait || $in_wait -ge 4 ) && $in_abc = $ver_abc ]]; then
    ZI_RUN+=( "${ZI_TASKS[$idx]}" )
    return 1
  else
    return idx
  fi
} # ]]]
# FUNCTION: @zi-scheduler. [[[
# Searches for timeout tasks, executes them. There's an array of tasks
# waiting for execution, this scheduler manages them, detects which ones
# should be run at current moment, decides to remove (or not) them from
# the array after execution.
#
# $1 - if "following", then it is non-first (second and more)
#      invocation of the scheduler; this results in chain of `sched'
#      invocations that results in repetitive @zi-scheduler activity.
#
#      if "burst", then all tasks are marked timeout and executed one
#      by one; this is handy if e.g. a docker image starts up and
#      needs to install all turbo-mode plugins without any hesitation
#      (delay), i.e. "burst" allows to run package installations from
#      script, not from prompt.
#

@zi-scheduler() {
  integer ___ret="${${ZI[lro-data]%:*}##*:}"
  # lro stands for lastarg-retval-option.
  [[ $1 = following ]] && sched +1 'ZI[lro-data]="$_:$?:${options[printexitvalue]}"; @zi-scheduler following "${ZI[lro-data]%:*:*}"'
  [[ -n $1 && $1 != (following*|burst) ]] && { local THEFD="$1"; zle -F "$THEFD"; exec {THEFD}<&-; }
  [[ $1 = burst ]] && local -h EPOCHSECONDS=$(( EPOCHSECONDS+10000 ))
  ZI[START_TIME]="${ZI[START_TIME]:-$EPOCHREALTIME}"

  integer ___t=EPOCHSECONDS ___i correct
  local -a match mbegin mend reply
  local MATCH REPLY AFD; integer MBEGIN MEND

  [[ -o ksharrays ]] && correct=1

  if [[ -n $1 ]] {
    if [[ ${#ZI_RUN} -le 1 || $1 = following ]]  {
      () {
        builtin emulate -L zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
        # Example entry:
        # 1531252764+2+1 p 18 light z-shell/zsh-diff-so-fancy
        #
        # This either doesn't change ZI_TASKS entry - when
        # ___i is used in the ternary expression, or replaces
        # an entry with "<no-data>", i.e. ZI_TASKS[1] entry.
        integer ___idx1 ___idx2
        local ___ar2 ___ar3 ___ar4 ___ar5
        for (( ___idx1 = 0; ___idx1 <= 4; ___idx1 ++ )) {
          for (( ___idx2 = 1; ___idx2 <= (___idx >= 4 ? 1 : 3); ___idx2 ++ )) {
            # The following substitution could be just (well, 'just'..) this:
            #
            # ZI_TASKS=( ${ZI_TASKS[@]/(#b)([0-9]##)+([0-9]##)+([1-3])(*)/
            # ${ZI_TASKS[$(( (${match[1]}+${match[2]}) <= $___t ?
            # zi_scheduler_add(___i++, ${match[2]},
            # ${(M)match[3]%[1-3]}, ___idx1, ___idx2) : ___i++ ))]}} )
            #
            # However, there's a severe bug in Zsh <= 5.3.1 - use of the period
            # (,) is impossible inside ${..//$arr[$(( ... ))]}.
            ___i=2
            ZI_TASKS=( ${ZI_TASKS[@]/(#b)([0-9]##)+([0-9]##)+([1-3])(*)/${ZI_TASKS[
            $(( (___ar2=${match[2]}+1) ? (
              (___ar3=${(M)match[3]%[1-3]}) ? (
              (___ar4=___idx1+1) ? (
              (___ar5=___idx2) ? (
        (${match[1]}+${match[2]}) <= $___t ?
        zi_scheduler_add(___i++) : ___i++ )
              : 1 )
              : 1 )
              : 1 )
              : 1  ))]}} )
            ZI_TASKS=( "<no-data>" ${ZI_TASKS[@]:#<no-data>} )
          }
        }
      }
    }
  } else {
    add-zsh-hook -d -- precmd @zi-scheduler
    add-zsh-hook -- chpwd @zi-scheduler
    () {
      builtin emulate -L zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
      # No "+" in this pattern, it will match only "1531252764" in "1531252764+2" and replace it with current time.
      ZI_TASKS=( ${ZI_TASKS[@]/(#b)([0-9]##)(*)/$(( ${match[1]} <= 1 ? ${match[1]} : ___t ))${match[2]}} )
    }
    # There's a bug in Zsh: first sched call would not be issued until a key-press,
    # if "sched +1 ..." would be called inside zle -F handler. So it's done here, in precmd-handle code.
    sched +1 'ZI[lro-data]="$_:$?:${options[printexitvalue]}"; @zi-scheduler following ${ZI[lro-data]%:*:*}'

    AFD=13371337 # for older Zsh + noclobber option
    exec {AFD}< <(LANG=C command sleep 0.002; builtin print run;)
    command true # workaround a Zsh bug, see: http://www.zsh.org/mla/workers/2018/msg00966.html
    zle -F "$AFD" @zi-scheduler
  }

  local ___task ___idx=0 ___count=0 ___idx2
  # All wait'' objects.
  for ___task ( "${ZI_RUN[@]}" ) {
    .zi-run-task 1 "${(@z)___task}" && ZI_TASKS+=( "$___task" )
    if [[ $(( ++___idx, ___count += ${${REPLY:+1}:-0} )) -gt 0 && $1 != burst ]] {
      AFD=13371337 # for older Zsh + noclobber option
      exec {AFD}< <(LANG=C command sleep 0.0002; builtin print run;)
      command true
      # The $? and $_ will be left unchanged automatically by Zsh.
      zle -F "$AFD" @zi-scheduler
      break
    }
  }
  # All unload'' objects.
  for (( ___idx2=1; ___idx2 <= ___idx; ++ ___idx2 )) {
    .zi-run-task 2 "${(@z)ZI_RUN[___idx2-correct]}"
  }
  # All load'' & subscribe'' objects.
  for (( ___idx2=1; ___idx2 <= ___idx; ++ ___idx2 )) {
    .zi-run-task 3 "${(@z)ZI_RUN[___idx2-correct]}"
  }
  ZI_RUN[1-correct,___idx-correct]=()

  [[ ${ZI[lro-data]##*:} = on ]] && return 0 || return ___ret
} # ]]]

#
# Exposed functions.
#

# FUNCTION: zi. [[[
# Main function directly exposed to user, obtains subcommand and its arguments, has completion.
zi() {
  local -A ICE ZI_ICE
  ICE=( "${(kv)ZI_ICES[@]}" )
  ZI_ICE=( "${(kv)ICE[@]}" )
  ZI_ICES=()

  integer ___retval ___retval2 ___correct
  local -a match mbegin mend
  local MATCH cmd ___q="\`" ___q2="'" IFS=$' \t\n\0'; integer MBEGIN MEND

  # An annex's subcommand might use the reply vars.
  match=( ${ZI_EXTS[(I)z-annex subcommand:$1]} )
  if (( !${#match} )) {
    local -a reply; local REPLY
  }

  [[ -o ksharrays ]] && ___correct=1

  local -A ___opt_map OPTS
  ___opt_map=(
    -q         opt_-q,--quiet:"update:[Turn off almost-all messages from the {cmd}update{rst} operation {b-lhi}FOR the objects{rst} which don't have any {b-lhi}new version{rst} available.] *:[Turn off any (or: almost-any) messages from the operation.]"
    --quiet    opt_-q,--quiet
    -v         opt_-v,--verbose:"Turn on more messages from the operation."
    --verbose  opt_-v,--verbose
    -r         opt_-r,--reset:"Reset the repository before updating (or remove the files for single-file snippets and gh-r plugins)."
    --reset    opt_-r,--reset
    -a         opt_-a,--all:"delete:[Delete {hi}all{rst} plugins and snippets.] update:[Update {b-lhi}all{rst} plugins and snippets.]"
    --all      opt_-a,--all
    -c         opt_-c,--clean:"Delete {b-lhi}only{rst} the {b-lhi}currently-not loaded{rst} plugins and snippets."
    --clean    opt_-c,--clean
    -y         opt_-y,--yes:"Automatically confirm any yes/no prompts."
    --yes      opt_-y,--yes
    -f         opt_-f,--force:"Force new download of the snippet file."
    --force    opt_-f,--force
    -p         opt_-p,--parallel:"Turn on concurrent, multi-thread update (of all objects)."
    --parallel opt_-p,--parallel
    -s         opt_-s,--snippets:"snippets:[Update only snippets (i.e.: skip updating plugins).] times:[Show times in seconds instead of milliseconds.]"
    --snippets opt_-s,--snippets
    -L         opt_-l,--plugins:"Update only plugins (i.e.: skip updating snippets)."
    --plugins  opt_-l,--plugins
    -h         opt_-h,--help:"Show this help message."
    --help     opt_-h,--help
    -u         opt_-u,--urge:"Cause all the hooks like{ehi}:{rst} {ice}atpull{apo}''{rst}, {ice}cp{apo}''{rst}, etc. to execute even when there aren't any new commits {b}/{rst} any new version of the {b}{meta}gh-r{rst} file {b}/{rst} etc.{…} available for download {ehi}{lr}{rst} simulate a non-empty update."
    --urge     opt_-u,--urge
    -n         opt_-n,--no-pager:"Disable the use of the pager."
    --no-pager opt_-n,--no-pager
    -m         opt_-m,--moments:"Show the {apo}*{b-lhi}moments{apo}*{rst} of object (i.e.: a plugin or snippet) loading time."
    --moments  opt_-m,--moments
    -b         opt_-b,--bindkeys:"Load in light mode, however do still track {cmd}bindkey{rst} calls (to allow remapping the keys bound)."
    --bindkeys opt_-b,--bindkeys
    -x         opt_-x,--command:"Load the snippet as a {cmd}command{rst}, i.e.: add it to {var}\$PATH{rst} and set {b-lhi}+x{rst} on it."
    --command  opt_-x,--command
    env-whitelist "-h|--help|-v|--verbose"
    update        "-L|--plugins|-s|--snippets|-p|--parallel|-a|--all|-q|--quiet|-r|--reset|-u|--urge|-n|--no-pager|-v|--verbose|-h|--help"
    delete        "-a|--all|-c|--clean|-y|--yes|-q|--quiet|-h|--help"
    unload        "-h|--help|-q|--quiet"
    cdclear       "-h|--help|-q|--quiet"
    cdreplay      "-h|--help|-q|--quiet"
    times         "-h|--help|-m|-s|-a"
    light         "-h|--help|-b"
    snippet       "-h|--help|-f|--force|--command|-x"
  )

  cmd="$1"
  if [[ $cmd == (times|unload|env-whitelist|update|snippet|load|light|cdreplay|cdclear|delete) ]]; then
    if (( $@[(I)-*] || OPTS[opt_-h,--help] )); then
      .zi-parse-opts "$cmd" "$@"
      if (( OPTS[opt_-h,--help] )); then
        +zi-prehelp-usage-message $cmd $___opt_map[$cmd] $@
        return 1
      fi
    fi
  fi

  reply=( ${ZI_EXTS[(I)z-annex subcommand:*]} )

  [[ -n $1 && $1 != (${~ZI[cmd-list]}${reply:+|${(~j:|:)"${reply[@]#z-annex subcommand:}"}}) || $1 = (load|light|snippet) ]] && {
    integer ___error
    if [[ $1 = (load|light|snippet) ]] {
      integer  ___is_snippet
      # Classic syntax -> simulate a call through the for-syntax.
      () {
        builtin setopt localoptions extendedglob
        : ${@[@]//(#b)([ $'\t']##|(#s))(-b|--command|-f|--force)([ $'\t']##|(#e))/${OPTS[${match[2]}]::=1}}
      } "$@"
      builtin set -- "${@[@]:#(-b|--command|-f|--force)}"
      [[ $1 = light && -z ${OPTS[(I)-b]} ]] && ICE[light-mode]=
      [[ $1 = snippet ]] && ICE[is-snippet]= || ___is_snippet=-1
      shift

      ZI_ICES=( "${(kv)ICE[@]}" )
      ICE=() ZI_ICE=()
      1="${1:+@}${1#@}${2:+/$2}"
      (( $# > 1 )) && { shift -p $(( $# - 1 )); }
      [[ -z $1 ]] && {
        +zi-message "Argument needed, try: {cmd}help."
        return 1
      }
    } else {
      .zi-ice "$@"
      ___retval2=$?
      local ___last_ice=${@[___retval2]}
      shift ___retval2
      if [[ $# -gt 0 && $1 != for ]] {
        +zi-message -n "{b}{u-warn}ERROR{b-warn}:{rst} Unknown subcommand{ehi}:" "{apo}\`{cmd}$1{apo}\`{rst} "
        +zi-prehelp-usage-message rst
        return 1
      } elif (( $# == 0 )) {
        ___error=1
      } else {
        shift
      }
    }
    integer ___had_wait
    local ___id ___ehid ___etid ___key
    local -a ___arr
    ZI[annex-exposed-processed-IDs]=
    if (( $# )) {
      local -a ___ices
      ___ices=( "${(kv)ZI_ICES[@]}" )
      ZI_ICES=()
      while (( $# )) {
        .zi-ice "$@"
        ___retval2=$?
        local ___last_ice=${@[___retval2]}
        shift ___retval2
        if [[ -n $1 ]] {
          ICE=( "${___ices[@]}" "${(kv)ZI_ICES[@]}" )
          ZI_ICE=( "${(kv)ICE[@]}" ) ZI_ICES=()
          integer ___msgs=${+ICE[debug]}
          (( ___msgs )) && +zi-message "{profile}zi-main{ehi}:{faint} Processing {pname}$1{faint}{…}{rst}"
          # Delete up to the final space to get the previously-processed ID.
          ZI[annex-exposed-processed-IDs]+="${___id:+ $___id}"
          # Strip the ID-qualifier (`@') and GitHub domain from the ID.
          ___id="${${1#@}%%(///|//|/)}"
          (( ___is_snippet == -1 )) && ___id="${___id#https://github.com/}"
          # Effective handle-ID – the label under which the object will be identified / referred-to by ZI.
          ___ehid="${ICE[id-as]:-$___id}"
          # Effective remote-ID (i.e.: URL, GitHub username/repo, package name, etc.). teleid'' allows "overriding" of $1.
          # In case of a package using teleid'', the value here is being took from the given ices, before disk-ices.
          ___etid="${ICE[teleid]:-$___id}"
          if (( ${+ICE[pack]} )); then
            ___had_wait=${+ICE[wait]}
            .zi-load-ices "$___ehid"
            # wait'' isn't possible via the disk-ices (for packages), only via the command's ice-spec.
            [[ $___had_wait -eq 0 ]] && unset 'ICE[wait]'
          fi
          [[ ${ICE[id-as]} = (auto|) && ${+ICE[id-as]} == 1 ]] && ICE[id-as]="${___etid:t}"
          integer  ___is_snippet=${${(M)___is_snippet:#-1}:-0}
          () {
            builtin setopt localoptions extendedglob
            if [[ $___is_snippet -ge 0 && ( -n ${ICE[is-snippet]+1} || $___etid = ((#i)(http(s|)|ftp(s|)):/|(${(~kj.|.)ZI_1MAP}))* ) ]] {
              ___is_snippet=1
            }
          } "$@"
          local ___type=${${${(M)___is_snippet:#1}:+snippet}:-plugin}
          reply=(
            ${(on)ZI_EXTS2[(I)zi hook:before-load-pre <->]}
            ${(on)ZI_EXTS[(I)z-annex hook:before-load-<-> <->]}
            ${(on)ZI_EXTS2[(I)zi hook:before-load-post <->]}
          )
          for ___key in "${reply[@]}"; do
            ___arr=( "${(Q)${(z@)ZI_EXTS[$___key]:-$ZI_EXTS2[$___key]}[@]}" )
            "${___arr[5]}" "$___type" "$___id" "${ICE[id_as]}" \
              "${(j: :)${(q)@[2,-1]}}" "${(j: :)${(qkv)___ices[@]}}" \
              "${${___key##(zi|z-annex) hook:}%% <->}" load
            ___retval2=$?
            if (( ___retval2 )) {
              # An error is actually only an odd return code.
              ___retval+=$(( ___retval2 & 1 ? ___retval2 : 0 ))
              (( ___retval2 & 1 && $# )) && shift
              # Override $@?
              if (( ___retval2 & 2 )) {
                local -a ___args
                ___args=( "${(@Q)${(@z)ZI[annex-before-load:new-@]}}" )
                builtin set -- "${___args[@]}"
              }
              # Override $___ices?
              if (( ___retval2 & 4 )) {
                local -a ___new_ices
                ___new_ices=( "${(Q@)${(@z)ZI[annex-before-load:new-global-ices]}}" )
                (( 0 == ${#___new_ices} % 2 )) && \
                  ___ices=( "${___new_ices[@]}" ) || \
                    { [[ ${ZI[MUTE_WARNINGS]} != (1|true|on|yes) ]] && \
                      +zi-message "{u-warn}Warning{b-warn}:{msg} Bad new-ices returned" \
                        "from the annex{ehi}:{rst} {annex}${___arr[3]}{msg}," \
                        "please file an issue report at:{url}" "https://github.com/z-shell/${___arr[3]}/issues/new{msg}.{rst}"
                      ___ices=(  ) ___retval+=7
                    }
              }
              continue 2
            }
          done
          integer ___action_load=0 ___turbo=0
          if [[ -n ${(M)${+ICE[wait]}:#1}${ICE[load]}${ICE[unload]}${ICE[service]}${ICE[subscribe]} ]] {
            ___turbo=1
          }

          if [[ -n ${ICE[trigger-load]} || ( ${+ICE[wait]} == 1 && ${ICE[wait]} = (\!|)(<->(a|b|c|)|) ) ]] && (( !ZI[OPTIMIZE_OUT_DISK_ACCESSES] )) {
            if (( ___is_snippet > 0 )) {
              .zi-get-object-path snippet $___ehid
            } else {
              .zi-get-object-path plugin $___ehid
            }
            (( $? )) && [[ ${zsh_eval_context[1]} = file ]] && { ___action_load=1; }
            local ___object_path="$REPLY"
          } elif (( ! ___turbo )) {
            ___action_load=1
            reply=( 1 )
          } else {
            reply=( 1 )
          }

          if [[ ${reply[-1]} -eq 1 && -n ${ICE[trigger-load]} ]] {
            () {
              builtin setopt localoptions extendedglob
              local ___mode
              (( ___is_snippet > 0 )) && ___mode=snippet || ___mode="${${${ICE[light-mode]+light}}:-load}"
              for MATCH ( ${(s.;.)ICE[trigger-load]} ) {
                eval "${MATCH#!}() {
                  ${${(M)MATCH#!}:+unset -f ${MATCH#!}}
                  local a b; local -a ices
                  # The wait'' ice is filtered-out.
                  for a b ( ${(qqkv@)${(kv@)ICE[(I)^(trigger-load|wait|light-mode)]}} ) {
                    ices+=( \"\$a\$b\" )
                  }
                  zi ice \${ices[@]}; zi $___mode ${(qqq)___id}
                  ${${(M)MATCH#!}:+# Forward the call
                  eval ${MATCH#!} \$@}
                }"
              }
            } "$@"
            ___retval+=$?
            (( $# )) && shift
            continue
          }

          if (( ${+ICE[if]} )) {
            eval "${ICE[if]}" || { (( $# )) && shift; continue; };
          }
          for REPLY ( ${(s.;.)ICE[has]} ) {
            (( ${+commands[$REPLY]} )) || { (( $# )) && shift; continue 2; }
          }

          integer ___had_cloneonly=0
          ICE[wait]="${${(M)${+ICE[wait]}:#1}:+${(M)ICE[wait]#!}${${ICE[wait]#!}:-0}}"
          if (( ___action_load || !ZI[HAVE_SCHEDULER] )) {
            if (( ___turbo && ZI[HAVE_SCHEDULER] )) {
              ___had_cloneonly=${+ICE[cloneonly]}
              ICE[cloneonly]=""
            }

            (( ___is_snippet )) && local ___opt="${(k)OPTS[*]}" || local ___opt="${${ICE[light-mode]+light}:-${OPTS[(I)-b]:+light-b}}"

            .zi-load-object ${${${(M)___is_snippet:#1}:+snippet}:-plugin} $___id $___opt
            integer ___last_retval=$?
            ___retval+=___last_retval

            if (( ___turbo && !___had_cloneonly && ZI[HAVE_SCHEDULER] )) {
              command rm -f $___object_path/._zi/cloneonly
              unset 'ICE[cloneonly]'
            }
          }
          if (( ___turbo && ZI[HAVE_SCHEDULER] && 0 == ___last_retval )) {
            ICE[wait]="${ICE[wait]:-${ICE[service]:+0}}"
            if (( ___is_snippet > 0 )); then
              ZI_SICE[$___ehid]=
              .zi-submit-turbo s${ICE[service]:+1} "" "$___id" "${(k)OPTS[*]}"
            else
              ZI_SICE[$___ehid]=
              .zi-submit-turbo p${ICE[service]:+1} "${${${ICE[light-mode]+light}}:-load}" "$___id" ""
            fi
            ___retval+=$?
          }
        } else {
          ___error=1
        }
        (( $# )) && shift
        ___is_snippet=0
      }
    } else {
      ___error=1
    }

    if (( ___error )) {
      () {
        builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
        +zi-message -n "{u-warn}Error{b-warn}:{rst} No plugin or snippet ID given"
        if [[ -n $___last_ice ]] {
          +zi-message -n " (the last recognized ice was: {ice}"\
          "${___last_ice/(#m)(${~ZI[ice-list]})/"{data}$MATCH"}{apo}''{rst}).{error}
          You can try to prepend {apo}${___q}{lhi}@{apo}'{error} to the ID if the last ice is in fact a plugin.{rst}
          {note}Note:{rst} The {apo}\`{ice}ice{apo}\`{rst} subcommand is now again required if not using the for-syntax"
        }
        +zi-message "."
      }
      return 2
    } elif (( ! $# )) {
      return ___retval
    }
  }

  case "$1" in
    (ice)
      shift
      .zi-ice "$@"
      ;;
    (cdreplay)
      .zi-compdef-replay "$2"; ___retval=$?
      ;;
    (cdclear)
      .zi-compdef-clear "$2"
      ;;
    (add-fpath)
      .zi-add-fpath "${@[2-correct,-1]}"
      ;;
    (run)
      .zi-run "${@[2-correct,-1]}"
      ;;
    (dstart|dtrace)
      (( ${+functions[.zi-service]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/additional.zsh"
      .zi-debug-start
      ;;
    (dstop)
      (( ${+functions[.zi-service]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/additional.zsh"
      .zi-debug-stop
      ;;
    (man)
      man "${ZI[BIN_DIR]}/docs/man/zi.1"
      ;;
    (env-whitelist)
      shift
      .zi-parse-opts env-whitelist "$@"
      builtin set -- "${reply[@]}"

      if (( $# == 0 )) {
        ZI[ENV-WHITELIST]=
        (( OPTS[opt_-v,--verbose] )) && +zi-message "{msg2}Cleared the parameter whitelist.{rst}"
      } else {
        ZI[ENV-WHITELIST]+="${(j: :)${(q-kv)@}} "
        local ___sep="$ZI[col-msg2], $ZI[col-data2]"
        (( OPTS[opt_-v,--verbose] )) && +zi-message "{msg2}Extended the parameter whitelist with: {data2}${(pj:$___sep:)@}{msg2}.{rst}"
      }
      ;;
    (*)
      # Check if there is a z-annex registered for the subcommand.
      reply=( ${ZI_EXTS[z-annex subcommand:${(q)1}]} )
      (( ${#reply} )) && {
        reply=( "${(Q)${(z@)reply[1]}[@]}" )
        (( ${+functions[${reply[5]}]} )) && { "${reply[5]}" "$@"; return $?; } || \
          { +zi-message "({error}Couldn't find the subcommand-handler \`{obj}${reply[5]}{error}' of the z-annex \`{file}${reply[3]}{error}')"; return 1; }
      }
      (( ${+functions[.zi-confirm]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/autoload.zsh" || return 1
      case "$1" in
        (zstatus)
          .zi-show-zstatus
          ;;
        (times)
          .zi-show-times "${@[2-correct,-1]}"
          ;;
        (self-update)
          .zi-self-update
          ;;
        (unload)
          (( ${+functions[.zi-unload]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/autoload.zsh" || return 1
          if [[ -z $2 && -z $3 ]]; then
            builtin print "Argument needed, try: help"; ___retval=1
          else
            [[ $2 = -q ]] && { 5=-q; shift; }
            # Unload given plugin. Cloned directory remains intact so as are completions.
            .zi-unload "${2%%(///|//|/)}" "${${3:#-q}%%(///|//|/)}" "${${(M)4:#-q}:-${(M)3:#-q}}"; ___retval=$?
          fi
          ;;
        (bindkeys)
          .zi-list-bindkeys
          ;;
        (update)
          if (( ${+ICE[if]} )) {
            eval "${ICE[if]}" || return 1
          }
          for REPLY ( ${(s.;.)ICE[has]} ) {
            (( ${+commands[$REPLY]} )) || return 1
          }
          shift
          .zi-parse-opts update "$@"
          builtin set -- "${reply[@]}"
          if [[ ${OPTS[opt_-a,--all]} -eq 1 || ${OPTS[opt_-p,--parallel]} -eq 1 || ${OPTS[opt_-s,--snippets]} -eq 1 || ${OPTS[opt_-l,--plugins]} -eq 1 || -z $1$2${ICE[teleid]}${ICE[id-as]} ]]; then
            [[ -z $1$2 && $(( OPTS[opt_-a,--all] + OPTS[opt_-p,--parallel] + OPTS[opt_-s,--snippets] + OPTS[opt_-l,--plugins] )) -eq 0 ]] && { builtin print -r -- "Assuming --all is passed"; sleep 3; }
            (( OPTS[opt_-p,--parallel] )) && OPTS[value]=${1:-15}
            .zi-update-or-status-all update; ___retval=$?
          else
            local ___key ___id="${1%%(///|//|/)}${2:+/}${2%%(///|//|/)}"
            [[ -z ${___id//[[:space:]]/} ]] && ___id="${ICE[id-as]:-$ICE[teleid]}"
            .zi-update-or-status update "$___id" ""; ___retval=$?
          fi
          ;;
        (status)
          if [[ $2 = --all || ( -z $2 && -z $3 ) ]]; then
            [[ -z $2 ]] && { builtin print -r -- "Assuming --all is passed"; sleep 3; }
            .zi-update-or-status-all status; ___retval=$?
          else
            .zi-update-or-status status "${2%%(///|//|/)}" "${3%%(///|//|/)}"; ___retval=$?
          fi
          ;;
        (report)
          if [[ $2 = --all || ( -z $2 && -z $3 ) ]]; then
            [[ -z $2 ]] && { builtin print -r -- "Assuming --all is passed"; sleep 4; }
          .zi-show-all-reports
          else
            .zi-show-report "${2%%(///|//|/)}" "${3%%(///|//|/)}"; ___retval=$?
          fi
          ;;
        (loaded|list)
          # Show list of loaded plugins.
          .zi-show-registered-plugins "$2"
          ;;
        (clist|completions)
          # Show installed, enabled or disabled, completions.
          # Detect stray and improper ones.
          .zi-show-completions "$2"
          ;;
        (cclear)
          # Delete stray and improper completions.
          .zi-clear-completions
          ;;
        (cdisable)
          if [[ -z $2 ]]; then
            builtin print "Argument needed, try: help"; ___retval=1
          else
            local ___f="_${2#_}"
            # Disable completion given by completion function name with or without leading _, e.g. cp, _cp.
            if .zi-cdisable "$___f"; then
              (( ${+functions[.zi-forget-completion]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
              .zi-forget-completion "$___f"
              +zi-message "Initializing completion system ({func}compinit{rst}){…}"
              builtin autoload -Uz compinit
              compinit -d "${ZI[ZCOMPDUMP_PATH]}" "${(Q@)${(z@)ZI[COMPINIT_OPTS]}}"
            else
              ___retval=1
            fi
          fi
          ;;
        (cenable)
          if [[ -z $2 ]]; then
            builtin print "Argument needed, try: help"; ___retval=1
          else
            local ___f="_${2#_}"
            # Enable completion given by completion function name
            # with or without leading _, e.g. cp, _cp.
            if .zi-cenable "$___f"; then
              (( ${+functions[.zi-forget-completion]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
              .zi-forget-completion "$___f"
              +zi-message "Initializing completion system ({func}compinit{rst}){…}"
              builtin autoload -Uz compinit
              compinit -d "${ZI[ZCOMPDUMP_PATH]}" "${(Q@)${(z@)ZI[COMPINIT_OPTS]}}"
            else
              ___retval=1
            fi
          fi
          ;;
        (creinstall)
          (( ${+functions[.zi-install-completions]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
          # Installs completions for plugin. Enables them all. It is a
          # reinstallation, thus every obstacle gets overwritten or removed.
          [[ $2 = -[qQ] ]] && { 5=$2; shift; }
          .zi-install-completions "${2%%(///|//|/)}" "${3%%(///|//|/)}" 1 "${(M)4:#-[qQ]}"; ___retval=$?
          [[ -z ${(M)4:#-[qQ]} ]] && +zi-message "Initializing completion ({func}compinit{rst}){…}"
          builtin autoload -Uz compinit
          compinit -d "${ZI[ZCOMPDUMP_PATH]}" "${(Q@)${(z@)ZI[COMPINIT_OPTS]}}"
          ;;
        (cuninstall)
          if [[ -z $2 && -z $3 ]]; then
            builtin print "Argument needed, try: help"; ___retval=1
          else
            (( ${+functions[.zi-forget-completion]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
            # Uninstalls completions for plugin.
            .zi-uninstall-completions "${2%%(///|//|/)}" "${3%%(///|//|/)}"; ___retval=$?
            +zi-message "Initializing completion ({func}compinit{rst}){…}"
            builtin autoload -Uz compinit
            compinit -d "${ZI[ZCOMPDUMP_PATH]}" "${(Q@)${(z@)ZI[COMPINIT_OPTS]}}"
          fi
          ;;
        (csearch)
          .zi-search-completions
          ;;
        (compinit)
          (( ${+functions[.zi-forget-completion]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
          .zi-compinit; ___retval=$?
          ;;
        (dreport)
          .zi-show-debug-report
          ;;
        (dclear)
          (( ${+functions[.zi-service]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/additional.zsh"
          .zi-clear-debug-report
          ;;
        (dunload)
          (( ${+functions[.zi-service]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/additional.zsh"
          .zi-debug-unload
          ;;
        (compile)
          (( ${+functions[.zi-compile-plugin]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/install.zsh" || return 1
          if [[ $2 = --all || ( -z $2 && -z $3 ) ]]; then
            [[ -z $2 ]] && { builtin print -r -- "Assuming --all is passed"; sleep 3; }
            .zi-compile-uncompile-all 1; ___retval=$?
          else
            .zi-compile-plugin "${2%%(///|//|/)}" "${3%%(///|//|/)}"; ___retval=$?
          fi
          ;;
        (uncompile)
          if [[ $2 = --all || ( -z $2 && -z $3 ) ]]; then
            [[ -z $2 ]] && { builtin print -r -- "Assuming --all is passed"; sleep 3; }
            .zi-compile-uncompile-all 0; ___retval=$?
          else
            .zi-uncompile-plugin "${2%%(///|//|/)}" "${3%%(///|//|/)}"; ___retval=$?
          fi
          ;;
        (compiled)
          .zi-compiled
          ;;
        (cdlist)
          .zi-list-compdef-replay
          ;;
        (cd|delete|recall|edit|glance|changes|create|stress)
          .zi-"$1" "${@[2-correct,-1]%%(///|//|/)}"; ___retval=$?
          ;;
        (recently)
          shift
          .zi-recently "$@"; ___retval=$?
          ;;
        (subcmds)
          .zi-registered-subcommands
          ;;
        (icemods)
          .zi-registered-ice-mods
          ;;
        (analytics)
          .zi-analytics-menu
          ;;
        (-h|--help|help)
          .zi-help
          ;;
        (ls)
          shift
          .zi-ls "$@"
          ;;
        (srv)
          () { builtin setopt localoptions extendedglob warncreateglobal
          [[ ! -e ${ZI[SERVICES_DIR]}/"$2".fifo ]] && { builtin print "No such service: $2"; } ||
            { [[ $3 = (#i)(next|stop|quit|restart) ]] &&
              { builtin print "${(U)3}" >>! ${ZI[SERVICES_DIR]}/"$2".fifo || builtin print "Service $2 inactive"; ___retval=1; } ||
                { [[ $3 = (#i)start ]] && rm -f ${ZI[SERVICES_DIR]}/"$2".stop ||
                  { builtin print "Unknown service-command: $3"; ___retval=1; }
                }
            }
          } "$@"
          ;;
        (module)
          .zi-module "${@[2-correct,-1]}"; ___retval=$?
          ;;
        (*)
          if [[ -z $1 ]] {
            +zi-message -n "{b}{u-warn}ERROR{b-warn}:{rst} Missing a {cmd}subcommand "
            +zi-prehelp-usage-message rst
          } else {
            +zi-message -n "{b}{u-warn}ERROR{b-warn}:{rst} Unknown subcommand{ehi}:{rst}" "{apo}\`{error}$1{apo}\`{rst} "
            +zi-prehelp-usage-message rst
          }
          ___retval=1
          ;;
      esac
      ;;
  esac

  return ___retval
} # ]]]
# FUNCTION: zicdreplay. [[[
# A function that can be invoked from within `atinit', `atload', etc. ice-mod.
# It works like `zi cdreplay', which cannot be invoked from such hook ices.
zicdreplay() { .zi-compdef-replay -q; }
# ]]]
# FUNCTION: zicdclear. [[[
# A wrapper for `zi cdclear -q' which can be called from hook ices like the atinit'', atload'', etc. ices.
zicdclear() { .zi-compdef-clear -q; }
# ]]]
# FUNCTION: zicompinit. [[[
# A function that can be invoked from within `atinit', `atload', etc. ice-mod.
# It runs `autoload compinit; compinit' and respects
# ZI[ZCOMPDUMP_PATH] and ZI[COMPINIT_OPTS].
zicompinit() { autoload -Uz compinit; compinit -d "${ZI[ZCOMPDUMP_PATH]}" "${(Q@)${(z@)ZI[COMPINIT_OPTS]}}"; }
# ]]]
# FUNCTION: zicompinit_fast. [[[
# Checking the cached .zcompdump file to see if it must be regenerated adds a noticable delay to zsh startup.
# This restricts checking it once a day, determines when to regenerate, as compinit doesn't always need to
# modify the compdump and compiles mapped to share (total mem reduction) run in background in multiple shells.
# A function that can be invoked from within `atinit', `atload'
zicompinit_fast() {
  autoload -Uz compinit
  local zcompf="${ZI[ZCOMPDUMP_PATH]}"
  #local check_ub="$(awk -F= '/^NAME/{print $2}' /etc/os-release | grep 'Ubuntu')"
  local zcompf_a="${zcompf}.augur"
  #[[ $check_ub ]] && export skip_global_compinit=1

  # Globbing (#qN.mh+24):
  # - '#q' is an explicit glob qualifier that makes globbing work within zsh's [[ ]] construct.
  # - 'N' makes the glob pattern evaluate to nothing when it doesn't match (rather than throw a globbing error)
  # - '.' matches "regular files"
  # - 'mh+24' matches files, directories and etc., that are older than 24 hours.
  if [[ -e "$zcompf_a" && -f "$zcompf_a"(#qN.mh+24) ]]; then
    compinit -d "$zcompf"
    command touch "$zcompf_a"
  else
    compinit -C -d "$zcompf"
  fi
  # if .zcompdump exists (and is non-zero), and is older than the .zwc file, then regenerate
  if [[ -s "$zcompf" && (! -s "${zcompf}.zwc" || "$zcompf" -nt "${zcompf}.zwc") ]]; then
    # since file is mapped, it might be mapped right now (current shells), so rename it then make a new one
    [[ -e "$zcompf.zwc" ]] && command mv -f "$zcompf.zwc" "$zcompf.zwc.old"
    # compile it mapped, so multiple shells can share it (total mem reduction) run in background
    { zcompile -M "$zcompf" && command rm -f "$zcompf.zwc.old" }&!
  fi
}
# ]]]
# FUNCTION: zicompdef. [[[
# Stores compdef for a replay with `zicdreplay' (turbo mode) or with `zi cdreplay' (normal mode).
# An utility function of an undefined use case.
zicompdef() { ZI_COMPDEF_REPLAY+=( "${(j: :)${(q)@}}" ); }
# ]]]
# FUNCTION: @autoload. [[[
@autoload() {
  :zi-tmp-subst-autoload -Uz ${(s: :)${${(j: :)${@#\!}}//(#b)((*)(->|=>|→)(*)|(*))/${match[2]:+$match[2] -S $match[4]}${match[5]:+${match[5]} -S ${match[5]}}}} ${${${(@M)${@#\!}:#*(->|=>|→)*}}:+-C} ${${@#\!}:+-C}
} # ]]]
# FUNCTION: zi-turbo. [[[
# With zi-turbo first argument is a wait time and suffix, i.e. "0a".
# Anything that doesn't match will be passed as if it were an ice mod.
# Default ices depth'3' and lucid, allowed values [0-9][a-c].
zi-turbo() { zi depth'3' lucid ${1/#[0-9][a-c]/wait"${1}"} "${@:2}"; }
# ]]]
# Compatibility functions. [[[
❮▼❯() { zi "$@"; }
zpcdreplay() { .zi-compdef-replay -q; }
zpcdclear() { .zi-compdef-clear -q; }
zpcompinit() { autoload -Uz compinit; compinit -d "${ZI[ZCOMPDUMP_PATH]}" "${(Q@)${(z@)ZI[COMPINIT_OPTS]}}"; }
zpcompdef() { ZI_COMPDEF_REPLAY+=( "${(j: :)${(q)@}}" ); }

#
# Source-executed code.
#

(( ZI[ALIASES_OPT] )) && builtin setopt aliases
(( ZI[SOURCED] ++ )) && return

autoload add-zsh-hook
if { zmodload zsh/datetime } {
  add-zsh-hook -- precmd @zi-scheduler  # zsh/datetime required for wait/load/unload ice-mods
  ZI[HAVE_SCHEDULER]=1
}
functions -M -- zi_scheduler_add 1 1 -zi_scheduler_add_sh 2>/dev/null
zmodload zsh/zpty zsh/system 2>/dev/null
zmodload -F zsh/stat b:zstat 2>/dev/null && ZI[HAVE_ZSTAT]=1

# code. [[[
builtin alias zini=zi zinit=zi zplugin=zi

.zi-prepare-home

# Remember source's timestamps for the automatic-reload feature.
typeset -g ZI_TMP
.zi-get-mtime-into "${ZI[BIN_DIR]}/zi.zsh" "ZI[mtime]"
for ZI_TMP ( side install autoload ) {
  .zi-get-mtime-into "${ZI[BIN_DIR]}/lib/zsh/${ZI_TMP}.zsh" "ZI[mtime-${ZI_TMP}]"
}

# Simulate existence of _local/zi plugin. This will allow to cuninstall of its completion
ZI_REGISTERED_PLUGINS=( _local/zi "${(u)ZI_REGISTERED_PLUGINS[@]:#_local/zi}" )
ZI[STATES___local/zi]=1

# Inform Prezto that the compdef function is available.
zstyle ':prezto:module:completion' loaded 1

# Colorize completions for commands unload, report, creinstall, cuninstall.
zstyle ':completion:*:zi:argument-rest:plugins' list-colors '=(#b)(*)/(*)==1;34=1;33'
zstyle ':completion:*:zi:argument-rest:plugins' matcher 'r:|=** l:|=*'
zstyle ':completion:*:*:zi:*' group-name ""
# ]]]
# Check module built / compile status [[[
if [[ -e "${ZI[ZMODULES_DIR]}/zpmod/Src/zi/zpmod.so" ]]; then
  if [[ ! -f ${ZI[ZMODULES_DIR]}/zpmod/COMPILED_AT || \
  ( ${ZI[ZMODULES_DIR]}/zpmod/COMPILED_AT -ot ${ZI[ZMODULES_DIR]}/zpmod/RECOMPILE_REQUEST ) ]]; then
    (( ${+functions[.zi-check-module]} )) || builtin source "${ZI[BIN_DIR]}/lib/zsh/side.zsh" || return 1
    .zi-check-module
  fi
fi # ]]]

# !atpull-pre.
@zi-register-hook "-r/--reset" hook:e-\!atpull-pre ∞zi-reset-hook
# !atpull-post.
@zi-register-hook "ICE[reset]" hook:e-\!atpull-post ∞zi-reset-hook
@zi-register-hook "atpull'!'" hook:e-\!atpull-post ∞zi-atpull-e-hook
# e-!atpull-pre.
@zi-register-hook "make'!!'" hook:no-e-\!atpull-pre ∞zi-make-ee-hook
@zi-register-hook "mv''" hook:no-e-\!atpull-pre ∞zi-mv-hook
@zi-register-hook "cp''" hook:no-e-\!atpull-pre ∞zi-cp-hook
@zi-register-hook "compile-plugin" hook:no-e-\!atpull-pre ∞zi-compile-plugin-hook
# no-e-!atpull-post.
@zi-register-hook "make'!'" hook:no-e-\!atpull-post ∞zi-make-e-hook
@zi-register-hook "atpull" hook:no-e-\!atpull-post ∞zi-atpull-hook
@zi-register-hook "make''" hook:no-e-\!atpull-post ∞zi-make-hook
@zi-register-hook "extract" hook:atpull-post ∞zi-extract-hook
# atpull-post.
@zi-register-hook "compile-plugin" hook:atpull-post ∞zi-compile-plugin-hook
@zi-register-hook "ps-on-update" hook:%atpull-post ∞zi-ps-on-update-hook
# !atclone-pre.
@zi-register-hook "make'!!'" hook:\!atclone-pre ∞zi-make-ee-hook
@zi-register-hook "mv''" hook:\!atclone-pre ∞zi-mv-hook
@zi-register-hook "cp''" hook:\!atclone-pre ∞zi-cp-hook
@zi-register-hook "compile-plugin" hook:\!atclone-pre ∞zi-compile-plugin-hook
# !atclone-post.
@zi-register-hook "make'!'" hook:\!atclone-post ∞zi-make-e-hook
@zi-register-hook "atclone" hook:\!atclone-post ∞zi-atclone-hook
@zi-register-hook "make''" hook:\!atclone-post ∞zi-make-hook
@zi-register-hook "extract" hook:\!atclone-post ∞zi-extract-hook
# atclone-post.
@zi-register-hook "compile-plugin" hook:atclone-post ∞zi-compile-plugin-hook
typeset -g REPLY
