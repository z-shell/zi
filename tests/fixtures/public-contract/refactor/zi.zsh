# A comment mentioning fake() and ZI[cmd-list]="removed" is not a contract.
ZI[ice-list]="atclone|\
    wait|load"
ZI[cmd-list]="update|help|\
      load"

@zi-register-annex () {
  # $99 in a comment must not narrow or widen the signature.
  local name="$1"
  local type="$2" handler="$3"
  local helphandler="$4" icemods="$5"
}

@zi-register-hook() {
  local name="$1"
  local type="$2"
  local handler="$3"
  local icemods="$4"
}

(( ${+functions[pmodload]} )) || pmodload () {
  print -r -- "$@"
}

# Compatibility functions. [[[
❮▼❯ () { zi "$@"; }
zpcdreplay () { zicdreplay "$@"; }
zpcdclear () { zicdclear "$@"; }
zpcompinit () { zicompinit "$@"; }
zpcompdef () { zicompdef "$@"; }
zpextract () { ziextract "$@"; }
# fake-compat() { :; }
# ]]]

internal_helper() { :; }
(( ZI[INTERNAL_ALIASES] )) &&
  builtin alias zplugin=zi zini=zi zinit=zi
