# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
#
# Copyright (c) 2016-2020 Sebastian Gniazdowski and contributors.
# Copyright (c) 2021 Salvydas Lukosius and Z-Shell ZI contributors.

builtin source "${ZI[BIN_DIR]}/lib/zsh/side.zsh" || { builtin print -P "${ZI[col-error]}ERROR:%f%b Couldn't find ${ZI[col-obj]}/lib/zsh/side.zsh%f%b."; return 1; }

# FUNCTION: .zi-parse-json [[[
# Retrievies the ice-list from given profile from the JSON of the package.json.
.zi-parse-json() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal typesetsilent

  local -A ___pos_to_level ___level_to_pos ___pair_map ___final_pairs ___Strings ___Counts
  local ___input=$1 ___workbuf=$1 ___key=$2 ___varname=$3 ___style ___quoting
  integer ___nest=${4:-1} ___idx=0 ___pair_idx ___level=0 ___start ___end ___sidx=1 ___had_quoted_value=0
  local -a match mbegin mend ___pair_order
  (( ${(P)+___varname} )) || typeset -gA "$___varname"
  ___pair_map=( "{" "}" "[" "]" )

  while [[ $___workbuf = (#b)[^"{}[]\\\"'":,]#((["{[]}\"'":,])|[\\](*))(*) ]]; do
    if [[ -n ${match[3]} ]] {
      ___idx+=${mbegin[1]}

      [[ $___quoting = \' ]] && \
        { ___workbuf=${match[3]}; } || \
        { ___workbuf=${match[3]:1}; (( ++ ___idx )); }
    } else {
      ___idx+=${mbegin[1]}
      if [[ -z $___quoting ]] {
        if [[ ${match[1]} = ["({["] ]]; then
          ___Strings[$___level/${___Counts[$___level]}]+=" $'\0'--object--$'\0'"
          ___pos_to_level[$___idx]=$(( ++ ___level ))
          ___level_to_pos[$___level]=$___idx
          (( ___Counts[$___level] += 1 ))
          ___sidx=___idx+1
          ___had_quoted_value=0
        elif [[ ${match[1]} = ["]})"] ]]; then
          (( !___had_quoted_value )) && \
            ___Strings[$___level/${___Counts[$___level]}]+=" ${(q)___input[___sidx,___idx-1]//((#s)[[:blank:]]##|([[:blank:]]##(#e)))}"
          ___had_quoted_value=1
          if (( ___level > 0 )); then
            ___pair_idx=${___level_to_pos[$___level]}
            ___pos_to_level[$___idx]=$(( ___level -- ))
            if [[ ${___pair_map[${___input[___pair_idx]}]} = ${___input[___idx]} ]] {
              ___final_pairs[$___idx]=$___pair_idx
              ___final_pairs[$___pair_idx]=$___idx
              ___pair_order+=( $___idx )
            }
          else
            ___pos_to_level[$___idx]=-1
          fi
        fi
      }

      [[ ${match[1]} = \" && $___quoting != \' ]] && \
        if [[ $___quoting = '"' ]]; then
          ___Strings[$___level/${___Counts[$___level]}]+=" ${(q)___input[___sidx,___idx-1]}"
          ___quoting=""
        else
          ___had_quoted_value=1
          ___sidx=___idx+1
          ___quoting='"'
        fi

      [[ ${match[1]} = , && -z $___quoting ]] && \
        {
          (( !___had_quoted_value )) && \
            ___Strings[$___level/${___Counts[$___level]}]+=" ${(q)___input[___sidx,___idx-1]//((#s)[[:blank:]]##|([[:blank:]]##(#e)))}"
          ___sidx=___idx+1
          ___had_quoted_value=0
        }

      [[ ${match[1]} = : && -z $___quoting ]] && \
        {
          ___had_quoted_value=0
          ___sidx=___idx+1
        }

      [[ ${match[1]} = \' && $___quoting != \" ]] && \
        if [[ $___quoting = "'" ]]; then
          ___Strings[$___level/${___Counts[$___level]}]+=" ${(q)___input[___sidx,___idx-1]}"
          ___quoting=""
        else
          ___had_quoted_value=1
          ___sidx=___idx+1
          ___quoting="'"
        fi

      ___workbuf=${match[4]}
    }
  done

  local ___text ___found
  if (( ___nest != 2 )) {
    integer ___pair_a ___pair_b
    for ___pair_a ( "${___pair_order[@]}" ) {
      ___pair_b="${___final_pairs[$___pair_a]}"
      ___text="${___input[___pair_b,___pair_a]}"
      if [[ $___text = [[:space:]]#\{[[:space:]]#[\"\']${___key}[\"\']* ]]; then
        ___found="$___text"
      fi
    }
  }

  if [[ -n $___found && $___nest -lt 2 ]] {
    .zi-parse-json "$___found" "$___key" "$___varname" 2
  }

  if (( ___nest == 2 )) {
    : ${(PAA)___varname::="${(kv)___Strings[@]}"}
  }
}
# ]]]
# FUNCTION: .zi-get-package [[[
.zi-get-package() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd

  local user=$1 pkg=$2 plugin=$2 id_as=$3 dir=$4 profile=$5 local_path=${ZI[PLUGINS_DIR]}/${3//\//---}
  local pkgjson tmpfile=${$(mktemp):-${TMPDIR:-/tmp}/zsh.xYzAbc123}
  local URL=https://raw.githubusercontent.com/${ZI[PKG_OWNER]}/$2/HEAD/package.json
  local pro_sep="{rst}, {profile}" epro_sep="{error}, {profile}" tool_sep="{rst}, {cmd}" lhi_hl="{lhi}" profile_hl="{profile}"

  trap "rmdir ${(qqq)local_path} 2>/dev/null; return 1" INT TERM QUIT HUP
  trap "rmdir ${(qqq)local_path} 2>/dev/null" EXIT

  if [[ $profile != ./* ]] {
    if { ! .zi-download-file-stdout $URL 0 1 2>/dev/null > $tmpfile } {
      rm -f $tmpfile; .zi-download-file-stdout $URL 1 1 2>/dev/null >1 $tmpfile
    }
  } else {
    tmpfile=${profile%:*}
    profile=${${${(M)profile:#*:*}:+${profile#*:}}:-default}
  }

  # load json from file
  [[ -e $tmpfile ]] && pkgjson="$(<$tmpfile)"

  if [[ -z $pkgjson ]] {
    +zi-message "{u-warn}Error{b-warn}{ehi}:{rst} the package {apo}\`{pid}$id_as{apo}\` {rst}couldn't be found"
    return 1
  }

  local -A Strings
  .zi-parse-json "$pkgjson" "plugin-info" Strings
  local -A jsondata1
  jsondata1=( ${(@Q)${(@z)Strings[2/1]}} )
  local user=${jsondata1[user]} plugin=${jsondata1[plugin]} url=${jsondata1[url]} message=${jsondata1[message]} required=${jsondata1[required]:-${jsondata1[requires]}}
  local -a profiles
  local key value
  integer pos
  profiles=( ${(@Q)${(@z)Strings[2/2]}} )
  profiles=( ${profiles[@]:#$'\0'--object--$'\0'} )
  pos=${${(@Q)${(@z)Strings[2/2]}}[(I)$profile]}
  if (( pos )) {
    for key value ( "${(@Q)${(@z)Strings[3/$(( (pos + 1) / 2 ))]}}" ) {
      (( ${+ICE[$key]} )) && [[ ${ICE[$key]} != +* ]] && continue
      ICE[$key]=$value${ICE[$key]#+}
    }
    ICE=( "${(kv)ICE[@]//\\\"/\"}" )
    [[ ${ICE[as]} = program ]] && ICE[as]="command"
    [[ -n ${ICE[on-update-of]} ]] && ICE[subscribe]="${ICE[subscribe]:-${ICE[on-update-of]}}"
    [[ -n ${ICE[pick]} ]] && ICE[pick]="${ICE[pick]//\$ZPFX/${ZPFX%/}}"
    if [[ -n ${ICE[id-as]} ]] {
      @zi-substitute 'ICE[id-as]'
      local -A map
      map=( "\"" "\\\"" "\\" "\\" )
      eval "ICE[id-as]=\"${ICE[id-as]//(#m)[\"\\]/${map[$MATCH]}}\""
    }
  } else {
    # Assumption: the default profile is the first in the table (see another color).
    +zi-message "{u-warn}Error{b-warn}:{error} the profile {apo}\`{hi}$profile{apo}\` {error}couldn't be found, aborting. Available profiles are: {lhi}${(pj:$epro_sep:)profiles[@]}{error}.{rst}"
    return 1
  }

  +zi-message "{info3}Package{ehi}:{rst} {pid}$pkg{rst}. Selected" "profile{ehi}:{rst} {hi}$profile{rst}. \
  Available profiles:${${${(M)profile:#default}:+$lhi_hl}:-$profile_hl}" "${(pj:$pro_sep:)profiles[@]}{rst}."
  if [[ $profile != *bgn* && -n ${(M)profiles[@]:#*bgn*} ]] {
    +zi-message "{note}Note:{rst} The {apo}\`{profile}bgn{glob}*{apo}\`{rst}" "profiles are recommended (if available)." \
    "They provide binaries without {slight}altering/cluttering{rst} the  {var}\$PATH{rst} environment variable."
  }

  ICE[required]=${ICE[required]:-$ICE[requires]}
  local -a req
  req=( ${(s.;.)${:-${required:+$required\;}${ICE[required]}}} )
  for required ( $req ) {
    if [[ $required == (bgn|dl|rdl) ]]; then
      if [[ ( $required == bgn && -z ${(k)ZI_EXTS[(r)<-> z-annex-data: z-a-bin-gem-node *]} ) || ( $required == dl && -z ${(k)ZI_EXTS[(r)<-> z-annex-data: z-a-patch-dl *]} ) || ( $required == rdl && -z ${(k)ZI_EXTS[(r)<-> z-annex-data: z-a-readurl *]} ) ]]; then
        local -A namemap
        namemap=( bgn bin-gem-node dl patch-dl rdl readurl )
        +zi-message -n "{u-warn}ERROR{b-warn}: {error}the "
        if [[ -z ${(MS)ICE[required]##(\;|(#s))$required(\;|(#e))} ]]; then
          +zi-message -n "{error}requested profile {apo}\`{hi}$profile{apo}\`{error} "
        else
          +zi-message -n "{error}package {pid}$pkg{error} "
        fi
        +zi-message '{error}requires the {apo}`{annex}'${namemap[$required]}'{apo}`' \
          "{error}annex, which is currently not installed." "{nl}{nl}If you'd like to install it, you can visit its homepage:" \
          "{nl}– {url}https://github.com/z-shell/z-a-${(L)namemap[$required]}{rst}" "{nl}for instructions."
        (( ${#profiles[@]:#$profile} > 0 )) && +zi-message "{nl}Other available profiles are:" "{profile}${(pj:$pro_sep:)${profiles[@]:#$profile}}{rst}."
        return 1
      fi
    else
      if ! command -v $required &>/dev/null; then
        +zi-message -n "{u-warn}ERROR{b-warn}: {error}the "
        if [[ -n ${(MS)ICE[required]##(\;|(#s))$required(\;|(#e))} ]]; then
          +zi-message -n "{error}requested profile {apo}\`{hi}$profile{apo}\`{error} "
        else
          +zi-message -n "{error}package {pid}$pkg{error} "
        fi
        +zi-message '{error}requires a {apo}`{cmd}'$required'{apo}`{error}' "command to be available in {var}\$PATH{error}.{rst}" \
          "{nl}{error}The package cannot be installed unless the" "command will be available."
        (( ${#profiles[@]:#$profile} > 0 )) && +zi-message "{nl}Other available profiles are: {profile}${(pj:$pro_sep:)${profiles[@]:#$profile}}{rst}."
        return 1
      fi
    fi
  }

  if [[ -n ${ICE[dl]} && -z ${(k)ZI_EXTS[(r)<-> z-annex-data: z-a-patch-dl *]} ]] {
    +zi-message "{nl}{u-warn}WARNING{b-warn}:{rst} the profile uses" \
      "{ice}dl''{rst} ice however there's currently no {annex}z-a-patch-dl{rst}" "annex loaded, which provides it."
    +zi-message "The ice will be inactive, i.e.: no additional" "files will become downloaded (the ice downloads the given URLs)." \
      "The package should still work, as it doesn't indicate to" "{u}{slight}require{rst} the annex."
    +zi-message "{nl}You can download the" "annex from its homepage at {url}https://github.com/z-shell/z-a-patch-dl{rst}."
  }

  [[ -n ${jsondata1[message]} ]] && +zi-message "{info}${jsondata1[message]}{rst}"

  if (( ${+ICE[is-snippet]} )) {
    reply=( "" "$url" )
    REPLY=snippet
    return 0
  }

  if (( !${+ICE[git]} && !${+ICE[from]} )) {
    (
      .zi-parse-json "$pkgjson" "_from" Strings
      local -A jsondata
      jsondata=( "${(@Q)${(@z)Strings[1/1]}}" )

      local URL=${jsondata[_resolved]}
      local fname="${${URL%%\?*}:t}"

      command mkdir -p $dir || {
        +zi-message "{u-warn}Error{b-warn}:{error} Couldn't create directory: {dir}$dir{error}, aborting.{rst}"
        return 1
      }
      builtin cd -q $dir || return 1

      +zi-message "Downloading tarball for {pid}$plugin{rst}{…}"

      if { ! .zi-download-file-stdout "$URL" 0 1 >! "$fname" } {
        if { ! .zi-download-file-stdout "$URL" 1 1 >! "$fname" } {
          command rm -f "$fname"
          +zi-message "Download of the file {apo}\`{file}$fname{apo}\`{rst} failed. No available download tool? One of{ehi}:{rst}" "{cmd}${(pj:$tool_sep:)${=:-curl wget lftp lynx}}{rst}."
          return 1
        }
      }
      ziextract "$fname" ${ICE[extract]---move} ${${(M)ICE[extract]:#!([^!]|(#e))*}:+--move} ${${(M)ICE[extract]:#!!*}:+--move2}
      return 0
    ) && {
      reply=( "$user" "$plugin" )
      REPLY=tarball
    }
  } else {
      reply=( "${ICE[user]:-$user}" "${ICE[plugin]:-$plugin}" )
      if [[ ${ICE[from]} = (|gh-r|github-rel) ]]; then
        REPLY=github
      else
        REPLY=unknown
      fi
  }

  return $?
} # ]]]
# FUNCTION: .zi-setup-plugin-dir [[[
# Clones given plugin into PLUGIN_DIR.
# Supports multiple sites (respecting `from' and `proto' ice modifiers).
# Invokes compilation of plugin's main file.
#
# $1 - user
# $2 - plugin
.zi-setup-plugin-dir() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal noshortloops rcquotes

  local user=$1 plugin=$2 id_as=$3 remote_url_path=${1:+$1/}$2 local_path tpe=$4 update=$5 version=$6

  if .zi-get-object-path plugin "$id_as" && [[ -z $update ]] {
    +zi-message "{error}Error{ehi}:{rst} A plugin named {pid}$id_as{rst} already exists, aborting."
    return 1
  }
  local_path=$REPLY

  trap "rmdir ${(qqq)local_path}/._zi ${(qqq)local_path} 2>/dev/null" EXIT
  trap "rmdir ${(qqq)local_path}/._zi ${(qqq)local_path} 2>/dev/null; return 1" INT TERM QUIT HUP

  local -A sites
  sites=(
    ge          gitee.com
    gitee       gitee.com
    github      github.com
    gh          github.com
    gitlab      gitlab.com
    gl          gitlab.com
    notabug     notabug.org
    nb          notabug.org
    bitbucket   bitbucket.org
    bb          bitbucket.org
    github-rel  github.com/$remote_url_path/releases
    gh-r        github.com/$remote_url_path/releases
    cygwin      cygwin
  )

  ZI[annex-multi-flag:pull-active]=${${${(M)update:#-u}:+${ZI[annex-multi-flag:pull-active]}}:-2}

  local -a arr

  if [[ $user = _local ]]; then
    builtin print "Warning: no local plugin \`$plugin\'."
    builtin print "(should be located at: $local_path)"
    return 1
  fi

  command rm -f ${TMPDIR:-/tmp}/zi-execs.$$.lst ${TMPDIR:-/tmp}/zi.installed_comps.$$.lst \
        ${TMPDIR:-/tmp}/zi.skipped_comps.$$.lst ${TMPDIR:-/tmp}/zi.compiled.$$.lst

  if [[ $tpe != tarball ]] {
    if [[ -z $update ]] {
      .zi-any-colorify-as-uspl2 "$user" "$plugin"
      local pid_hl='{pid}' id_msg_part=" (at label{ehi}:{rst} {id-as}$id_as{rst}{…})"
      (( $+ICE[pack] )) && local infix_m="({b}{ice}pack{apo}''{rst}) "
      +zi-message "{nl}Downloading{ehi}:{rst} $infix_m{pid}$user${user:+/}$plugin{…}${${${id_as:#$user/$plugin}}:+$id_msg_part}"
    }

    local site
    [[ -n ${ICE[from]} ]] && site=${sites[${ICE[from]}]}
    if [[ -z $site && ${ICE[from]} = *(gh-r|github-rel)* ]] {
      site=${ICE[from]/(gh-r|github-re)/${sites[gh-r]}}
    }
  }

  (
    if [[ $site = */releases ]] {
      local tag_version=${ICE[ver]}
      if [[ -z $tag_version ]]; then
        tag_version="$( { .zi-download-file-stdout $site/latest || .zi-download-file-stdout $site/latest 1; } 2>/dev/null | \
        command grep -m1 -o 'href=./'$user'/'$plugin'/releases/tag/[^"]\+')"
        tag_version=${tag_version##*/}
      fi
      local url=$site/expanded_assets/$tag_version

      .zi-get-latest-gh-r-url-part "$user" "$plugin" "$url" || return $?

      command mkdir -p "$local_path"
      [[ -d "$local_path" ]] || return 1
      (
        () { builtin setopt localoptions noautopushd; builtin cd -q "$local_path"; } || return 1
        integer count

        for REPLY ( $reply ) {
          count+=1
          url="https://github.com${REPLY}"
          if [[ -d $local_path/._zi ]] {
            { local old_version="$(<$local_path/._zi/is_release${count:#1})"; } 2>/dev/null
            old_version=${old_version/(#b)(\/[^\/]##)(#c4,4)\/([^\/]##)*/${match[2]}}
          }
          +zi-message "(Requesting \`${REPLY:t}'${version:+, version $version}{…}${old_version:+ Current version: $old_version.})"
          if { ! .zi-download-file-stdout "$url" 0 1 >! "${REPLY:t}" } {
            if { ! .zi-download-file-stdout "$url" 1 1 >! "${REPLY:t}" } {
              command rm -f "${REPLY:t}"
              +zi-message "{auto}Download of release for \`$remote_url_path' failed{nl}{mmdsh} Tried url{ehi}:{rst} {auto}"
              return 1
            }
          }
          if .zi-download-file-stdout "$url.sig" 2>/dev/null >! "${REPLY:t}.sig"; then
            :
          else
            command rm -f "${REPLY:t}.sig"
          fi

          command mkdir -p ._zi
          [[ -d ._zi ]] || return 2
          builtin print -r -- $url >! ._zi/url || return 3
          builtin print -r -- ${REPLY} >! ._zi/is_release${count:#1} || return 4
          ziextract ${REPLY:t} ${${${#reply}:#1}:+--nobkp} ${${(M)ICE[extract]:#!([^!]|(#e))*}:+--move} ${${(M)ICE[extract]:#!!*}:+--move2}
        }
        return $?
      ) || {
        return 1
      }
    } elif [[ $site = cygwin ]] {
      command mkdir -p "$local_path/._zi"
      [[ -d "$local_path" ]] || return 1
      (
        () { builtin setopt localoptions noautopushd; builtin cd -q "$local_path"; } || return 1
        .zi-get-cygwin-package "$remote_url_path" || return 1
        builtin print -r -- $REPLY >! ._zi/is_release
        ziextract "$REPLY"
      ) || return $?
    } elif [[ $tpe = github ]] {
      case ${ICE[proto]} in
        (|https|git|http|ftp|ftps|rsync|ssh)
          :zi-git-clone() {
            command git clone --verbose --progress ${(s: :)ICE[cloneopts]---recursive} ${(s: :)ICE[depth]:+--depth ${ICE[depth]}} \
            "${ICE[proto]:-https}://${site:-${ICE[from]:-github.com}}/$remote_url_path" "$local_path" \
            --config transfer.fsckobjects=false --config receive.fsckobjects=false \
            --config fetch.fsckobjects=false --config pull.rebase=false

            integer retval=$?
            unfunction :zi-git-clone
            return $retval
          }
          :zi-git-clone |& { command ${ZI[BIN_DIR]}/lib/zsh/git-process-output.zsh || cat; }
          if (( pipestatus[1] == 141 )) {
            :zi-git-clone
            integer retval=$?
            if (( retval )) {
              builtin print -Pr -- "$ZI[col-error]Clone failed (code: $ZI[col-obj]$retval$ZI[col-error]).%f%b"
              return 1
            }
          } elif (( pipestatus[1] )) {
            builtin print -Pr -- "$ZI[col-error]Clone failed (code: $ZI[col-obj]$pipestatus[1]$ZI[col-error]).%f%b"
            return 1
          }
          ;;
        (*)
          builtin print -Pr "${ZI[col-error]}Unknown protocol:%f%b ${ICE[proto]}."
          return 1
      esac

      if [[ -n ${ICE[ver]} ]] {
        command git -C "$local_path" checkout "${ICE[ver]}"
      }
    }

    if [[ $update != -u ]] {
      hook_rc=0
      # Store ices at clone of a plugin
      .zi-store-ices "$local_path/._zi" ICE "" "" "" ""
      reply=(
        ${(on)ZI_EXTS2[(I)zi hook:\!atclone-pre <->]}
        ${(on)ZI_EXTS[(I)z-annex hook:\!atclone-<-> <->]}
        ${(on)ZI_EXTS2[(I)zi hook:\!atclone-post <->]}
      )
      for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
        "${arr[5]}" plugin "$user" "$plugin" "$id_as" "$local_path" "${${key##(zi|z-annex) hook:}%% <->}" load
        hook_rc=$?
        # Effectively return the last != 0 rc
        [[ "$hook_rc" -ne 0 ]] && {
          retval="$hook_rc"
          builtin print -Pr -- "${ZI[col-warn]}Warning:%f%b ${ZI[col-obj]}${arr[5]}${ZI[col-warn]} hook returned with ${ZI[col-obj]}${hook_rc}${ZI[col-rst]}"
        }
      done
      # Run annexes' atclone hooks (the after atclone-ice ones)
      reply=(
        ${(on)ZI_EXTS2[(I)zi hook:atclone-pre <->]}
        ${(on)ZI_EXTS[(I)z-annex hook:atclone-<-> <->]}
        ${(on)ZI_EXTS2[(I)zi hook:atclone-post <->]}
      )
      for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
        "${arr[5]}" plugin "$user" "$plugin" "$id_as" "$local_path" "${${key##(zi|z-annex) hook:}%% <->}"
        hook_rc=$?
        [[ "$hook_rc" -ne 0 ]] && {
          retval="$hook_rc"
          builtin print -Pr -- "${ZI[col-warn]}Warning:%f%b ${ZI[col-obj]}${arr[5]}${ZI[col-warn]} hook returned with ${ZI[col-obj]}${hook_rc}${ZI[col-rst]}"
        }
      done
    }
    return "$retval"
  ) || return $?

  typeset -ga INSTALLED_EXECS
  { INSTALLED_EXECS=( "${(@f)$(<${TMPDIR:-/tmp}/zi-execs.$$.lst)}" ) } 2>/dev/null

  # After additional executions like atclone'' - install completions (1 - plugins)
  local -A OPTS
  OPTS[opt_-q,--quiet]=1
  [[ 0 = ${+ICE[nocompletions]} && ${ICE[as]} != null && ${+ICE[null]} -eq 0 ]] && \
    .zi-install-completions "$id_as" "" "0"

  if [[ -e ${TMPDIR:-/tmp}/zi.skipped_comps.$$.lst || -e ${TMPDIR:-/tmp}/zi.installed_comps.$$.lst ]] {
    typeset -ga INSTALLED_COMPS SKIPPED_COMPS
    { INSTALLED_COMPS=( "${(@f)$(<${TMPDIR:-/tmp}/zi.installed_comps.$$.lst)}" ) } 2>/dev/null
    { SKIPPED_COMPS=( "${(@f)$(<${TMPDIR:-/tmp}/zi.skipped_comps.$$.lst)}" ) } 2>/dev/null
  }

  if [[ -e ${TMPDIR:-/tmp}/zi.compiled.$$.lst ]] {
    typeset -ga ADD_COMPILED
    { ADD_COMPILED=( "${(@f)$(<${TMPDIR:-/tmp}/zi.compiled.$$.lst)}" ) } 2>/dev/null
  }

  # After any download – rehash the command table this will miss the as"program" binaries
  # as their PATH gets extended - and it is done later. It will however work for sbin'' ice.
  (( !OPTS[opt_-p,--parallel] )) && rehash

  return 0
} # ]]]
# FUNCTION: .zi-install-completions [[[
# Installs all completions of given plugin. After that they are
# visible to `compinit'. Visible completions can be selectively
# disabled and enabled. User can access completion data with
# `clist' or `completions' subcommand.
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
# $3 - if 1, then reinstall, otherwise only install completions that aren't there
.zi-install-completions() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt nullglob extendedglob warncreateglobal typesetsilent noshortloops

  local id_as=$1${2:+${${${(M)1:#%}:+$2}:-/$2}}
  local reinstall=${3:-0} quiet=${${4:+1}:-0}
  (( OPTS[opt_-q,--quiet] )) && quiet=1
  [[ $4 = -Q ]] && quiet=2
  typeset -ga INSTALLED_COMPS SKIPPED_COMPS
  INSTALLED_COMPS=() SKIPPED_COMPS=()

  .zi-any-to-user-plugin "$id_as" ""
  local user=${reply[-2]}
  local plugin=${reply[-1]}
  .zi-any-colorify-as-uspl2 "$user" "$plugin"
  local abbrev_pspec=$REPLY

  .zi-exists-physically-message "$id_as" "" || return 1

  # Symlink any completion files included in plugin's directory
  typeset -a completions already_symlinked backup_comps
  local c cfile bkpfile
  # The plugin == . is a semi-hack/trick to handle `creinstall .' properly
  [[ $user == % || ( -z $user && $plugin == . ) ]] && \
  completions=( "${plugin}"/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*|*.ps1)(DN^/) ) || \
  completions=( "${ZI[PLUGINS_DIR]}/${id_as//\//---}"/**/_[^_.]*~*(*.zwc|*.html|*.txt|*.png|*.jpg|*.jpeg|*.js|*.md|*.yml|*.ri|_zsh_highlight*|/zsdoc/*|*.ps1)(DN^/) )
  already_symlinked=( "${ZI[COMPLETIONS_DIR]}"/_[^_.]*~*.zwc(DN) )
  backup_comps=( "${ZI[COMPLETIONS_DIR]}"/[^_.]*~*.zwc(DN) )

  # Symlink completions if they are not already there
  # either as completions (_fname) or as backups (fname)
  # OR - if it's a reinstall
  for c in "${completions[@]}"; do
    cfile="${c:t}"
    bkpfile="${cfile#_}"
    if [[ ( -z ${already_symlinked[(r)*/$cfile]} || $reinstall = 1 ) &&
      -z ${backup_comps[(r)*/$bkpfile]}
    ]]; then
      if [[ $reinstall = 1 ]]; then
        # Remove old files
        command rm -f "${ZI[COMPLETIONS_DIR]}/${cfile}" "${ZI[COMPLETIONS_DIR]}/${bkpfile}"
      fi
      INSTALLED_COMPS+=( $cfile )
      (( quiet )) || +zi-message "{auto}Symlinking completion \`$cfile' to completions directory{…}{rst}"
      command ln -fs "$c" "${ZI[COMPLETIONS_DIR]}/${cfile}"
      # Make compinit notice the change
      .zi-forget-completion "$cfile" "$quiet"
    else
      SKIPPED_COMPS+=( $cfile )
      (( quiet )) || +zi-message "{auto}Not symlinking completion \`$cfile', it already exists{…}{rst}"
      (( quiet )) || +zi-message "{mmdsh}{rst} {auto}Use \`zi creinstall $abbrev_pspec' to force install"
    fi
  done

  if (( quiet == 1 && (${#INSTALLED_COMPS} || ${#SKIPPED_COMPS}) )) {
    +zi-message "{msg}Installed {num}${#INSTALLED_COMPS} {msg}completions" \
      "{nl}{mmdsh} They are stored in{var} \$INSTALLED_COMPS{msg} array"
    if (( ${#SKIPPED_COMPS} )) {
      +zi-message "{msg}Skipped installing {num}${#SKIPPED_COMPS}{msg} completions" \
        "{nl}{mmdsh} They are stored in{var} \$SKIPPED_COMPS{msg} array"
    }
  }

  if (( ZSH_SUBSHELL )) {
    builtin print -rl -- $INSTALLED_COMPS >! ${TMPDIR:-/tmp}/zi.installed_comps.$$.lst
    builtin print -rl -- $SKIPPED_COMPS >! ${TMPDIR:-/tmp}/zi.skipped_comps.$$.lst
  }

  .zi-compinit 1 1 &>/dev/null
} # ]]]
# FUNCTION: .zi-compinit [[[
# User-exposed `compinit' frontend which first ensures that all completions managed by ❮ ZI ❯ are forgotten by Z-shell.
# After that it runs normal `compinit', which should more easily detect ❮ ZI ❯ completions.
#
# No arguments.
.zi-compinit() {
  [[ -n ${OPTS[opt_-p,--parallel]} && $1 != 1 ]] && return
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt nullglob extendedglob warncreateglobal typesetsilent

  integer use_C=$2

  typeset -a symlinked backup_comps
  local c cfile bkpfile action

  symlinked=( "${ZI[COMPLETIONS_DIR]}"/_[^_.]*~*.zwc )
  backup_comps=( "${ZI[COMPLETIONS_DIR]}"/[^_.]*~*.zwc )

  # Delete completions if they are really there,
  # either as completions (_fname) or backups (fname)
  for c in "${symlinked[@]}" "${backup_comps[@]}"; do
    action=0
    cfile="${c:t}"
    cfile="_${cfile#_}"
    bkpfile="${cfile#_}"

    #print -Pr "${ZI[col-info]}Processing completion $cfile%f%b"
    .zi-forget-completion "$cfile"
  done

  +zi-message "Initializing completion ({func}compinit{rst}){…}"
  command rm -f "${ZI[ZCOMPDUMP_PATH]}"

  # Workaround for a nasty trick in _vim
  (( ${+functions[_vim_files]} )) && unfunction _vim_files

  builtin autoload -Uz compinit
  compinit ${${(M)use_C:#1}:+-C} -d "${ZI[ZCOMPDUMP_PATH]}" "${(Q@)${(z@)ZI[COMPINIT_OPTS]}}"
} # ]]]
# FUNCTION: .zi-download-file-stdout [[[
# Downloads file to stdout.
# Supports following backend commands: curl, wget, lftp, lynx.
# Used by snippet loading.
.zi-download-file-stdout() {
  local url="$1" restart="$2" progress="${(M)3:#1}"
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt localtraps extendedglob

  if (( restart )) {
    (( ${path[(I)/usr/local/bin]} )) || {
        path+=( "/usr/local/bin" );
        trap "path[-1]=()" EXIT
      }

    if (( ${+commands[curl]} )); then
      if [[ -n $progress ]]; then
        command curl --progress-bar -fSL "$url" 2> >(${ZI[BIN_DIR]}/lib/zsh/single-line.zsh >&2) || return 1
      else
        command curl -fsSL "$url" || return 1
      fi
    elif (( ${+commands[wget]} )); then
      command wget ${${progress:--q}:#1} "$url" -O - || return 1
    elif (( ${+commands[lftp]} )); then
      command lftp -c "cat $url" || return 1
    elif (( ${+commands[lynx]} )); then
      command lynx -source "$url" || return 1
    else
      +zi-message "{error}Error{ehi}:{rst} No compatible download tool detected" \
      "{nl}{mmdsh} Expected{ehi}:{rst} {cmd}curl{rst}, {cmd}wget{rst}, {cmd}lftp{rst}," "{cmd}lynx{rst}"
      return 2
    fi
  } else {
    if type curl 2>/dev/null 1>&2; then
      if [[ -n $progress ]]; then
        command curl --progress-bar -fSL "$url" 2> >(${ZI[BIN_DIR]}/lib/zsh/single-line.zsh >&2) || return 1
      else
        command curl -fsSL "$url" || return 1
      fi
    elif type wget 2>/dev/null 1>&2; then
      command wget ${${progress:--q}:#1} "$url" -O - || return 1
    elif type lftp 2>/dev/null 1>&2; then
      command lftp -c "cat $url" || return 1
    else
      .zi-download-file-stdout "$url" "1" "$progress"
      return $?
    fi
  }

  return 0

} # ]]]
# FUNCTION: .zi-get-url-mtime [[[
# For the given URL returns the date in the Last-Modified header as a time stamp
.zi-get-url-mtime() {
  local url="$1" IFS line header
  local -a cmd

  builtin setopt localoptions localtraps

  (( !${path[(I)/usr/local/bin]} )) && {
    path+=( "/usr/local/bin" );
    trap "path[-1]=()" EXIT
  }

  if (( ${+commands[curl]} )) || type curl 2>/dev/null 1>&2; then
    cmd=(command curl -sIL "$url")
  elif (( ${+commands[wget]} )) || type wget 2>/dev/null 1>&2; then
    cmd=(command wget --server-response --spider -q "$url" -O -)
  else
    REPLY=$(( $(date +"%s") ))
    return 2
  fi

  "${cmd[@]}" |& command grep -i Last-Modified: | while read -r line; do
    header="${${line#*, }//$'\r'}"
  done

  if [[ -z $header ]] {
    REPLY=$(( $(date +"%s") ))
    return 3
  }

  LANG=C TZ=UTC strftime -r -s REPLY "%d %b %Y %H:%M:%S GMT" "$header" &>/dev/null || {
    REPLY=$(( $(date +"%s") ))
    return 4
  }

  return 0
} # ]]]
# FUNCTION: .zi-mirror-using-svn [[[
# Used to clone subdirectories from Github.
# If in update mode (see $2), then invokes `svn update',
# in normal mode invokes `svn checkout --non-interactive -q <URL>'.
# In test mode only compares remote and local revision and outputs true if update is needed.
#
# $1 - URL
# $2 - mode, "" - normal, "-u" - update, "-t" - test
# $3 - subdirectory (not path) with working copy, needed for -t and -u
.zi-mirror-using-svn() {
  builtin setopt localoptions extendedglob warncreateglobal
  local url="$1" update="$2" directory="$3"

  (( ${+commands[svn]} )) || \
    +zi-message "{error}Warning{ehi}:{rst} Subversion not found{nl}{mmdsh}{rst} {auto}Please install it to use \`svn' ice"

  if [[ "$update" = "-t" ]]; then
    ( () { builtin setopt localoptions noautopushd; builtin cd -q "$directory"; }
      local -a out1 out2
      out1=( "${(f@)"$(LANG=C svn info -r HEAD)"}" )
      out2=( "${(f@)"$(LANG=C svn info)"}" )

      out1=( "${(M)out1[@]:#Revision:*}" )
      out2=( "${(M)out2[@]:#Revision:*}" )
      [[ "${out1[1]##[^0-9]##}" != "${out2[1]##[^0-9]##}" ]] && return 0
      return 1
    )
    return $?
  fi
  if [[ "$update" = "-u" && -d "$directory" && -d "$directory/.svn" ]]; then
    ( () { builtin setopt localoptions noautopushd; builtin cd -q "$directory"; }
    command svn update
    return $? )
  else
    command svn checkout --non-interactive -q "$url" "$directory"
  fi
  return $?
}
# ]]]
# FUNCTION: .zi-forget-completion [[[
# Implements alternation of Zsh state so that already initialized
# completion stops being visible to Zsh.
#
# $1 - completion function name, e.g. "_cp"; can also be "cp"
.zi-forget-completion() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob typesetsilent warncreateglobal

  local f="$1" quiet="$2"

  typeset -a commands
  commands=( ${(k)_comps[(Re)$f]} )

  [[ "${#commands}" -gt 0 ]] && (( quiet == 0 )) && builtin print -Prn "Forgetting commands completed by \`${ZI[col-obj]}$f%f%b': "

  local k
  integer first=1
  for k ( $commands ) {
    unset "_comps[$k]"
    (( quiet )) || builtin print -Prn "${${first:#1}:+, }${ZI[col-info]}$k%f%b"
    first=0
  }
  (( quiet || first )) || builtin print

  unfunction -- 2>/dev/null "$f"
} # ]]]
# FUNCTION: .zi-compile-plugin [[[
# Compiles given plugin (its main source file, and also an additional "....zsh" file if it exists).
#
# $1 - plugin spec (4 formats: user---plugin, user/plugin, user, plugin)
# $2 - plugin (only when $1 - i.e. user - given)
.zi-compile-plugin() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal typesetsilent noshortloops rcquotes

  local id_as=$1${2:+${${${(M)1:#%}:+$2}:-/$2}} first plugin_dir filename is_snippet
  local -a list
  local -A ICE
  .zi-compute-ice "$id_as" "pack" ICE plugin_dir filename is_snippet || return 1

  if [[ ${ICE[pick]} != /dev/null && ${ICE[as]} != null && ${+ICE[null]} -eq 0 && ${ICE[as]} != command && ${+ICE[binary]} -eq 0 && ( ${+ICE[nocompile]} = 0 || ${ICE[nocompile]} = \! ) ]] {
    reply=()
    if [[ -n ${ICE[pick]} ]]; then
      list=( ${~${(M)ICE[pick]:#/*}:-$plugin_dir/$ICE[pick]}(DN) )
      if [[ ${#list} -eq 0 ]] {
        +zi-message "No files for compilation found (pick-ice didn't match){rst}{…}"
        return 1
      }
      reply=( "${list[1]:h}" "${list[1]}" )
    else
      if (( is_snippet )) {
        if [[ -f $plugin_dir/$filename ]] {
          reply=( "$plugin_dir" $plugin_dir/$filename )
        } elif { ! .zi-first % "$plugin_dir" } {
          +zi-message "No files for compilation found{rst}{…}"
          return 1
        }
      } else {
        .zi-first "$1" "$2" || {
          +zi-message "No files for compilation found{rst}{…}"
          return 1
        }
      }
    fi
    local pdir_path=${reply[-2]}
    first=${reply[-1]}
    local fname=${first#$pdir_path/}

    +zi-message -n "Compiling{ehi}:{rst} {b}{file}$fname{rst}{…}"
    if [[ -z ${ICE[(i)(\!|)(sh|bash|ksh|csh)]} ]] {
      () {
        builtin emulate -LR zsh -o extendedglob
        if { ! zcompile -U "$first" } {
          +zi-message "{error}Warning{ehi}:{rst} Compilation failed. Don't worry, the plugin will work also without compilation"
          +zi-message "{error}Warning{ehi}:{rst} Consider submitting an error report to ❮ ZI ❯ or to the plugin's author"
        } else {
          +zi-message " {version}✔{rst}"
        }
        # Try to catch possible additional file
        zcompile -U "${${first%.plugin.zsh}%.zsh-theme}.zsh" 2>/dev/null
      }
    }
  }

  if [[ -n "${ICE[compile]}" ]]; then
    local -a pats
    pats=( ${(s.;.)ICE[compile]} )
    local pat
    list=()
    for pat ( $pats ) {
      eval "list+=( \$plugin_dir/$~pat(N) )"
    }
    if [[ ${#list} -eq 0 ]] {
      +zi-message "{error}Warning{ehi}:{rst} ice {ice}compile{apo}''{rst} didn't match any files."
    } else {
      integer retval
      for first in $list; do
        () {
          builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
          zcompile -U "$first"; retval+=$?
        }
      done
      builtin print -rl -- ${list[@]#$plugin_dir/} >! ${TMPDIR:-/tmp}/zi.compiled.$$.lst
      if (( retval )) {
        +zi-message "{mmdsh}{rst} The additional {num}${#list}{rst} compiled files" \
          "are listed in the {var}\$ADD_COMPILED{rst} array ({p}exit code{ehi}:{rst} {data2}$retval{rst})"
      } else {
        +zi-message "{mmdsh}{rst} The additional {num}${#list}{rst} compiled files" \
          "are listed in the {var}\$ADD_COMPILED{rst} array"
      }
    }
  fi

  return 0
} # ]]]
# FUNCTION: .zi-download-snippet [[[
# Downloads snippet – either a file – with curl, wget, lftp or lynx, or a directory,
# with Subversion – when svn-ICE is active. Github supports Subversion protocol and allows
# to clone subdirectories. This is used to provide a layer of support for Oh-My-Zsh and Prezto.
.zi-download-snippet() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal typesetsilent

  local save_url=$1 url=$2 id_as=$3 local_dir=$4 dirname=$5 filename=$6 update=$7

  trap "command rmdir ${(qqq)local_dir}/${(qqq)dirname} 2>/dev/null; return 1;" INT TERM QUIT HUP

  local -a list arr
  integer retval=0 hook_rc=0
  local teleid_clean=${ICE[teleid]%%\?*}
  [[ $teleid_clean == *://* ]] && \
    local sname=${(M)teleid_clean##*://[^/]##(/[^/]##)(#c0,4)} || \
    local sname=${${teleid_clean:h}:t}/${teleid_clean:t}
  [[ $sname = */trunk* ]] && sname=${${ICE[teleid]%%/trunk*}:t}/${ICE[teleid]:t}
  sname=${sname#./}

  if (( ${+ICE[svn]} )) {
    [[ $url = *(${(~kj.|.)${(Mk)ZI_1MAP:#OMZ*}}|robbyrussell*oh-my-zsh|ohmyzsh/ohmyzsh)* ]] && local ZSH=${ZI[SNIPPETS_DIR]}
    url=${url/(#s)(#m)(${(~kj.|.)ZI_1MAP})/$ZI_1MAP[$MATCH]}
  } else {
    url=${url/(#s)(#m)(${(~kj.|.)ZI_2MAP})/$ZI_2MAP[$MATCH]}
    if [[ $save_url == (${(~kj.|.)${(Mk)ZI_1MAP:#OMZ*}})* ]] {
      if [[ $url != *.zsh(|-theme) && $url != */_[^/]## ]] {
        if [[ $save_url == OMZT::* ]] {
          url+=.zsh-theme
        } else {
          url+=/${${url#*::}:t}.plugin.zsh
        }
      }
    } elif [[ $save_url = (${(~kj.|.)${(kM)ZI_1MAP:#PZT*}})* ]] {
      if [[ $url != *.zsh && $url != */_[^/]## ]] {
        url+=/init.zsh
      }
    }
  }

  # Change the url to point to raw github content if it isn't like that
  if [[ "$url" = *github.com* && ! "$url" = */raw/* && "${+ICE[svn]}" = "0" ]] {
    url="${${url/\/blob\///raw/}/\/tree\///raw/}"
  }

  command rm -f ${TMPDIR:-/tmp}/zi-execs.$$.lst ${TMPDIR:-/tmp}/zi.installed_comps.$$.lst ${TMPDIR:-/tmp}/zi.skipped_comps.$$.lst ${TMPDIR:-/tmp}/zi.compiled.$$.lst

  if [[ ! -d $local_dir/$dirname ]]; then
    local id_msg_part="{…} ({p}at label{ehi}:{rst} {id-as}$id_as{rst})"
    [[ $update != -u ]] && +zi-message "{nl}{apo}Snippet{ehi}:{rst} {url}$sname{rst}${ICE[id-as]:+$id_msg_part}"
    command mkdir -p "$local_dir"
  fi

  if [[ $update = -u && ${OPTS[opt_-q,--quiet]} != 1 ]]; then
    local id_msg_part="{…} ({p}identified as{ehi}: {id-as}$id_as{rst})"
    +zi-message "{nl}{apo}Updating snippet{ehi}:{rst} {url}$sname{rst}${ICE[id-as]:+$id_msg_part}"
  fi

  # A flag for the annexes. 0 – no new commits, 1 - run-atpull mode,
  # 2 – full update/there are new commits to download, 3 - full but
  # a forced download (i.e.: the medium doesn't allow to peek update)
  #
  # The below inherits the flag if it's an update call (i.e.: -u given),
  # otherwise it sets it to 2 – a new download is treated like a full update.
  ZI[annex-multi-flag:pull-active]=${${${(M)update:#-u}:+${ZI[annex-multi-flag:pull-active]}}:-2}
  (
    if [[ $url = (http|https|ftp|ftps|scp)://* ]] {
      # URL
      (
        () { builtin setopt localoptions noautopushd; builtin cd -q "$local_dir"; } || return 4
        (( !OPTS[opt_-q,--quiet] )) && \
        +zi-message "Downloading{ehi}:{rst} {apo}\`{url}$sname{apo}\`{rst}${${ICE[svn]+" ({p}with Subversion{rst})"}:-" ({p}with curl, wget, lftp{rst})"}{…}"

        if (( ${+ICE[svn]} )) {
          if [[ $update = -u ]] {
            # Test if update available
            if ! .zi-mirror-using-svn "$url" "-t" "$dirname"; then
              if (( ${+ICE[run-atpull]} || OPTS[opt_-u,--urge] )) {
                ZI[annex-multi-flag:pull-active]=1
              } else { return 0; }
              # Will return when no updates so atpull'' code below doesn't need any checks.
              # This return 0 statement also sets the pull-active flag outside this subshell.
            else
              ZI[annex-multi-flag:pull-active]=2
            fi
            # Run annexes' atpull hooks (the before atpull-ice ones). The SVN block.
            reply=(
              ${(on)ZI_EXTS2[(I)zi hook:e-\!atpull-pre <->]}
              ${${(M)ICE[atpull]#\!}:+${(on)ZI_EXTS[(I)z-annex hook:\!atpull-<-> <->]}}
              ${(on)ZI_EXTS2[(I)zi hook:e-\!atpull-post <->]}
            )
            for key in "${reply[@]}"; do
              arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
              "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zi|z-annex) hook:}%% <->}" update:svn
              hook_rc=$?
              [[ "$hook_rc" -ne 0 ]] && {
                retval="$hook_rc"
                builtin print -Pr -- "${ZI[col-warn]}Warning:%f%b ${ZI[col-obj]}${arr[5]}${ZI[col-warn]} hook returned with ${ZI[col-obj]}${hook_rc}${ZI[col-rst]}"
              }
            done

            if (( ZI[annex-multi-flag:pull-active] == 2 )) {
              # Do the update
              # The condition is reversed on purpose – to show only the messages on an actual update
              if (( OPTS[opt_-q,--quiet] )); then
                local id_msg_part="{…} ({p}identified as{ehi}: {id-as}$id_as{rst})"
                +zi-message "{nl}{apo}Updating snippet{ehi}:{rst} {url}${sname}{rst}${ICE[id-as]:+$id_msg_part}"
                +zi-message "Downloading{ehi}:{rst} {apo}\`{rst}$sname{apo}\`{rst} ({p}with Subversion{rst}){…}"
              fi
              .zi-mirror-using-svn "$url" "-u" "$dirname" || return 4
            }
          } else {
            .zi-mirror-using-svn "$url" "" "$dirname" || return 4
          }

          # Redundant code, just to compile SVN snippet
          if [[ ${ICE[as]} != command ]]; then
            if [[ -n ${ICE[pick]} ]]; then
              list=( ${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN) )
            elif [[ -z ${ICE[pick]} ]]; then
              list=(
                $local_dir/$dirname/*.plugin.zsh(DN) $local_dir/$dirname/*.zsh-theme(DN) $local_dir/$dirname/init.zsh(DN)
                $local_dir/$dirname/*.zsh(DN) $local_dir/$dirname/*.sh(DN) $local_dir/$dirname/.zshrc(DN)
              )
            fi
            if [[ -e ${list[1]} && ${list[1]} != */dev/null && -z ${ICE[(i)(\!|)(sh|bash|ksh|csh)]} && ${+ICE[nocompile]} -eq 0 ]] {
              () {
                builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
                zcompile -U "${list[1]}" &>/dev/null || \
                  +zi-message "{error}Warning{ehi}:{rst} Couldn't compile {apo}\`{file}${list[1]}{rst}'"
              }
            }
          fi

          return $ZI[annex-multi-flag:pull-active]
        } else {
          command mkdir -p "$local_dir/$dirname"

          if (( !OPTS[opt_-f,--force] )) {
            .zi-get-url-mtime "$url"
          } else {
            REPLY=$EPOCHSECONDS
          }

          # Returned is: modification time of the remote file.
          # Thus, EPOCHSECONDS - REPLY is: allowed window for the
          # local file to be modified in. ms-$secs is: files accessed
          # within last $secs seconds. Thus, if there's no match, the
          # local file is out of date.

          local secs=$(( EPOCHSECONDS - REPLY ))
          # Guard so that it's positive
          (( $secs >= 0 )) || secs=0
          integer skip_dl
          local -a matched
          matched=( $local_dir/$dirname/$filename(DNms-$secs) )
          if (( ${#matched} )) {
            +zi-message "{info}Already up to date.{rst}"
            # Empty-update return-short path – it also decides the
            # pull-active flag after the return from this sub-shell
            (( ${+ICE[run-atpull]} || OPTS[opt_-u,--urge] )) && skip_dl=1 || return 0
          }
          if [[ ! -f $local_dir/$dirname/$filename ]] {
            ZI[annex-multi-flag:pull-active]=2
          } else {
            # secs > 1 → the file is outdated, then:
            #   - if true, then the mode is 2 minus run-atpull-activation,
            #   - if false, then mode is 3 → a forced download (no remote mtime found).
            ZI[annex-multi-flag:pull-active]=$(( secs > 1 ? (2 - skip_dl) : 3 ))
          }

          # Run annexes' atpull hooks (the before atpull-ice ones).
          # The URL-snippet block.
          if [[ $update = -u && $ZI[annex-multi-flag:pull-active] -ge 1 ]] {
            reply=(
              ${(on)ZI_EXTS2[(I)zi hook:e-\!atpull-pre <->]}
              ${${ICE[atpull]#\!}:+${(on)ZI_EXTS[(I)z-annex hook:\!atpull-<-> <->]}}
              ${(on)ZI_EXTS2[(I)zi hook:e-\!atpull-post <->]}
            )
            for key in "${reply[@]}"; do
              arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
              "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zi|z-annex) hook:}%% <->}" update:url
              hook_rc="$?"
              [[ "$hook_rc" -ne 0 ]] && {
                retval="$hook_rc"
                builtin print -Pr -- "${ZI[col-warn]}Warning:%f%b ${ZI[col-obj]}${arr[5]}${ZI[col-warn]} hook returned with ${ZI[col-obj]}${hook_rc}${ZI[col-rst]}"
              }
            done
          }

          if (( !skip_dl )) {
            if { ! .zi-download-file-stdout "$url" 0 1 >! "$dirname/$filename" } {
              if { ! .zi-download-file-stdout "$url" 1 1 >! "$dirname/$filename" } {
                command rm -f "$dirname/$filename"
                +zi-message "{error}Error{ehi}:{rst} Download failed{…}"
                return 4
              }
            }
          }
          return $ZI[annex-multi-flag:pull-active]
        }
      )
      retval=$?

      # Overestimate the pull-level to 2 also in error situations
      # – no hooks will be run anyway because of the error
      ZI[annex-multi-flag:pull-active]=$retval

      if [[ $ICE[as] != command && ${+ICE[svn]} -eq 0 ]] {
        local file_path=$local_dir/$dirname/$filename
        if [[ -n ${ICE[pick]} ]]; then
          list=( ${(M)~ICE[pick]##/*}(DN) $local_dir/$dirname/${~ICE[pick]}(DN) )
          file_path=${list[1]}
        fi
        if [[ -e $file_path && -z ${ICE[(i)(\!|)(sh|bash|ksh|csh)]} && $file_path != */dev/null && ${+ICE[nocompile]} -eq 0 ]] {
          () {
            builtin emulate -LR zsh -o extendedglob ${=${options[xtrace]:#off}:+-o xtrace}
            if ! zcompile -U "$file_path" 2>/dev/null; then
              builtin print -r "Couldn't compile \`${file_path:t}', it MIGHT be wrongly downloaded"
              builtin print -r "(snippet URL points to a directory instead of a file?"
              builtin print -r "to download directory, use preceding: zi ice svn)."
              retval=4
            fi
          }
        }
      }
    } else { # Local-file snippet branch
      # Local files are (yet…) forcefully copied.
      ZI[annex-multi-flag:pull-active]=3 retval=3
      # Run annexes' atpull hooks (the before atpull-ice ones).
      # The local-file snippets block.
      if [[ $update = -u ]] {
        reply=(
          ${(on)ZI_EXTS2[(I)zi hook:e-\!atpull-pre <->]}
          ${${(M)ICE[atpull]#\!}:+${(on)ZI_EXTS[(I)z-annex hook:\!atpull-<-> <->]}}
          ${(on)ZI_EXTS2[(I)zi hook:e-\!atpull-post <->]}
        )
        for key in "${reply[@]}"; do
          arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
          "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zi|z-annex) hook:}%% <->}" update:file
          hook_rc="$?"
          [[ "$hook_rc" -ne 0 ]] && {
            retval="$hook_rc"
            builtin print -Pr -- "${ZI[col-warn]}Warning:%f%b ${ZI[col-obj]}${arr[5]}${ZI[col-warn]} hook returned with ${ZI[col-obj]}${hook_rc}${ZI[col-rst]}"
          }
        done
      }

      command mkdir -p "$local_dir/$dirname"
      if [[ ! -e $url ]] {
        (( !OPTS[opt_-q,--quiet] )) && +zi-message "{error}Error{ehi}:{rst} {msg}The source file {file}$url{msg} doesn't exist.{rst}"
        retval=4
      }
      if [[ -e $url && ! -f $url && $url != /dev/null ]] {
        (( !OPTS[opt_-q,--quiet] )) && +zi-message "{error}Error{ehi}:{rst} {msg}The source {file}$url{msg} isn't a regular file.{rst}"
        retval=4
      }
      if [[ -e $url && ! -r $url && $url != /dev/null ]] {
        (( !OPTS[opt_-q,--quiet] )) && +zi-message "{error}Error{ehi}:{rst} {msg}The source {file}$url{msg} isn't" \
          "accessible{nl}{mmdsh}{error} wrong permissions{rst}"
        retval=4
      }
      if (( !OPTS[opt_-q,--quiet] )) && [[ $url != /dev/null ]] {
        +zi-message "{msg}Copying {file}$filename{msg}{…}{rst}"
        command cp -vf "$url" "$local_dir/$dirname/$filename" || \
          { +zi-message "{error}Error{ehi}:{rst} {auto}The file copying has been unsuccessful"; retval=4; }
      } else {
        command cp -f "$url" "$local_dir/$dirname/$filename" &>/dev/null || \
          { +zi-message "{error}Error{ehi}:{rst} {msg}The copying of {file}$filename{msg} has been unsuccessful"\
            "${${(M)OPTS[opt_-q,--quiet]:#1}:+, skip the -q/--quiet option for more information}{rst}"; retval=4; }
      }
    }

    (( retval == 4 )) && { command rmdir "$local_dir/$dirname" 2>/dev/null; return $retval; }

    if [[ ${${:-$local_dir/$dirname}%%/##} != ${ZI[SNIPPETS_DIR]} ]] {
      # Store ices at "clone" and update of snippet, SVN and single-file
      local pfx=$local_dir/$dirname/._zi
      .zi-store-ices "$pfx" ICE url_rsvd "" "$save_url" "${+ICE[svn]}"
    } elif [[ -n $id_as ]] {
      +zi-message "{u-warn}Warning{b-warn}:{rst} the snippet {url}$id_as{rst} isn't" \
        "fully downloaded – you should remove it with {apo}\`{cmd}zi delete $id_as{apo}\`{rst}."
    }
    # Empty update short-path
    if (( ZI[annex-multi-flag:pull-active] == 0 )) {
      # Run annexes' atpull hooks (the `always' after atpull-ice ones)
      reply=(
        ${(on)ZI_EXTS2[(I)zi hook:%atpull-pre <->]}
        ${(on)ZI_EXTS[(I)z-annex hook:%atpull-<-> <->]}
        ${(on)ZI_EXTS2[(I)zi hook:%atpull-post <->]}
      )
      for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
        "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zi|z-annex) hook:}%% <->}" update:0
        hook_rc="$?"
        [[ "$hook_rc" -ne 0 ]] && {
          retval="$hook_rc"
          builtin print -Pr -- "${ZI[col-warn]}Warning:%f%b ${ZI[col-obj]}${arr[5]}${ZI[col-warn]} hook returned with ${ZI[col-obj]}${hook_rc}${ZI[col-rst]}"
        }
      done
      return $retval;
    }

    if [[ $update = -u ]] {
      # Run annexes' atpull hooks (the before atpull-ice ones).
      # The block is common to all 3 snippet types.
      reply=(
        ${(on)ZI_EXTS2[(I)zi hook:no-e-\\\!atpull-pre <->]}
        ${${ICE[atpull]:#\!*}:+${(on)ZI_EXTS[(I)z-annex hook:\!atpull-<-> <->]}}
        ${(on)ZI_EXTS2[(I)zi hook:no-e-\\\!atpull-post <->]}
      )
      for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
        "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zi|z-annex) hook:}%% <->}" update
        hook_rc=$?
        [[ "$hook_rc" -ne 0 ]] && {
          retval="$hook_rc"
          builtin print -Pr -- "${ZI[col-warn]}Warning:%f%b ${ZI[col-obj]}${arr[5]}${ZI[col-warn]} hook returned with ${ZI[col-obj]}${hook_rc}${ZI[col-rst]}"
        }
      done
    } else {
      # Run annexes' atclone hooks (the before atclone-ice ones)
      # The block is common to all 3 snippet types.
      reply=(
        ${(on)ZI_EXTS2[(I)zi hook:\!atclone-pre <->]}
        ${(on)ZI_EXTS[(I)z-annex hook:\!atclone-<-> <->]}
        ${(on)ZI_EXTS2[(I)zi hook:\!atclone-post <->]}
      )
      for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
        "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zi|z-annex) hook:}%% <->}" load
      done

      reply=(
        ${(on)ZI_EXTS2[(I)zi hook:atclone-pre <->]}
        ${(on)ZI_EXTS[(I)z-annex hook:atclone-<-> <->]}
        ${(on)ZI_EXTS2[(I)zi hook:atclone-post <->]}
      )
      for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
        "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zi|z-annex) hook:}%% <->}" load
      done
    }

    # Run annexes' atpull hooks (the after atpull-ice ones)
    # The block is common to all 3 snippet types.
    if [[ $update = -u ]] {
      if (( ZI[annex-multi-flag:pull-active] > 0 )) {
        reply=(
          ${(on)ZI_EXTS2[(I)zi hook:atpull-pre <->]}
          ${(on)ZI_EXTS[(I)z-annex hook:atpull-<-> <->]}
          ${(on)ZI_EXTS2[(I)zi hook:atpull-post <->]}
        )
        for key in "${reply[@]}"; do
          arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
          "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zi|z-annex) hook:}%% <->}" update
          hook_rc=$?
          [[ "$hook_rc" -ne 0 ]] && {
            retval="$hook_rc"
            builtin print -Pr -- "${ZI[col-warn]}Warning:%f%b ${ZI[col-obj]}${arr[5]}${ZI[col-warn]} hook returned with ${ZI[col-obj]}${hook_rc}${ZI[col-rst]}"
          }
        done
      }
      # Run annexes' atpull hooks (the `always' after atpull-ice ones)
      # The block is common to all 3 snippet types.
      reply=(
        ${(on)ZI_EXTS2[(I)zi hook:%atpull-pre <->]}
        ${(on)ZI_EXTS[(I)z-annex hook:%atpull-<-> <->]}
        ${(on)ZI_EXTS2[(I)zi hook:%atpull-post <->]}
      )
      for key in "${reply[@]}"; do
        arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
        "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" "${${key##(zi|z-annex) hook:}%% <->}" update:$ZI[annex-multi-flag:pull-active]
        hook_rc=$?
        [[ "$hook_rc" -ne 0 ]] && {
          retval="$hook_rc"
          builtin print -Pr -- "${ZI[col-warn]}Warning:%f%b ${ZI[col-obj]}${arr[5]}${ZI[col-warn]} hook returned with ${ZI[col-obj]}${hook_rc}${ZI[col-rst]}"
        }
      done
    }
  ) || return $?
  typeset -ga INSTALLED_EXECS
  { INSTALLED_EXECS=( "${(@f)$(<${TMPDIR:-/tmp}/zi-execs.$$.lst)}" ) } 2>/dev/null
  # After additional executions like atclone'' - install completions (2 - snippets)
  local -A OPTS
  OPTS[opt_-q,--quiet]=1
  [[ 0 = ${+ICE[nocompletions]} && ${ICE[as]} != null && ${+ICE[null]} -eq 0 ]] && \
    .zi-install-completions "%" "$local_dir/$dirname" 0
  if [[ -e ${TMPDIR:-/tmp}/zi.skipped_comps.$$.lst || -e ${TMPDIR:-/tmp}/zi.installed_comps.$$.lst ]] {
    typeset -ga INSTALLED_COMPS SKIPPED_COMPS
    { INSTALLED_COMPS=( "${(@f)$(<${TMPDIR:-/tmp}/zi.installed_comps.$$.lst)}" ) } 2>/dev/null
    { SKIPPED_COMPS=( "${(@f)$(<${TMPDIR:-/tmp}/zi.skipped_comps.$$.lst)}" ) } 2>/dev/null
  }
  if [[ -e ${TMPDIR:-/tmp}/zi.compiled.$$.lst ]] {
    typeset -ga ADD_COMPILED
    { ADD_COMPILED=( "${(@f)$(<${TMPDIR:-/tmp}/zi.compiled.$$.lst)}" ) } 2>/dev/null
  }

  # After any download – rehash the command table
  # This will however miss the as"program" binaries as their PATH gets extended - and it is done later.
  # It will however work for sbin'' ice.
  (( !OPTS[opt_-p,--parallel] )) && rehash

  return $retval
}
# ]]]
# FUNCTION: .zi-update-snippet [[[
.zi-update-snippet() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal typesetsilent noshortloops rcquotes

  local -a tmp opts
  local url=$1
  integer correct=0
  [[ -o ksharrays ]] && correct=1
  opts=( -u ) # for z-a-readurl

  # Create a local copy of OPTS,
  # basically for z-a-readurl annex
  local -A ice_opts
  ice_opts=( "${(kv)OPTS[@]}" )
  local -A OPTS
  OPTS=( "${(kv)ice_opts[@]}" )

  ZI[annex-multi-flag:pull-active]=0 ZI[-r/--reset-opt-hook-has-been-run]=0

  # Remove leading whitespace and trailing /
  url=${${url#${url%%[! $'\t']*}}%/}
  ICE[teleid]=${ICE[teleid]:-$url}
  [[ ${ICE[as]} = null || ${+ICE[null]} -eq 1 || ${+ICE[binary]} -eq 1 ]] && ICE[pick]=${ICE[pick]:-/dev/null}

  local local_dir dirname filename save_url=$url id_as=${ICE[id-as]:-$url}

  .zi-pack-ice "$id_as" ""

  # Allow things like $OSTYPE in the URL
  eval "url=\"$url\""

  # - case A: called from `update --all', ICE empty, static ice will win
  # - case B: called from `update', ICE packed, so it will win
  tmp=( "${(Q@)${(z@)ZI_SICE[$id_as]}}" )
  if (( ${#tmp} > 1 && ${#tmp} % 2 == 0 )) {
    ICE=( "${(kv)ICE[@]}" "${tmp[@]}" )
  } elif [[ -n ${ZI_SICE[$id_as]} ]] {
    +zi-message "{error}Warning{ehi}:{rst} {msg2}Inconsistency #3 occurred, please report the string: \`{obj}${ZI_SICE[$id_as]}{msg2}' to the" \
    "GitHub issues page: {obj}https://github.com/z-shell/zi/issues/{msg2}.{rst}"
  }
  id_as=${ICE[id-as]:-$id_as}

  # Oh-My-Zsh, Prezto and manual shorthands
  if (( ${+ICE[svn]} )) {
    [[ $url = *(${(~kj.|.)${(Mk)ZI_1MAP:#OMZ*}}|robbyrussell*oh-my-zsh|ohmyzsh/ohmyzsh)* ]] && local ZSH=${ZI[SNIPPETS_DIR]}
    url=${url/(#s)(#m)(${(~kj.|.)ZI_1MAP})/$ZI_1MAP[$MATCH]}
  } else {
    url=${url/(#s)(#m)(${(~kj.|.)ZI_2MAP})/$ZI_2MAP[$MATCH]}
    if [[ $save_url == (${(~kj.|.)${(Mk)ZI_1MAP:#OMZ*}})* ]] {
      if [[ $url != *.zsh(|-theme) && $url != */_[^/]## ]] {
        if [[ $save_url == OMZT::* ]] {
          url+=.zsh-theme
        } else {
          url+=/${${url#*::}:t}.plugin.zsh
        }
      }
    } elif [[ $save_url = (${(~kj.|.)${(kM)ZI_1MAP:#PZT*}})* ]] {
      if [[ $url != *.zsh ]] {
        url+=/init.zsh
      }
    }
  }

  if { ! .zi-get-object-path snippet "$id_as" } {
    +zi-message "{msg2}Error{ehi}:{rst} the snippet \`{obj}$id_as{msg2}'" "doesn't exist, aborting the update.{rst}"
      return 1
  }
  filename=$reply[-2] dirname=$reply[-2] local_dir=$reply[-3]

  local -a arr
  local key
  reply=(
    ${(on)ZI_EXTS2[(I)zi hook:preinit-pre <->]}
    ${(on)ZI_EXTS[(I)z-annex hook:preinit-<-> <->]}
    ${(on)ZI_EXTS2[(I)zi hook:preinit-post <->]}
  )
  for key in "${reply[@]}"; do
    arr=( "${(Q)${(z@)ZI_EXTS[$key]:-$ZI_EXTS2[$key]}[@]}" )
    "${arr[5]}" snippet "$save_url" "$id_as" "$local_dir/$dirname" ${${key##(zi|z-annex) hook:}%% <->} update || return $(( 10 - $? ))
  done

  # Download or copy the file
  [[ $url = *github.com* && $url != */raw/* ]] && url=${url/\/(blob|tree)\///raw/}
  .zi-download-snippet "$save_url" "$url" "$id_as" "$local_dir" "$dirname" "$filename" "-u"

  return $?
}
# ]]]
# FUNCTION: .zi-get-latest-gh-r-url-part [[[
# Gets version string of latest release of given Github package.
# Connects to Github releases page.
.zi-get-latest-gh-r-url-part() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops

  REPLY=
  local user=$1 plugin=$2 urlpart=$3

  if [[ -z $urlpart ]]; then
    local tag_version=${ICE[ver]}
    if [[ -z $tag_version ]]; then
      local releases_url=https://github.com/$user/$plugin/releases/latest
      tag_version="$( { .zi-download-file-stdout $releases_url || .zi-download-file-stdout $releases_url 1; } 2>/dev/null | \
      command grep -m1 -o 'href=./'$user'/'$plugin'/releases/tag/[^"]\+')"
      tag_version=${tag_version##*/}
    fi
    local url=https://github.com/$user/$plugin/releases/expanded_assets/$tag_version
  else
    local url=https://$urlpart
  fi

  local -A matchstr
  matchstr=(
    i386      "((amd32|386|686|linux32|x86*(#e))~*x86_84*)"
    i686      "((amd32|386|686|linux32|x86*(#e))~*x86_64*)"
    amd32     "((amd32|386|686|linux32|x86*(#e))~*x86_64*)"
    x86_64    "(amd64|x86_64|intel|linux64)"
    amd64     "(amd64|x86_64|intel|linux64)"
    linux     "(linux|linux-gnu)"
    darwin    "(darwin|mac|macos|macosx|osx|os-x)"
    mingw     "(windows|windows-gnu|mingw|mingw64|mingw-w32|mingw-w64|[-_]win|win64|win32|winnt|winnt64)"
    cygwin    "(windows|windows-gnu|cygwin|[-_]win|win64|win32|winnt|winnt64)"
    windows   "(windows|windows-gnu|cygwin|[-_]win|win64|win32|winnt|winnt64)"
    aarch64   "(aarch64|arm64|arm64v8|armv8|armv8l|arm64v8l)"
    aarch64-2 "arm"
    arm64     "(aarch64|arm64|arm64v8|armv8|armv8l|arm64v8l)"
    arm64-2   "arm"
    armv8l    "(aarch64|arm64|arm64v8|armv8|armv8l|arm64v8l)"
    armv8l-2  "arm"
    armv7l    "(arm7|armv7)"
    armv7l-2  "arm"
    armv6l    "(arm6|armv6)"
    armv6l-2  "arm"
    armv5l    "(arm5|armv5)"
    armv5l-2  "arm"
  )

  local -a list init_list

  init_list=( ${(@f)"$( { .zi-download-file-stdout $url || .zi-download-file-stdout $url 1; } 2>/dev/null | \
    command grep -o 'href=./'$user'/'$plugin'/releases/download/[^"]\+')"} )
  init_list=( ${init_list[@]#href=?} )

  local -a list2 bpicks
  bpicks=( ${(s.;.)ICE[bpick]} )
  [[ -z $bpicks ]] && bpicks=( "" )
  local bpick

  reply=()
  for bpick ( "${bpicks[@]}" ) {
    list=( $init_list )

    if [[ -n $bpick ]] {
      list=( ${(M)list[@]:#(#i)*/$~bpick} )
    }

    if (( $#list > 1 )) {
      list2=( ${(M)list[@]:#(#i)*${~matchstr[$MACHTYPE]:-${MACHTYPE#(#i)(i|amd)}}*} )
      (( $#list2 > 0 )) && list=( ${list2[@]} )
    }

    if (( ${#list} > 1 && ${#matchstr[${MACHTYPE}-2]} )) {
      list2=( ${(M)list[@]:#(#i)*${~matchstr[${MACHTYPE}-2]:-${MACHTYPE#(#i)(i|amd)}}*} )
      (( $#list2 > 0 )) && list=( ${list2[@]} )
    }

    if (( $#list > 1 )) {
      list2=( ${(M)list[@]:#(#i)*${~matchstr[$CPUTYPE]:-${CPUTYPE#(#i)(i|amd)}}*} )
      (( $#list2 > 0 )) && list=( ${list2[@]} )
    }

    if (( $#list > 1 )) {
      list2=( ${(M)list[@]:#(#i)*${~matchstr[${${OSTYPE%(#i)-(gnu|musl)}%%(-|)[0-9.]##}]:-${${OSTYPE%(#i)-(gnu|musl)}%%(-|)[0-9.]##}}*} )
      (( $#list2 > 0 )) && list=( ${list2[@]} )
    }

    if (( $#list > 1 )) {
      list2=( ${list[@]:#(#i)*.(sha[[:digit:]]#|asc)} )
      (( $#list2 > 0 )) && list=( ${list2[@]} )
    }

    if (( $#list > 1 && $+commands[dpkg-deb] )) {
      list2=( ${list[@]:#*.deb} )
      (( $#list2 > 0 )) && list=( ${list2[@]} )
    }

    if (( $#list > 1 && $+commands[rpm] )) {
      list2=( ${list[@]:#*.rpm} )
      (( $#list2 > 0 )) && list=( ${list2[@]} )
    }

    if (( !$#list )) {
      +zi-message -n "{error}Didn't find correct Github" "release-file to download"
      if [[ -n $bpick ]] {
        +zi-message -n ", try adapting {obj}bpick{error}-ICE" "({auto}current bpick{ehi}:{rst} {file}${bpick}{error})"
      } else {
        +zi-message -n .
      }
      +zi-message '{rst}'
      return 1
    }

    reply+=( $list[1] )
  }
  [[ -n $reply ]] # testable
}
# ]]]
# FUNCTION: ziextract [[[
# If the file is an archive, it is extracted by this function.
# Next stage is scanning of files with the common utility `file',
# to detect executables. They are given +x mode. There are also
# messages to the user on performed actions.
#
# $1 - url
# $2 - file
ziextract() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob typesetsilent noshortloops # warncreateglobal

  if (( $+commands[file] != 1 )) { +zi-message "{annex}ziextract{ehi}:{rst} {error}The {cmd}file{error} command is required for recognizing the type of data to be processed{rst}"
    return 1
  }
  local -a opt_move opt_move2 opt_norm opt_auto opt_nobkp
  zparseopts -D -E -move=opt_move -move2=opt_move2 -norm=opt_norm -auto=opt_auto -nobkp=opt_nobkp || \
  { +zi-message "{annex}ziextract{ehi}:{rst} {error}Incorrect options given to" "\`{annex}ziextract{error}' {rst}({p}available are{ehi}:{rst} {opt}--auto{msg2}," \
  "{opt}--move{msg2}, {opt}--move2{msg2}, {opt}--norm{msg2}, {opt}--nobkp{rst})"; return 1; }

  local file="$1" ext="$2"
  integer move=${${${(M)${#opt_move}:#0}:+0}:-1} \
  move2=${${${(M)${#opt_move2}:#0}:+0}:-1} \
  norm=${${${(M)${#opt_norm}:#0}:+0}:-1} \
  auto=${${${(M)${#opt_auto}:#0}:+0}:-1} \
  nobkp=${${${(M)${#opt_nobkp}:#0}:+0}:-1}

  if (( auto )) {
    # First try known file extensions
    local -a files
    integer ret_val
    files=( (#i)**/*.(zip|rar|7z|tgz|tbz|tbz2|tar.gz|tar.bz2|tar.7z|txz|tar.xz|gz|xz|tar|dmg|exe)~(*/*|.(_backup|git))/*(-.DN) )
    for file ( $files ) {
      ziextract "$file" $opt_move $opt_move2 $opt_norm $opt_nobkp ${${${#files}:#1}:+--nobkp}
      ret_val+=$?
    }
    # Second, try to find the archive via `file' tool
    if (( !${#files} )) {
      local -aU output infiles stage2_processed archives
      infiles=( **/*~(._zi*|._backup|.git)(|/*)~*/*/*(-.DN) )
      output=( ${(@f)"$(command file -- $infiles 2>&1)"} )
      archives=( ${(M)output[@]:#(#i)(* |(#s))(zip|rar|xz|7-zip|gzip|bzip2|tar|exe|PE32) *} )
      for file ( $archives ) {
        local fname=${(M)file#(${(~j:|:)infiles}): } desc=${file#(${(~j:|:)infiles}): } type
        fname=${fname%%??}
        [[ -z $fname || -n ${stage2_processed[(r)$fname]} ]] && continue
        type=${(L)desc/(#b)(#i)(* |(#s))(zip|rar|xz|7-zip|gzip|bzip2|tar|exe|PE32) */$match[2]}
        if [[ $type = (zip|rar|xz|7-zip|gzip|bzip2|tar|exe|pe32) ]] {
          (( !OPTS[opt_-q,--quiet] )) && \
          +zi-message "{annex}ziextract{ehi}:{rst} {note}Detected a {obj2}$type{note} archive in the file{ehi}:{rst} {file}$fname{rst}"
          ziextract "$fname" "$type" $opt_move $opt_move2 $opt_norm --norm ${${${#archives}:#1}:+--nobkp}
          integer iret_val=$?
          ret_val+=iret_val

          (( iret_val )) && continue

          # Support nested tar.(bz2|gz|…) archives
          local infname=$fname
          [[ -f $fname.out ]] && fname=$fname.out
          files=( *.tar(ND) )
          if [[ -f $fname || -f ${fname:r} ]] {
            local -aU output2 archives2
            output2=( ${(@f)"$(command file -- "$fname"(N) "${fname:r}"(N) $files[1](N) 2>&1)"} )
            archives2=( ${(M)output2[@]:#(#i)(* |(#s))(zip|rar|xz|7-zip|gzip|bzip2|tar|exe|PE32) *} )
            local file2
            for file2 ( $archives2 ) {
              fname=${file2%:*} desc=${file2##*:}
              local type2=${(L)desc/(#b)(#i)(* |(#s))(zip|rar|xz|7-zip|gzip|bzip2|tar|exe|PE32) */$match[2]}
              if [[ $type != $type2 && $type2 = (zip|rar|xz|7-zip|gzip|bzip2|tar) ]] {
                # TODO: #115 If multiple archives are really in the archive, this might delete too soon… However, it's unusual case.
                [[ $fname != $infname && $norm -eq 0 ]] && command rm -f "$infname"
                (( !OPTS[opt_-q,--quiet] )) && \
                +zi-message "{annex}ziextract{ehi}:{rst} {note}Detected a {obj2}${type2}{note} archive in the file{ehi}:{rst} {file}${fname}{rst}"
                ziextract "$fname" "$type2" $opt_move $opt_move2 $opt_norm ${${${#archives}:#1}:+--nobkp}
                ret_val+=$?
                stage2_processed+=( $fname )
                if [[ $fname == *.out ]] {
                  [[ -f $fname ]] && command mv -f "$fname" "${fname%.out}"
                  stage2_processed+=( ${fname%.out} )
                }
              }
            }
          }
        }
      }
    }
    return $ret_val
  }

  if [[ -z $file ]] {
    +zi-message "{annex}ziextract{ehi}:{rst} {error}Argument required for {file}file{error} to extract or the {opt}--auto{error} option{rst}"
    return 1
  }
  if [[ ! -e $file ]] {
    +zi-message "{annex}ziextract{ehi}:{rst} {error}The {file}file{error} \`{pname}${file}{error}' does not exist{rst}"
    return 1
  }
  if (( !nobkp )) {
    command mkdir -p ._backup
    command rm -rf ._backup/*(DN)
    command mv -f *~(._zi*|._backup|.git|.svn|.hg|$file)(DN) ._backup 2>/dev/null
  }

  .zi-extract-wrapper() {
    local file="$1" fun="$2" retval
    (( !OPTS[opt_-q,--quiet] )) && +zi-message "{annex}ziextract{ehi}:{rst} Unpacking the files from{ehi}:{rst} \`{file}$file{rst}'{…}{rst}"
    $fun; retval=$?
    if (( retval == 0 )) {
      local -a files
      files=( *~(._zi*|._backup|.git|.svn|.hg|$file)(DN) )
      (( ${#files} && !norm )) && command rm -f "$file"
    }
    return $retval
  }

  →zi-check() { (( ${+commands[$1]} )) || +zi-message "{annex}ziextract{ehi}:{rst} {error}No command {cmd}$1{msg2},{error} it is required to unpack {file}$2{rst}"; }

  case "${${ext:+.$ext}:-$file}" in
    ((#i)*.zip)
      →zi-extract() { →zi-check unzip "$file" || return 1; command unzip -o "$file"; }
      ;;
    ((#i)*.rar)
      →zi-extract() { →zi-check unrar "$file" || return 1; command unrar x "$file"; }
      ;;
    ((#i)*.tar.bz2|(#i)*.tbz|(#i)*.tbz2)
      →zi-extract() { →zi-check bzip2 "$file" || return 1; command bzip2 -dc "$file" | command tar -xf -; }
      ;;
    ((#i)*.tar.gz|(#i)*.tgz)
      →zi-extract() { →zi-check gzip "$file" || return 1; command gzip -dc "$file" | command tar -xf -; }
      ;;
    ((#i)*.tar.xz|(#i)*.txz)
      →zi-extract() { →zi-check xz "$file" || return 1; command xz -dc "$file" | command tar -xf -; }
      ;;
    ((#i)*.tar.7z|(#i)*.t7z)
      →zi-extract() { →zi-check 7z "$file" || return 1; command 7z x -so "$file" | command tar -xf -; }
      ;;
    ((#i)*.tar)
      →zi-extract() { →zi-check tar "$file" || return 1; command tar -xf "$file"; }
      ;;
    ((#i)*.gz|(#i)*.gzip)
      if [[ $file != (#i)*.gz ]] {
        command mv $file $file.gz
        file=$file.gz
        integer zi_was_renamed=1
      }
      →zi-extract() {
        →zi-check gunzip "$file" || return 1
        .zi-get-mtime-into "$file" 'ZI[tmp]'
        command gunzip "$file" |& command grep -E -v '.out$'
        integer ret=$pipestatus[1]
        command touch -t "$(strftime %Y%m%d%H%M.%S $ZI[tmp])" "$file"
        return ret
      }
      ;;
    ((#i)*.bz2|(#i)*.bzip2)
      # Rename file if its extension does not match "bz2". bunzip2 refuses to operate on files that are not named correctly.
      if [[ $file != (#i)*.bz2 ]] {
        command mv $file $file.bz2
        file=$file.bz2
      }
      →zi-extract() { →zi-check bunzip2 "$file" || return 1
        .zi-get-mtime-into "$file" 'ZI[tmp]'
        command bunzip2 "$file" |& command grep -E -v '.out$'
        integer ret=$pipestatus[1]
        command touch -t "$(strftime %Y%m%d%H%M.%S $ZI[tmp])" "$file"
        return ret
      }
      ;;
    ((#i)*.xz)
      if [[ $file != (#i)*.xz ]] {
        command mv $file $file.xz
        file=$file.xz
      }
      →zi-extract() { →zi-check xz "$file" || return 1
        .zi-get-mtime-into "$file" 'ZI[tmp]'
        command xz -d "$file"
        integer ret=$?
        command touch -t "$(strftime %Y%m%d%H%M.%S $ZI[tmp])" "$file"
        return ret
      }
      ;;
    ((#i)*.7z|(#i)*.7-zip)
      →zi-extract() { →zi-check 7z "$file" || return 1; command 7z x "$file" >/dev/null;  }
      ;;
    ((#i)*.dmg)
      →zi-extract() {
        local prog
        for prog ( hdiutil cp ) { →zi-check $prog "$file" || return 1; }

        integer retval
        local attached_vol="$( command hdiutil attach "$file" | command tail -n1 | command cut -f 3 )"
        command cp -Rf ${attached_vol:-${TMPDIR:-/tmp}/acb321GEF}/*(D) .
        retval=$?
        command hdiutil detach $attached_vol
        if (( retval )) {
          +zi-message "{annex}ziextract{ehi}:{rst} {warn}Problem occurred when attempted to copy the files from the mounted image{ehi}:{rst} \`{file}${file}{rst}'"
        }
        return $retval
      }
      ;;
    ((#i)*.deb)
      →zi-extract() { →zi-check dpkg-deb "$file" || return 1; command dpkg-deb -R "$file" .; }
      ;;
    ((#i)*.rpm)
      →zi-extract() { →zi-check cpio "$file" || return 1; $ZI[BIN_DIR]/lib/zsh/rpm2cpio.zsh "$file" | command cpio -imd --no-absolute-filenames; }
      ;;
    ((#i)*.exe|(#i)*.pe32)
      →zi-extract() {
        command chmod a+x -- ./$file
        ./$file /S /D="`cygpath -w $PWD`"
      }
      ;;
  esac

  if [[ $(typeset -f + →zi-extract) == "→zi-extract" ]] {
    .zi-extract-wrapper "$file" →zi-extract || {
      +zi-message -n "{annex}ziextract{ehi}:{rst} {warn}Problem occurred while extracting \`{file}$file{warn}'{rst}"
      local -a bfiles
      bfiles=( ._backup/*(DN) )
      if (( ${#bfiles} && !nobkp )) {
        +zi-message -n ", restoring the previous version of the {pname}plugin{ehi}/{apo}snippet{rst}"
        command mv ._backup/*(DN) . 2>/dev/null
      }
      +zi-message ".{rst}"
      unfunction -- →zi-extract →zi-check 2>/dev/null
      return 1
    }
    unfunction -- →zi-extract →zi-check
  } else {
    integer warning=1
  }
  unfunction -- .zi-extract-wrapper

  local -a execs
  execs=( **/*~(._zi(|/*)|.git(|/*)|.svn(|/*)|.hg(|/*)|._backup(|/*))(DN-.) )
  if [[ ${#execs} -gt 0 && -n $execs ]] {
    execs=( ${(@f)"$( file ${execs[@]} )"} )
    execs=( "${(M)execs[@]:#[^:]##:*executable*}" )
    execs=( "${execs[@]/(#b)([^:]##):*/${match[1]}}" )
  }

  builtin print -rl -- ${execs[@]} >! ${TMPDIR:-/tmp}/zi-execs.$$.lst
  if [[ ${#execs} -gt 0 ]] {
    command chmod a+x "${execs[@]}"
    if (( !OPTS[opt_-q,--quiet] )) {
      if (( ${#execs} == 1 )); then
        +zi-message "{annex}ziextract{ehi}:{rst} {auto}Successfully extracted and assigned \`+x\` chmod to the file{ehi}:{rst} \`{file}${execs[1]}{rst}'"
      else
        local sep="$ZI[col-rst],$ZI[col-obj] "
        if (( ${#execs} > 7 )) {
          +zi-message "{annex}ziextract{ehi}:{rst} {auto}Successfully extracted and assigned \`+x\` chmod to the files{ehi}:{rst} ({obj2}${(pj:$sep:)${(@)execs[1,5]:t}},…{rst}) contained" \
            "in \`{file}$file{rst}' {nl}{mmdsh}{msg} All the extracted {obj2}${#execs}{rst} executables are available in the {var}INSTALLED_EXECS{rst} array"
        } else {
          +zi-message "{annex}ziextract{ehi}:{rst} {auto}Successfully extracted and assigned \`+x\` chmod to the files{ehi}:{rst} ({obj2}${(pj:$sep:)${execs[@]:t}}{rst}) contained in \`{file}$file{rst}'"
        }
      fi
    }
  } elif (( warning )) {
    +zi-message "{annex}ziextract{ehi}:{rst} {auto}Did not recognize the archive type of \`{file}${file}{rst}'" \
      "${ext:+/ {obj2}${ext}{rst} } {nl}{mmdsh}{rst}{error} No extraction has been done{rst}"
  }
  if (( move | move2 )) {
    local -a files
    files=( *~(._zi|.git|._backup|.tmp231ABC)(DN/) )
    if (( ${#files} )) {
      command mkdir -p .tmp231ABC
      command mv -f *~(._zi|.git|._backup|.tmp231ABC)(D) .tmp231ABC
      if (( !move2 )) {
        command mv -f **/*~(*/*~*/*/*|*/*/*/*|^*/*|._zi(|/*)|.git(|/*)|._backup(|/*))(DN) .
      } else {
        command mv -f **/*~(*/*~*/*/*/*|*/*/*/*/*|^*/*|._zi(|/*)|.git(|/*)|._backup(|/*))(DN) .
      }
      command mv .tmp231ABC/$file . &>/dev/null
      command rm -rf .tmp231ABC
    }
    REPLY="${${execs[1]:h}:h}/${execs[1]:t}"
  } else {
    REPLY="${execs[1]}"
  }
  return 0
} # ]]]
# FUNCTION: .zi-extract() [[[
.zi-extract() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal typesetsilent
  local tpe=$1 extract=$2 local_dir=$3
  (
    builtin cd -q "$local_dir" || {
      +zi-message "{auto}The path of the $tpe {dir}$local_dir{rst} {nl}{mmdsh}{error} Not accessible{rst}"
      return 1
    }
    local -a files
    files=( ${(@)${(@s: :)${extract##(\!-|-\!|\!|-)}}//(#b)(((#s)|([^\\])[\\]([\\][\\])#)|((#s)|([^\\])([\\][\\])#)) /${match[2]:+$match[3]$match[4] }${match[5]:+$match[6]${(l:${#match[7]}/2::\\:):-} }} )
    if [[ ${#files} -eq 0 && -n ${extract##(\!-|-\!|\!|-)} ]] {
        +zi-message "{auto}The files ${extract##(\!-|-\!|\!|-)} not found{rst}{nl}{mmdsh}{error} Failed to extract{rst}"
        return 1
    } else {
      (( !${#files} )) && files=( "" )
    }
    local file
    for file ( "${files[@]}" ) {
      [[ -z $extract ]] && local auto2=--auto
      ziextract ${${(M)extract:#(\!|-)##}:+--auto} $auto2 $file ${${(MS)extract[1,2]##-}:+--norm} ${${(MS)extract[1,2]##\!}:+--move} ${${(MS)extract[1,2]##\!\!}:+--move2} ${${${#files}:#1}:+--nobkp}
    }
  )
}
# ]]]
# FUNCTION: zpextract [[[
zpextract() { ziextract "$@"; }
# ]]]
# FUNCTION: .zi-at-eval [[[
.zi-at-eval() {
  local atpull="$1" atclone="$2"
  integer retval
  @zi-substitute atclone atpull
  local cmd="$atpull"
  [[ $atpull == "%atclone" ]] && cmd="$atclone"
  eval "$cmd"
  return "$?"
} # ]]]
# FUNCTION: .zi-get-cygwin-package [[[
.zi-get-cygwin-package() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes no_auto_pushd

  REPLY=

  local pkg=$1 nl=$'\n'
  integer retry=3

  #
  # Download mirrors.lst
  #

  +zi-message "{info}Downloading{ehi}:{rst} {obj}mirrors.lst{info}{…}{rst}"
  local mlst="$(mktemp)"
  while (( retry -- )) {
    if ! .zi-download-file-stdout https://cygwin.com/mirrors.lst 0 > $mlst; then
      .zi-download-file-stdout https://cygwin.com/mirrors.lst 1 > $mlst
    fi

    local -a mlist
    mlist=( "${(@f)$(<$mlst)}" )

    local mirror=${${mlist[ RANDOM % (${#mlist} + 1) ]}%%;*}
    [[ -n $mirror ]] && break
  }

  if [[ -z $mirror ]] {
    +zi-message "{error}Couldn't download{ehi}:{rst} {obj}mirrors.lst {error}."
    return 1
  }

  mirror=http://ftp.eq.uc.pt/software/pc/prog/cygwin/

  #
  # Download setup.ini.bz2
  #

  +zi-message "{info2}Selected mirror is{ehi}:{rst} {url}${mirror}{rst}"
  +zi-message "{info}Downloading{ehi}:{rst} {file}setup.ini.bz2{info}{…}{rst}"
  local setup="$(mktemp -u)"
  retry=3
  while (( retry -- )) {
    if ! .zi-download-file-stdout ${mirror}x86_64/setup.bz2 0 1 > $setup.bz2; then
      .zi-download-file-stdout ${mirror}x86_64/setup.bz2 1 1 > $setup.bz2
    fi

    command bunzip2 "$setup.bz2" 2>/dev/null
    [[ -s $setup ]] && break
    mirror=${${mlist[ RANDOM % (${#mlist} + 1) ]}%%;*}
    +zi-message "{pre}Retrying{ehi}:{rst} {meta}#{obj}$(( 3 - $retry ))/3, {pre}with mirror{error}: {url}$mirror{rst}"
  }
  local setup_contents="$(command grep -A 26 "@ $pkg\$" "$setup")"
  local urlpart=${${(S)setup_contents/(#b)*@ $pkg${nl}*install: (*)$nl*/$match[1]}%% *}
  if [[ -z $urlpart ]] {
    +zi-message "{error}Couldn't find package{ehi}:{rst} {data2}\`{data}$pkg{data2}'{error}.{rst}"
    return 2
  }
  local url=$mirror/$urlpart outfile=${TMPDIR:-${TMPDIR:-/tmp}}/${urlpart:t}

  #
  # Download the package
  #

  +zi-message "{info}Downloading{ehi}:{rst} {file}${url:t}{info}{…}{rst}"
  retry=2
  while (( retry -- )) {
    integer retval=0
    if ! .zi-download-file-stdout $url 0 1 > $outfile; then
      if ! .zi-download-file-stdout $url 1 1 > $outfile; then
        +zi-message "{error}Couldn't download{ehi}:{rst} {url}$url{error}."
        retval=1
        mirror=${${mlist[ RANDOM % (${#mlist} + 1) ]}%%;*}
        url=$mirror/$urlpart outfile=${TMPDIR:-${TMPDIR:-/tmp}}/${urlpart:t}
        if (( retry )) {
          +zi-message "{info2}Retrying, with mirror{ehi}:{rst} {url}$mirror{info2}{…}{rst}"
          continue
        }
      fi
    fi
    break
  }
  REPLY=$outfile
}
# ]]]
# FUNCTION zicp [[[
zicp() {
  builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
  builtin setopt extendedglob warncreateglobal typesetsilent noshortloops rcquotes

  local -a mbegin mend match
  local cmd=cp
  if [[ $1 = (-m|--mv) ]] { cmd=mv; shift; }

  local dir
  if [[ $1 = (-d|--dir)  ]] { dir=$2; shift 2; }

  local arg
  arg=${${(j: :)@}//(#b)(([[:space:]]~ )#(([^[:space:]]| )##)([[:space:]]~ )#(#B)(->|=>|→)(#B)([[:space:]]~ )#(#b)(([^[:space:]]| )##)|(#B)([[:space:]]~ )#(#b)(([^[:space:]]| )##))/${match[3]:+$match[3] $match[6]\;}${match[8]:+$match[8] $match[8]\;}}
  (
    if [[ -n $dir ]] { cd $dir || return 1; }
    local a b var
    integer retval
    for a b ( "${(s: :)${${(@s.;.)${arg%\;}}:-* .}}" ) {
      for var ( a b ) {
        : ${(P)var::=${(P)var//(#b)(((#s)|([^\\])[\\]([\\][\\])#)|((#s)|([^\\])([\\][\\])#)) /${match[2]:+$match[3]$match[4] }${match[5]:+$match[6]${(l:${#match[7]}/2::\\:):-} }}}
      }
      if [[ $a != *\** ]] { a=${a%%/##}"/*" }
      command mkdir -p ${~${(M)b:#/*}:-$ZPFX/$b}
      command $cmd -f ${${(M)cmd:#cp}:+-R} $~a ${~${(M)b:#/*}:-$ZPFX/$b}
      retval+=$?
    }
    return $retval
  )
  return
}
# ]]]
# FUNCTION zimv [[[
zimv() {
  local dir
  if [[ $1 = (-d|--dir) ]] { dir=$2; shift 2; }
  zicp --mv ${dir:+--dir} $dir "$@"
}
# ]]]
# FUNCTION: ∞zi-reset-opt-hook [[[
∞zi-reset-hook() {
  # File
  if [[ "$1" = plugin ]] {
    local type="$1" user="$2" plugin="$3" id_as="$4" dir="${5#%}" hook="$6"
  } else {
    local type="$1" url="$2" id_as="$3" dir="${4#%}" hook="$5"
  }
  if (( ( OPTS[opt_-r,--reset] && ZI[-r/--reset-opt-hook-has-been-run] == 0 ) || ( ${+ICE[reset]} && ZI[-r/--reset-opt-hook-has-been-run] == 1 ) )) {
    if (( ZI[-r/--reset-opt-hook-has-been-run] )) {
      local msg_bit="{ice}reset{msg} ice given{pre}" option=
    } else {
      local msg_bit="{opt}-r/--reset{msg} given to \`{cmd}update{rst}'{pre}" option=1
    }
    if [[ $type == snippet ]] {
      if (( $+ICE[svn] )) {
        if [[ $skip_pull -eq 0 && -d $filename/.svn ]] {
          (( !OPTS[opt_-q,--quiet] )) && +zi-message "{pre}reset ($msg_bit){ehi}:{rst} {msg}Resetting the repository ($msg_bit) with command{ehi}:{rst} {rst}svn revert --recursive {…}/{file}$filename/.{rst} {…}"
          command svn revert --recursive $filename/.
        }
      } else {
        if (( ZI[annex-multi-flag:pull-active] >= 2 )) {
          if (( !OPTS[opt_-q,--quiet] )) {
            if [[ -f $local_dir/$dirname/$filename ]] {
              if [[ -n $option || -z $ICE[reset] ]] {
                +zi-message "{pre}reset ($msg_bit){ehi}:{rst} {msg}Removing the snippet-file{ehi}:{rst} {file}$filename{msg} {…}{rst}"
              } else {
                +zi-message "{pre}reset ($msg_bit){ehi}:{rst} {msg}Removing the snippet-file{ehi}:{rst} {file}$filename{msg}, with the supplied code{ehi}:{rst} {data2}$ICE[reset]{msg} {…}{rst}"
              }
              if (( option )) {
                command rm -f "$local_dir/$dirname/$filename"
              } else {
                eval "${ICE[reset]:-rm -f \"$local_dir/$dirname/$filename\"}"
              }
            } else {
              +zi-message "{pre}reset ($msg_bit){ehi}:{rst} {msg}The file {file}$filename{msg} is already deleted {…}{rst}"
              if [[ -n $ICE[reset] && ! -n $option ]] {
                +zi-message "{pre}reset ($msg_bit){ehi}:{rst} {msg}(skipped running the provided reset-code{ehi}:{rst} {data2}$ICE[reset]{msg}){rst}"
              }
            }
          }
        } else {
          [[ -f $local_dir/$dirname/$filename ]] && \
            +zi-message "{pre}reset ($msg_bit){ehi}:{rst} {msg}Skipping the removal of {file}$filename{msg} as there is no new copy scheduled for download{rst}" || \
            +zi-message "{pre}reset ($msg_bit){ehi}:{rst} {msg}The file {file}$filename{msg} is already deleted and no new download is being scheduled{rst}"
        }
      }
    } elif [[ $type == plugin ]] {
      if (( is_release && !skip_pull )) {
        if (( option )) {
          (( !OPTS[opt_-q,--quiet] )) && +zi-message "{pre}reset ($msg_bit){ehi}:{rst} {msg}Running{ehi}:{rst} rm -rf ${${ZI[PLUGINS_DIR]:#[/[:space:]]##}:-${TMPDIR:-/tmp}/xyzabc312}/${${(M)${local_dir##${ZI[PLUGINS_DIR]}[/[:space:]]#}:#[^/]*}:-${TMPDIR:-/tmp}/xyzabc312-zi-protection-triggered}/*"
          builtin eval command rm -rf ${${ZI[PLUGINS_DIR]:#[/[:space:]]##}:-${TMPDIR:-/tmp}/xyzabc312}/"${${(M)${local_dir##${ZI[PLUGINS_DIR]}[/[:space:]]#}:#[^/]*}:-${TMPDIR:-/tmp}/xyzabc312-zi-protection-triggered}"/*(ND)
        } else {
          (( !OPTS[opt_-q,--quiet] )) && +zi-message "{pre}reset ($msg_bit){ehi}:{rst} {msg}Running{ehi}:{rst} ${ICE[reset]:-rm -rf ${${ZI[PLUGINS_DIR]:#[/[:space:]]##}:-${TMPDIR:-/tmp}/xyzabc312}/${${(M)${local_dir##${ZI[PLUGINS_DIR]}[/[:space:]]#}:#[^/]*}:-${TMPDIR:-/tmp}/xyzabc312-zi-protection-triggered}/*}"
          builtin eval ${ICE[reset]:-command rm -rf ${${ZI[PLUGINS_DIR]:#[/[:space:]]##}:-${TMPDIR:-/tmp}/xyzabc312}/"${${(M)${local_dir##${ZI[PLUGINS_DIR]}[/[:space:]]#}:#[^/]*}:-${TMPDIR:-/tmp}/xyzabc312-zi-protection-triggered}"/*(ND)}
        }
      } elif (( !skip_pull )) {
        if (( option )) {
          +zi-message "{pre}reset ($msg_bit){ehi}:{rst} {msg}Resetting the repository with command{ehi}:{rst} {auto}git reset --hard HEAD {…}"
          command git reset --hard HEAD
        } else {
          +zi-message "{pre}reset ($msg_bit){ehi}:{rst} {msg}Resetting the repository with command{ehi}:{rst} {auto}${ICE[reset]:-git reset --hard HEAD} {…}"
          builtin eval "${ICE[reset]:-git reset --hard HEAD}"
        }
      }
    }
  }

  if (( OPTS[opt_-r,--reset] )) {
    if (( ZI[-r/--reset-opt-hook-has-been-run] == 1 )) {
      ZI[-r/--reset-opt-hook-has-been-run]=0
    } else {
      ZI[-r/--reset-opt-hook-has-been-run]=1
    }
  } else {
    # If there's no -r/--reset, pretend that it already has been served.
    ZI[-r/--reset-opt-hook-has-been-run]=1
  }
} # ]]]
# FUNCTION: ∞zi-make-ee-hook [[[
∞zi-make-ee-hook() {
  [[ "$1" = plugin ]] && local dir="${5#%}" hook="$6" subtype="$7" || local dir="${4#%}" hook="$5" subtype="$6"

  local make=${ICE[make]}
  @zi-substitute make
  (( ${+ICE[make]} )) || return 0
  [[ $make = "!!"* ]] || return 0
  # Git-plugin make'' at download
  .zi-countdown make && command make -C "$dir" ${(@s; ;)${make#\!\!}}
} # ]]]
# FUNCTION: ∞zi-make-e-hook [[[
∞zi-make-e-hook() {
  [[ "$1" = plugin ]] && local dir="${5#%}" hook="$6" subtype="$7" || local dir="${4#%}" hook="$5" subtype="$6"

  local make=${ICE[make]}
  @zi-substitute make
  (( ${+ICE[make]} )) || return 0
  [[ $make = ("!"[^\!]*|"!") ]] || return 0
  # Git-plugin make'' at download
  .zi-countdown make && command make -C "$dir" ${(@s; ;)${make#\!}}
} # ]]]
# FUNCTION: ∞zi-make-hook [[[
∞zi-make-hook() {
  [[ "$1" = plugin ]] && local dir="${5#%}" hook="$6" subtype="$7" || local dir="${4#%}" hook="$5" subtype="$6"
  local make=${ICE[make]}
  @zi-substitute make
  (( ${+ICE[make]} )) || return 0
  [[ $make != "!"* ]] || return 0
  # Git-plugin make'' at download
  .zi-countdown make && command make -C "$dir" ${(@s; ;)make}
} # ]]]
# FUNCTION: ∞zi-atclone-hook [[[
∞zi-atclone-hook() {
  [[ "$1" = plugin ]] && local dir="${5#%}" hook="$6" subtype="$7" || local dir="${4#%}" hook="$5" subtype="$6"
  local atclone=${ICE[atclone]}
  @zi-substitute atclone
  (( ${+ICE[atclone]} )) || return 0
  local rc=0
  [[ -n $atclone ]] && .zi-countdown atclone && {
    local ___oldcd=$PWD
    (( ${+ICE[nocd]} == 0 )) && {
      () {
        builtin setopt localoptions noautopushd
        builtin cd -q "$dir"
      }
    }
    eval "$atclone"
    rc="$?"
    () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; }
  }
  return "$rc"
} # ]]]
# FUNCTION: ∞zi-extract-hook [[[
∞zi-extract-hook() {
  [[ "$1" = plugin ]] && local dir="${5#%}" hook="$6" subtype="$7" || local dir="${4#%}" hook="$5" subtype="$6"
  local extract=${ICE[extract]}
  @zi-substitute extract
  (( ${+ICE[extract]} )) || return 0
  .zi-extract plugin "$extract" "$dir"
} # ]]]
# FUNCTION: ∞zi-mv-hook [[[
∞zi-mv-hook() {
  [[ -z $ICE[mv] ]] && return 0
  [[ "$1" = plugin ]] && local dir="${5#%}" hook="$6" subtype="$7" || local dir="${4#%}" hook="$5" subtype="$6"
  if [[ $ICE[mv] == *("->"|"→")* ]] {
    local from=${ICE[mv]%%[[:space:]]#(->|→)*} to=${ICE[mv]##*(->|→)[[:space:]]#} || \
  } else {
    local from=${ICE[mv]%%[[:space:]]##*} to=${ICE[mv]##*[[:space:]]##}
  }
  @zi-substitute from to
  local -a mv_args=("-f")
  local -a afr
    ( () { builtin setopt localoptions noautopushd; builtin cd -q "$dir"; } || return 1
      afr=( ${~from}(DN) )
      if (( ! ${#afr} )) {
        +zi-message "{warn}Warning{ehi}:{rst} {auto}mv ice didn't match any file{rst} [{error}$ICE[mv]{rst}]" \
        "{nl}{mmdsh} Available files{ehi}:{rst}{nl}{obj}$(ls -1)"
        return 1
      }
      if (( !OPTS[opt_-q,--quiet] )) {
        mv_args+=("-v")
      }

      command mv "${mv_args[@]}" "${afr[1]}" "$to"
      local retval=$?
      command mv "${mv_args[@]}" "${afr[1]}".zwc "$to".zwc 2>/dev/null
      return $retval
    )
} # ]]]
# FUNCTION: ∞zi-cp-hook [[[
∞zi-cp-hook() {
  [[ -z $ICE[cp] ]] && return
  [[ "$1" = plugin ]] && local dir="${5#%}" hook="$6" subtype="$7" || local dir="${4#%}" hook="$5" subtype="$6"

  if [[ $ICE[cp] == *("->"|"→")* ]] {
    local from=${ICE[cp]%%[[:space:]]#(->|→)*} to=${ICE[cp]##*(->|→)[[:space:]]#} || \
  } else {
    local from=${ICE[cp]%%[[:space:]]##*} to=${ICE[cp]##*[[:space:]]##}
  }

  @zi-substitute from to

  local -a afr retval
  ( () { builtin setopt localoptions noautopushd; builtin cd -q "$dir"; } || return 1
    afr=( ${~from}(DN) )
    if (( ${#afr} )); then
      if (( !OPTS[opt_-q,--quiet] )); then
        command cp -vf "${afr[1]}" "$to"; retval=$?
        command cp -vf "${afr[1]}".zwc "$to".zwc 2>/dev/null
      else
        command cp -f "${afr[1]}" "$to"; retval=$?
        command cp -f "${afr[1]}".zwc "$to".zwc 2>/dev/null
      fi
    fi
    return $retval
  )
} # ]]]
# FUNCTION: ∞zi-compile-plugin-hook [[[
∞zi-compile-plugin-hook() {
  [[ "$1" = plugin ]] && local dir="${5#%}" hook="$6" subtype="$7" || local dir="${4#%}" hook="$5" subtype="$6"
    if ! [[ ( $hook = *\!at(clone|pull)* && ${+ICE[nocompile]} -eq 0 ) || ( $hook = at(clone|pull)* && $ICE[nocompile] = '!' ) ]] {
      return 0
    }
    # Compile plugin
    if [[ -z $ICE[(i)(\!|)(sh|bash|ksh|csh)] ]] {
      () {
        builtin emulate -LR zsh ${=${options[xtrace]:#off}:+-o xtrace}
        builtin setopt extendedglob warncreateglobal
        if [[ $tpe == snippet ]] {
          .zi-compile-plugin "%$dir" ""
        } else {
          .zi-compile-plugin "$id_as" ""
        }
      }
    }
} # ]]]
# FUNCTION: ∞zi-atpull-e-hook [[[
∞zi-atpull-e-hook() {
  (( ${+ICE[atpull]} )) || return 0
  [[ -n ${ICE[atpull]} ]] || return 0
  # Only process atpull"!cmd"
  [[ $ICE[atpull] == "!"* ]] || return 0
  [[ "$1" = plugin ]] && local dir="${5#%}" hook="$6" subtype="$7" || local dir="${4#%}" hook="$5" subtype="$6"
  local atpull=${ICE[atpull]#\!}
  local rc=0

  .zi-countdown atpull && {
    local ___oldcd=$PWD
    (( ${+ICE[nocd]} == 0 )) && {
      () { builtin setopt localoptions noautopushd; builtin cd -q "$dir"; }
    }
    .zi-at-eval "$atpull" "$ICE[atclone]"
    rc="$?"
    () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; };
  }
  return "$rc"
} # ]]]
# FUNCTION: ∞zi-atpull-hook [[[
∞zi-atpull-hook() {
  (( ${+ICE[atpull]} )) || return 0
  [[ -n ${ICE[atpull]} ]] || return 0
  # Exit early if atpull"!cmd" -> this is done by zi-atpull-e-hook
  [[ $ICE[atpull] == "!"* ]] && return 0
  [[ "$1" == plugin ]] && local dir="${5#%}" hook="$6" subtype="$7" || local dir="${4#%}" hook="$5" subtype="$6"
  local atpull=${ICE[atpull]}
  local rc=0
  .zi-countdown atpull && {
    local ___oldcd=$PWD
    (( ${+ICE[nocd]} == 0 )) && {
      () { builtin setopt localoptions noautopushd; builtin cd -q "$dir"; }
    }
    .zi-at-eval "$atpull" $ICE[atclone]
    rc="$?"
    () { builtin setopt localoptions noautopushd; builtin cd -q "$___oldcd"; };
  }
  return "$rc"
} # ]]]
# FUNCTION: ∞zi-ps-on-update-hook [[[
∞zi-ps-on-update-hook() {
  [[ -z $ICE[ps-on-update] ]] && return 0
  [[ "$1" = plugin ]] && local tpe="$1" dir="${5#%}" hook="$6" subtype="$7" || local tpe="$1" dir="${4#%}" hook="$5" subtype="$6"
  if (( !OPTS[opt_-q,--quiet] )) {
    +zi-message "Running $tpe's provided update code{ehi}:{rst} {info}${ICE[ps-on-update][1,50]}${ICE[ps-on-update][51]:+…}{rst}"
    (
      builtin cd -q "$dir" || return 1
      eval "$ICE[ps-on-update]"
    )
  } else {
    (
      builtin cd -q "$dir" || return 1
      eval "$ICE[ps-on-update]" &> /dev/null
    )
  }
} # ]]]
