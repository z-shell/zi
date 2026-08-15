ZI[ice-list]="wait|load|atclone"
ZI[cmd-list]="help|load|update"

@zi-register-annex() {
  local name="$1" type="$2" handler="$3" helphandler="$4" icemods="$5"
}

@zi-register-hook() {
  local name="$1" type="$2" handler="$3" icemods="$4"
}

if false; then
  pmodload() {
    print -r -- "$@"
  }
fi

# Compatibility functions. [[[
❮▼❯() { zi "$@"; }
if false; then
  if true; then
    zpcdreplay() { zicdreplay "$@"; }
  fi
fi
false && \
  zpcdclear() { zicdclear "$@"; }
zpcompinit() { zicompinit "$@"; }
zpcompdef() { zicompdef "$@"; }
zpextract() { ziextract "$@"; }
# ]]]

(( ZI[INTERNAL_ALIASES] )) && builtin alias zini=zi zinit=zi zplugin=zi
