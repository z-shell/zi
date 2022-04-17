#!/usr/bin/env zsh
# -*- mode: sh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
#
# Copyright (c) YEAR USER_NAME
#
# An example of type-agnostic script/function, i.e.: the file can be run as a +x
# script or as an autoload function. Set the base and typically useful options
emulate -LR zsh
setopt extendedglob warncreateglobal typesetsilent noshortloops rcquotes
# Run as script? ZSH_SCRIPT is a Zsh 5.3 addition
if [[ $0 != example-script || -n $ZSH_SCRIPT ]]; then
# #̶ =̶=̶=̶ =̶=̶=̶ =̶=̶=̶ #̶
# 𝟘 - https://z.digitalclouds.dev/community/zsh_plugin_standard
# Standardized $0 Handling - [ zero-handling ]
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"
# #̶ =̶=̶=̶ =̶=̶=̶ =̶=̶=̶ #̶
# 𝟙 - # https://z.digitalclouds.dev/community/zsh_plugin_standard#funtions-directory
# The below snippet added to the plugin.zsh file will add the directory
# to the $fpath with the compatibility with any new plugin managers preserved.
if [[ $PMSPEC != *f* ]] {
  fpath+=( "${0:h}/functions" )
}
# #̶ =̶=̶=̶ =̶=̶=̶ =̶=̶=̶ #̶
# 𝟚 - # https://z.digitalclouds.dev/community/zsh_plugin_standard#unload-function
# If a plugin is named kalc* and is available via any-user/kalc_plugin_ID,
# then it can provide a function, kalc_plugin_unload, that can be called by a
# plugin manager to undo the effects of loading that plugin.
# #̶ =̶=̶=̶ =̶=̶=̶ =̶=̶=̶ #̶
# 𝟛 - https://z.digitalclouds.dev/community/zsh_plugin_standard#run-on-unload-call
# RUN ON UNLOAD CALL
# #̶ =̶=̶=̶ =̶=̶=̶ =̶=̶=̶ #̶
# 𝟜 - https://z.digitalclouds.dev/community/zsh_plugin_standard#run-on-update-call
# RUN ON UPDATE CALL
# #̶ =̶=̶=̶ =̶=̶=̶ =̶=̶=̶ #̶
# 𝟝 - https://z.digitalclouds.dev/community/zsh_plugin_standard#activity-indicator
# ZI will set the $zsh_loaded_plugins array to contain all previously loaded plugins
# and the plugin currently being loaded, as the last element.
if [[ ${zsh_loaded_plugins[-1]} != */kalc && -z ${fpath[(r)${0:h}]} ]] {
  fpath+=( "${0:h}" )
}
# #̶ =̶=̶=̶ =̶=̶=̶ =̶=̶=̶ #̶
# 𝟞 - https://z.digitalclouds.dev/community/zsh_plugin_standard#global-parameter-with-prefix
# Global Parameter With PREFIX For Make, Configure, Etc
# #̶ =̶=̶=̶ =̶=̶=̶ =̶=̶=̶ #̶
# 𝟟 - https://z.digitalclouds.dev/community/zsh_plugin_standard#global-parameter-with-capabilities
# PMSPEC
# #̶ =̶=̶=̶ =̶=̶=̶ =̶=̶=̶ #̶
# 𝟠 - https://z.digitalclouds.dev/community/zsh_plugin_standard#zsh-plugin-programming-best-practices
# Zsh Plugin-Programming Best practices
# #̶ =̶=̶=̶ =̶=̶=̶ =̶=̶=̶ #̶
# Such global variable is expected to be typeset'd -g in the plugin.zsh
# file. Here it's restored in case of the function being run as a script.
typeset -gA Plugins
Plugins[MY_PLUGIN_DIR]=${0:h}
# In case of the script using other scripts from the plugin, either set up
# $fpath and autoload, or add the directory to $PATH.
fpath+=( $Plugins[MY_PLUGIN_DIR] )
autoload …
# OR
path+=( $Plugins[MY_PLUGIN_DIR] )
fi
# The script/function contents possibly using $Plugins[MY_PLUGIN_DIR] …
# …
# Use alternate marks [[[ and ]]] as the original ones can confuse nested
# substitutions, e.g.: ${${${VAR}}}
#
# Made with love by Z-Shell Community
#
# vim:ft=zsh:tw=120:sw=2:sts=2:et:foldmarker=[[[,]]]
