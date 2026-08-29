@zsh-plugin-run-on-unload \
  'builtin print -r -- "snippet-unload:first:$PWD:$#:${(j:,:)@}" >> "$ZI_CALLBACK_LOG"' \
  'builtin print -r -- "snippet-unload:second:$PWD:$#:${(j:,:)@}" >> "$ZI_CALLBACK_LOG"' \
  'return ${ZI_CALLBACK_UNLOAD_RETURN:-0}'

@zsh-plugin-run-on-update \
  'builtin print -r -- "snippet-update:first:$PWD:$#:${(j:,:)@}" >> "$ZI_CALLBACK_LOG"' \
  'builtin print -r -- "snippet-update:second:$PWD:$#:${(j:,:)@}" >> "$ZI_CALLBACK_LOG"' \
  'return ${ZI_CALLBACK_RETURN:-0}'
