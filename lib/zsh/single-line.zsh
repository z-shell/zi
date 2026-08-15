#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -R zsh ${=${options[xtrace]:#off}:+-o xtrace}
builtin setopt extended_glob warn_create_global typeset_silent no_short_loops rc_quotes

local zero=$'\0' r=$'\r' n=$'\n' IFS=
{ command perl -pe 'BEGIN { $|++; $/ = \1 }; tr/\r\n/\n\0/' || gstdbuf -o0 gtr '\r\n' '\n\0' || \
stdbuf -o0 tr '\r\n' '\n\0'; print } 2>/dev/null | while read -r line; do
  if [[ $line == *$zero* ]]; then
  # Unused by cURL (there's no newline after the previous progress bar) print -nr -- $r${(l:COLUMNS:: :):-}$r${line##*$zero}
    print -nr -- $r${(l:COLUMNS:: :):-}$r${line%$zero}
  else
    print -nr -- $r${(l:COLUMNS:: :):-}$r${${line//[$r$n]/}%\%*}${${(M)line%\%}:+%}
  fi
  done
print
