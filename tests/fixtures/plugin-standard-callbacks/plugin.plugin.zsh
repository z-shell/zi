@zsh-plugin-run-on-unload \
  'builtin print -r -- "plugin-unload:first:$PWD:$#:${(j:,:)@}" >> "$ZI_CALLBACK_LOG"' \
  'builtin print -r -- "plugin-unload:second:$PWD:$#:${(j:,:)@}" >> "$ZI_CALLBACK_LOG"' \
  'return ${ZI_CALLBACK_UNLOAD_RETURN:-0}'

@zsh-plugin-run-on-update \
  'builtin print -r -- "plugin-update:first:$PWD:$#:${(j:,:)@}" >> "$ZI_CALLBACK_LOG"' \
  'builtin print -r -- "plugin-update:second:$PWD:$#:${(j:,:)@}" >> "$ZI_CALLBACK_LOG"' \
  'return ${ZI_CALLBACK_RETURN:-0}'
