ZI[ice-list]="wait|load|\
  atclone"
ZI[cmd-list]="help|load|\
  update"

# FUNCTION: @zi-register-annex. [[[
@zi-register-annex() {
  local name="$1" type="$2" handler="$3" helphandler="$4" icemods="$5"
}

# FUNCTION: @zi-register-hook. [[[
@zi-register-hook() {
  local name="$1" type="$2" handler="$3" icemods="$4"
}

# FUNCTION: +zi-message. [[[
+zi-message() {
  print -r -- "$@"
}

# FUNCTION: +zi-progress. [[[
+zi-progress() {
  print -r -- "$@"
}

# FUNCTION: pmodload. [[[
(( ${+functions[pmodload]} )) || pmodload() {
  print -r -- "$@"
}

# Compatibility functions. [[[
❮▼❯() { zi "$@"; }
zpcdreplay() { zicdreplay "$@"; }
zpcdclear() { zicdclear "$@"; }
zpcompinit() { zicompinit "$@"; }
zpcompdef() { zicompdef "$@"; }
zpextract() { ziextract "$@"; }
# ]]]

(( ZI[INTERNAL_ALIASES] )) && builtin alias zini=zi zinit=zi zplugin=zi
