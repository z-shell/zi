# Copyright (c) 2016-2020 Sebastian Gniazdowski and contributors.
# Copyright (c) 2021 Salvydas Lukosius and Z-Shell ZI contributors.

builtin source "${ZI[BIN_DIR]}/lib/zsh/side.zsh" || { builtin print -P "${ZI[col-error]}ERROR:%f%b Couldn't find ${ZI[col-obj]}/lib/zsh/side.zsh%f%b."; return 1; }
ZI[EXTENDED_GLOB]=""

#
# Backend, low level functions
#

# FUNCTION: .zi-unregister-plugin [[[
# Removes the plugin from ZI_REGISTERED_PLUGINS array and from the
# zsh_loaded_plugins array (managed according to the plugin standard)
.zi-unregister-plugin() {
  .zi-any-to-user-plugin "$1" "$2"
  local uspl2="${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]}" teleid="$3"
  # If not found, the index will be length+1
  ZI_REGISTERED_PLUGINS[${ZI_REGISTERED_PLUGINS[(i)$uspl2]}]=()
  # Support Zsh plugin standard
  zsh_loaded_plugins[${zsh_loaded_plugins[(i)$teleid]}]=()
  ZI[STATES__$uspl2]="0"
} # ]]]
# FUNCTION: .zi-diff-functions-compute [[[
# Computes FUNCTIONS that holds new functions added by plugin.
# Uses data gathered earlier by .zi-diff-functions().
#
# $1 - user/plugin
.zi-diff-functions-compute() {
  local uspl2="$1"
  # Cannot run diff if *_BEFORE or *_AFTER variable is not set
  # Following is paranoid for *_BEFORE and *_AFTER being only spaces
  builtin setopt localoptions extendedglob nokshglob noksharrays
  [[ "${ZI[FUNCTIONS_BEFORE__$uspl2]}" != *[$'! \t']* || "${ZI[FUNCTIONS_AFTER__$uspl2]}" != *[$'! \t']* ]] && return 1
  typeset -A func
  local i
  # This includes new functions. Quoting is kept (i.e. no i=${(Q)i})
  for i in "${(z)ZI[FUNCTIONS_AFTER__$uspl2]}"; do
    func[$i]=1
  done
  # Remove duplicated entries, i.e. existing before. Quoting is kept
  for i in "${(z)ZI[FUNCTIONS_BEFORE__$uspl2]}"; do
    # if would do unset, then: func[opp+a\[]: invalid parameter name
    func[$i]=0
  done
  # Store the functions, associating them with plugin ($uspl2)
  ZI[FUNCTIONS__$uspl2]=""
  for i in "${(onk)func[@]}"; do
    [[ "${func[$i]}" = "1" ]] && ZI[FUNCTIONS__$uspl2]+="$i "
  done
  return 0
} # ]]]
# FUNCTION: .zi-diff-options-compute [[[
# Computes OPTIONS that holds options changed by plugin.
# Uses data gathered earlier by .zi-diff-options().
#
# $1 - user/plugin
.zi-diff-options-compute() {
  local uspl2="$1"
  # Cannot run diff if *_BEFORE or *_AFTER variable is not set
  # Following is paranoid for *_BEFORE and *_AFTER being only spaces
  builtin setopt localoptions extendedglob nokshglob noksharrays
  [[ "${ZI[OPTIONS_BEFORE__$uspl2]}" != *[$'! \t']* || "${ZI[OPTIONS_AFTER__$uspl2]}" != *[$'! \t']* ]] && return 1
  typeset -A opts_before opts_after opts
  opts_before=( "${(z)ZI[OPTIONS_BEFORE__$uspl2]}" )
  opts_after=( "${(z)ZI[OPTIONS_AFTER__$uspl2]}" )
  opts=( )
  # Iterate through first array (keys the same
  # on both of them though) and test for a change
  local key
  for key in "${(k)opts_before[@]}"; do
  if [[ "${opts_before[$key]}" != "${opts_after[$key]}" ]]; then
    opts[$key]="${opts_before[$key]}"
  fi
  done
  # Serialize for reporting
  local IFS=" "
  ZI[OPTIONS__$uspl2]="${(kv)opts[@]}"
  return 0
} # ]]]
# FUNCTION: .zi-diff-env-compute [[[
# Computes ZI_PATH, ZI_FPATH that hold (f)path components
# added by plugin. Uses data gathered earlier by .zi-diff-env().
#
# $1 - user/plugin
.zi-diff-env-compute() {
  local uspl2="$1"
  typeset -a tmp
  # Cannot run diff if *_BEFORE or *_AFTER variable is not set
  # Following is paranoid for *_BEFORE and *_AFTER being only spaces
  builtin setopt localoptions extendedglob nokshglob noksharrays
  [[ "${ZI[PATH_BEFORE__$uspl2]}" != *[$'! \t']* || "${ZI[PATH_AFTER__$uspl2]}" != *[$'! \t']* ]] && return 1
  [[ "${ZI[FPATH_BEFORE__$uspl2]}" != *[$'! \t']* || "${ZI[FPATH_AFTER__$uspl2]}" != *[$'! \t']* ]] && return 1
  typeset -A path_state fpath_state
  local i
  #
  # PATH processing
  #
  # This includes new path elements
  for i in "${(z)ZI[PATH_AFTER__$uspl2]}"; do
    path_state[${(Q)i}]=1
  done
  # Remove duplicated entries, i.e. existing before
  for i in "${(z)ZI[PATH_BEFORE__$uspl2]}"; do
    unset "path_state[${(Q)i}]"
  done
  # Store the path elements, associating them with plugin ($uspl2)
  ZI[PATH__$uspl2]=""
  for i in "${(onk)path_state[@]}"; do
    ZI[PATH__$uspl2]+="${(q)i} "
  done
  #
  # FPATH processing
  #
  # This includes new path elements
  for i in "${(z)ZI[FPATH_AFTER__$uspl2]}"; do
    fpath_state[${(Q)i}]=1
  done
  # Remove duplicated entries, i.e. existing before
  for i in "${(z)ZI[FPATH_BEFORE__$uspl2]}"; do
    unset "fpath_state[${(Q)i}]"
  done
  # Store the path elements, associating them with plugin ($uspl2)
  ZI[FPATH__$uspl2]=""
  for i in "${(onk)fpath_state[@]}"; do
    ZI[FPATH__$uspl2]+="${(q)i} "
  done
  return 0
} # ]]]
# FUNCTION: .zi-diff-parameter-compute [[[
# Computes ZI_PARAMETERS_PRE, ZI_PARAMETERS_POST that hold
# parameters created or changed (their type) by plugin. Uses
# data gathered earlier by .zi-diff-parameter().
#
# $1 - user/plugin
.zi-diff-parameter-compute() {
  local uspl2="$1"
  typeset -a tmp
  # Cannot run diff if *_BEFORE or *_AFTER variable is not set
  # Following is paranoid for *_BEFORE and *_AFTER being only spaces
  builtin setopt localoptions extendedglob nokshglob noksharrays
  [[ "${ZI[PARAMETERS_BEFORE__$uspl2]}" != *[$'! \t']* || "${ZI[PARAMETERS_AFTER__$uspl2]}" != *[$'! \t']* ]] && return 1
  # Un-concatenated parameters from moment of diff start and of diff end
  typeset -A params_before params_after
  params_before=( "${(z)ZI[PARAMETERS_BEFORE__$uspl2]}" )
  params_after=( "${(z)ZI[PARAMETERS_AFTER__$uspl2]}" )
  # The parameters that changed, with save of what
  # parameter was when diff started or when diff ended
  typeset -A params_pre params_post
  params_pre=( )
  params_post=( )
  # Iterate through all existing keys, before or after diff,
  # i.e. after all variables that were somehow live across
  # the diffing process
  local key
  typeset -aU keys
  keys=( "${(k)params_after[@]}" );
  keys=( "${keys[@]}" "${(k)params_before[@]}" );
  for key in "${keys[@]}"; do
  key="${(Q)key}"
  [[ "${params_after[$key]}" = *local* ]] && continue
  if [[ "${params_after[$key]}" != "${params_before[$key]}" ]]; then
    # Empty for a new param, a type otherwise
    [[ -z "${params_before[$key]}" ]] && params_before[$key]="\"\""
    params_pre[$key]="${params_before[$key]}"
    # Current type, can also be empty, when plugin unsets a parameter
    [[ -z "${params_after[$key]}" ]] && params_after[$key]="\"\""
    params_post[$key]="${params_after[$key]}"
    fi
  done
  # Serialize for reporting
  ZI[PARAMETERS_PRE__$uspl2]="${(j: :)${(qkv)params_pre[@]}}"
  ZI[PARAMETERS_POST__$uspl2]="${(j: :)${(qkv)params_post[@]}}"
  return 0
} # ]]]
# FUNCTION: .zi-any-to-uspl2 [[[
# Converts given plugin-spec to format that's used in keys for hash tables.
# So basically, creates string "user/plugin" (this format is called: uspl2).
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - (optional) plugin (only when $1 - i.e. user - given)
.zi-any-to-uspl2() {
  .zi-any-to-user-plugin "$1" "$2"
  [[ "${reply[-2]}" = "%" ]] && REPLY="${reply[-2]}${reply[-1]}" || REPLY="${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]//---//}"
} # ]]]
# FUNCTION: .zi-save-set-extendedglob [[[
# Enables extendedglob-option first saving if it was already
# enabled, for restoration of this state later.
.zi-save-set-extendedglob() {
  [[ -o "extendedglob" ]] && ZI[EXTENDED_GLOB]="1" || ZI[EXTENDED_GLOB]="0"
  builtin setopt extendedglob
} # ]]]
# FUNCTION: .zi-restore-extendedglob [[[
# Restores extendedglob-option from state saved earlier.
.zi-restore-extendedglob() {
  [[ "${ZI[EXTENDED_GLOB]}" = "0" ]] && builtin unsetopt extendedglob || builtin setopt extendedglob
} # ]]]
# FUNCTION: .zi-prepare-readlink [[[
# Prepares readlink command, used for establishing completion's owner.
#
# $REPLY = ":" or "readlink"
.zi-prepare-readlink() {
  REPLY=":"
  if type readlink 2>/dev/null 1>&2; then
  REPLY="readlink"
  fi
} # ]]]
# FUNCTION: .zi-clear-report-for [[[
# Clears all report data for given user/plugin. This is done by resetting all related global ZI_* hashes.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - (optional) plugin (only when $1 - i.e. user - given)
.zi-clear-report-for() {
  .zi-any-to-uspl2 "$1" "$2"
  # Shadowing
  ZI_REPORTS[$REPLY]=""
  ZI[BINDKEYS__$REPLY]=""
  ZI[ZSTYLES__$REPLY]=""
  ZI[ALIASES__$REPLY]=""
  ZI[WIDGETS_SAVED__$REPLY]=""
  ZI[WIDGETS_DELETE__$REPLY]=""
  # Function diffing
  ZI[FUNCTIONS__$REPLY]=""
  ZI[FUNCTIONS_BEFORE__$REPLY]=""
  ZI[FUNCTIONS_AFTER__$REPLY]=""
  # Option diffing
  ZI[OPTIONS__$REPLY]=""
  ZI[OPTIONS_BEFORE__$REPLY]=""
  ZI[OPTIONS_AFTER__$REPLY]=""
  # Environment diffing
  ZI[PATH__$REPLY]=""
  ZI[PATH_BEFORE__$REPLY]=""
  ZI[PATH_AFTER__$REPLY]=""
  ZI[FPATH__$REPLY]=""
  ZI[FPATH_BEFORE__$REPLY]=""
  ZI[FPATH_AFTER__$REPLY]=""
  # Parameter diffing
  ZI[PARAMETERS_PRE__$REPLY]=""
  ZI[PARAMETERS_POST__$REPLY]=""
  ZI[PARAMETERS_BEFORE__$REPLY]=""
  ZI[PARAMETERS_AFTER__$REPLY]=""
} # ]]]
# FUNCTION: .zi-exists-message [[[
# Checks if plugin is loaded. Testable. Also outputs error message if plugin is not loaded.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - (optional) plugin (only when $1 - i.e. user - given)
.zi-exists-message() {
  .zi-any-to-uspl2 "$1" "$2"
  if [[ -z "${ZI_REGISTERED_PLUGINS[(r)$REPLY]}" ]]; then
    .zi-any-colorify-as-uspl2 "$1" "$2"
    builtin print "${ZI[col-error]}No such plugin${ZI[col-rst]} $REPLY"
    return 1
  fi
  return 0
} # ]]]
# FUNCTION: .zi-at-eval [[[
.zi-at-eval() {
  local atclone="$2" atpull="$1"
  integer retval
  @zi-substitute atclone atpull
  [[ $atpull = "%atclone" ]] && { eval "$atclone"; retval=$?; } || { eval "$atpull"; retval=$?; }
  return $retval
} # ]]]

#
# Format functions
#

# FUNCTION: .zi-format-functions [[[
# Creates a one or two columns text with functions created by given plugin.
#
# $1 - user/plugin (i.e. uspl2 format of plugin-spec)
.zi-format-functions() {
  local uspl2="$1"
  typeset -a func
  func=( "${(z)ZI[FUNCTIONS__$uspl2]}" )
  # Get length of longest left-right string pair, and length of longest left string
  integer longest=0 longest_left=0 cur_left_len=0 count=1
  local f
  for f in "${(on)func[@]}"; do
  [[ -z "${#f}" ]] && continue
  f="${(Q)f}"
  # Compute for elements in left column, ones that will be paded with spaces
  if (( count ++ % 2 != 0 )); then
    [[ "${#f}" -gt "$longest_left" ]] && longest_left="${#f}"
    cur_left_len="${#f}"
  else
    cur_left_len+="${#f}"
    cur_left_len+=1 # For separating space
    [[ "$cur_left_len" -gt "$longest" ]] && longest="$cur_left_len"
  fi
  done
  # Output in one or two columns
  local answer=""
  count=1
  for f in "${(on)func[@]}"; do
  [[ -z "$f" ]] && continue
  f="${(Q)f}"
  if (( COLUMNS >= longest )); then
    if (( count ++ % 2 != 0 )); then
    answer+="${(r:longest_left+1:: :)f}"
    else
    answer+="$f"$'\n'
    fi
  else
    answer+="$f"$'\n'
  fi
  done
  REPLY="$answer"
  # == 0 is: next element would have newline (postfix addition in "count ++")
  (( COLUMNS >= longest && count % 2 == 0 )) && REPLY="$REPLY"$'\n'
} # ]]]
# FUNCTION: .zi-format-options [[[
# Creates one-column text about options that changed when plugin "$1" was loaded.
#
# $1 - user/plugin (i.e. uspl2 format of plugin-spec)
.zi-format-options() {
  local uspl2="$1"
  REPLY=""
  # Paranoid, don't want bad key/value pair error
  integer empty=0
  .zi-save-set-extendedglob
  [[ "${ZI[OPTIONS__$uspl2]}" != *[$'! \t']* ]] && empty=1
  .zi-restore-extendedglob
  (( empty )) && return 0
  typeset -A opts
  opts=( "${(z)ZI[OPTIONS__$uspl2]}" )
  # Get length of longest option
  integer longest=0
  local k
  for k in "${(kon)opts[@]}"; do
    [[ "${#k}" -gt "$longest" ]] && longest="${#k}"
  done
  # Output in one column
  local txt
  for k in "${(kon)opts[@]}"; do
    [[ "${opts[$k]}" = "on" ]] && txt="was unset" || txt="was set"
    REPLY+="${(r:longest+1:: :)k}$txt"$'\n'
  done
} # ]]]
# FUNCTION: .zi-format-env [[[
# Creates one-column text about FPATH or PATH elements added when given plugin was loaded.
#
# $1 - user/plugin (i.e. uspl2 format of plugin-spec)
# $2 - if 1, then examine PATH, if 2, then examine FPATH
.zi-format-env() {
  local uspl2="$1" which="$2"
  # Format PATH?
  if [[ "$which" = "1" ]]; then
    typeset -a elem
    elem=( "${(z@)ZI[PATH__$uspl2]}" )
  elif [[ "$which" = "2" ]]; then
    typeset -a elem
    elem=( "${(z@)ZI[FPATH__$uspl2]}" )
  fi
  # Enumerate elements added
  local answer="" e
  for e in "${elem[@]}"; do
    [[ -z "$e" ]] && continue
    e="${(Q)e}"
    answer+="$e"$'\n'
  done
  [[ -n "$answer" ]] && REPLY="$answer"
} # ]]]
# FUNCTION: .zi-format-parameter [[[
# Creates one column text that lists global parameters that changed when the given plugin was loaded.
#
# $1 - user/plugin (i.e. uspl2 format of plugin-spec)
.zi-format-parameter() {
  local uspl2="$1" infoc="${ZI[col-info]}" k
  builtin setopt localoptions extendedglob nokshglob noksharrays
  REPLY=""
  [[ "${ZI[PARAMETERS_PRE__$uspl2]}" != *[$'! \t']* || "${ZI[PARAMETERS_POST__$uspl2]}" != *[$'! \t']* ]] && return 0
  typeset -A elem_pre elem_post
  elem_pre=( "${(z)ZI[PARAMETERS_PRE__$uspl2]}" )
  elem_post=( "${(z)ZI[PARAMETERS_POST__$uspl2]}" )
  # Find longest key and longest value
  integer longest=0 vlongest1=0 vlongest2=0
  local v1 v2
  for k in "${(k)elem_post[@]}"; do
    k="${(Q)k}"
    [[ "${#k}" -gt "$longest" ]] && longest="${#k}"
    v1="${(Q)elem_pre[$k]}"
    v2="${(Q)elem_post[$k]}"
    [[ "${#v1}" -gt "$vlongest1" ]] && vlongest1="${#v1}"
    [[ "${#v2}" -gt "$vlongest2" ]] && vlongest2="${#v2}"
  done
  # Enumerate parameters that changed. A key
  # always exists in both of the arrays
  local answer="" k
  for k in "${(k)elem_post[@]}"; do
    v1="${(Q)elem_pre[$k]}"
    v2="${(Q)elem_post[$k]}"
    k="${(Q)k}"
    k="${(r:longest+1:: :)k}"
    v1="${(l:vlongest1+1:: :)v1}"
    v2="${(r:vlongest2+1:: :)v2}"
    answer+="$k ${infoc}[$v1 -> $v2]${ZI[col-rst]}"$'\n'
  done
  [[ -n "$answer" ]] && REPLY="$answer"
  return 0
} # ]]]

#
# Completion functions
#

# FUNCTION: .zi-get-completion-owner [[[
# Returns "user---plugin" string (uspl1 format) of plugin that owns given completion.
#
# Both :A and readlink will be used, then readlink's output if results differ. Readlink might not be available.
#
# :A will read the link "twice" and give the final repository
# directory, possibly without username in the uspl format; readlink will read the link "once"
#
# $1 - absolute path to completion file (in COMPLETIONS_DIR)
# $2 - readlink command (":" or "readlink")
.zi-get-completion-owner() {
  setopt localoptions extendedglob nokshglob noksharrays noshwordsplit
  local cpath="$1"
  local readlink_cmd="$2"
  local in_plugin_path tmp
  # Try to go not too deep into resolving the symlink, to have the name as it is in .zi/plugins
  # :A goes deep, descends fully to origin directory
  # Readlink just reads what symlink points to
  in_plugin_path="${cpath:A}"
  tmp=$( "$readlink_cmd" "$cpath" )
  # This in effect works as: "if different, then readlink"
  [[ -n "$tmp" ]] && in_plugin_path="$tmp"
  if [[ "$in_plugin_path" != "$cpath" ]]; then
    # Get the user---plugin part of path
    while [[ "$in_plugin_path" != ${ZI[PLUGINS_DIR]}/[^/]## && "$in_plugin_path" != "/" ]]; do
      in_plugin_path="${in_plugin_path:h}"
    done
    in_plugin_path="${in_plugin_path:t}"
    if [[ -z "$in_plugin_path" ]]; then
      in_plugin_path="${tmp:h}"
    fi
  else
    # readlink and :A have nothing
    in_plugin_path="[unknown]"
  fi
  REPLY="$in_plugin_path"
} # ]]]
# FUNCTION: .zi-get-completion-owner-uspl2col [[[
# For shortening of code - returns colorized plugin name
# that owns given completion.
#
# $1 - absolute path to completion file (in COMPLETIONS_DIR)
# $2 - readlink command (":" or "readlink")
.zi-get-completion-owner-uspl2col() {
  # "cpath" "readline_cmd"
  .zi-get-completion-owner "$1" "$2"
  .zi-any-colorify-as-uspl2 "$REPLY"
} # ]]]
# FUNCTION: .zi-find-completions-of-plugin [[[
# Searches for completions owned by given plugin.
# Returns them in `reply' array.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-find-completions-of-plugin() {
  builtin setopt localoptions nullglob extendedglob nokshglob noksharrays
  .zi-any-to-user-plugin "$1" "$2"
  local user="${reply[-2]}" plugin="${reply[-1]}" uspl
  [[ "$user" = "%" ]] && uspl="${user}${plugin}" || uspl="${reply[-2]}${reply[-2]:+---}${reply[-1]//\//---}"
  reply=( "${ZI[PLUGINS_DIR]}/$uspl"/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*|*.ps1)(DN) )
} # ]]]
# FUNCTION: .zi-check-comp-consistency [[[
# ❮ ZI ❯ creates symlink for each installed completion.
# This function checks whether given completion (i.e.
# file like "_mkdir") is indeed a symlink. Backup file
# is a completion that is disabled - has the leading "_" removed.
#
# $1 - path to completion within plugin's directory
# $2 - path to backup file within plugin's directory
.zi-check-comp-consistency() {
  local cfile="$1" bkpfile="$2"
  integer error="$3"
  # bkpfile must be a symlink
  if [[ -e "$bkpfile" && ! -L "$bkpfile" ]]; then
    builtin print "${ZI[col-error]}Warning: completion's backup file \`${bkpfile:t}' isn't a symlink${ZI[col-rst]}"
    error=1
  fi
  # cfile must be a symlink
  if [[ -e "$cfile" && ! -L "$cfile" ]]; then
    builtin print "${ZI[col-error]}Warning: completion file \`${cfile:t}' isn't a symlink${ZI[col-rst]}"
    error=1
  fi
  # Tell user that he can manually modify but should do it right
  (( error )) && builtin print "${ZI[col-error]}Manual edit of ${ZI[COMPLETIONS_DIR]} occured?${ZI[col-rst]}"
} # ]]]
# FUNCTION: .zi-check-which-completions-are-installed [[[
# For each argument that each should be a path to completion
# within a plugin's dir, it checks whether that completion
# is installed - returns 0 or 1 on corresponding positions in reply.
#
# $1, ... - path to completion within plugin's directory
.zi-check-which-completions-are-installed() {
  local i cfile bkpfile
  reply=( )
  for i in "$@"; do
    cfile="${i:t}"
    bkpfile="${cfile#_}"
    if [[ -e "${ZI[COMPLETIONS_DIR]}"/"$cfile" || -e "${ZI[COMPLETIONS_DIR]}"/"$bkpfile" ]]; then
      reply+=( "1" )
    else
      reply+=( "0" )
    fi
  done
} # ]]]
# FUNCTION: .zi-check-which-completions-are-enabled [[[
# For each argument that each should be a path to completion
# within a plugin's dir, it checks whether that completion
# is disabled - returns 0 or 1 on corresponding positions in reply.
#
# Uninstalled completions will be reported as "0" - i.e. disabled
#
# $1, ... - path to completion within plugin's directory
.zi-check-which-completions-are-enabled() {
  local i cfile
  reply=( )
  for i in "$@"; do
    cfile="${i:t}"
    if [[ -e "${ZI[COMPLETIONS_DIR]}"/"$cfile" ]]; then
      reply+=( "1" )
    else
      reply+=( "0" )
    fi
  done
} # ]]]
# FUNCTION: .zi-uninstall-completions [[[
# Removes all completions of given plugin from Zshell (i.e. from FPATH).
# The FPATH is typically `~/.zi/completions/'.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-uninstall-completions() {
  builtin emulate -LR zsh
  builtin setopt nullglob extendedglob warncreateglobal typesetsilent noshortloops
  typeset -a completions symlinked backup_comps
  local c cfile bkpfile
  integer action global_action=0
  .zi-get-path "$1" "$2"
  [[ -e $REPLY ]] && {
    completions=( $REPLY/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*|*.ps1)(DN) )
  } || {
    builtin print "No completions found for \`$1${${1:#(%|/)*}:+${2:+/}}$2'"
    return 1
  }
  symlinked=( ${ZI[COMPLETIONS_DIR]}/_[^_.]*~*.zwc )
  backup_comps=( ${ZI[COMPLETIONS_DIR]}/[^_.]*~*.zwc )
  (( ${+functions[.zi-forget-completion]} )) || builtin source ${ZI[BIN_DIR]}"/lib/zsh/install.zsh"
  # Delete completions if they are really there, either as completions (_fname) or backups (fname)
  for c in ${completions[@]}; do
    action=0
    cfile=${c:t}
    bkpfile=${cfile#_}
    # Remove symlink to completion
    if [[ -n ${symlinked[(r)*/$cfile]} ]]; then
      command rm -f ${ZI[COMPLETIONS_DIR]}/$cfile
      action=1
    fi
    # Remove backup symlink (created by cdisable)
    if [[ -n ${backup_comps[(r)*/$bkpfile]} ]]; then
      command rm -f ${ZI[COMPLETIONS_DIR]}/$bkpfile
      action=1
    fi
    if (( action )); then
      +zi-message "{info}Uninstalling completion \`{file}$cfile{info}'{…}{rst}"
      # Make compinit notice the change
      .zi-forget-completion "$cfile"
      (( global_action ++ ))
    else
      +zi-message "{info}Completion \`{file}$cfile{info}' not installed.{rst}"
    fi
  done
  if (( global_action > 0 )); then
    +zi-message "{info}Uninstalled {num}$global_action{info} completions.{rst}"
  fi
  .zi-compinit >/dev/null
} # ]]]

#
# User-exposed functions
#

# FUNCTION: .zi-pager [[[
# BusyBox less lacks the -X and -i options, so it can use more
.zi-pager() {
  setopt LOCAL_OPTIONS EQUALS
  # Quiet mode ? → no pager.
  if (( OPTS[opt_-n,--no-pager] )) {
    cat
    return 0
  }
  if [[ ${${:-=less}:A:t} = busybox* ]] {
    more 2>/dev/null
    (( ${+commands[more]} ))
  } else {
    less -FRXi 2>/dev/null
    (( ${+commands[less]} ))
  }
  (( $? )) && cat
  return 0
} # ]]]
# FUNCTION: .zi-self-update [[[
# Updates ❮ ZI ❯ code (does a git pull).
#
# User-action entry point.
.zi-self-update() {
  emulate -LR zsh
  setopt extendedglob typesetsilent warncreateglobal
  [[ $1 = -q ]] && +zi-message "{info2}Updating »»» ❮ ZI ❯ {…}{rst}"
  local nl=$'\n' escape=$'\x1b['
  local -a lines
  (   builtin cd -q "$ZI[BIN_DIR]" && command git checkout main &>/dev/null && command git checkout master &>/dev/null && command git fetch --quiet && \
  lines=( ${(f)"$(command git log --color --date=short --pretty=format:'%Cgreen%cd %h %Creset%s %Cred%d%Creset || %b' ..FETCH_HEAD)"} )
  if (( ${#lines} > 0 )); then
    # Remove the (origin/master ...) segments, to expect only tags to appear
    lines=( "${(S)lines[@]//\(([,[:blank:]]#(origin|HEAD|master|main)[^a-zA-Z]##(HEAD|origin|master|main)[,[:blank:]]#)#\)/}" )
    # Remove " ||" if it ends the line (i.e. no additional text from the body)
    lines=( "${lines[@]/ \|\|[[:blank:]]#(#e)/}" )
    # If there's no ref-name, 2 consecutive spaces occur - fix this
    lines=( "${lines[@]/(#b)[[:space:]]#\|\|[[:space:]]#(*)(#e)/|| ${match[1]}}" )
    lines=( "${lines[@]/(#b)$escape([0-9]##)m[[:space:]]##${escape}m/$escape${match[1]}m${escape}m}" )
    # Replace what follows "|| ..." with the same thing but with no newlines,
    # and also only first 10 words (the (w)-flag enables word-indexing)
    lines=( "${lines[@]/(#b)[[:blank:]]#\|\|(*)(#e)/| ${${match[1]//$nl/ }[(w)1,(w)10]}}" )
    builtin print -rl -- "${lines[@]}" | .zi-pager
    builtin print
  fi
  if [[ $1 != -q ]] {
    command git pull --no-stat --ff-only origin main
  } else {
    command git pull --no-stat --quiet --ff-only origin main
  }
  )
  if [[ $1 != -q ]] {
    +zi-message "Compiling »»» ❮ ZI ❯ {…}"
  }
  command rm -f ${ZI[BIN_DIR]}/*.zwc(DN)
  command rm -f ${ZI[BIN_DIR]}/lib/zsh/*.zwc(DN)
  zcompile -U ${ZI[BIN_DIR]}/zi.zsh
  zcompile -U ${ZI[BIN_DIR]}/lib/zsh/side.zsh
  zcompile -U ${ZI[BIN_DIR]}/lib/zsh/install.zsh
  zcompile -U ${ZI[BIN_DIR]}/lib/zsh/autoload.zsh
  zcompile -U ${ZI[BIN_DIR]}/lib/zsh/additional.zsh
  zcompile -U ${ZI[BIN_DIR]}/lib/zsh/git-process-output.zsh
  # Load for the current session
  [[ $1 != -q ]] && +zi-message "Reloading »»» ❮ ZI ❯ for the current session{…}"
  source ${ZI[BIN_DIR]}/zi.zsh
  source ${ZI[BIN_DIR]}/lib/zsh/side.zsh
  source ${ZI[BIN_DIR]}/lib/zsh/install.zsh
  source ${ZI[BIN_DIR]}/lib/zsh/autoload.zsh
  # Read and remember the new modification timestamps
  local file
  .zi-get-mtime-into "${ZI[BIN_DIR]}/zi.zsh" "ZI[mtime]"
  for file ( side install autoload ) {
    .zi-get-mtime-into "${ZI[BIN_DIR]}/lib/zsh/${file}.zsh" "ZI[mtime-${file}]"
  }
} # ]]]
# FUNCTION: .zi-show-registered-plugins [[[
# Lists loaded plugins (subcommands list, loaded).
#
# User-action entry point.
.zi-show-registered-plugins() {
  emulate -LR zsh
  setopt extendedglob warncreateglobal typesetsilent noshortloops
  typeset -a filtered
  local keyword="$1"
  keyword="${keyword## ##}"
  keyword="${keyword%% ##}"
  if [[ -n "$keyword" ]]; then
    builtin print "Installed plugins matching ${ZI[col-info]}$keyword${ZI[col-rst]}:"
    filtered=( "${(M)ZI_REGISTERED_PLUGINS[@]:#*$keyword*}" )
  else
    filtered=( "${ZI_REGISTERED_PLUGINS[@]}" )
  fi
  local i
  for i in "${filtered[@]}"; do
    [[ "$i" = "_local/zi" ]] && continue
    .zi-any-colorify-as-uspl2 "$i"
    # Mark light loads
    [[ "${ZI[STATES__$i]}" = "1" ]] && REPLY="$REPLY ${ZI[col-info]}*${ZI[col-rst]}"
    builtin print -r -- "$REPLY"
  done
} # ]]]
# FUNCTION: .zi-unload [[[
# 0. Call the Zsh Plugin's Standard *_plugin_unload function
# 0. Call the code provided by the Zsh Plugin's Standard @zsh-plugin-run-at-update
# 1. Delete bindkeys (...)
# 2. Delete Zstyles
# 3. Restore options
# 4. Remove aliases
# 5. Restore Zle state
# 6. Unfunction functions (created by plugin)
# 7. Clean-up FPATH and PATH
# 8. Delete created variables
# 9. Forget the plugin
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-unload() {
.zi-any-to-user-plugin "$1" "$2"
local uspl2="${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]}" user="${reply[-2]}" plugin="${reply[-1]}" quiet="${${3:+1}:-0}"
local k
.zi-any-colorify-as-uspl2 "$uspl2"
(( quiet )) || builtin print -r -- "${ZI[col-bar]}---${ZI[col-rst]} Unloading plugin: $REPLY ${ZI[col-bar]}---${ZI[col-rst]}"
local ___dir
[[ "$user" = "%" ]] && ___dir="$plugin" || ___dir="${ZI[PLUGINS_DIR]}/${user:+${user}---}${plugin//\//---}"
# KSH_ARRAYS immunity
integer correct=0
[[ -o "KSH_ARRAYS" ]] && correct=1
# Allow unload for debug user
if [[ "$uspl2" != "_dtrace/_dtrace" ]]; then
  .zi-exists-message "$1" "$2" || return 1
fi
.zi-any-colorify-as-uspl2 "$1" "$2"
local uspl2col="$REPLY"
# Store report of the plugin in variable LASTREPORT
typeset -g LASTREPORT
LASTREPORT=`.zi-show-report "$1" "$2"`

#
# Call the Zsh Plugin's Standard *_plugin_unload function
#

(( ${+functions[${plugin}_plugin_unload]} )) && ${plugin}_plugin_unload

#
# Call the code provided by the Zsh Plugin's Standard @zsh-plugin-run-at-update
#

local -a tmp
local -A sice
tmp=( "${(z@)ZI_SICE[$uspl2]}" )
(( ${#tmp} > 1 && ${#tmp} % 2 == 0 )) && sice=( "${(Q)tmp[@]}" ) || sice=()
if [[ -n ${sice[ps-on-unload]} ]]; then
  (( quiet )) || builtin print -r "Running plugin's provided unload code: ${ZI[col-info]}${sice[ps-on-unload][1,50]}${sice[ps-on-unload][51]:+…}${ZI[col-rst]}"
  local ___oldcd="$PWD"
  () { setopt localoptions noautopushd; builtin cd -q "$___dir"; }
  eval "${sice[ps-on-unload]}"
  () { setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }
fi

#
# 1. Delete done bindkeys
#

typeset -a string_widget
string_widget=( "${(z)ZI[BINDKEYS__$uspl2]}" )
local sw
for sw in "${(Oa)string_widget[@]}"; do
  [[ -z "$sw" ]] && continue
  # Remove one level of quoting to split using (z)
  sw="${(Q)sw}"
  typeset -a sw_arr
  sw_arr=( "${(z)sw}" )
  # Remove one level of quoting to pass to bindkey
  local sw_arr1="${(Q)sw_arr[1-correct]}" # Keys
  local sw_arr2="${(Q)sw_arr[2-correct]}" # Widget
  local sw_arr3="${(Q)sw_arr[3-correct]}" # Optional previous-bound widget
  local sw_arr4="${(Q)sw_arr[4-correct]}" # Optional -M or -A or -N
  local sw_arr5="${(Q)sw_arr[5-correct]}" # Optional map name
  local sw_arr6="${(Q)sw_arr[6-correct]}" # Optional -R (not with -A, -N)
  if [[ "$sw_arr4" = "-M" && "$sw_arr6" != "-R" ]]; then
    if [[ -n "$sw_arr3" ]]; then
      () {
        emulate -LR zsh -o extendedglob
        (( quiet )) || builtin print -r "Restoring bindkey ${${(q)sw_arr1}//(#m)\\[\^\?\]\[\)\(\'\"\}\{\`]/${MATCH#\\}} $sw_arr3 ${ZI[col-info]}in map ${ZI[col-rst]}$sw_arr5"
      }
      bindkey -M "$sw_arr5" "$sw_arr1" "$sw_arr3"
    else
      (( quiet )) || builtin print -r "Deleting bindkey ${(q)sw_arr1} $sw_arr2 ${ZI[col-info]}in map ${ZI[col-rst]}$sw_arr5"
      bindkey -M "$sw_arr5" -r "$sw_arr1"
    fi
  elif [[ "$sw_arr4" = "-M" && "$sw_arr6" = "-R" ]]; then
    if [[ -n "$sw_arr3" ]]; then
      (( quiet )) || builtin print -r "Restoring ${ZI[col-info]}range${ZI[col-rst]} bindkey ${(q)sw_arr1} $sw_arr3 ${ZI[col-info]}in map ${ZI[col-rst]}$sw_arr5"
      bindkey -RM "$sw_arr5" "$sw_arr1" "$sw_arr3"
    else
      (( quiet )) || builtin print -r "Deleting ${ZI[col-info]}range${ZI[col-rst]} bindkey ${(q)sw_arr1} $sw_arr2 ${ZI[col-info]}in map ${ZI[col-rst]}$sw_arr5"
      bindkey -M "$sw_arr5" -Rr "$sw_arr1"
    fi
  elif [[ "$sw_arr4" != "-M" && "$sw_arr6" = "-R" ]]; then
    if [[ -n "$sw_arr3" ]]; then
      (( quiet )) || builtin print -r "Restoring ${ZI[col-info]}range${ZI[col-rst]} bindkey ${(q)sw_arr1} $sw_arr3"
      bindkey -R "$sw_arr1" "$sw_arr3"
    else
      (( quiet )) || builtin print -r "Deleting ${ZI[col-info]}range${ZI[col-rst]} bindkey ${(q)sw_arr1} $sw_arr2"
      bindkey -Rr "$sw_arr1"
    fi
  elif [[ "$sw_arr4" = "-A" ]]; then
    (( quiet )) || builtin print -r "Linking backup-\`main' keymap \`$sw_arr5' back to \`main'"
    bindkey -A "$sw_arr5" "main"
  elif [[ "$sw_arr4" = "-N" ]]; then
    (( quiet )) || builtin print -r "Deleting keymap \`$sw_arr5'"
    bindkey -D "$sw_arr5"
  else
    if [[ -n "$sw_arr3" ]]; then
      () {
        emulate -LR zsh -o extendedglob
        (( quiet )) || builtin print -r "Restoring bindkey ${${(q)sw_arr1}//(#m)\\[\^\?\]\[\)\(\'\"\}\{\`]/${MATCH#\\}} $sw_arr3"
      }
      bindkey "$sw_arr1" "$sw_arr3"
    else
      (( quiet )) || builtin print -r "Deleting bindkey ${(q)sw_arr1} $sw_arr2"
      bindkey -r "$sw_arr1"
    fi
  fi
done

#
# 2. Delete created Zstyles
#

typeset -a pattern_style
pattern_style=( "${(z)ZI[ZSTYLES__$uspl2]}" )
local ps
for ps in "${(Oa)pattern_style[@]}"; do
  [[ -z "$ps" ]] && continue
  # Remove one level of quoting to split using (z)
  ps="${(Q)ps}"
  typeset -a ps_arr
  ps_arr=( "${(z)ps}" )
  # Remove one level of quoting to pass to zstyle
  local ps_arr1="${(Q)ps_arr[1-correct]}"
  local ps_arr2="${(Q)ps_arr[2-correct]}"
  (( quiet )) || builtin print "Deleting zstyle $ps_arr1 $ps_arr2"
  zstyle -d "$ps_arr1" "$ps_arr2"
done

#
# 3. Restore changed options
#

# Paranoid, don't want bad key/value pair error
.zi-diff-options-compute "$uspl2"
integer empty=0
.zi-save-set-extendedglob
[[ "${ZI[OPTIONS__$uspl2]}" != *[$'! \t']* ]] && empty=1
.zi-restore-extendedglob
if (( empty != 1 )); then
  typeset -A opts
  opts=( "${(z)ZI[OPTIONS__$uspl2]}" )
  for k in "${(kon)opts[@]}"; do
    # Internal options
    [[ "$k" = "physical" ]] && continue
    if [[ "${opts[$k]}" = "on" ]]; then
      (( quiet )) || builtin print "Setting option $k"
      builtin setopt "$k"
    else
      (( quiet )) || builtin print "Unsetting option $k"
      builtin unsetopt "$k"
    fi
  done
fi

#
# 4. Delete aliases
#

typeset -a aname_avalue
aname_avalue=( "${(z)ZI[ALIASES__$uspl2]}" )
local nv
for nv in "${(Oa)aname_avalue[@]}"; do
  [[ -z "$nv" ]] && continue
  # Remove one level of quoting to split using (z)
  nv="${(Q)nv}"
  typeset -a nv_arr
  nv_arr=( "${(z)nv}" )
  # Remove one level of quoting to pass to unalias
  local nv_arr1="${(Q)nv_arr[1-correct]}"
  local nv_arr2="${(Q)nv_arr[2-correct]}"
  local nv_arr3="${(Q)nv_arr[3-correct]}"
  if [[ "$nv_arr3" = "-s" ]]; then
    if [[ -n "$nv_arr2" ]]; then
      (( quiet )) || builtin print "Restoring ${ZI[col-info]}suffix${ZI[col-rst]} alias ${nv_arr1}=${nv_arr2}"
      alias "$nv_arr1" &> /dev/null && unalias -s -- "$nv_arr1"
      alias -s -- "${nv_arr1}=${nv_arr2}"
    else
      (( quiet )) || alias "$nv_arr1" &> /dev/null && {
        builtin print "Removing ${ZI[col-info]}suffix${ZI[col-rst]} alias ${nv_arr1}"
        unalias -s -- "$nv_arr1"
      }
    fi
  elif [[ "$nv_arr3" = "-g" ]]; then
    if [[ -n "$nv_arr2" ]]; then
      (( quiet )) || builtin print "Restoring ${ZI[col-info]}global${ZI[col-rst]} alias ${nv_arr1}=${nv_arr2}"
      alias "$nv_arr1" &> /dev/null && unalias -g -- "$nv_arr1"
      alias -g -- "${nv_arr1}=${nv_arr2}"
    else
      (( quiet )) || alias "$nv_arr1" &> /dev/null && {
        builtin print "Removing ${ZI[col-info]}global${ZI[col-rst]} alias ${nv_arr1}"
        unalias -- "${(q)nv_arr1}"
      }
    fi
  else
    if [[ -n "$nv_arr2" ]]; then
      (( quiet )) || builtin print "Restoring alias ${nv_arr1}=${nv_arr2}"
      alias "$nv_arr1" &> /dev/null && unalias -- "$nv_arr1"
      alias -- "${nv_arr1}=${nv_arr2}"
    else
      (( quiet )) || alias "$nv_arr1" &> /dev/null && {
        builtin print "Removing alias ${nv_arr1}"
        unalias -- "$nv_arr1"
      }
    fi
  fi
done

#
# 5. Restore Zle state
#

local -a keys
keys=( "${(@on)ZI[(I)TIME_<->_*]}" )
integer keys_size=${#keys}
() {
  setopt localoptions extendedglob noksharrays typesetsilent
  typeset -a restore_widgets skip_delete
  local wid
  restore_widgets=( "${(z)ZI[WIDGETS_SAVED__$uspl2]}" )
  for wid in "${(Oa)restore_widgets[@]}"; do
    [[ -z "$wid" ]] && continue
    wid="${(Q)wid}"
    typeset -a orig_saved
    orig_saved=( "${(z)wid}" )
    local tpe="${orig_saved[1]}"
    local orig_saved1="${(Q)orig_saved[2]}" # Original widget
    local comp_wid="${(Q)orig_saved[3]}"
    local orig_saved2="${(Q)orig_saved[4]}" # Saved target function
    local orig_saved3="${(Q)orig_saved[5]}" # Saved previous $widget's contents
    local found_time_key="${keys[(r)TIME_<->_${uspl2//\//---}]}" to_process_plugin
    integer found_time_idx=0 idx=0
    to_process_plugin=""
    [[ "$found_time_key" = (#b)TIME_(<->)_* ]] && found_time_idx="${match[1]}"
    if (( found_time_idx )); then # Must be true
      for (( idx = found_time_idx + 1; idx <= keys_size; ++ idx )); do
        found_time_key="${keys[(r)TIME_${idx}_*]}"
        local oth_uspl2=""
        [[ "$found_time_key" = (#b)TIME_${idx}_(*) ]] && oth_uspl2="${match[1]//---//}"
        local -a entry_splitted
        entry_splitted=( "${(z@)ZI[WIDGETS_SAVED__$oth_uspl2]}" )
        integer found_idx="${entry_splitted[(I)(-N|-C)\ $orig_saved1\\\ *]}"
        local -a entry_splitted2
        entry_splitted2=( "${(z@)ZI[BINDKEYS__$oth_uspl2]}" )
        integer found_idx2="${entry_splitted2[(I)*\ $orig_saved1\ *]}"
        if (( found_idx || found_idx2 ))
        then
          # Skip multiple loads of the same plugin
          # TODO: #56 Fully handle multiple plugin loads
          if [[ "$oth_uspl2" != "$uspl2" ]]; then
            to_process_plugin="$oth_uspl2"
            break # Only the first one is needed
          fi
        fi
      done
      if [[ -n "$to_process_plugin" ]]; then
        if (( !found_idx && !found_idx2 )); then
          (( quiet )) || builtin print "Problem (1) during handling of widget \`$orig_saved1' (contents: $orig_saved2)"
          continue
        fi
        (( quiet )) || builtin print "Chaining widget \`$orig_saved1' to plugin $oth_uspl2"
        local -a oth_orig_saved
        if (( found_idx )) {
          oth_orig_saved=( "${(z)${(Q)entry_splitted[found_idx]}}" )
          local oth_fun="${oth_orig_saved[4]}"
          # oth_orig_saved[2]="${(q)orig_saved2}" # not do this, because
          # we don't want to call other plugin's function at any moment
          oth_orig_saved[5]="${(q)orig_saved3}" # chain up the widget
          entry_splitted[found_idx]="${(q)${(j: :)oth_orig_saved}}"
          ZI[WIDGETS_SAVED__$oth_uspl2]="${(j: :)entry_splitted}"
        } else {
          oth_orig_saved=( "${(z)${(Q)entry_splitted2[found_idx2]}}" )
          local oth_fun="${widgets[${oth_orig_saved[3]}]#*:}"
        }
        integer idx="${functions[$orig_saved2][(i)(#b)([^[:space:]]#${orig_saved1}[^[:space:]]#)]}"
        if (( idx <= ${#functions[$orig_saved2]} ))
        then
          local prefix_X="${match[1]#\{}"
          [[ $prefix_X != \$* ]] && prefix_X="${prefix_X%\}}"
          idx="${functions[$oth_fun][(i)(#b)([^[:space:]]#${orig_saved1}[^[:space:]]#)]}"
          if (( idx <= ${#functions[$oth_fun]} )); then
            match[1]="${match[1]#\{}"
            [[ ${match[1]} != \$* ]] && match[1]="${match[1]%\}}"
            eval "local oth_prefix_uspl2_X=\"${match[1]}\""
            if [[ "${widgets[$prefix_X]}" = builtin ]]; then
              (( quiet )) || builtin print "Builtin-restoring widget \`$oth_prefix_uspl2_X' ($oth_uspl2)"
              zle -A ".${prefix_X#.}" "$oth_prefix_uspl2_X"
            elif [[ "${widgets[$prefix_X]}" = completion:* ]]; then
              (( quiet )) || builtin print "Chain*-restoring widget \`$oth_prefix_uspl2_X' ($oth_uspl2)"
              zle -C "$oth_prefix_uspl2_X" "${(@)${(@s.:.)${orig_saved3#user:}}[2,3]}"
            else
              (( quiet )) || builtin print "Chain-restoring widget \`$oth_prefix_uspl2_X' ($oth_uspl2)"
              zle -N "$oth_prefix_uspl2_X" "${widgets[$prefix_X]#user:}"
            fi
          fi
          # The alternate method
          # skip_delete+=( "${match[1]}" )
          # functions[$oth_fun]="${functions[$oth_fun]//[^\{[:space:]]#$orig_saved1/${match[1]}}"
        fi
      else
        (( quiet )) || builtin print "Restoring Zle widget $orig_saved1"
        if [[ "$orig_saved3" = builtin ]]; then
          zle -A ".$orig_saved1" "$orig_saved1"
        elif [[ "$orig_saved3" = completion:* ]]; then
          zle -C "$orig_saved1" "${(@)${(@s.:.)${orig_saved3#user:}}[2,3]}"
        else
          zle -N "$orig_saved1" "${orig_saved3#user:}"
        fi
      fi
    else
      (( quiet )) || builtin print "Problem (2) during handling of widget \`$orig_saved1' (contents: $orig_saved2)"
    fi
  done
}
typeset -a delete_widgets
delete_widgets=( "${(z)ZI[WIDGETS_DELETE__$uspl2]}" )
local wid
for wid in "${(Oa)delete_widgets[@]}"; do
  [[ -z "$wid" ]] && continue
  wid="${(Q)wid}"
  if [[ -n "${skip_delete[(r)$wid]}" ]]; then
    builtin print "Would delete $wid"
    continue
  fi
  if [[ "${ZI_ZLE_HOOKS_LIST[$wid]}" = "1" ]]; then
    (( quiet )) || builtin print "Removing Zle hook \`$wid'"
  else
    (( quiet )) || builtin print "Removing Zle widget \`$wid'"
  fi
  zle -D "$wid"
done

#
# 6. Unfunction
#

.zi-diff-functions-compute "$uspl2"
typeset -a func
func=( "${(z)ZI[FUNCTIONS__$uspl2]}" )
local f
for f in "${(on)func[@]}"; do
  [[ -z "$f" ]] && continue
  f="${(Q)f}"
  (( quiet )) || builtin print "Deleting function $f"
  (( ${+functions[$f]} )) && unfunction -- "$f"
  (( ${+precmd_functions} )) && precmd_functions=( ${precmd_functions[@]:#$f} )
  (( ${+preexec_functions} )) && preexec_functions=( ${preexec_functions[@]:#$f} )
  (( ${+chpwd_functions} )) && chpwd_functions=( ${chpwd_functions[@]:#$f} )
  (( ${+periodic_functions} )) && periodic_functions=( ${periodic_functions[@]:#$f} )
  (( ${+zshaddhistory_functions} )) && zshaddhistory_functions=( ${zshaddhistory_functions[@]:#$f} )
  (( ${+zshexit_functions} )) && zshexit_functions=( ${zshexit_functions[@]:#$f} )
done

#
# 7. Clean up FPATH and PATH
#

.zi-diff-env-compute "$uspl2"

# Have to iterate over $path elements and
# skip those that were added by the plugin
typeset -a new elem p
elem=( "${(z)ZI[PATH__$uspl2]}" )
for p in "${path[@]}"; do
  if [[ -z "${elem[(r)${(q)p}]}" ]] {
    new+=( "$p" )
  } else {
    (( quiet )) || builtin print "Removing PATH element ${ZI[col-info]}$p${ZI[col-rst]}"
    [[ -d "$p" ]] || (( quiet )) || builtin print "${ZI[col-error]}Warning:${ZI[col-rst]} it didn't exist on disk"
  }
done
path=( "${new[@]}" )
# The same for $fpath
elem=( "${(z)ZI[FPATH__$uspl2]}" )
new=( )
for p ( "${fpath[@]}" ) {
  if [[ -z "${elem[(r)${(q)p}]}" ]] {
    new+=( "$p" )
  } else {
    (( quiet )) || builtin print "Removing FPATH element ${ZI[col-info]}$p${ZI[col-rst]}"
    [[ -d "$p" ]] || (( quiet )) || builtin print "${ZI[col-error]}Warning:${ZI[col-rst]} it didn't exist on disk"
  }
}
fpath=( "${new[@]}" )

#
# 8. Delete created variables
#

  .zi-diff-parameter-compute "$uspl2"
  empty=0
  .zi-save-set-extendedglob
  [[ "${ZI[PARAMETERS_POST__$uspl2]}" != *[$'! \t']* ]] && empty=1
  .zi-restore-extendedglob
  if (( empty != 1 )); then
    typeset -A elem_pre elem_post
    elem_pre=( "${(z)ZI[PARAMETERS_PRE__$uspl2]}" )
    elem_post=( "${(z)ZI[PARAMETERS_POST__$uspl2]}" )
    # Find variables created or modified
    local wl found
    local -a whitelist
    whitelist=( "${(@Q)${(z@)ZI[ENV-WHITELIST]}}" )
    for k in "${(k)elem_post[@]}"; do
      k="${(Q)k}"
      local v1="${(Q)elem_pre[$k]}"
      local v2="${(Q)elem_post[$k]}"
      # "" means a variable was deleted, not created/changed
      if [[ $v2 != '""' ]]; then
        # Don't unset readonly variables
        [[ ${(tP)k} == *-readonly(|-*) ]] && continue
        # Don't unset arrays managed by add-zsh-hook,
        # also ignore a few special parameters
        # TODO: #55 remember and remove hooks
        case "$k" in
          (chpwd_functions|precmd_functions|preexec_functions|periodic_functions|zshaddhistory_functions|zshexit_functions|zsh_directory_name_functions)
            continue
          (path|PATH|fpath|FPATH)
            continue;
            ;;
        esac
        # Don't unset redefined variables, only newly defined
        # "" means variable didn't exist before plugin load
        # (didn't have a type).
        # Do an exception for the prompt variables.
        if [[ $v1 = '""' || ( $k = (RPROMPT|RPS1|RPS2|PROMPT|PS1|PS2|PS3|PS4) && $v1 != $v2 ) ]]; then
          found=0
          for wl in "${whitelist[@]}"; do
            if [[ "$k" = ${~wl} ]]; then
              found=1
              break
            fi
          done
          if (( !found )); then
            (( quiet )) || builtin print "Unsetting variable $k"
            # Checked that 4.3.17 does support "--"
            # There cannot be parameter starting with
            # "-" but let's defensively use "--" here
            unset -- "$k"
          else
            builtin print "Skipping unset of variable $k (whitelist)"
          fi
        fi
      fi
    done
  fi

#
# 9. Forget the plugin
#

if [[ "$uspl2" = "_dtrace/_dtrace" ]]; then
  .zi-clear-debug-report
  (( quiet )) || builtin print "dtrace report saved to \$LASTREPORT"
else
  (( quiet )) || builtin print "Unregistering plugin $uspl2col"
  .zi-unregister-plugin "$user" "$plugin" "${sice[teleid]}"
  zsh_loaded_plugins[${zsh_loaded_plugins[(i)$user${${user:#(%|/)*}:+/}$plugin]}]=()  # Support Zsh plugin standard
  .zi-clear-report-for "$user" "$plugin"
  (( quiet )) || builtin print "Plugin's report saved to \$LASTREPORT"
fi

} # ]]]
# FUNCTION: .zi-show-report [[[
# Displays report of the plugin given.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user (+ plugin in $2), plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-show-report() {
  setopt localoptions extendedglob warncreateglobal typesetsilent noksharrays
  .zi-any-to-user-plugin "$1" "$2"
  local user="${reply[-2]}" plugin="${reply[-1]}" uspl2="${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]}"
  # Allow debug report
  if [[ "$user/$plugin" != "_dtrace/_dtrace" ]]; then
    .zi-exists-message "$user" "$plugin" || return 1
  fi
  # Print title
  builtin printf "${ZI[col-title]}Report for${ZI[col-rst]} %s%s plugin\n"\
      "${user:+${ZI[col-uname]}$user${ZI[col-rst]}}${${user:#(%|/)*}:+/}"\
      "${ZI[col-pname]}$plugin${ZI[col-rst]}"
  # Print "----------"
  local msg="Report for $user${${user:#(%|/)*}:+/}$plugin plugin"
  builtin print -- "${ZI[col-bar]}${(r:${#msg}::-:)tmp__}${ZI[col-rst]}"
  local -A map
  map=(
    Error:  "${ZI[col-error]}"
    Warning:  "${ZI[col-error]}"
    Note:  "${ZI[col-note]}"
  )
  # Print report gathered via shadowing
  () {
    setopt localoptions extendedglob
    builtin print -rl -- "${(@)${(f@)ZI_REPORTS[$uspl2]}/(#b)(#s)([^[:space:]]##)([[:space:]]##)/${map[${match[1]}]:-${ZI[col-keyword]}}${match[1]}${ZI[col-rst]}${match[2]}}"
  }
  # Print report gathered via $functions-diffing
  REPLY=""
  .zi-diff-functions-compute "$uspl2"
  .zi-format-functions "$uspl2"
  [[ -n "$REPLY" ]] && builtin print "${ZI[col-p]}Functions created:${ZI[col-rst]}"$'\n'"$REPLY"
  # Print report gathered via $options-diffing
  REPLY=""
  .zi-diff-options-compute "$uspl2"
  .zi-format-options "$uspl2"
  [[ -n "$REPLY" ]] && builtin print "${ZI[col-p]}Options changed:${ZI[col-rst]}"$'\n'"$REPLY"
  # Print report gathered via environment diffing
  REPLY=""
  .zi-diff-env-compute "$uspl2"
  .zi-format-env "$uspl2" "1"
  [[ -n "$REPLY" ]] && builtin print "${ZI[col-p]}PATH elements added:${ZI[col-rst]}"$'\n'"$REPLY"
  REPLY=""
  .zi-format-env "$uspl2" "2"
  [[ -n "$REPLY" ]] && builtin print "${ZI[col-p]}FPATH elements added:${ZI[col-rst]}"$'\n'"$REPLY"
  # Print report gathered via parameter diffing
  .zi-diff-parameter-compute "$uspl2"
  .zi-format-parameter "$uspl2"
  [[ -n "$REPLY" ]] && builtin print "${ZI[col-p]}Variables added or redefined:${ZI[col-rst]}"$'\n'"$REPLY"
  # Print what completions plugin has
  .zi-find-completions-of-plugin "$user" "$plugin"
  typeset -a completions
  completions=( "${reply[@]}" )
  if [[ "${#completions[@]}" -ge "1" ]]; then
    builtin print "${ZI[col-p]}Completions:${ZI[col-rst]}"
    .zi-check-which-completions-are-installed "${completions[@]}"
    typeset -a installed
    installed=( "${reply[@]}" )
    .zi-check-which-completions-are-enabled "${completions[@]}"
    typeset -a enabled
    enabled=( "${reply[@]}" )
    integer count="${#completions[@]}" idx
    for (( idx=1; idx <= count; idx ++ )); do
      builtin print -n "${completions[idx]:t}"
      if [[ "${installed[idx]}" != "1" ]]; then
        builtin print -n " ${ZI[col-uninst]}[not installed]${ZI[col-rst]}"
      else
        if [[ "${enabled[idx]}" = "1" ]]; then
          builtin print -n " ${ZI[col-info]}[enabled]${ZI[col-rst]}"
        else
          builtin print -n " ${ZI[col-error]}[disabled]${ZI[col-rst]}"
        fi
      fi
      builtin print
    done
    builtin print
  fi
} # ]]]
# FUNCTION: .zi-show-all-reports [[[
# Displays reports of all loaded plugins.
#
# User-action entry point.
.zi-show-all-reports() {
  local i
  for i in "${ZI_REGISTERED_PLUGINS[@]}"; do
    [[ "$i" = "_local/zi" ]] && continue
    .zi-show-report "$i"
  done
} # ]]]
# FUNCTION: .zi-show-debug-report [[[
# Displays dtrace report (data recorded in interactive session).
#
# User-action entry point.
.zi-show-debug-report() {
  .zi-show-report "_dtrace/_dtrace"
} # ]]]
# FUNCTION: .zi-update-or-status [[[
# Updates (git pull) or does `git status' for given plugin.
#
# User-action entry point.
#
# $1 - "status" for status, other for update
# $2 - plugin spec (4 formats: user---plugin, user/plugin, user (+ plugin in $2), plugin)
# $3 - plugin (only when $1 - i.e. user - given)
.zi-update-or-status() {
  # Set the localtraps option.
  emulate -LR zsh
  setopt extendedglob nullglob warncreateglobal typesetsilent noshortloops
  local -a arr
  ZI[first-plugin-mark]=${${ZI[first-plugin-mark]:#init}:-1}
  ZI[-r/--reset-opt-hook-has-been-run]=0
  # Deliver and withdraw the `m` function when finished.
  .zi-set-m-func set
  trap ".zi-set-m-func unset" EXIT
  integer retval was_snippet
  .zi-two-paths "$2${${2:#(%|/)*}:+${3:+/}}$3"
  if [[ -d ${reply[-4]} || -d ${reply[-2]} ]]; then
    .zi-update-or-status-snippet "$1" "$2${${2:#(%|/)*}:+${3:+/}}$3"
    retval=$?
    was_snippet=1
  fi
  .zi-any-to-user-plugin "$2" "$3"
  local user=${reply[-2]} plugin=${reply[-1]} st=$1 local_dir filename is_snippet key id_as="${reply[-2]}${${reply[-2]:#(%|/)*}:+/}${reply[-1]}"
  local -A ice
  if (( was_snippet )) {
    .zi-exists-physically "$user" "$plugin" || return $retval
    .zi-any-colorify-as-uspl2 "$2" "$3"
    (( !OPTS[opt_-q,--quiet] )) && +zi-message "{msg2}Updating also \`$REPLY{rst}{msg2}'" "plugin (already updated a snippet of the same name){…}{rst}"
  } else {
    .zi-exists-physically-message "$user" "$plugin" || return 1
  }
  if [[ $st = status ]]; then
    ( builtin cd -q ${ZI[PLUGINS_DIR]}/${user:+${user}---}${plugin//\//---}; command git status; )
    return $retval
  fi
  command rm -f ${TMPDIR:-${TMPDIR:-/tmp}}/zi-execs.$$.lst ${TMPDIR:-${TMPDIR:-/tmp}}/zi.installed_comps.$$.lst \
  ${TMPDIR:-${TMPDIR:-/tmp}}/zi.skipped_comps.$$.lst ${TMPDIR:-${TMPDIR:-/tmp}}/zi.compiled.$$.lst
  # A flag for the annexes. 0 – no new commits, 1 - run-atpull mode,
  # 2 – full update/there are new commits to download, 3 - full but
  # a forced download (i.e.: the medium doesn't allow to peek update)
  ZI[annex-multi-flag:pull-active]=0
  (( ${#ICE[@]} > 0 )) && { ZI_SICE[$user${${user:#(%|/)*}:+/}$plugin]=""; local nf="-nftid"; }
  .zi-compute-ice "$user${${user:#(%|/)*}:+/}$plugin" "pack$nf" ice local_dir filename is_snippet || return 1
  .zi-any-to-user-plugin ${ice[teleid]:-$id_as}
  user=${reply[1]} plugin=${reply[2]}
  local repo="${${${(M)id_as#%}:+${id_as#%}}:-${ZI[PLUGINS_DIR]}/${id_as//\//---}}"
  # Run annexes' preinit hooks
  local -a arr
  reply=(
    ${(on)ZI_EXTS2[(I)zi hook:preinit-pre <->]}
    ${(on)ZI_EXTS[(I)z-annex hook:preinit-<-> <->]}
    ${(on)ZI_EXTS2[(I)zi hook:preinit-post <->]}
  )
  for key in "${reply[@]}"; do
    arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
    "${arr[5]}" plugin "$user" "$plugin" "$id_as" "$local_dir" ${${key##(zi|z-annex) hook:}%% <->} update || \
      return $(( 10 - $? ))
  done
  # Check if repository has a remote set, if it is _local
  if [[ -f $local_dir/.git/config ]]; then
    local -a config
    config=( ${(f)"$(<$local_dir/.git/config)"} )
    if [[ ${#${(M)config[@]:#\[remote[[:blank:]]*\]}} -eq 0 ]]; then
      (( !OPTS[opt_-q,--quiet] )) && {
        .zi-any-colorify-as-uspl2 "$id_as"
        [[ $id_as = _local/* ]] && builtin print -r -- "Skipping local plugin $REPLY" || \
          builtin print -r -- "$REPLY doesn't have a remote set, will not fetch"
      }
      return 1
    fi
  fi
  command rm -f $local_dir/.zi_lastupd
  if (( 1 )); then
    if [[ -z ${ice[is_release]} && ${ice[from]} = (gh-r|github-rel|cygwin) ]] {
      ice[is_release]=true
    }
    integer count is_release=0
    for (( count = 1; count <= 5; ++ count )) {
      if (( ${+ice[is_release${count:#1}]} )) {
        is_release=1
      }
    }
    (( ${+functions[.zi-setup-plugin-dir]} )) || builtin source ${ZI[BIN_DIR]}"/lib/zsh/install.zsh"
    if [[ $ice[from] == (gh-r|github-rel) ]] {
      {
        ICE=( "${(kv)ice[@]}" )
        .zi-get-latest-gh-r-url-part "$user" "$plugin" || return $?
      } always {
        ICE=()
      }
    } else {
      REPLY=""
    }
    if (( is_release )) {
      count=0
      for REPLY ( $reply ) {
        count+=1
        local version=${REPLY/(#b)(\/[^\/]##)(#c4,4)\/([^\/]##)*/${match[2]}}
        if [[ ${ice[is_release${count:#1}]} = $REPLY ]] {
          (( ${+ice[run-atpull]} || OPTS[opt_-u,--urge] )) && ZI[annex-multi-flag:pull-active]=1 || ZI[annex-multi-flag:pull-active]=0
        } else {
          ZI[annex-multi-flag:pull-active]=2
          break
        }
      }
      if (( ZI[annex-multi-flag:pull-active] <= 1 && !OPTS[opt_-q,--quiet] )) {
        builtin print -- "\rBinary release already up to date (version: $version)"
      }
    }
    if (( 1 )) {
      if (( ZI[annex-multi-flag:pull-active] >= 1 )) {
        if (( OPTS[opt_-q,--quiet] && !PUPDATE )) {
          .zi-any-colorify-as-uspl2 "$id_as"
          (( ZI[first-plugin-mark] )) && {
            ZI[first-plugin-mark]=0
          } || builtin print
          builtin print "\rUpdating $REPLY"
        }
        ICE=( "${(kv)ice[@]}" )
        # Run annexes' atpull hooks (the before atpull-ice ones).
        # The gh-r / GitHub releases block.
        reply=(
          ${(on)ZI_EXTS2[(I)zi hook:e-\\\!atpull-pre <->]}
          ${${(M)ICE[atpull]#\!}:+${(on)ZI_EXTS[(I)z-annex hook:\\\!atpull-<-> <->]}}
          ${(on)ZI_EXTS2[(I)zi hook:e-\\\!atpull-post <->]}
        )
        for key in "${reply[@]}"; do
          arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
          "${arr[5]}" plugin "$user" "$plugin" "$id_as" "$local_dir" "${${key##(zi|z-annex) hook:}%% <->}" update:bin
        done
        if (( ZI[annex-multi-flag:pull-active] >= 2 )) {
          if ! .zi-setup-plugin-dir "$user" "$plugin" "$id_as" release -u $version; then
            ZI[annex-multi-flag:pull-active]=0
          fi
          if (( OPTS[opt_-q,--quiet] != 1 )) {
            builtin print
          }
        }
        ICE=()
      }
    }
    if [[ -d $local_dir/.git ]] && ( builtin cd -q $local_dir ; git show-ref --verify --quiet refs/heads/main ); then
      local main_branch=main
    else
      local main_branch=master
    fi
    if (( ! is_release )) {
      ( builtin cd -q "$local_dir" || return 1
      integer had_output=0
      local IFS=$'\n'
      command git fetch --quiet && \
        command git log --color --date=short --pretty=format:'%Cgreen%cd %h %Creset%s%n' ..FETCH_HEAD | \
        while read line; do
          [[ -n ${line%%[[:space:]]##} ]] && {
            [[ $had_output -eq 0 ]] && {
              had_output=1
              if (( OPTS[opt_-q,--quiet] && !PUPDATE )) {
                .zi-any-colorify-as-uspl2 "$id_as"
                (( ZI[first-plugin-mark] )) && {
                ZI[first-plugin-mark]=0
              } || builtin print
              builtin print "Updating $REPLY"
            }
          }
          builtin print $line
        }
        done | \
        command tee .zi_lastupd | \
        .zi-pager &
      integer pager_pid=$!
      { sleep 20 && kill -9 $pager_pid 2>/dev/null 1>&2; } &!
      { wait $pager_pid; } > /dev/null 2>&1
      local -a log
      { log=( ${(@f)"$(<$local_dir/.zi_lastupd)"} ); } 2>/dev/null
      command rm -f $local_dir/.zi_lastupd
      if [[ ${#log} -gt 0 ]] {
        ZI[annex-multi-flag:pull-active]=2
      } else {
        if (( ${+ice[run-atpull]} || OPTS[opt_-u,--urge] )) {
          ZI[annex-multi-flag:pull-active]=1
          # Handle the snippet/plugin boundary in the messages
          if (( OPTS[opt_-q,--quiet] && !PUPDATE )) {
            .zi-any-colorify-as-uspl2 "$id_as"
            (( ZI[first-plugin-mark] )) && {
              ZI[first-plugin-mark]=0
            } || builtin print
            builtin print "\rUpdating $REPLY"
          }
        } else {
          ZI[annex-multi-flag:pull-active]=0
        }
      }
      if (( ZI[annex-multi-flag:pull-active] >= 1 )) {
        ICE=( "${(kv)ice[@]}" )
          # Run annexes' atpull hooks (the before atpull-ice ones).
          # The regular Git-plugins block.
          reply=(
            ${(on)ZI_EXTS2[(I)zi hook:e-\\\!atpull-pre <->]}
            ${${(M)ICE[atpull]#\!}:+${(on)ZI_EXTS[(I)z-annex hook:\\\!atpull-<-> <->]}}
            ${(on)ZI_EXTS2[(I)zi hook:e-\\\!atpull-post <->]}
          )
        for key in "${reply[@]}"; do
          arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
          "${arr[5]}" plugin "$user" "$plugin" "$id_as" "$local_dir" "${${key##(zi|z-annex) hook:}%% <->}" update:git
        done
        ICE=()
        (( ZI[annex-multi-flag:pull-active] >= 2 )) && command git pull --no-stat ${=ice[pullopts]:---ff-only} origin ${ice[ver]:-$main_branch} |& command egrep -v '(FETCH_HEAD|up.to.date\.|From.*://)'
      }
        return ${ZI[annex-multi-flag:pull-active]}
      )
      ZI[annex-multi-flag:pull-active]=$?
    }
    if [[ -d $local_dir/.git ]]; then
      (
        builtin cd -q "$local_dir" # || return 1 - don't return, maybe it's some hook's logic
        if (( OPTS[opt_-q,--quiet] )) {
          command git pull --recurse-submodules ${=ice[pullopts]:---ff-only} origin ${ice[ver]:-$main_branch} &> /dev/null
        } else {
          command git pull --recurse-submodules ${=ice[pullopts]:---ff-only} origin ${ice[ver]:-$main_branch} |& command egrep -v '(FETCH_HEAD|up.to.date\.|From.*://)'
        }
      )
    fi
    if [[ -n ${(v)ice[(I)(mv|cp|atpull|ps-on-update|cargo)]} || $+ice[sbin]$+ice[make]$+ice[extract] -ne 0 ]] {
      if (( !OPTS[opt_-q,--quiet] && ZI[annex-multi-flag:pull-active] == 1 )) {
        +zi-message -n "{pre}[update]{msg3} Continuing with the update because "
        (( ${+ice[run-atpull]} )) && \
          +zi-message "{ice}run-atpull{apo}''{msg3} ice given.{rst}" || \
          +zi-message "{opt}-u{msg3}/{opt}--urge{msg3} given.{rst}"
      }
    }
    # Any new commits?
    if (( ZI[annex-multi-flag:pull-active] >= 1  )) {
      ICE=( "${(kv)ice[@]}" )
      # Run annexes' atpull hooks (the before atpull[^!]…-ice ones).
      # Block common for Git and gh-r plugins.
      reply=(
        ${(on)ZI_EXTS2[(I)zi hook:no-e-\\\!atpull-pre <->]}
        ${${ICE[atpull]:#\!*}:+${(on)ZI_EXTS[(I)z-annex hook:\\\!atpull-<-> <->]}}
        ${(on)ZI_EXTS2[(I)zi hook:no-e-\\\!atpull-post <->]}
      )
      for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
        "${arr[5]}" plugin "$user" "$plugin" "$id_as" "$local_dir" "${${key##(zi|z-annex) hook:}%% <->}" update
      done
      # Run annexes' atpull hooks (the after atpull-ice ones).
      # Block common for Git and gh-r plugins.
      reply=(
        ${(on)ZI_EXTS2[(I)zi hook:atpull-pre <->]}
        ${(on)ZI_EXTS[(I)z-annex hook:atpull-<-> <->]}
        ${(on)ZI_EXTS2[(I)zi hook:atpull-post <->]}
      )
      for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
        "${arr[5]}" plugin "$user" "$plugin" "$id_as" "$local_dir" "${${key##(zi|z-annex) hook:}%% <->}" update
      done
      ICE=()
    }
    # Store ices to disk at update of plugin
    .zi-store-ices "$local_dir/._zi" ice "" "" "" ""
  fi
  # Run annexes' atpull hooks (the `always' after atpull-ice ones)
  # Block common for Git and gh-r plugins.
  ICE=( "${(kv)ice[@]}" )
  reply=(
    ${(on)ZI_EXTS2[(I)zi hook:%atpull-pre <->]}
    ${(on)ZI_EXTS[(I)z-annex hook:%atpull-<-> <->]}
    ${(on)ZI_EXTS2[(I)zi hook:%atpull-post <->]}
  )
  for key in "${reply[@]}"; do
    arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
    "${arr[5]}" plugin "$user" "$plugin" "$id_as" "$local_dir" "${${key##(zi|z-annex) hook:}%% <->}" update:$ZI[annex-multi-flag:pull-active]
  done
  ICE=()
  typeset -ga INSTALLED_EXECS
  { INSTALLED_EXECS=( "${(@f)$(<${TMPDIR:-${TMPDIR:-/tmp}}/zi-execs.$$.lst)}" ) } 2>/dev/null
  if [[ -e ${TMPDIR:-${TMPDIR:-/tmp}}/zi.skipped_comps.$$.lst || -e ${TMPDIR:-${TMPDIR:-/tmp}}/zi.installed_comps.$$.lst ]] {
    typeset -ga INSTALLED_COMPS SKIPPED_COMPS
    { INSTALLED_COMPS=( "${(@f)$(<${TMPDIR:-${TMPDIR:-/tmp}}/zi.installed_comps.$$.lst)}" ) } 2>/dev/null
    { SKIPPED_COMPS=( "${(@f)$(<${TMPDIR:-${TMPDIR:-/tmp}}/zi.skipped_comps.$$.lst)}" ) } 2>/dev/null
  }
  if [[ -e ${TMPDIR:-${TMPDIR:-/tmp}}/zi.compiled.$$.lst ]] {
    typeset -ga ADD_COMPILED
    { ADD_COMPILED=( "${(@f)$(<${TMPDIR:-${TMPDIR:-/tmp}}/zi.compiled.$$.lst)}" ) } 2>/dev/null
  }
  if (( PUPDATE && ZI[annex-multi-flag:pull-active] > 0 )) {
    builtin print ${ZI[annex-multi-flag:pull-active]} >! $PUFILE.ind
  }
  return $retval
} # ]]]
# FUNCTION: .zi-update-or-status-snippet [[[
#
# Implements update or status operation for snippet given by URL.
#
# $1 - "status" or "update"
# $2 - snippet URL
.zi-update-or-status-snippet() {
  local st="$1" URL="${2%/}" local_dir filename is_snippet
  (( ${#ICE[@]} > 0 )) && { ZI_SICE[$URL]=""; local nf="-nftid"; }
  local -A ICE2
  .zi-compute-ice "$URL" "pack$nf" ICE2 local_dir filename is_snippet || return 1
  integer retval
  if [[ "$st" = "status" ]]; then
    if (( ${+ICE2[svn]} )); then
      builtin print -r -- "${ZI[col-info]}Status for ${${${local_dir:h}:t}##*--}/${local_dir:t}${ZI[col-rst]}"
      ( builtin cd -q "$local_dir"; command svn status -vu )
      retval=$?
      builtin print
    else
      builtin print -r -- "${ZI[col-info]}Status for ${${local_dir:h}##*--}/$filename${ZI[col-rst]}"
      ( builtin cd -q "$local_dir"; command ls -lth $filename )
      retval=$?
      builtin print
    fi
  else
    (( ${+functions[.zi-setup-plugin-dir]} )) || builtin source ${ZI[BIN_DIR]}"/lib/zsh/install.zsh"
    ICE=( "${(kv)ICE2[@]}" )
    .zi-update-snippet "${ICE2[teleid]:-$URL}"
    retval=$?
  fi
  ICE=()
  if (( PUPDATE && ZI[annex-multi-flag:pull-active] > 0 )) {
    builtin print ${ZI[annex-multi-flag:pull-active]} >! $PUFILE.ind
  }
  return $retval
} # ]]]
# FUNCTION: .zi-update-or-status-all [[[
# Updates (git pull) or does `git status` for all existing plugins.
# This includes also plugins that are not loaded into Zsh (but exist
# on disk). Also updates (i.e. redownloads) snippets.
#
# User-action entry point.
.zi-update-or-status-all() {
  emulate -LR zsh
  setopt extendedglob nullglob warncreateglobal typesetsilent noshortloops
  local -F2 SECONDS=0
  .zi-self-update -q
  [[ $2 = restart ]] && +zi-message "{msg2}Restarting the update with the new codebase loaded.{rst}"$'\n'
  local file
  integer sum ela elb
  .zi-get-mtime-into "${ZI[BIN_DIR]}/zi.zsh" ela; (( sum += ela ))
  for file ( side install autoload ) {
    .zi-get-mtime-into "${ZI[BIN_DIR]}/lib/zsh/${file}.zsh" elb; (( sum += elb ))
  }
  # Reload ZI?
  if [[ $2 != restart ]] && (( ZI[mtime] + ZI[mtime-side] + ZI[mtime-install] + ZI[mtime-autoload] != sum )) {
    +zi-message "{msg2}Detected ❮ ZI ❯ update in another session -" "{pre}reloading{msg2}{…}{rst}"
    source ${ZI[BIN_DIR]}/zi.zsh
    source ${ZI[BIN_DIR]}/lib/zsh/side.zsh
    source ${ZI[BIN_DIR]}/lib/zsh/install.zsh
    source ${ZI[BIN_DIR]}/lib/zsh/autoload.zsh
    .zi-get-mtime-into "${ZI[BIN_DIR]}/zi.zsh" "ZI[mtime]"
    for file ( side install autoload ) {
      .zi-get-mtime-into "${ZI[BIN_DIR]}/lib/zsh/${file}.zsh" "ZI[mtime-${file}]"
    }
    +zi-message "{pname}Done.{rst}"$'\n'
    .zi-update-or-status-all "$1" restart
    return $?
  }
  if (( OPTS[opt_-p,--parallel] )) && [[ $1 = update ]] {
    (( !OPTS[opt_-q,--quiet] )) && \
      +zi-message '{info2}Parallel Update Starts Now{…}{rst}'
    .zi-update-all-parallel
    integer retval=$?
    .zi-compinit 1 1 &>/dev/null
    rehash
    if (( !OPTS[opt_-q,--quiet] )) {
      +zi-message "{msg2}The update took {obj}${SECONDS}{msg2} seconds{rst}"
    }
    return $retval
  }
  local st=$1 id_as repo snip pd user plugin
    integer PUPDATE=0
  local -A ICE
  if (( OPTS[opt_-s,--snippets] || !OPTS[opt_-l,--plugins] )) {
    local -a snipps
    snipps=( ${ZI[SNIPPETS_DIR]}/**/(._zi|._zinit|._zplugin)(ND) )
    [[ $st != status && ${OPTS[opt_-q,--quiet]} != 1 && -n $snipps ]] && +zi-message "{info}Note:{rst} updating also unloaded snippets"
    for snip ( ${ZI[SNIPPETS_DIR]}/**/(._zi|._zinit|._zplugin)/mode(D) ) {
      [[ ! -f ${snip:h}/url ]] && continue
      [[ -f ${snip:h}/id-as ]] && id_as="$(<${snip:h}/id-as)" || id_as=
      .zi-update-or-status-snippet "$st" "${id_as:-$(<${snip:h}/url)}"
      ICE=()
    }
    [[ -n $snipps ]] && builtin print
  }
  ICE=()
  if (( OPTS[opt_-s,--snippets] && !OPTS[opt_-l,--plugins] )) {
    return
  }
  if [[ $st = status ]]; then
    (( !OPTS[opt_-q,--quiet] )) && +zi-message "{info}Note:{rst} status done also for unloaded plugins"
  else
    (( !OPTS[opt_-q,--quiet] )) && +zi-message "{info}Note:{rst} updating also unloaded plugins"
  fi
  ZI[first-plugin-mark]=init
  for repo in ${ZI[PLUGINS_DIR]}/*; do
    pd=${repo:t}
    # Two special cases
    [[ $pd = custom || $pd = _local---zi ]] && continue
    .zi-any-colorify-as-uspl2 "$pd"
    # Check if repository has a remote set
    if [[ -f $repo/.git/config ]]; then
      local -a config
      config=( ${(f)"$(<$repo/.git/config)"} )
      if [[ ${#${(M)config[@]:#\[remote[[:blank:]]*\]}} -eq 0 ]]; then
        if (( !OPTS[opt_-q,--quiet] )) {
          [[ $pd = _local---* ]] && builtin print -- "\nSkipping local plugin $REPLY" || \
          builtin print "\n$REPLY doesn't have a remote set, will not fetch"
        }
        continue
      fi
    fi
    .zi-any-to-user-plugin "$pd"
    local user=${reply[-2]} plugin=${reply[-1]}
    # Must be a git repository or a binary release
    if [[ ! -d $repo/.git && ! -f $repo/._zi/is_release ]]; then
      (( !OPTS[opt_-q,--quiet] )) && \
        builtin print "$REPLY: not a git repository"
      continue
    fi
    if [[ $st = status ]]; then
      builtin print "\nStatus for plugin $REPLY"
      ( builtin cd -q "$repo"; command git status )
    else
      (( !OPTS[opt_-q,--quiet] )) && builtin print "Updating $REPLY" || builtin print -n .
      .zi-update-or-status update "$user" "$plugin"
    fi
  done
  .zi-compinit 1 1 &>/dev/null
  if (( !OPTS[opt_-q,--quiet] )) {
    +zi-message "{msg2}The update took {obj}${SECONDS}{msg2} seconds{rst}"
  }
} # ]]]
# FUNCTION: .zi-update-in-parallel [[[
.zi-update-all-parallel() {
  emulate -LR zsh
  setopt extendedglob warncreateglobal typesetsilent noshortloops nomonitor nonotify
  local id_as repo snip uspl user plugin PUDIR="$(mktemp -d)"
  local -A PUAssocArray map
  map=( / --  "=" -EQ-  "?" -QM-  "&" -AMP-  : - )
  local -a files
  integer main_counter counter PUPDATE=1
  files=( ${ZI[SNIPPETS_DIR]}/**/(._zi|._zinit|._zplugin)/mode(ND) )
  main_counter=${#files}
  if (( OPTS[opt_-s,--snippets] || !OPTS[opt_-l,--plugins] )) {
    for snip ( "${files[@]}" ) {
      main_counter=main_counter-1
      # The continue may cause the tail of processes to
      # fall-through to the following plugins-specific `wait'
      # Should happen only in a very special conditions
      # TODO handle this
      [[ ! -f ${snip:h}/url ]] && continue
      [[ -f ${snip:h}/id-as ]] && id_as="$(<${snip:h}/id-as)" || id_as=
      counter+=1
      local ef_id="${id_as:-$(<${snip:h}/url)}"
      local PUFILEMAIN=${${ef_id#/}//(#m)[\/=\?\&:]/${map[$MATCH]}}
      local PUFILE=$PUDIR/${counter}_$PUFILEMAIN.out
      .zi-update-or-status-snippet "$st" "$ef_id" &>! $PUFILE &
      PUAssocArray[$!]=$PUFILE
      .zi-wait-for-update-jobs snippets
    }
  }

  counter=0
  PUAssocArray=()
  if (( OPTS[opt_-l,--plugins] || !OPTS[opt_-s,--snippets] )) {
    local -a files2
    files=( ${ZI[PLUGINS_DIR]}/*(ND/) )
    # Pre-process plugins
    for repo ( $files ) {
      uspl=${repo:t}
      # Two special cases
      [[ $uspl = custom || $uspl = _local---zi ]] && continue
      # Check if repository has a remote set
      if [[ -f $repo/.git/config ]] {
        local -a config
        config=( ${(f)"$(<$repo/.git/config)"} )
        if [[ ${#${(M)config[@]:#\[remote[[:blank:]]*\]}} -eq 0 ]] {
          continue
        }
      }
      .zi-any-to-user-plugin "$uspl"
      local user=${reply[-2]} plugin=${reply[-1]}
      # Must be a git repository or a binary release
      if [[ ! -d $repo/.git && ! -f $repo/._zi/is_release ]] {
        continue
      }
      files2+=( $repo )
    }
    main_counter=${#files2}
    for repo ( "${files2[@]}" ) {
      main_counter=main_counter-1
      uspl=${repo:t}
      id_as=${uspl//---//}
      counter+=1
      local PUFILEMAIN=${${id_as#/}//(#m)[\/=\?\&:]/${map[$MATCH]}}
      local PUFILE=$PUDIR/${counter}_$PUFILEMAIN.out
      .zi-any-colorify-as-uspl2 "$uspl"
      +zi-message "Updating $REPLY{…}" >! $PUFILE
      .zi-any-to-user-plugin "$uspl"
      local user=${reply[-2]} plugin=${reply[-1]}
      .zi-update-or-status update "$user" "$plugin" &>>! $PUFILE &
      PUAssocArray[$!]=$PUFILE
      .zi-wait-for-update-jobs plugins
    }
  }
  # Shouldn't happen
  # (( ${#PUAssocArray} > 0 )) && wait ${(k)PUAssocArray}
}
# ]]]
# FUNCTION: .zi-wait-for-update-jobs [[[
.zi-wait-for-update-jobs() {
  local tpe=$1
  if (( counter > OPTS[value] || main_counter == 0 )) {
    wait ${(k)PUAssocArray}
    local ind_file
    for ind_file ( ${^${(von)PUAssocArray}}.ind(DN.) ) {
      command cat ${ind_file:r}
      (( !OPTS[opt_-d,--debug] && !ZI[DEBUG_MODE] )) && command rm -f $ind_file
    }
    (( !OPTS[opt_-d,--debug] && !ZI[DEBUG_MODE] )) && command rm -f ${(v)PUAssocArray}
    counter=0
    PUAssocArray=()
  } elif (( counter == 1 && !OPTS[opt_-q,--quiet] )) {
    +zi-message "{obj}Spawning the next{num}" "${OPTS[value]}{obj} concurrent update jobs" "({msg2}${tpe}{obj}){…}{rst}"
  }
} # ]]]
# FUNCTION: .zi-show-zstatus [[[
# Shows ❮ ZI ❯ status, i.e. number of loaded plugins,
# of available completions, etc.
#
# User-action entry point.
.zi-show-zstatus() {
  builtin setopt localoptions nullglob extendedglob nokshglob noksharrays

  local infoc="${ZI[col-info2]}"

  +zi-message "Home directory:        {file}${ZI[HOME_DIR]}{rst}"
  +zi-message "Binary directory:      {file}${ZI[BIN_DIR]}{rst}"
  +zi-message "Plugin directory:      {file}${ZI[PLUGINS_DIR]}{rst}"
  +zi-message "Snippet directory:     {file}${ZI[SNIPPETS_DIR]}{rst}"
  +zi-message "Service directory:     {file}${ZI[SERVICES_DIR]}{rst}"
  +zi-message "Modules directory:     {file}${ZI[ZMODULES_DIR]}{rst}"
  +zi-message "Completions directory: {file}${ZI[COMPLETIONS_DIR]}{rst}"
  # Without _zlocal/zi
  +zi-message "Loaded plugins: {num}$(( ${#ZI_REGISTERED_PLUGINS[@]} - 1 )){rst}"
  # Count light-loaded plugins
  integer light=0
  local s
  for s in "${(@v)ZI[(I)STATES__*]}"; do
    [[ "$s" = 1 ]] && (( light ++ ))
  done
  # Without _zlocal/zi
  +zi-message "Light loaded: {num}$(( light - 1 )){rst}"
  # Downloaded plugins, without _zlocal/zi, custom
  typeset -a plugins
  plugins=( "${ZI[PLUGINS_DIR]}"/*(DN) )
  +zi-message "Downloaded plugins: {num}$(( ${#plugins} - 1 )){rst}"
  # Number of enabled completions, with _zlocal/zi
  typeset -a completions
  completions=( "${ZI[COMPLETIONS_DIR]}"/_[^_.]*~*.zwc(DN) )
  +zi-message "Enabled completions: {num}${#completions[@]}{rst}"
  # Number of disabled completions, with _zlocal/zi
  completions=( "${ZI[COMPLETIONS_DIR]}"/[^_.]*~*.zwc(DN) )
  +zi-message "Disabled completions: {num}${#completions[@]}{rst}"
  # Number of completions existing in all plugins
  completions=( "${ZI[PLUGINS_DIR]}"/*/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*|*.ps1)(DN) )
  +zi-message "Completions available overall: {num}${#completions[@]}{rst}"
  # Enumerate snippets loaded
  # }, ${infoc}{rst}", j:, :, {msg}"$'\e[0m, +zi-message h
  +zi-message -n "Snippets loaded: "
  local sni
  for sni in ${(onv)ZI_SNIPPETS[@]}; do
    +zi-message -n "{url}${sni% <[^>]#>}{rst} ${(M)sni%<[^>]##>}, "
  done
  [[ -z $sni ]] && builtin print -n " "
  builtin print '\b\b  '
  # Number of compiled plugins
  typeset -a matches m
  integer count=0
  matches=( ${ZI[PLUGINS_DIR]}/*/*.zwc(DN) )
  local cur_plugin="" uspl1
  for m in "${matches[@]}"; do
    uspl1="${${m:h}:t}"
    if [[ "$cur_plugin" != "$uspl1" ]]; then
      (( count ++ ))
      cur_plugin="$uspl1"
    fi
  done
  +zi-message "Compiled plugins: {num}$count{rst}"
} # ]]]
# FUNCTION: .zi-show-times [[[
# Shows loading times of all loaded plugins.
#
# User-action entry point.
.zi-show-times() {
  emulate -LR zsh
  setopt  extendedglob warncreateglobal noshortloops
  local opt="$1 $2 $3" entry entry2 entry3 user plugin
  float -F 3 sum=0.0
  local -A sice
  local -a tmp
  [[ "$opt" = *-[a-z]#m[a-z]#* ]] && \
    { builtin print "Plugin loading moments (relative to the first prompt):"; ((1)); } || \
    builtin print "Plugin loading times:"
  for entry in "${(@on)ZI[(I)TIME_[0-9]##_*]}"; do
    entry2="${entry#TIME_[0-9]##_}"
    entry3="AT_$entry"
    if [[ "$entry2" = (http|https|ftp|ftps|scp|${(~j.|.)${${(k)ZI_1MAP}%::}}):* ]]; then
      REPLY="${ZI[col-pname]}$entry2${ZI[col-rst]}"
      tmp=( "${(z@)ZI_SICE[${entry2%/}]}" )
      (( ${#tmp} > 1 && ${#tmp} % 2 == 0 )) && sice=( "${(Q)tmp[@]}" ) || sice=()
    else
      user="${entry2%%---*}"
      plugin="${entry2#*---}"
      [[ "$user" = \% ]] && plugin="/${plugin//---/\/}"
      [[ "$user" = "$plugin" && "$user/$plugin" != "$entry2" ]] && user=""
      .zi-any-colorify-as-uspl2 "$user" "$plugin"
      tmp=( "${(z@)ZI_SICE[$user/$plugin]}" )
      (( ${#tmp} > 1 && ${#tmp} % 2 == 0 )) && sice=( "${(Q)tmp[@]}" ) || sice=()
    fi
    local attime=$(( ZI[$entry3] - ZI[START_TIME] ))
    if [[ "$opt" = *-[a-z]#s[a-z]#* ]]; then
      local time="$ZI[$entry] sec"
      attime="${(M)attime#*.???} sec"
    else
      local time="${(l:5:: :)$(( ZI[$entry] * 1000 ))%%[,.]*} ms"
      attime="${(l:5:: :)$(( attime * 1000 ))%%[,.]*} ms"
    fi
    [[ -z $EPOCHREALTIME ]] && attime="<no zsh/datetime module → no time data>"
    if [[ "$opt" = *-[a-z]#m[a-z]#* ]]; then
      time="$attime"
    fi
    if [[ ${sice[as]} == "command" ]]; then
      builtin print "$time" - "$REPLY (command)"
    elif [[ -n ${sice[sbin]+abc} ]]; then
      builtin print "$time" - "$REPLY (sbin command)"
    elif [[ -n ${sice[fbin]+abc} ]]; then
      builtin print "$time" - "$REPLY (fbin command)"
    elif [[ ( ${sice[pick]} = /dev/null || ${sice[as]} = null ) && ${+sice[make]} = 1 ]]; then
      builtin print "$time" - "$REPLY (/dev/null make plugin)"
    else
      builtin print "$time" - "$REPLY"
    fi
    (( sum += ZI[$entry] ))
  done
  builtin print "Total: $sum sec"
} # ]]]
# FUNCTION: .zi-list-bindkeys [[[
.zi-list-bindkeys() {
  local uspl2 uspl2col sw first=1
  local -a string_widget
  # KSH_ARRAYS immunity
  integer correct=0
  [[ -o "KSH_ARRAYS" ]] && correct=1
  for uspl2 in "${(@ko)ZI[(I)BINDKEYS__*]}"; do
    [[ -z "${ZI[$uspl2]}" ]] && continue
    (( !first )) && builtin print
    first=0
    uspl2="${uspl2#BINDKEYS__}"
    .zi-any-colorify-as-uspl2 "$uspl2"
    uspl2col="$REPLY"
    builtin print "$uspl2col"
    string_widget=( "${(z@)ZI[BINDKEYS__$uspl2]}" )
    for sw in "${(Oa)string_widget[@]}"; do
      [[ -z "$sw" ]] && continue
      # Remove one level of quoting to split using (z)
      sw="${(Q)sw}"
      typeset -a sw_arr
      sw_arr=( "${(z@)sw}" )
      # Remove one level of quoting to pass to bindkey
      local sw_arr1="${(Q)sw_arr[1-correct]}" # Keys
      local sw_arr2="${(Q)sw_arr[2-correct]}" # Widget
      local sw_arr3="${(Q)sw_arr[3-correct]}" # Optional -M or -A or -N
      local sw_arr4="${(Q)sw_arr[4-correct]}" # Optional map name
      local sw_arr5="${(Q)sw_arr[5-correct]}" # Optional -R (not with -A, -N)

      if [[ "$sw_arr3" = "-M" && "$sw_arr5" != "-R" ]]; then
        builtin print "bindkey $sw_arr1 $sw_arr2 ${ZI[col-info]}for keymap $sw_arr4${ZI[col-rst]}"
      elif [[ "$sw_arr3" = "-M" && "$sw_arr5" = "-R" ]]; then
        builtin print "${ZI[col-info]}range${ZI[col-rst]} bindkey $sw_arr1 $sw_arr2 ${ZI[col-info]}mapped to $sw_arr4${ZI[col-rst]}"
      elif [[ "$sw_arr3" != "-M" && "$sw_arr5" = "-R" ]]; then
        builtin print "${ZI[col-info]}range${ZI[col-rst]} bindkey $sw_arr1 $sw_arr2"
      elif [[ "$sw_arr3" = "-A" ]]; then
        builtin print "Override of keymap \`main'"
      elif [[ "$sw_arr3" = "-N" ]]; then
        builtin print "New keymap \`$sw_arr4'"
      else
        builtin print "bindkey $sw_arr1 $sw_arr2"
      fi
    done
  done
} # ]]]
# FUNCTION: .zi-compiled [[[
# Displays list of plugins that are compiled.
#
# User-action entry point.
.zi-compiled() {
  builtin setopt localoptions nullglob

  typeset -a matches m
  matches=( ${ZI[PLUGINS_DIR]}/*/*.zwc(DN) )

  if [[ "${#matches[@]}" -eq "0" ]]; then
    builtin print "No compiled plugins"
    return 0
  fi
  local cur_plugin="" uspl1 file user plugin
  for m in "${matches[@]}"; do
    file="${m:t}"
    uspl1="${${m:h}:t}"
    .zi-any-to-user-plugin "$uspl1"
    user="${reply[-2]}" plugin="${reply[-1]}"
    if [[ "$cur_plugin" != "$uspl1" ]]; then
      [[ -n "$cur_plugin" ]] && builtin print # newline
      .zi-any-colorify-as-uspl2 "$user" "$plugin"
      builtin print -r -- "$REPLY:"
      cur_plugin="$uspl1"
    fi
    builtin print "$file"
  done
} # ]]]
# FUNCTION: .zi-compile-uncompile-all [[[
# Compiles or uncompiles all existing (on disk) plugins.
#
# User-action entry point.
.zi-compile-uncompile-all() {
  builtin setopt localoptions nullglob

  local compile="$1"
  typeset -a plugins
  plugins=( "${ZI[PLUGINS_DIR]}"/*(DN) )

  local p user plugin
  for p in "${plugins[@]}"; do
    [[ "${p:t}" = "custom" || "${p:t}" = "_local---zi" ]] && continue
    .zi-any-to-user-plugin "${p:t}"
    user="${reply[-2]}" plugin="${reply[-1]}"
    .zi-any-colorify-as-uspl2 "$user" "$plugin"
    builtin print -r -- "$REPLY:"
    if [[ "$compile" = "1" ]]; then
      .zi-compile-plugin "$user" "$plugin"
    else
      .zi-uncompile-plugin "$user" "$plugin" "1"
    fi
  done
} # ]]]
# FUNCTION: .zi-uncompile-plugin [[[
# Uncompiles given plugin.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user (+ plugin in $2), plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-uncompile-plugin() {
  builtin setopt localoptions nullglob

  .zi-any-to-user-plugin "$1" "$2"
  local user="${reply[-2]}" plugin="${reply[-1]}" silent="$3"
  # There are plugins having ".plugin.zsh"
  # in ${plugin} directory name, also some
  # have ".zsh" there
  [[ "$user" = "%" ]] && local pdir_path="$plugin" || local pdir_path="${ZI[PLUGINS_DIR]}/${user:+${user}---}${plugin//\//---}"
  typeset -a matches m
  matches=( $pdir_path/*.zwc(DN) )
  if [[ "${#matches[@]}" -eq "0" ]]; then
    if [[ "$silent" = "1" ]]; then
      builtin print "not compiled"
    else
      .zi-any-colorify-as-uspl2 "$user" "$plugin"
      builtin print -r -- "$REPLY not compiled"
    fi
    return 1
  fi
  for m in "${matches[@]}"; do
    builtin print "Removing ${ZI[col-info]}${m:t}${ZI[col-rst]}"
    command rm -f "$m"
  done
} # ]]]

# FUNCTION: .zi-show-completions [[[
# Display installed (enabled and disabled), completions. Detect
# stray and improper ones.
#
# Completions live even when plugin isn't loaded - if they are
# installed and enabled.
#
# User-action entry point.
.zi-show-completions() {
  builtin setopt localoptions nullglob extendedglob nokshglob noksharrays
  local count="${1:-3}"
  typeset -a completions
  completions=( "${ZI[COMPLETIONS_DIR]}"/_[^_.]*~*.zwc "${ZI[COMPLETIONS_DIR]}"/[^_.]*~*.zwc )

  local cpath c o s group
  # Prepare readlink command for establishing
  # completion's owner
  .zi-prepare-readlink
  local rdlink="$REPLY"
  float flmax=${#completions} flcur=0
  typeset -F1 flper
  local -A owner_to_group
  local -a packs splitted
  integer disabled unknown stray
  for cpath in "${completions[@]}"; do
    c="${cpath:t}"
    [[ "${c#_}" = "${c}" ]] && disabled=1 || disabled=0
    c="${c#_}"
    # This will resolve completion's symlink to obtain
    # information about the repository it comes from, i.e.
    # about user and plugin, taken from directory name
    .zi-get-completion-owner "$cpath" "$rdlink"
    [[ "$REPLY" = "[unknown]" ]] && unknown=1 || unknown=0
    o="$REPLY"
    # If we successfully read a symlink (unknown == 0), test if it isn't broken
    stray=0
    if (( unknown == 0 )); then
      [[ ! -f "$cpath" ]] && stray=1
    fi
    s=$(( 1*disabled + 2*unknown + 4*stray ))
    owner_to_group[${o}--$s]+="$c;"
    group="${owner_to_group[${o}--$s]%;}"
    splitted=( "${(s:;:)group}" )
    if [[ "${#splitted}" -ge "$count" ]]; then
      packs+=( "${(q)group//;/, } ${(q)o} ${(q)s}" )
      unset "owner_to_group[${o}--$s]"
    fi
    (( ++ flcur ))
    flper=$(( flcur / flmax * 100 ))
    builtin print -u 2 -n -- "\r${flper}% "
  done
  for o in "${(k)owner_to_group[@]}"; do
    group="${owner_to_group[$o]%;}"
    s="${o##*--}"
    o="${o%--*}"
    packs+=( "${(q)group//;/, } ${(q)o} ${(q)s}" )
  done
  packs=( "${(on)packs[@]}" )

  builtin print -u 2 # newline after percent

  # Find longest completion name
  integer longest=0
  local -a unpacked
  for c in "${packs[@]}"; do
    unpacked=( "${(Q@)${(z@)c}}" )
    [[ "${#unpacked[1]}" -gt "$longest" ]] && longest="${#unpacked[1]}"
  done
  for c in "${packs[@]}"; do
    unpacked=( "${(Q@)${(z@)c}}" ) # TODO: ${(Q)${(z@)c}[@]} ?
    .zi-any-colorify-as-uspl2 "$unpacked[2]"
    builtin print -n "${(r:longest+1:: :)unpacked[1]} $REPLY"

    (( unpacked[3] & 0x1 )) && builtin print -n " ${ZI[col-error]}[disabled]${ZI[col-rst]}"
    (( unpacked[3] & 0x2 )) && builtin print -n " ${ZI[col-error]}[unknown file, clean with cclear]${ZI[col-rst]}"
    (( unpacked[3] & 0x4 )) && builtin print -n " ${ZI[col-error]}[stray, clean with cclear]${ZI[col-rst]}"
    builtin print
  done
} # ]]]
# FUNCTION: .zi-clear-completions [[[
# Delete stray and improper completions.
#
# Completions live even when plugin isn't loaded - if they are
# installed and enabled.
#
# User-action entry point.
.zi-clear-completions() {
  builtin setopt localoptions nullglob extendedglob nokshglob noksharrays

  typeset -a completions
  completions=( "${ZI[COMPLETIONS_DIR]}"/_[^_.]*~*.zwc "${ZI[COMPLETIONS_DIR]}"/[^_.]*~*.zwc )
  # Find longest completion name
  local cpath c
  integer longest=0
  for cpath in "${completions[@]}"; do
    c="${cpath:t}"
    c="${c#_}"
    [[ "${#c}" -gt "$longest" ]] && longest="${#c}"
  done

  .zi-prepare-readlink
  local rdlink="$REPLY"
  integer disabled unknown stray
  for cpath in "${completions[@]}"; do
    c="${cpath:t}"
    [[ "${c#_}" = "${c}" ]] && disabled=1 || disabled=0
    c="${c#_}"

    # This will resolve completion's symlink to obtain
    # information about the repository it comes from, i.e.
    # about user and plugin, taken from directory name
    .zi-get-completion-owner "$cpath" "$rdlink"
    [[ "$REPLY" = "[unknown]" ]] && unknown=1 || unknown=0
    .zi-any-colorify-as-uspl2 "$REPLY"

    # If we successfully read a symlink (unknown == 0), test if it isn't broken
    stray=0
    if (( unknown == 0 )); then
      [[ ! -f "$cpath" ]] && stray=1
    fi
    if (( unknown == 1 || stray == 1 )); then
      builtin print -n "Removing completion: ${(r:longest+1:: :)c} $REPLY"
      (( disabled )) && builtin print -n " ${ZI[col-error]}[disabled]${ZI[col-rst]}"
      (( unknown )) && builtin print -n " ${ZI[col-error]}[unknown file]${ZI[col-rst]}"
      (( stray )) && builtin print -n " ${ZI[col-error]}[stray]${ZI[col-rst]}"
      builtin print
      command rm -f "$cpath"
    fi
  done
} # ]]]
# FUNCTION: .zi-search-completions [[[
# While .zi-show-completions() shows what completions are
# installed, this functions searches through all plugin dirs
# showing what's available in general (for installation).
#
# User-action entry point.
.zi-search-completions() {
  builtin setopt localoptions nullglob extendedglob nokshglob noksharrays

  typeset -a plugin_paths
  plugin_paths=( "${ZI[PLUGINS_DIR]}"/*(DN) )
  # Find longest plugin name. Things are ran twice here, first pass
  # is to get longest name of plugin which is having any completions
  integer longest=0
  typeset -a completions
  local pp
  for pp in "${plugin_paths[@]}"; do
    completions=( "$pp"/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*|*.ps1)(DN^/) )
    if [[ "${#completions[@]}" -gt 0 ]]; then
      local pd="${pp:t}"
      [[ "${#pd}" -gt "$longest" ]] && longest="${#pd}"
    fi
  done
  builtin print "${ZI[col-info]}[+]${ZI[col-rst]} is installed, ${ZI[col-p]}[-]${ZI[col-rst]} uninstalled, ${ZI[col-error]}[+-]${ZI[col-rst]} partially installed"

  local c
  for pp in "${plugin_paths[@]}"; do
    completions=( "$pp"/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*|*.ps1)(DN^/) )
    if [[ "${#completions[@]}" -gt 0 ]]; then
      # Array of completions, e.g. ( _cp _xauth )
      completions=( "${completions[@]:t}" )
      # Detect if the completions are installed
      integer all_installed="${#completions[@]}"
      for c in "${completions[@]}"; do
        if [[ -e "${ZI[COMPLETIONS_DIR]}/$c" || -e "${ZI[COMPLETIONS_DIR]}/${c#_}" ]]; then
          (( all_installed -- ))
        fi
      done
      if [[ "$all_installed" -eq "${#completions[@]}" ]]; then
        builtin print -n "${ZI[col-p]}[-]${ZI[col-rst]} "
      elif [[ "$all_installed" -eq "0" ]]; then
        builtin print -n "${ZI[col-info]}[+]${ZI[col-rst]} "
      else
        builtin print -n "${ZI[col-error]}[+-]${ZI[col-rst]} "
      fi
      # Convert directory name to colorified $user/$plugin
      .zi-any-colorify-as-uspl2 "${pp:t}"
      # Adjust for escape code (nasty, utilizes fact that
      # ${ZI[col-rst]} is used twice, so as a $ZI_COL)
      integer adjust_ec=$(( ${#ZI[col-rst]} * 2 + ${#ZI[col-uname]} + ${#ZI[col-pname]} ))
      builtin print "${(r:longest+adjust_ec:: :)REPLY} ${(j:, :)completions}"
    fi
  done
} # ]]]
# FUNCTION: .zi-cenable [[[
# Disables given installed completion.
#
# User-action entry point.
#
# $1 - e.g. "_mkdir" or "mkdir"
.zi-cenable() {
  local c="$1"
  c="${c#_}"
  local cfile="${ZI[COMPLETIONS_DIR]}/_${c}"
  local bkpfile="${cfile:h}/$c"
  if [[ ! -e "$cfile" && ! -e "$bkpfile" ]]; then
    builtin print "${ZI[col-error]}No such completion \`$c'${ZI[col-rst]}"
    return 1
  fi
  # Check if there is no backup file
  # This is treated as if the completion is already enabled
  if [[ ! -e "$bkpfile" ]]; then
    builtin print "Completion ${ZI[col-info]}$c${ZI[col-rst]} already enabled"
    .zi-check-comp-consistency "$cfile" "$bkpfile" 0
    return 1
  fi

  # Disabled, but completion file already exists?
  if [[ -e "$cfile" ]]; then
    builtin print "${ZI[col-error]}Warning: completion's file \`${cfile:t}' exists, will overwrite${ZI[col-rst]}"
    builtin print "${ZI[col-error]}Completion is actually enabled and will re-enable it again${ZI[col-rst]}"
    .zi-check-comp-consistency "$cfile" "$bkpfile" 1
    command rm -f "$cfile"
  else
    .zi-check-comp-consistency "$cfile" "$bkpfile" 0
  fi
  # Enable
  command mv "$bkpfile" "$cfile" # move completion's backup file created when disabling
  # Prepare readlink command for establishing completion's owner
  .zi-prepare-readlink
  # Get completion's owning plugin
  .zi-get-completion-owner-uspl2col "$cfile" "$REPLY"
  builtin print "Enabled ${ZI[col-info]}$c${ZI[col-rst]} completion belonging to $REPLY"
  return 0
} # ]]]
# FUNCTION: .zi-cdisable [[[
# Enables given installed completion.
#
# User-action entry point.
#
# $1 - e.g. "_mkdir" or "mkdir"
.zi-cdisable() {
  local c="$1"
  c="${c#_}"
  local cfile="${ZI[COMPLETIONS_DIR]}/_${c}"
  local bkpfile="${cfile:h}/$c"

  if [[ ! -e "$cfile" && ! -e "$bkpfile" ]]; then
    builtin print "${ZI[col-error]}No such completion \`$c'${ZI[col-rst]}"
    return 1
  fi
  # Check if it's already disabled
  # Not existing "$cfile" says that
  if [[ ! -e "$cfile" ]]; then
    builtin print "Completion ${ZI[col-info]}$c${ZI[col-rst]} already disabled"
    .zi-check-comp-consistency "$cfile" "$bkpfile" 0
    return 1
  fi
  # No disable, but bkpfile exists?
  if [[ -e "$bkpfile" ]]; then
    builtin print "${ZI[col-error]}Warning: completion's backup file \`${bkpfile:t}' already exists, will overwrite${ZI[col-rst]}"
    .zi-check-comp-consistency "$cfile" "$bkpfile" 1
    command rm -f "$bkpfile"
  else
    .zi-check-comp-consistency "$cfile" "$bkpfile" 0
  fi
  # Disable
  command mv "$cfile" "$bkpfile"
  # Prepare readlink command for establishing completion's owner
  .zi-prepare-readlink
  # Get completion's owning plugin
  .zi-get-completion-owner-uspl2col "$bkpfile" "$REPLY"
  builtin print "Disabled ${ZI[col-info]}$c${ZI[col-rst]} completion belonging to $REPLY"

  return 0
} # ]]]

# FUNCTION: .zi-cd [[[
# Jumps to plugin's directory (in ❮ ZI ❯ home directory).
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-cd() {
  builtin emulate -LR zsh
  builtin setopt extendedglob warncreateglobal typesetsilent rcquotes

  .zi-get-path "$1" "$2" && {
    if [[ -e $REPLY ]]; then
      builtin pushd $REPLY
    else
      +zi-message "No such plugin or snippet"
      return 1
    fi
    builtin print
  } || {
    +zi-message "No such plugin or snippet"
    return 1
  }
} # ]]]
# FUNCTION: .zi-run-delete-hooks [[[
.zi-run-delete-hooks() {
  if [[ -n ${ICE[atdelete]} ]]; then
    .zi-countdown "atdelete" && ( (( ${+ICE[nocd]} == 0 )) && \
        { builtin cd -q "$5" && eval "${ICE[atdelete]}"; ((1)); } || \
        eval "${ICE[atdelete]}" )
  fi

  local -a arr
  local key
  # Run annexes' atdelete hooks
  reply=(
    ${(on)ZI_EXTS2[(I)zi hook:atdelete-pre <->]}
    ${(on)ZI_EXTS[(I)z-annex hook:atdelete-<-> <->]}
    ${(on)ZI_EXTS2[(I)zi hook:atdelete-post <->]}
  )
  for key in "${reply[@]}"; do
    arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
    "${arr[5]}" "$1" "$2" $3 "$4" "$5" "${${key##(zi|z-annex) hook:}%% <->}" delete:TODO
  done
} # ]]]
# FUNCTION: .zi-delete [[[
# Deletes plugin's or snippet's directory (in ❮ ZI ❯ home directory).
#
# User-action entry point.
#
# $1 - snippet URL or plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-delete() {
  emulate -LR zsh
  setopt extendedglob warncreateglobal typesetsilent
  local -a opts match mbegin mend
  local MATCH; integer MBEGIN MEND _retval
  # Parse options
  .zi-parse-opts delete "$@"
  builtin set -- "${reply[@]}"
  if (( $@[(I)-*] || OPTS[opt_-h,--help] )) { +zi-prehelp-usage-message delete $___opt_map[delete] $@; return 1; }
  local the_id="$1${${1:#(%|/)*}:+${2:+/}}$2"
  # -a/--all given?
  if (( OPTS[opt_-a,--all] )); then
    .zi-confirm "Prune all plugins in \`${ZI[PLUGINS_DIR]}'"\
"and snippets in \`${ZI[SNIPPETS_DIR]}'?" \
"command rm -rf ${${ZI[PLUGINS_DIR]%%[/[:space:]]##}:-${TMPDIR:-${TMPDIR:-/tmp}}/abcEFG312}/*~*/_local---zi(ND) "\
"${${ZI[SNIPPETS_DIR]%%[/[:space:]]##}:-${TMPDIR:-${TMPDIR:-/tmp}}/abcEFG312}/*~*/plugins(ND)"
    return $?
  fi
  # -c/--clean given?
  if (( OPTS[opt_-c,--clean] )) {
    .zi-confirm "Prune ${ZI[col-info]}CURRENTLY NOT LOADED${ZI[col-rst]}"\
" plugins in $ZI[col-file]$ZI[PLUGINS_DIR]%f%b"\
" and snippets in $ZI[col-file]$ZI[SNIPPETS_DIR]%f%b?" \
" # Delete unloaded snippets
local -aU loadedsnips todelete final_todelete
loadedsnips=( \${\${ZI_SNIPPETS[@]% <*>}/(#m)*/\$(.zi-get-object-path snippet \"\$MATCH\" && builtin print -rn \$REPLY; )} )
local dir=\${\${ZI[SNIPPETS_DIR]%%[/[:space:]]##}:-${TMPDIR:-${TMPDIR:-/tmp}}/xyzcba231}
todelete=( \$dir/*/*/*(ND/) \$dir/*/*(ND/) \$dir/*(ND/) )
final_todelete=( \${todelete[@]:#*/(\${(~j:|:)loadedsnips}|*/plugins|._backup|._zi|.svn|.git)(|/*)} )
final_todelete=( \${final_todelete[@]//(#m)*/\$( .zi-get-object-path snippet \"\${\${\${MATCH##\${dir}[/[:space:]]#}/(#i)(#b)(http(s|)|ftp(s|)|ssh|rsync)--/\${match[1]##--}://}//--//}\" && builtin print -r -- \$REPLY)} )
final_todelete=( \${final_todelete[@]:#(\${(~j:|:)loadedsnips}|*/plugins|*/._backup|*/._zi|*/.svn|*/.git)(|/*)} )
todelete=( \${\${\${(@)\${(@)final_todelete##\$dir/#}//(#i)(#m)(http(s|)|ftp(s|)|ssh|rsync)--/\${MATCH%--}://}//--//}//(#b)(*)\/([^\/]##)(#e)/\$match[1]/\$ZI[col-file]\$match[2]\$ZI[col-rst]} )
todelete=( \${todelete[@]//(#m)(#s)[^\/]##(#e)/\$ZI[col-file]\$MATCH\$ZI[col-rst]} )
final_todelete=( \${\${\${(@)\${(@)final_todelete##\$dir/#}//(#i)(#m)(http(s|)|ftp(s|)|ssh|rsync)--/\${MATCH%--}://}//--//}//(#b)(*)\/([^\/]##)(#e)/\$match[1]/\$match[2]} )
builtin print; print -Prln \"\$ZI[col-obj]Deleting the following \"\
\"\$ZI[col-file]\${#todelete}\$ZI[col-msg2] UNLOADED\$ZI[col-obj] snippets:%f%b\" \
\$todelete \"%f%b\"
sleep 3
local snip
for snip ( \$final_todelete ) { zi delete -q -y \$snip; _retval+=\$?; }
builtin print -Pr \"\$ZI[col-obj]Done (with the exit code: \$_retval).%f%b\"

# Next delete unloaded plugins
local -a dirs
dirs=( \${\${ZI[PLUGINS_DIR]%%[/[:space:]]##}:-${TMPDIR:-${TMPDIR:-/tmp}}/abcEFG312}/*~*/(\${(~j:|:)\${ZI_REGISTERED_PLUGINS[@]//\//---}})(ND/) )
dirs=( \${(@)\${dirs[@]##\$ZI[PLUGINS_DIR]/#}//---//} )
builtin print -Prl \"\" \"\$ZI[col-obj]Deleting the following \"\
\"\$ZI[col-file]\${#dirs}\$ZI[col-msg2] UNLOADED\$ZI[col-obj] plugins:%f%b\" \
\${\${dirs//(#b)(*)(\/([^\/]##))(#e)/\${\${match[2]:+\$ZI[col-uname]\$match[1]\$ZI[col-rst]/\$ZI[col-pname]\$match[3]\$ZI[col-rst]}:-\$ZI[col-pname]\$match[1]}}//(#b)(^\$ZI[col-uname])(*)/\$ZI[col-pname]\$match[1]}
sleep 3
for snip ( \$dirs ) { zi delete -q -y \$snip; _retval+=\$?; }
builtin print -Pr \"\$ZI[col-obj]Done (with the exit code: \$_retval).%f%b\""
    return _retval
  }

  local -A ICE2
  local local_dir filename is_snippet
  .zi-compute-ice "$the_id" "pack" \
    ICE2 local_dir filename is_snippet || return 1
  if [[ "$local_dir" != /* ]]
  then
    builtin print "Obtained a risky, not-absolute path ($local_dir), aborting"
    return 1
  fi

  ICE2[teleid]="${ICE2[teleid]:-${ICE2[id-as]}}"

  local -a files
  files=( "$local_dir"/*.(zsh|sh|bash|ksh)(DN:t)
    "$local_dir"/*(*DN:t) "$local_dir"/*(@DN:t) "$local_dir"/*(.DN:t)
    "$local_dir"/*~*/.(_zi|svn|git)(/DN:t) "$local_dir"/*(=DN:t)
    "$local_dir"/*(pDN:t) "$local_dir"/*(%DN:t)
  )
  (( !${#files} )) && files=( "no files?" )
  files=( ${(@)files[1,4]} ${files[4]+more…} )

  # Make the ices available for the hooks.
  local -A ICE
  ICE=( "${(kv)ICE2[@]}" )
  if (( is_snippet )); then
    if [[ "${+ICE2[svn]}" = "1" ]] {
      if [[ -e "$local_dir" ]]
      then
        .zi-confirm "Delete $local_dir? (it holds: ${(j:, :)${(@u)files}})" \
          ".zi-run-delete-hooks snippet \"${ICE2[teleid]}\" \"\" \"$the_id\" \
          \"$local_dir\"; \
          command rm -rf ${(q)${${local_dir:#[/[:space:]]##}:-${TMPDIR:-${TMPDIR:-/tmp}}/abcYZX321}}"
      else
        builtin print "No such snippet"
        return 1
      fi
    } else {
      if [[ -e "$local_dir" ]]; then
        .zi-confirm "Delete $local_dir? (it holds: ${(j:, :)${(@u)files}})" \
          ".zi-run-delete-hooks snippet \"${ICE2[teleid]}\" \"\" \"$the_id\" \
          \"$local_dir\"; command rm -rf \
            ${(q)${${local_dir:#[/[:space:]]##}:-${TMPDIR:-${TMPDIR:-/tmp}}/abcYZX321}}"
      else
        builtin print "No such snippet"
        return 1
      fi
    }
  else
    .zi-any-to-user-plugin "${ICE2[teleid]}"
    if [[ -e "$local_dir" ]]; then
      .zi-confirm "Delete $local_dir? (it holds: ${(j:, :)${(@u)files}})" \
        ".zi-run-delete-hooks plugin \"${reply[-2]}\" \"${reply[-1]}\" \"$the_id\" \
        \"$local_dir\"; \
        command rm -rf ${(q)${${local_dir:#[/[:space:]]##}:-${TMPDIR:-${TMPDIR:-/tmp}}/abcYZX321}}"
    else
      builtin print -r -- "No such plugin or snippet"
      return 1
    fi
  fi
  return 0
} # ]]]
# FUNCTION: .zi-confirm [[[
# Prints given question, waits for "y" key, evals given expression if "y" obtained
#
# $1 - question
# $2 - expression
.zi-confirm() {
  if (( OPTS[opt_-y,--yes] )); then
    integer retval
    eval "$2"; retval=$?
    (( OPTS[opt_-q,--quiet] )) || builtin print "\nDone (action executed, exit code: $retval)"
  else
    builtin print -Pr -- "$1"
    builtin print "[yY/n…]"
    local ans
    if [[ -t 0 ]] {
      read -q ans
    } else {
      read -k1 -u0 ans
    }
    if [[ "$ans" = "y" ]] {
      eval "$2"
      builtin print "\nDone (action executed, exit code: $?)"
    } else {
      builtin print "\nBreak, no action"
      return 1
    }
  fi
  return 0
} # ]]]
# FUNCTION: .zi-changes [[[
# Shows `git log` of given plugin.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-changes() {
  .zi-any-to-user-plugin "$1" "$2"
  local user="${reply[-2]}" plugin="${reply[-1]}"
  .zi-exists-physically-message "$user" "$plugin" || return 1
  (
    builtin cd -q "${ZI[PLUGINS_DIR]}/${user:+${user}---}${plugin//\//---}" && command git log -p --graph --decorate --date=relative -C -M
  )
} # ]]]
# FUNCTION: .zi-recently [[[
# Shows plugins that obtained commits in specified past time.
#
# User-action entry point.
#
# $1 - time spec, e.g. "1 week"
.zi-recently() {
  emulate -LR zsh
  builtin setopt nullglob extendedglob warncreateglobal typesetsilent noshortloops
  local IFS=.
  local gitout
  local timespec=${*// ##/.}
  timespec=${timespec//.##/.}
  [[ -z $timespec ]] && timespec=1.week
  typeset -a plugins
  plugins=( ${ZI[PLUGINS_DIR]}/*(DN-/) )
  local p uspl1
  for p in ${plugins[@]}; do
    uspl1=${p:t}
    [[ $uspl1 = custom || $uspl1 = _local---zi ]] && continue
    pushd "$p" >/dev/null || continue
    if [[ -d .git ]]; then
      gitout=`command git log --all --max-count=1 --since=$timespec 2>/dev/null`
      if [[ -n $gitout ]]; then
        .zi-any-colorify-as-uspl2 "$uspl1"
        builtin print -r -- "$REPLY"
      fi
    fi
    popd >/dev/null
  done
} # ]]]
# FUNCTION: .zi-create [[[
# Creates a plugin, also on Github (if not "_local/name" plugin).
#
# User-action entry point.
#
# $1 - (optional) plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - (optional) plugin (only when $1 - i.e. user - given)
.zi-create() {
  emulate -LR zsh
  setopt localoptions extendedglob warncreateglobal typesetsilent noshortloops rcquotes

  .zi-any-to-user-plugin "$1" "$2"
  local user="${reply[-2]}" plugin="${reply[-1]}"
  if (( ${+commands[curl]} == 0 || ${+commands[git]} == 0 )); then
    builtin print "${ZI[col-error]}curl and git are needed${ZI[col-rst]}"
    return 1
  fi
  # Read whether to create under organization
  local isorg
  vared -cp 'Create under an organization? (y/n): ' isorg
  if [[ $isorg = (y|yes) ]]; then
    local org="$user"
    vared -cp "Github organization name: " org
  fi
  # Read user
  local compcontext="user:User Name:(\"$USER\" \"$user\")"
  vared -cp "Github user name or just \"_local\" (or leave blank, for an userless plugin): " user
  # Read plugin
  unset compcontext
  vared -cp 'Plugin name: ' plugin
  if [[ "$plugin" = "_unknown" ]]; then
    builtin print "${ZI[col-error]}No plugin name entered${ZI[col-rst]}"
    return 1
  fi
  plugin="${plugin//[^a-zA-Z0-9_]##/-}"
  .zi-any-colorify-as-uspl2 "${${${(M)isorg:#(y|yes)}:+$org}:-$user}" "$plugin"
  local uspl2col="$REPLY"
  builtin print "Plugin is $uspl2col"

  if .zi-exists-physically "${${${(M)isorg:#(y|yes)}:+$org}:-$user}" "$plugin"; then
    builtin print "${ZI[col-error]}Repository${ZI[col-rst]} $uspl2col ${ZI[col-error]}already exists locally${ZI[col-rst]}"
    return 1
  fi

  builtin cd -q "${ZI[PLUGINS_DIR]}"

  if [[ "$user" != "_local" && -n "$user" ]]; then
    builtin print "${ZI[col-info]}Creating Github repository${ZI[col-rst]}"
    if [[ $isorg = (y|yes) ]]; then
      curl --silent -u "$user" https://api.github.com/orgs/$org/repos -d '{"name":"'"$plugin"'"}' >/dev/null
    else
      curl --silent -u "$user" https://api.github.com/user/repos -d '{"name":"'"$plugin"'"}' >/dev/null
    fi
    command git clone "https://github.com/${${${(M)isorg:#(y|yes)}:+$org}:-$user}/${plugin}.git" "${${${(M)isorg:#(y|yes)}:+$org}:-$user}---${plugin//\//---}" || {
      builtin print "${ZI[col-error]}Creation of remote repository $uspl2col ${ZI[col-error]}failed${ZI[col-rst]}"
      builtin print "${ZI[col-error]}Bad credentials?${ZI[col-rst]}"
      return 1
    }
    builtin cd -q "${${${(M)isorg:#(y|yes)}:+$org}:-$user}---${plugin//\//---}"
    command git config credential.https://github.com.username "${user}"
  else
    builtin print "${ZI[col-info]}Creating local git repository${${user:+.}:-, ${ZI[col-pname]}free-style, without the \"_local/\" part${ZI[col-info]}.}${ZI[col-rst]}"
    command mkdir "${user:+${user}---}${plugin//\//---}"
    builtin cd -q "${user:+${user}---}${plugin//\//---}"
    command git init || {
      builtin print "Git repository initialization failed, aborting"
      return 1
    }
  fi
  local user_name="$(command git config user.name 2>/dev/null)"
  local year="${$(command date "+%Y"):-2020}"

  command cat >! "${plugin:t}.plugin.zsh" <<EOF
# -*- mode: sh; sh-indentation: 4; indent-tabs-mode: nil; sh-basic-offset: 4; -*-

# Copyright (c) $year $user_name

# According to the Zsh Plugin Standard:
# https://github.com/z-shell/zi/wiki/Zsh-Plugin-Standard

0=\${\${ZERO:-\${0:#\$ZSH_ARGZERO}}:-\${(%):-%N}}
0=\${\${(M)0:#/*}:-\$PWD/\$0}

# Then \${0:h} to get plugin's directory

if [[ \${zsh_loaded_plugins[-1]} != */${plugin:t} && -z \${fpath[(r)\${0:h}]} ]] {
  fpath+=( "\${0:h}" )
}

# Standard hash for plugins, to not pollute the namespace
typeset -gA Plugins
Plugins[${${(U)plugin:t}//-/_}_DIR]="\${0:h}"

autoload -Uz example-script

# Use alternate vim marks [[[ and ]]] as the original ones can
# confuse nested substitutions, e.g.: \${\${\${VAR}}}

# vim:ft=zsh:tw=80:sw=4:sts=4:et:foldmarker=[[[,]]]
EOF

  command cat >>! .git/config <<EOF

[diff "zsh"]
  xfuncname = "^((function[[:blank:]]+[^[:blank:]]+[[:blank:]]*(\\\\(\\\\)|))|([^[:blank:]]+[[:blank:]]*\\\\(\\\\)))[[:blank:]]*(\\\\{|)[[:blank:]]*$"
[diff "markdown"]
  xfuncname = "^#+[[:blank:]].*$"
EOF

  builtin print -r -- "*.zsh  diff=zsh" >! .gitattributes
  builtin print -r -- "*.md   diff=markdown" >! .gitattributes
  builtin print -r -- "# $plugin" >! "README.md"
  command cp -vf "${ZI[BIN_DIR]}/LICENSE" LICENSE
  command cp -vf "${ZI[BIN_DIR]}/lib/templates/zsh.gitignore" .gitignore
  command cp -vf "${ZI[BIN_DIR]}/lib/templates/example-script" .

  command sed -i -e "s/MY_PLUGIN_DIR/${${(U)plugin:t}//-/_}_DIR/g" example-script
  command sed -i -e "s/USER_NAME/$user_name/g" example-script
  command sed -i -e "s/YEAR/$year/g" example-script

  if [[ "$user" != "_local" && -n "$user" ]]; then
    builtin print "Remote repository $uspl2col set up as origin."
    builtin print "You're in plugin's local folder, the files aren't added to git."
    builtin print "Your next step after commiting will be:"
    builtin print "git push -u origin master (or \`… -u origin main')"
  else
    builtin print "Created local $uspl2col plugin."
    builtin print "You're in plugin's repository folder, the files aren't added to git."
  fi
} # ]]]
# FUNCTION: .zi-glance [[[
# Shows colorized source code of plugin. Is able to use pygmentize,
# highlight, GNU source-highlight.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-glance() {
  .zi-any-to-user-plugin "$1" "$2"
  local user="${reply[-2]}" plugin="${reply[-1]}"

  .zi-exists-physically-message "$user" "$plugin" || return 1

  .zi-first "$1" "$2" || {
    builtin print "${ZI[col-error]}No source file found, cannot glance${ZI[col-rst]}"
    return 1
  }
  local fname="${reply[-1]}"

  integer has_256_colors=0
  [[ "$TERM" = xterm* || "$TERM" = "screen" ]] && has_256_colors=1
  {
    if (( ${+commands[pygmentize]} )); then
      builtin print "Glancing with ${ZI[col-info]}pygmentize${ZI[col-rst]}"
      pygmentize -l bash -g "$fname"
    elif (( ${+commands[highlight]} )); then
      builtin print "Glancing with ${ZI[col-info]}highlight${ZI[col-rst]}"
      if (( has_256_colors )); then
        highlight -q --force -S sh -O xterm256 "$fname"
      else
        highlight -q --force -S sh -O ansi "$fname"
      fi
    elif (( ${+commands[source-highlight]} )); then
      builtin print "Glancing with ${ZI[col-info]}source-highlight${ZI[col-rst]}"
      source-highlight -fesc --failsafe -s zsh -o STDOUT -i "$fname"
    else
      cat "$fname"
    fi
  } | {
    if [[ -t 1 ]]; then
      .zi-pager
    else
      cat
    fi
  }
} # ]]]
# FUNCTION: .zi-edit [[[
# Runs $EDITOR on source of given plugin. If the variable is not set then defaults to `code'.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-edit() {
  local -A ICE2
  local local_dir filename is_snippet the_id="$1${${1:#(%|/)*}:+${2:+/}}$2"

  .zi-compute-ice "$the_id" "pack" ICE2 local_dir filename is_snippet || return 1

  ICE2[teleid]="${ICE2[teleid]:-${ICE2[id-as]}}"
  if (( is_snippet )); then
    if [[ ! -e "$local_dir" ]]; then
      builtin print "No such snippet"
      return 1
    fi
  else
    if [[ ! -e "$local_dir" ]]; then
      builtin print -r -- "No such plugin or snippet"
      return 1
    fi
  fi
  "${EDITOR:-code}" "$local_dir"
  return 0
} # ]]]
# FUNCTION: .zi-stress [[[
# Compiles plugin with various options on and off to see how well the code is written. The options are:
#
# NO_SHORT_LOOPS, IGNORE_BRACES, IGNORE_CLOSE_BRACES, SH_GLOB, CSH_JUNKIE_QUOTES, NO_MULTI_FUNC_DEF.
#
# User-action entry point.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-stress() {
  .zi-any-to-user-plugin "$1" "$2"
  local user="${reply[-2]}" plugin="${reply[-1]}"
  .zi-exists-physically-message "$user" "$plugin" || return 1
  .zi-first "$1" "$2" || {
  builtin print "${ZI[col-error]}No source file found, cannot stress${ZI[col-rst]}"
  return 1
  }
  local pdir_path="${reply[-2]}" fname="${reply[-1]}"
  integer compiled=1
  [[ -e "${fname}.zwc" ]] && command rm -f "${fname}.zwc" || compiled=0
  local -a ZI_STRESS_TEST_OPTIONS
  ZI_STRESS_TEST_OPTIONS=(
  "NO_SHORT_LOOPS" "IGNORE_BRACES" "IGNORE_CLOSE_BRACES"
  "SH_GLOB" "CSH_JUNKIE_QUOTES" "NO_MULTI_FUNC_DEF"
  )
  (
  emulate -LR ksh
  builtin unsetopt shglob kshglob
  for i in "${ZI_STRESS_TEST_OPTIONS[@]}"; do
    builtin setopt "$i"
    builtin print -n "Stress-testing ${fname:t} for option $i "
      zcompile -UR "$fname" 2>/dev/null && {
      builtin print "[${ZI[col-success]}Success${ZI[col-rst]}]"
    } || {
      builtin print "[${ZI[col-failure]}Fail${ZI[col-rst]}]"
    }
    builtin unsetopt "$i"
  done
  )
  command rm -f "${fname}.zwc"
  (( compiled )) && zcompile -U "$fname"
} # ]]]
# FUNCTION: .zi-list-compdef-replay [[[
# Shows recorded compdefs (called by plugins loaded earlier). Plugins often call `compdef' hoping
# for `compinit' being already ran. ❮ ZI ❯ solves this by recording compdefs.
#
# User-action entry point.
.zi-list-compdef-replay() {
  builtin print "Recorded compdefs:"
  local cdf
  for cdf in "${ZI_COMPDEF_REPLAY[@]}"; do
  builtin print "compdef ${(Q)cdf}"
  done
} # ]]]
# FUNCTION: .zi-ls [[[
.zi-ls() {
  (( ${+commands[tree]} )) || {
    builtin print "${ZI[col-error]}No \`tree' program, it is required by the subcommand \`ls\'${ZI[col-rst]}"
    builtin print "Download from: http://mama.indstate.edu/users/ice/tree/"
    builtin print "It is also available probably in all distributions and Homebrew, as package \`tree'"
  }
  (
    builtin cd -q "${ZI[SNIPPETS_DIR]}"
    local -a list
    list=( "${(f@)"$(LANG=en_US.utf-8 tree -L 3 --charset utf-8)"}" )
    # Oh-My-Zsh single file
    list=( "${list[@]//(#b)(https--github.com--(ohmyzsh|robbyrussel)l--oh-my-zsh--raw--master(--)(#c0,1)(*))/$ZI[col-info]Oh-My-Zsh$ZI[col-error]${match[2]/--//}$ZI[col-pname]${match[3]//--/$ZI[col-error]/$ZI[col-pname]} $ZI[col-info](single-file)$ZI[col-rst] ${match[1]}}" )
    # Oh-My-Zsh SVN
    list=( "${list[@]//(#b)(https--github.com--(ohmyzsh|robbyrussel)l--oh-my-zsh--trunk(--)(#c0,1)(*))/$ZI[col-info]Oh-My-Zsh$ZI[col-error]${match[2]/--//}$ZI[col-pname]${match[3]//--/$ZI[col-error]/$ZI[col-pname]} $ZI[col-info](SVN)$ZI[col-rst] ${match[1]}}" )
    # Prezto single file
    list=( "${list[@]//(#b)(https--github.com--sorin-ionescu--prezto--raw--master(--)(#c0,1)(*))/$ZI[col-info]Prezto$ZI[col-error]${match[2]/--//}$ZI[col-pname]${match[3]//--/$ZI[col-error]/$ZI[col-pname]} $ZI[col-info](single-file)$ZI[col-rst] ${match[1]}}" )
    # Prezto SVN
    list=( "${list[@]//(#b)(https--github.com--sorin-ionescu--prezto--trunk(--)(#c0,1)(*))/$ZI[col-info]Prezto$ZI[col-error]${match[2]/--//}$ZI[col-pname]${match[3]//--/$ZI[col-error]/$ZI[col-pname]} $ZI[col-info](SVN)$ZI[col-rst] ${match[1]}}" )
    # First-level names
    list=( "${list[@]//(#b)(#s)(│   └──|    └──|    ├──|│   ├──) (*)/${match[1]} $ZI[col-p]${match[2]}$ZI[col-rst]}" )
    list[-1]+=", located at ZI[SNIPPETS_DIR], i.e. ${ZI[SNIPPETS_DIR]}"
    builtin print -rl -- "${list[@]}"
  )
} # ]]]
# FUNCTION: .zi-get-path [[[
# Returns path of given ID-string, which may be a plugin-spec (like "user/plugin" or "user" "plugin"), an absolute path
# ("%" "/home/..." and also "%SNIPPETS/..." etc.), or a plugin nickname (i.e. id-as'' ice-mod), or a snippet nickname.
.zi-get-path() {
  emulate -LR zsh
  setopt extendedglob warncreateglobal typesetsilent noshortloops
  [[ $1 == % ]] && local id_as=%$2 || local id_as=$1${1:+/}$2
  .zi-get-object-path snippet "$id_as" || .zi-get-object-path plugin "$id_as"
  return $(( 1 - reply[3] ))
} # ]]]
# FUNCTION: .zi-recall [[[
.zi-recall() {
  emulate -LR zsh
  setopt extendedglob warncreateglobal typesetsilent noshortloops
  local -A ice
  local el val cand1 cand2 local_dir filename is_snippet
  local -a ice_order nval_ices output
  ice_order=(
    ${(s.|.)ZI[ice-list]}
    # Include all additional ices – after stripping them from the possible: ''
    ${(@)${(@Akons:|:u)${ZI_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}
  )
  nval_ices=(
    ${(s.|.)ZI[nval-ice-list]}
    # Include only those additional ices, don't have the '' in their name, i.e. aren't designed to hold value
    ${(@)${(@)${(@Akons:|:u)ZI_EXTS[ice-mods]}:#*\'\'*}/(#s)<->-/}
    # Must be last
    svn
  )
  .zi-compute-ice "$1${${1:#(%|/)*}:+${2:+/}}$2" "pack" ice local_dir filename is_snippet || return 1
  [[ -e $local_dir ]] && {
    for el ( ${ice_order[@]} ) {
      val="${ice[$el]}"
      cand1="${(qqq)val}"
      cand2="${(qq)val}"
      if [[ -n "$val" ]] {
        [[ "${cand1/\\\$/}" != "$cand1" || "${cand1/\\\!/}" != "$cand1" ]] && output+=( "$el$cand2" ) || output+=( "$el$cand1" )
      } elif [[ ${+ice[$el]} = 1 && -n "${nval_ices[(r)$el]}" ]] {
        output+=( "$el" )
      }
    }
    if [[ ${#output} = 0 ]]; then
      builtin print -zr "# No Ice modifiers"
    else
      builtin print -zr "zi ice ${output[*]}; zi "
    fi
    +zi-deploy-message @rst
  } || builtin print -r -- "No such plugin or snippet"
} # ]]]
# FUNCTION: .zi-module [[[
# Function that has sub-commands passed as long-options (with two dashes, --).
# It's an attempt to plugin only this one function into `zi' function
# defined in zi.zsh, to not make this file longer than it's needed.
.zi-module() {
  if [[ "$1" = "build" ]]; then
    .zi-build-module "${@[2,-1]}"
  elif [[ "$1" = "info" ]]; then
    if [[ "$2" = "--link" ]]; then
      builtin print -r "You can copy the error messages and submit"
      builtin print -r "error-report at: https://github.com/z-shell/zpmod/issues"
    else
      builtin print -r "To load the module, add following 2 lines to .zshrc, at top:"
      builtin print -r "    module_path+=( ${ZI[ZMODULES_DIR]}/zpmod/Src )"
      builtin print -r "    zmodload zi/zpmod"
      builtin print -r ""
      builtin print -r "After loading, use command \`zpmod' to communicate with the module."
      builtin print -r "See \`zpmod -h' for more information."
    fi
  elif [[ "$1" = (help|usage) ]]; then
    builtin print -r "Usage: zi module {build|info|help} [options]"
    builtin print -r "       zi module build [--clean]"
    builtin print -r "       zi module info [--link]"
    builtin print -r ""
    builtin print -r "To start using the ❮ ZI ❯ Zsh module run: \`zi module build'"
    builtin print -r "and follow the instructions. Option --clean causes \`make distclean'"
    builtin print -r "to be run. To display the instructions on loading the module, run:"
    builtin print -r "\`zi module info'."
  fi
} # ]]]
# FUNCTION: .zi-build-module [[[
# Performs ./configure && make on the module and displays information how to load the module in .zshrc.
.zi-build-module() {
  if command git -C "${${ZI[ZMODULES_DIR]}}/zpmod" rev-parse 2>/dev/null; then
    command git -C "${${ZI[ZMODULES_DIR]}}/zpmod" clean -d -f -f
    command git -C "${${ZI[ZMODULES_DIR]}}/zpmod" reset --hard HEAD
    command git -C "${${ZI[ZMODULES_DIR]}}/zpmod" pull
  else
    if ! test -d "${${ZI[ZMODULES_DIR]}}/zpmod"; then
      mkdir -p "${${ZI[ZMODULES_DIR]}}/zpmod"
      chmod g-rwX "${${ZI[ZMODULES_DIR]}}/zpmod"
    fi
    command git clone "https://github.com/z-shell/zpmod.git" "${${ZI[ZMODULES_DIR]}}/zpmod" || {
      builtin print "${ZI[col-error]}Failed to clone module repo${ZI[col-rst]}"
      return 1
    }
  fi
  ( builtin cd -q "${ZI[ZMODULES_DIR]}/zpmod"
    +zi-message "{pname}== Building module zi/zpmod, running: make clean, then ./configure and then make =={rst}"
    +zi-message "{pname}== The module sources are located at: "${ZI[ZMODULES_DIR]}/zpmod" =={rst}"
    if [[ -f Makefile ]] {
      if [[ "$1" = "--clean" ]] {
        noglob +zi-message {p}-- make distclean --{rst}
        make distclean
        ((1))
      } else {
        noglob +zi-message {p}-- make clean --{rst}
        make clean
      }
    }
    noglob +zi-message  {p}-- ./configure --{rst}
    CPPFLAGS=-I/usr/local/include CFLAGS="-g -Wall -O3" LDFLAGS=-L/usr/local/lib ./configure --disable-gdbm --without-tcsetpgrp && {
      noglob +zi-message {p}-- make --{rst}
      if { make } {
        [[ -f Src/zi/zpmod.so ]] && cp -vf Src/zi/zpmod.{so,bundle}
        noglob +zi-message "{info}Module has been built correctly.{rst}"
        .zi-module info
      } else {
        noglob +zi-message  "{error}Module didn't build.{rst} "
        .zi-module info --link
      }
    }
    builtin print $EPOCHSECONDS >! "${ZI[ZMODULES_DIR]}/zpmod/COMPILED_AT"
  )
}
# ]]]

#
# Help function
#

# FUNCTION: .zi-help [[[
# Shows usage information.
#
# User-action entry point.
.zi-help() {
  builtin print -r -- "${ZI[col-p]}❮ ZI ❯ Usage${ZI[col-rst]}:
»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
❯ analytics                     – ❮ ZI ❯ Analytics
❯ control                       – ❮ ZI ❯ Control options
❯ self-update                   – ❮ ZI ❯ Self update and compile
❯ compinit                      – Refresh completions
❯ cdreplay [-q]                 – Replay compdefs (to be done after compinit), -q – quiet
❯ cdclear  [-q]                 – Clear compdef replay list, -q – quiet
❯ bindkeys                      – Lists bindkeys
❯ module                        – Manage zpmod (binary Zsh module), see \`zi module help'
❯ env-whitelist [-v|-h] {env..} – Specify names or paterns of variables left unchanged during an unload. -v – verbose
❯ man                           – Manual
❯ help                          – Help
»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
${ZI[col-p]}Available sub-commands${ZI[col-rst]}:"
  integer idx
  local type key
  local -a arr
  for type in subcommand hook; do
    for (( idx=1; idx <= ZI_EXTS[seqno]; ++ idx )); do
      key="${(k)ZI_EXTS[(r)$idx *]}"
      [[ -z "$key" || "$key" != "z-annex $type:"* ]] && continue
      arr=( "${(Q)${(z@)ZI_EXTS[$key]}[@]}" )
      (( ${+functions[${arr[6]}]} )) && { "${arr[6]}"; ((1)); } || \
        { builtin print -rl -- "(Couldn't find the help-handler \`${arr[6]}' of the z-annex \`${arr[3]}')"; }
    done
  done
local -a ice_order
ice_order=( ${${(s.|.)ZI[ice-list]}:#teleid} ${(@)${(@)${(@Akons:|:u)${ZI_EXTS[ice-mods]//\'\'/}}/(#s)<->-/}:#(.*|dynamic-unscope)} )
  builtin print -r -- "${ZI[col-p]}Available ice-modifiers:${ZI[col-rst]}
${ice_order[*]}"
} # ]]]
# FUNCTION: .zi-analytics-menu [[[
# Shows ❮ ZI ❯ analytics.
#
# User-action entry point.
.zi-analytics-menu() {
  builtin print -r -- "${ZI[col-p]}❮ ZI ❯ Analytics${ZI[col-rst]}:
»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
❯ cd             ${ZI[col-pname]}[plugin]${ZI[col-rst]}     – Enter plugin's directory; also support snippets, if feed with URL
❯ status         ${ZI[col-pname]}[plugin]${ZI[col-rst]}|URL – Git status for plugin or svn status for snippet; – accepts --all
❯ report         ${ZI[col-pname]}[plugin]${ZI[col-rst]}     – Show plugin's report; – accepts --all
❯ glance         ${ZI[col-pname]}[plugin]${ZI[col-rst]}     – Look at plugin's source (pygmentize, {,source-}highlight)
❯ stress         ${ZI[col-pname]}[plugin]${ZI[col-rst]}     – Test plugin for compatibility with set of options
❯ changes        ${ZI[col-pname]}[plugin]${ZI[col-rst]}     – View plugin's git log
❯ recently       ${ZI[col-info]}[time]${ZI[col-rst]}       – Show plugins that changed recently, argument is e.g. 1 month 2 days
❯ times [-s] [-m]             – Statistics on plugin load times, sorted in order of loading; -s – use seconds instead of milliseconds, -m – show plugin loading moments
❯ zstatus                     – Overall ❮ ZI ❯ status
❯ dtrace|dstart               – Start tracking what's going on in session
❯ dstop                       – Stop tracking what's going on in session
❯ dreport                     – Report what was going on in session
❯ dunload                     – Revert changes recorded between dstart and dstop
❯ dclear                      – Clear report of what was going on in session
❯ loaded|list {keyword}       – Show what plugins are loaded (filter with \'keyword')
❯ compiled                    – List plugins that are compiled
❯ clist|completions           – List completions in use
❯ cdlist                      – Show compdef replay list
❯ csearch                     – Search for available completions from any plugin
❯ ls                          – List snippets in formatted and colorized manner
»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»"
} # ]]]
# FUNCTION: .zi-control-menu [[[
# Shows control options.
#
# User-action entry point.
.zi-control-menu() {
  builtin print -r -- "»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
${ZI[col-p]}❮ ZI ❯ Control${ZI[col-rst]}:
❯ update  [-q]   ${ZI[col-pname]}[plugin]${ZI[col-rst]}|URL   – Git update plugin or snippet; – accepts --all; -q/--quiet; -r/--reset causes to run 'git reset --hard' or 'svn revert'
❯ load           ${ZI[col-pname]}[plugin]${ZI[col-rst]}       – Load plugin, can also receive absolute local path
❯ light   [-b]   ${ZI[col-pname]}[plugin]${ZI[col-rst]}       – Light plugin load, without reporting/tracking (-b – do track but bindkey-calls only)
❯ unload         ${ZI[col-pname]}[plugin]${ZI[col-rst]}       – Unload plugin; -q – quiet
❯ snippet [-f]   ${ZI[col-pname]}{url}${ZI[col-rst]}          – Source local or remote file (by direct URL), -f: force – don't use cache
❯ cdisable       ${ZI[col-info]}[cname]${ZI[col-rst]}        – Disable completion \`cname'
❯ cenable        ${ZI[col-info]}[cname]${ZI[col-rst]}        – Enable completion \`cname'
❯ delete         ${ZI[col-pname]}[plugin]${ZI[col-rst]}|URL   – Remove plugin or snippet from disk (good to forget wrongly passed ice-mods); --all – purge, --clean – delete plugins and snippets that are not loaded
❯ create         ${ZI[col-pname]}[plugin]${ZI[col-rst]}       – Create plugin (also together with Github repository)
❯ edit           ${ZI[col-pname]}[plugin]${ZI[col-rst]}       – Edit plugin's file with \$EDITOR
❯ recall         ${ZI[col-pname]}[plugin]${ZI[col-rst]}|URL   – Fetch saved ice modifiers and construct \`zi ice ...' command
❯ add-fpath      ${ZI[col-pname]}[plugin]${ZI[col-rst]}|DIR   – Adds given plugin directory to \$fpath; second argument is appended to the directory path; use -f/--front to prepend instead.
❯ compile        ${ZI[col-pname]}[plugin]${ZI[col-rst]}       – Compile plugin (or all plugins if --all passed)
❯ uncompile      ${ZI[col-pname]}[plugin]${ZI[col-rst]}       – Remove compiled version of plugin (or of all plugins if --all passed)
❯ creinstall     ${ZI[col-pname]}[plugin]${ZI[col-rst]}       – Install completions for plugin, can also receive absolute local path; -q – quiet
❯ cuninstall     ${ZI[col-pname]}[plugin]${ZI[col-rst]}       – Uninstall completions for plugin
❯ run     [-l]   ${ZI[col-pname]}[plugin]${ZI[col-rst]}|CMD   – Runs command in the given plugin's directory; if -l given then plugin should be skipped – the option will cause the previous plugin to be reused
❯ ice ${ZI[col-pname]}<ice specification>${ZI[col-rst]}       – Add ICE to next command, e.g. from\"gitlab\"
❯ srv        ${ZI[col-pname]}{service-id}${ZI[col-rst]}|CMD   – Control a service, command can be: stop,start,restart,next,quit; \`next' moves the service to another Z-Shell
»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»"
} # ]]]
