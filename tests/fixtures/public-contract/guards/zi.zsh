ZI[ice-list]="wait|load|atclone"
ZI[cmd-list]="help|load|update"

# FUNCTION: @zi-register-annex. [[[
false && {
  @zi-register-annex() {
    local name="$1" type="$2" handler="$3" helphandler="$4" icemods="$5"
  }
}

# FUNCTION: @zi-register-hook. [[[
true || @zi-register-hook() {
  local name="$1" type="$2" handler="$3" icemods="$4"
}

# FUNCTION: pmodload. [[[
true || pmodload() {
  print -r -- "$@"
}

# Compatibility functions. [[[
❮▼❯() { zi "$@"; }
true || zpcdreplay() { zicdreplay "$@"; }
false && {
  zpcdclear() { zicdclear "$@"; }
}
custom_guard || zpcompinit() { zicompinit "$@"; }
zpcompdef() { zicompdef "$@"; }
zpextract() { ziextract "$@"; }
# ]]]

(( ZI[INTERNAL_ALIASES] )) && builtin alias zini=zi zinit=zi zplugin=zi
