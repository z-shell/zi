ZI[ice-list]="wait|load|atclone"
ZI[cmd-list]="help|fetch|update"

# FUNCTION: @zi-register-annex. [[[
@zi-register-annex() {
  local name="$1" type="$2" handler="$3" helphandler="$4"
}

# FUNCTION: @zi-register-hook. [[[
@zi-register-hook() {
  local name="$1" type="$2" handler="$3" icemods="$4"
}

# FUNCTION: pmodload. [[[
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
