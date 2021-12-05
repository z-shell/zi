## Using Turbo mode and for-syntax

```zsh
# A.
setopt promptsubst

# B.
zi wait lucid for \
  OMZL::git.zsh \
  atload"unalias grv" \
  OMZP::git

PS1="READY >" # provide a simple prompt till the theme loads

# C.
zi wait'!' lucid for \
  OMZL::prompt_info_functions.zsh \
  OMZT::gnzh

# D.
zi wait lucid for \
  atinit"zicompinit; zicdreplay" \
  z-shell/fast-syntax-highlighting \
  OMZP::colored-man-pages \
  as"completion" \
  OMZP::docker/_docker
```

**A** - Most themes use this option.

**B** - OMZ themes use this library and some other use also the plugin. It
provides many aliases – `atload''` shows how to disable some of them (e.g.: to
use program `rgburke/grv`).

**C** - Set OMZ theme. Loaded separately because the theme needs the `!` passed
to the `wait` ice to reset the prompt after loading the snippet in Turbo.

**D** - Some plugins: a) syntax-highlighting, loaded possibly early for a
better user experience), b) example functional plugin, c) Docker
completion.

Above setup loads everything after prompt, because of preceding `wait` ice. That
is called **Turbo mode**, it shortens Zsh startup time by <u>50%-80%</u>, so
e.g. instead of 200 ms, it'll be getting your shell started up after **40 ms**
(!).

It is using the for-syntax, which is a recent addition to ZI and it's
described in detail [on this page](https://z-shell.github.io/zi/wiki/For-Syntax/).

## Without using Turbo and for-syntax

The same setup using the classic syntax and without Turbo mode (prompt will be
initially set like in typical, normal setup – **you can remove `wait` only from
the theme plugin** and its dependencies to have the same effect while still
using Turbo for everything remaining):

```zsh
# A.
setopt promptsubst

# B.
zi snippet OMZL::git.zsh

# C.
zi ice atload"unalias grv"
zi snippet OMZP::git

# D.
zi for OMZL::prompt_info_functions.zsh OMZT::gnzh

# E.
zi snippet OMZP::colored-man-pages

# F.
zi ice as"completion"
zi snippet OMZP::docker/_docker

# G.
zi ice atinit"zicompinit; zicdreplay"
zi light z-shell/fast-syntax-highlighting
```

In general, Turbo can be optionally enabled only for a subset of plugins or for
all plugins. It needs Zsh \>= 5.3.

The **Introduction** contains [**more
information**](http://z-shell.github.io/zi/wiki/INTRODUCTION/#turbo_mode_zsh_62_53)
on Turbo.
