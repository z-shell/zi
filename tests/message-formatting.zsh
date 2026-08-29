#!/usr/bin/env zsh
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

builtin emulate -LR zsh
builtin setopt err_exit pipe_fail extended_glob

typeset project_root=${0:A:h:h}
typeset temp_root
temp_root=$(command mktemp -d "${TMPDIR:-/tmp}/zi-message-formatting.XXXXXXXX")
trap 'command rm -rf -- "$temp_root"' EXIT INT TERM

typeset -gx HOME=$temp_root/home
typeset -gx ZDOTDIR=$temp_root/zdotdir
typeset -gx XDG_CACHE_HOME=$temp_root/cache
typeset -gx XDG_CONFIG_HOME=$temp_root/config
typeset -gx XDG_DATA_HOME=$temp_root/data
command mkdir -p -- "$HOME" "$ZDOTDIR"

typeset -gAH ZI
ZI[BIN_DIR]=$project_root
builtin source "$project_root/zi.zsh" >/dev/null
builtin setopt err_exit pipe_fail extended_glob

fail() {
  builtin print -ru2 -- "not ok - $1"
  exit 1
}

pass() {
  builtin print -r -- "ok - $1"
}

assert_equal() {
  [[ $1 == "$2" ]] || fail "$3: expected ${(qqq)2}, got ${(qqq)1}"
}

assert_contains() {
  [[ $1 == *"$2"* ]] || fail "$3: ${(qqq)1} does not contain ${(qqq)2}"
}

assert_not_contains() {
  [[ $1 != *"$2"* ]] || fail "$3: ${(qqq)1} unexpectedly contains ${(qqq)2}"
}

strip_ansi() {
  REPLY=${1//$'\e'\[[0-9\;]#m/}
}

typeset sample output expected stdout_file stderr_file selected_file
integer command_status output_fd
stdout_file=$temp_root/stdout
stderr_file=$temp_root/stderr
selected_file=$temp_root/selected

sample=$'tabs\tremain  doubled\nnew line {unknown} 100% -leading Unicode: λ sentinel: ←→ control: \e[31m'
output=$(+zi-message -n --color=never -- "$sample")
assert_equal "$output" "$sample" 'safe auto preserves unstyled bytes'
pass 'safe auto preserves unstyled bytes'

output=$(+zi-message -n --color=never --literal -- '{error}literal{rst} {auto}load')
assert_equal "$output" '{error}literal{rst} {auto}load' 'literal mode bypasses markup and auto'
pass 'literal mode bypasses markup and auto'

output=$(+zi-message -n --color=never -- 'before {unknown} after')
assert_equal "$output" 'before {unknown} after' 'unknown tags remain literal'
pass 'unknown tags remain literal'

output=$(+zi-message -n --color=never -- $'{profile}I have been loaded{nl}{auto}`Zi Rocks ♥`')
assert_equal "$output" $'I have been loaded\n`Zi Rocks ♥`' 'existing wiki markup example'
pass 'existing documented markup remains compatible'

expected='See https://example.com/a-b?x=1#frag and ssh://user@example.com/repo; load --wait=1 in 1.5s with 42 and `two words`.'
output=$(+zi-message -n --color=always -- "$expected")
strip_ansi "$output"
assert_equal "$REPLY" "$expected" 'safe auto preserves recognized text'
assert_contains "$output" "${ZI[col-url]}https://example.com/a-b?x=1#frag${ZI[col-rst]}" 'HTTP URL style'
assert_contains "$output" "${ZI[col-url]}ssh://user@example.com/repo${ZI[col-rst]}" 'SSH URL style'
assert_contains "$output" "${ZI[col-cmd]}load${ZI[col-rst]}" 'Zi command style'
assert_contains "$output" "${ZI[col-ice]}--wait=1${ZI[col-rst]}" 'ice style'
assert_contains "$output" "${ZI[col-time]}1.5s${ZI[col-rst]}" 'duration style'
assert_contains "$output" "${ZI[col-num]}42${ZI[col-rst]}" 'number style'
assert_contains "$output" "${ZI[col-quo]}\`two words\`${ZI[col-rst]}" 'balanced quote style'
assert_not_contains "$output" "${ZI[col-rst]}${ZI[col-rst]}" 'redundant trailing reset'
pass 'safe auto recognizes deterministic forms'

expected='ambiguous owner/repo usr/bin 1..2 ... are plain'
output=$(+zi-message -n --color=always -- "$expected")
assert_equal "$output" "$expected" 'safe auto rejects ambiguous forms'
pass 'safe auto rejects ambiguous forms'

zi_message_test_function() { :; }
@zi-register-annex message-test subcommand:annexcmd message-test-handler '' annexice
command mkdir -p -- "${ZI[PLUGINS_DIR]}/owner---repo" "$temp_root/existing-path"
output=$(builtin cd -q -- "$temp_root" && +zi-message -n --color=always --auto=contextual -- 'print zi_message_test_function annexcmd --annexice=value owner/repo existing-path')
assert_contains "$output" "${ZI[col-bcmd]}print${ZI[col-rst]}" 'contextual command style'
assert_contains "$output" "${ZI[col-func]}zi_message_test_function${ZI[col-rst]}" 'contextual function style'
assert_contains "$output" "${ZI[col-cmd]}annexcmd${ZI[col-rst]}" 'contextual annex command style'
assert_contains "$output" "${ZI[col-ice]}--annexice=value${ZI[col-rst]}" 'contextual annex ice style'
assert_contains "$output" "${ZI[col-pname]}owner/repo${ZI[col-rst]}" 'contextual plugin style'
assert_contains "$output" "${ZI[col-file]}existing-path${ZI[col-rst]}" 'contextual path style'
pass 'contextual auto recognizes shell and filesystem forms'

output=$(+zi-message -n --color=always -- '{error}load{rst}')
assert_contains "$output" "${ZI[col-error]}load" 'explicit tag style'
assert_not_contains "$output" "${ZI[col-cmd]}load" 'explicit tag precedence'
output=$(+zi-message -n --color=always -- '{error}load{rst} update')
assert_contains "$output" "${ZI[col-cmd]}update${ZI[col-rst]}" 'reset resumes safe auto'
output=$(+zi-message -n --color=always -- '{no-auto}load {auto}update')
assert_not_contains "$output" "${ZI[col-cmd]}load${ZI[col-rst]}" 'inline no-auto mode'
assert_contains "$output" "${ZI[col-cmd]}update${ZI[col-rst]}" 'inline safe auto mode'
pass 'explicit tags take precedence over auto'

output=$(+zi-message -n --color=always --auto=off --level=error -- 'level message')
strip_ansi "$output"
assert_equal "$REPLY" 'level message' 'semantic level text'
assert_contains "$output" "$ZI[col-error]" 'semantic level style'
pass 'semantic levels preserve text and apply style'

typeset level level_style
typeset -A expected_level_styles=(
  debug dbg
  info info
  warn warn
  error error
  success happy
)
for level level_style in ${(kv)expected_level_styles}; do
  output=$(+zi-message -n --color=always --auto=off --level="$level" -- message)
  assert_contains "$output" "$ZI[col-$level_style]" "$level level style"
  strip_ansi "$output"
  assert_equal "$REPLY" message "$level level text"
done
output=$(+zi-message -n --color=always --auto=off --level=plain -- message)
assert_equal "$output" message 'plain level does not add a style'
pass 'all semantic levels have stable mappings'

zstyle ':zi:message' auto off
output=$(+zi-message -n --color=always -- load)
assert_equal "$output" load 'zstyle disables auto'
zstyle -d ':zi:message' auto
pass 'zstyle configures default auto mode'

zstyle ':zi:message' color never
output=$(+zi-message -n -- load)
assert_equal "$output" load 'zstyle disables color'
zstyle -d ':zi:message' color
pass 'zstyle configures default color mode'

zstyle ':zi:message' auto invalid
unsetopt err_exit
+zi-message message >| "$stdout_file" 2>| "$stderr_file"
command_status=$?
setopt err_exit
(( command_status == 2 )) || fail 'invalid zstyle auto mode did not return status 2'
zstyle -d ':zi:message' auto
zstyle ':zi:message' color invalid
unsetopt err_exit
+zi-message message >| "$stdout_file" 2>| "$stderr_file"
command_status=$?
setopt err_exit
(( command_status == 2 )) || fail 'invalid zstyle color mode did not return status 2'
zstyle -d ':zi:message' color
pass 'invalid zstyle modes fail explicitly'

typeset -gx NO_COLOR=1
output=$(+zi-message -n --color=auto -- load)
assert_equal "$output" load 'NO_COLOR disables automatic color'
output=$(+zi-message -n --color=always -- load)
assert_contains "$output" "$ZI[col-cmd]" 'explicit color overrides NO_COLOR'
unset NO_COLOR
pass 'color policy honors NO_COLOR and explicit override'

typeset saved_term=$TERM
typeset -gx TERM=dumb
output=$(+zi-message -n --color=auto -- load)
assert_equal "$output" load 'TERM dumb disables automatic color'
typeset -gx TERM=$saved_term
pass 'color policy honors TERM dumb'

output=$(
  TERM=xterm-color ZI_TEST_ROOT=$temp_root ZI_TEST_PROJECT=$project_root zsh -f <<'ZSH'
typeset -gx HOME=$ZI_TEST_ROOT/eight-home ZDOTDIR=$ZI_TEST_ROOT/eight-zdotdir
typeset -gx XDG_CACHE_HOME=$ZI_TEST_ROOT/eight-cache XDG_CONFIG_HOME=$ZI_TEST_ROOT/eight-config XDG_DATA_HOME=$ZI_TEST_ROOT/eight-data
command mkdir -p -- "$HOME" "$ZDOTDIR"
typeset -gAH ZI
ZI[BIN_DIR]=$ZI_TEST_PROJECT
builtin source "$ZI_TEST_PROJECT/zi.zsh" >/dev/null
typeset key
for key in ${(k)ZI}; do
  [[ $key == col-* && ${ZI[$key]} == *'38;5'* ]] && builtin print -r -- "$key=${ZI[$key]}"
done
builtin true
ZSH
)
assert_equal "$output" '' 'eight-color palette has no 256-color sequences'
output=$(
  TERM=xterm-256color ZI_TEST_ROOT=$temp_root ZI_TEST_PROJECT=$project_root zsh -f <<'ZSH'
typeset -gx HOME=$ZI_TEST_ROOT/full-home ZDOTDIR=$ZI_TEST_ROOT/full-zdotdir
typeset -gx XDG_CACHE_HOME=$ZI_TEST_ROOT/full-cache XDG_CONFIG_HOME=$ZI_TEST_ROOT/full-config XDG_DATA_HOME=$ZI_TEST_ROOT/full-data
command mkdir -p -- "$HOME" "$ZDOTDIR"
typeset -gAH ZI
ZI[BIN_DIR]=$ZI_TEST_PROJECT
builtin source "$ZI_TEST_PROJECT/zi.zsh" >/dev/null
builtin print -rn -- "$ZI[col-url]"
ZSH
)
assert_contains "$output" '38;5' '256-color palette'
pass 'palette follows terminal color capability'

output=$(
  SOURCED=1 TERM=xterm-256color ZI_TEST_ROOT=$temp_root ZI_TEST_PROJECT=$project_root zsh -f <<'ZSH'
typeset -gx HOME=$ZI_TEST_ROOT/sourced-home ZDOTDIR=$ZI_TEST_ROOT/sourced-zdotdir
typeset -gx XDG_CACHE_HOME=$ZI_TEST_ROOT/sourced-cache XDG_CONFIG_HOME=$ZI_TEST_ROOT/sourced-config XDG_DATA_HOME=$ZI_TEST_ROOT/sourced-data
command mkdir -p -- "$HOME" "$ZDOTDIR"
typeset -gAH ZI
ZI[BIN_DIR]=$ZI_TEST_PROJECT
builtin source "$ZI_TEST_PROJECT/zi.zsh" >/dev/null
builtin print -r -- "legacy=${ZI[col-url]-}"
+zi-message -n --color=always --auto=off -- '{url}https://example.com{rst}'
ZSH
)
assert_equal "${${(f)output}[1]}" 'legacy=' 'SOURCED suppresses the legacy public palette'
assert_contains "${${(f)output}[2]}" $'\e[' 'explicit color uses the private message palette'
pass 'SOURCED compatibility does not weaken explicit message color'

output=$(
  TERM=xterm-256color ZI_TEST_ROOT=$temp_root ZI_TEST_PROJECT=$project_root zsh -f <<'ZSH'
typeset -gx HOME=$ZI_TEST_ROOT/custom-home ZDOTDIR=$ZI_TEST_ROOT/custom-zdotdir
typeset -gx XDG_CACHE_HOME=$ZI_TEST_ROOT/custom-cache XDG_CONFIG_HOME=$ZI_TEST_ROOT/custom-config XDG_DATA_HOME=$ZI_TEST_ROOT/custom-data
command mkdir -p -- "$HOME" "$ZDOTDIR"
typeset -gAH ZI
ZI[BIN_DIR]=$ZI_TEST_PROJECT
ZI[col-url]='custom-url-color'
builtin source "$ZI_TEST_PROJECT/zi.zsh" >/dev/null
builtin print -r -- "$ZI[col-url]"
builtin print -r -- "$ZI[col-error]"
ZSH
)
assert_equal "${${(f)output}[1]}" 'custom-url-color' 'partial palette customization'
assert_contains "${${(f)output}[2]}" $'\e[' 'missing palette entries initialized'
pass 'partial palette customization is preserved and completed'

typeset saved_url_color=$ZI[col-url]
ZI[col-url]='custom-url-color'
builtin source "$project_root/zi.zsh" >/dev/null
assert_equal "$ZI[col-url]" 'custom-url-color' 'reload preserves customized palette'
ZI[col-url]=$saved_url_color
builtin setopt err_exit pipe_fail extended_glob
pass 'reload preserves customized palette'

exec {output_fd}>| "$selected_file"
+zi-message -u "$output_fd" --color=never -- 'selected descriptor' >| "$stdout_file" 2>| "$stderr_file"
exec {output_fd}>&-
assert_equal "$(<"$selected_file")" 'selected descriptor' 'selected descriptor content'
[[ ! -s $stdout_file ]] || fail 'selected descriptor leaked to stdout'
[[ ! -s $stderr_file ]] || fail 'selected descriptor wrote to stderr'
pass 'output and newline use only the selected descriptor'

unsetopt err_exit
+zi-message -u 999 --color=never -- invalid >| "$stdout_file" 2>| "$stderr_file"
command_status=$?
setopt err_exit
(( command_status != 0 )) || fail 'invalid descriptor returned success'
[[ ! -s $stdout_file ]] || fail 'invalid descriptor wrote to stdout'
pass 'invalid descriptors return failure'

unset zi_message_option_target
unsetopt err_exit
+zi-message -vzi_message_option_target value >| "$stdout_file" 2>| "$stderr_file"
command_status=$?
setopt err_exit
(( command_status == 2 )) || fail 'invalid option did not return status 2'
(( ! ${+parameters[zi_message_option_target]} )) || fail 'invalid option created a parameter'
pass 'strict option parsing prevents print option injection'

output=$(+zi-message -n --color=never -- 'literal %F{red} percent')
assert_equal "$output" 'literal %F{red} percent' 'percent text remains literal'
output=$(+zi-message -n --color=never -- -leading)
assert_equal "$output" -leading 'option boundary preserves leading hyphen'
pass 'literal output does not perform prompt expansion'

+zi-message --color=never -- message >| "$stdout_file"
assert_equal "$(command od -An -tx1 -v "$stdout_file" | tr -d ' \n')" 6d6573736167650a 'ordinary message terminator'
+zi-progress --color=never -- message >| "$stdout_file"
assert_equal "$(command od -An -tx1 -v "$stdout_file" | tr -d ' \n')" 6d6573736167650d 'progress terminator'
pass 'message and progress terminators are separated'

typeset saved_columns=$COLUMNS
integer COLUMNS=1
output=$(+zi-message -n --color=always --auto=off -- '{bar}X')
assert_contains "$output" "${ZI[col-bar]}${ZI[col-rst]}X" 'zero-width bar resets before following text'
strip_ansi "$output"
assert_equal "$REPLY" X 'zero-width bar text'
integer COLUMNS=$saved_columns
pass 'structural tags remain structural with empty output'

output=$(+zi-message -n -l --color=never -- one two three)
assert_equal "$output" $'one\ntwo\nthree' 'line mode'
pass 'line mode preserves argument boundaries'

typeset before_directory=$PWD
typeset -g REPLY='caller reply'
typeset -g MATCH='caller match'
typeset -ga match=( 'caller match array' )
unset 'ZI[__last-formatter-code]'
() {
  builtin emulate -L zsh
  setopt ksh_arrays sh_word_split no_rc_quotes
  typeset hostile_options=${(j:,:)${(ok)options}}
  +zi-message -n --color=never -- 'caller state' >| "$stdout_file"
  assert_equal "${(j:,:)${(ok)options}}" "$hostile_options" 'hostile options restored'
  assert_equal "$PWD" "$before_directory" 'working directory restored'
  assert_equal "$REPLY" 'caller reply' 'caller REPLY restored'
  assert_equal "$MATCH" 'caller match' 'caller MATCH restored'
  assert_equal "${(j: :)match}" 'caller match array' 'caller match array restored'
  (( ! ${+ZI[__last-formatter-code]} )) || fail 'global formatter scratch was created'
}
pass 'caller state is preserved'

if [[ ${ZI_MESSAGE_BENCHMARK:-0} == 1 ]]; then
  zmodload zsh/datetime
  typeset payload='Zi update --wait=1 from https://example.com/a-b?x=1#frag in 1.5s, then load `tree`.'
  integer iterations=1000 index
  float started=$EPOCHREALTIME elapsed microseconds_per_call
  for (( index = 1; index <= iterations; ++index )); do
    +zi-message -n --color=always -- "$payload" >/dev/null
  done
  elapsed=$(( EPOCHREALTIME - started ))
  microseconds_per_call=$(( elapsed * 1000000.0 / iterations ))
  (( microseconds_per_call < 1000.0 )) || fail "safe auto benchmark exceeded 1 ms: $microseconds_per_call us"
  builtin printf 'ok - safe auto benchmark: %.1f us per call\n' $microseconds_per_call
fi
