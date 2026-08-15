ZI[ice-list]="wait|load|atclone"
ZI[cmd-list]="help|fetch|update"

@zi-register-annex() {
  local name="$1" type="$2" handler="$3" helphandler="$4"
}

@zi-register-hook() {
  local name="$1" type="$2" handler="$3" icemods="$4"
}

(( ${+functions[pmodload]} )) || pmodload() {
  print -r -- "$@"
}

# Compatibility functions. [[[
❮▼❯() { zi "$@"; }
zpcdreplay() { zicdreplay "$@"; }
zpcompinit() { zicompinit "$@"; }
zpcompdef() { zicompdef "$@"; }
zpextract() { ziextract "$@"; }
# ]]]

(( ZI[INTERNAL_ALIASES] )) && builtin alias zini=zi zinit=zi
