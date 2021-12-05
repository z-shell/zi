# Gallery Of Zi Invocations

PRs welcomed :)

## Programs

```zsh
# junegunn/fzf-bin
zi ice from"gh-r" as"program"
zi light junegunn/fzf-bin

# sharkdp/fd
zi ice as"command" from"gh-r" mv"fd* -> fd" pick"fd/fd"
zi light sharkdp/fd

# sharkdp/bat
zi ice as"command" from"gh-r" mv"bat* -> bat" pick"bat/bat"
zi light sharkdp/bat

# ogham/exa, replacement for ls
zi ice wait"2" lucid from"gh-r" as"program" mv"exa* -> exa"
zi light ogham/exa

# All of the above using the for-syntax and also z-a-bin-gem-node annex
zi wait"1" lucid from"gh-r" as"null" for \
  sbin"fzf" junegunn/fzf-bin \
  sbin"**/fd" @sharkdp/fd \
  sbin"**/bat" @sharkdp/bat \
  sbin"exa* -> exa" ogham/exa

zi ice from"gh-r" as"program" mv"docker* -> docker-compose"
zi light docker/compose

# jarun/nnn, a file browser, using the for-syntax
zi pick"misc/quitcd/quitcd.zsh" sbin make light-mode for jarun/nnn

zi ice as"program" atclone"rm -f src/auto/config.cache; ./configure" \
  atpull"%atclone" make pick"src/vim"
zi light vim/vim

zi ice as"program" make'!' atclone'./direnv hook zsh > zhook.zsh' \
  atpull'%atclone' src"zhook.zsh"
zi light direnv/direnv

zi ice from"gh-r" as"program" mv"direnv* -> direnv"
zi light direnv/direnv

zi ice from"gh-r" as"program" mv"shfmt* -> shfmt"
zi light mvdan/sh

zi ice from"gh-r" as"program" mv"gotcha_* -> gotcha"
zi light b4b4r07/gotcha

zi ice as"program" pick"yank" make
zi light mptre/yank

zi ice atclone'PYENV_ROOT="$PWD" ./libexec/pyenv init - > zpyenv.zsh' \
  atinit'export PYENV_ROOT="$PWD"' atpull"%atclone" \
  as'command' pick'bin/pyenv' src"zpyenv.zsh" nocompile'!'
zi light pyenv/pyenv

zi ice as"program" pick"$ZPFX/sdkman/bin/sdk" id-as'sdkman' run-atpull \
  atclone"wget https://get.sdkman.io/?rcupdate=false -O scr.sh; SDKMAN_DIR=$ZPFX/sdkman bash scr.sh" \
  atpull"SDKMAN_DIR=$ZPFX/sdkman sdk selfupdate" \
  atinit"export SDKMAN_DIR=$ZPFX/sdkman; source $ZPFX/sdkman/bin/sdkman-init.sh"
zi light z-shell/null

# asciinema
zi ice as"command" wait lucid \
  atinit"export PYTHONPATH=$ZPFX/lib/python3.7/site-packages/" \
  atclone"PYTHONPATH=$ZPFX/lib/python3.7/site-packages/ \
    python3 setup.py --quiet install --prefix $ZPFX" \
  atpull'%atclone' test'0' \
  pick"$ZPFX/bin/asciinema"
zi load asciinema/asciinema.git

# Installation of Rust compiler environment via the z-a-rust annex
zi id-as"rust" wait=1 as=null sbin="bin/*" lucid rustup \
  atload="[[ ! -f ${ZI[COMPLETIONS_DIR]}/_cargo ]] && zi creinstall -q rust; \
    export CARGO_HOME=\$PWD; export RUSTUP_HOME=\$PWD/rustup" for \
  z-shell/null
```

## Completions

```zsh
zi ice as"completion"
zi snippet https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker
```

## Scripts

```zsh
# ogham/exa also uses the definitions
zi ice wait"0c" lucid reset \
    atclone"local P=${${(M)OSTYPE:#*darwin*}:+g}
            \${P}sed -i \
            '/DIR/c\DIR 38;5;63;1' LS_COLORS; \
            \${P}dircolors -b LS_COLORS > c.zsh" \
    atpull'%atclone' pick"c.zsh" nocompile'!' \
    atload'zstyle ":completion:*" list-colors “${(s.:.)LS_COLORS}”'
zi light trapd00r/LS_COLORS

# revolver
zi ice wait"2" lucid as"program" pick"revolver"
zi light molovo/revolver

# zunit
zi ice wait"2" lucid as"program" pick"zunit" \
            atclone"./build.zsh" atpull"%atclone"
zi load molovo/zunit

zi ice as"program" pick"$ZPFX/bin/git-*" make"PREFIX=$ZPFX" nocompile
zi light tj/git-extras

zi ice as"program" atclone'perl Makefile.PL PREFIX=$ZPFX' \
    atpull'%atclone' make'install' pick"$ZPFX/bin/git-cal"
zi light k4rthik/git-cal

zi ice as"program" id-as"git-unique" pick"git-unique"
zi snippet https://github.com/Osse/git-scripts/blob/master/git-unique

zi ice as"program" cp"wd.sh -> wd" mv"_wd.sh -> _wd" \
    atpull'!git reset --hard' pick"wd"
zi light mfaerevaag/wd

zi ice as"program" pick"bin/archey"
zi load obihann/archey-osx
```

## Plugins

```zsh
zi ice pick"h.sh"
zi light paoloantinori/hhighlighter

# zsh-tag-search; after ^G, prepend with "/" for the regular search
zi ice wait lucid bindmap"^R -> ^G"
zi light -b z-shell/zsh-tag-search

# forgit
zi ice wait lucid
zi load 'wfxr/forgit'

# diff-so-fancy
zi ice wait"2" lucid as"program" pick"bin/git-dsf"
zi load z-shell/zsh-diff-so-fancy

# zsh-startify, a vim-startify like plugin
zi ice wait"0b" lucid atload"zsh-startify"
zi load z-shell/zsh-startify

# declare-zsh
zi ice wait"2" lucid
zi load z-shell/declare-zsh

# fzf-marks
zi ice wait lucid
zi load urbainvaes/fzf-marks

# zsh-autopair
zi ice wait lucid
zi load hlissner/zsh-autopair

zi ice wait"1" lucid
zi load z-shell/zsh-navigation-tools

# z-shell/history-search-multi-word
zstyle ":history-search-multi-word" page-size "11"
zi ice wait"1" lucid
zi load z-shell/history-search-multi-word

# ZUI and Crasis
zi ice wait"1" lucid
zi load z-shell/zui

zi ice wait'[[ -n ${ZLAST_COMMANDS[(r)cra*]} ]]' lucid
zi load z-shell/zi-crasis

# Gitignore plugin – commands gii and gi
zi ice wait"2" lucid
zi load voronkovich/gitignore.plugin.zsh

# Autosuggestions & fast-syntax-highlighting
zi ice wait lucid atinit"ZPLGM[COMPINIT_OPTS]=-C; zpcompinit; zpcdreplay"
zi light z-shell/fast-syntax-highlighting
# zsh-autosuggestions
zi ice wait lucid atload"!_zsh_autosuggest_start"
zi load zsh-users/zsh-autosuggestions

# F-Sy-H automatic per-directory themes plugin – available for patrons:
# https://patreon.com/psprint
zi ice wait"1" lucid from"psprint@gitlab.com"
zi load psprint/fsh-auto-themes

# zredis together with some binding/tying
# – defines the variable $rdhash
zstyle ":plugin:zredis" configure_opts "--without-tcsetpgrp"
zstyle ":plugin:zredis" cflags "-Wall -O2 -g -Wno-unused-but-set-variable"
zi ice wait"1" lucid \
  atload'ztie -d db/redis -a 127.0.0.1:4815/5 -zSL main rdhash'
zi load z-shell/zredis

# Github-Issue-Tracker – the notifier thread
zi ice lucid id-as"GitHub-notify" \
  on-update-of'~/.cache/zsh-github-issues/new_titles.log' \
  notify'New issue: $NOTIFY_MESSAGE'
zi light z-shell/zsh-github-issues
```

## Services

```zsh
# a service that runs the redis database, in background, single instance
zi ice wait"1" lucid service"redis"
zi light zservices/redis
```

```zsh
# Github-Issue-Tracker – the issue-puller thread
GIT_SLEEP_TIME=700
GIT_PROJECTS=z-shell/zsh-github-issues:z-shell/zi

zi ice wait"2" lucid service"GIT" pick"zsh-github-issues.service.zsh"
zi light z-shell/zsh-github-issues
```

## Snippets

```zsh
zi ice svn pick"completion.zsh" src"git.zsh"
zi snippet OMZ::lib

zi ice svn wait"0" lucid atinit"local ZSH=\$PWD" \
  atclone"mkdir -p plugins; cd plugins; ln -sfn ../. osx"
zi snippet OMZ::plugins/osx

# Or with most recent Zi and with ~/.zi/snippets
# directory pruned (rm -rf -- ${ZPLGM[SNIPPETS_DIR]}):
zi ice svn
zi snippet OMZ::plugins/osx
```

## Themes

```zsh
GEOMETRY_COLOR_DIR=152
zi ice wait"0" lucid atload"geometry::prompt"
zi light geometry-zsh/geometry

zi ice pick"async.zsh" src"pure.zsh"
zi light sindresorhus/pure

zi light mafredri/zsh-async # dependency
zi ice svn silent atload'prompt sorin'
zi snippet PZT::modules/prompt

zi ice atload"fpath+=( \$PWD );"
zi light chauncey-garrett/zsh-prompt-garrett
zi ice svn atload"prompt garrett" silent
zi snippet PZT::modules/prompt

zi ice wait'!' lucid nocompletions \
  compile"{zinc_functions/*,segments/*,zinc.zsh}" \
  atload'!prompt_zinc_setup; prompt_zinc_precmd'
zi load robobenklein/zinc

# ZINC git info is already async, but if you want it
# even faster with gitstatus in Turbo mode:
# https://github.com/romkatv/gitstatus
zi ice wait'1' atload'zinc_optional_depenency_loaded'
zi load romkatv/gitstatus

# p10k one-line
zi ice depth=1; zi light romkatv/powerlevel10k

# After finishing the configuration wizard for the last question:
# "Apply changes to ~/.zshrc?" choose no - unless you know what you're doing.
zi ice depth'1' atload'[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' nocd
zi light romkatv/powerlevel10k
```
