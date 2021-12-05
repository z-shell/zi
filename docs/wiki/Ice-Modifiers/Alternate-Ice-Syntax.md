# Alternate Ice Syntax

## The Standard Syntax

The normal way of specifying ices and their values is by concatenating the ice
name and its value quoted, i.e.:

```zsh
zi wait"1" from"gh-r" atload"print Hello World"
zi load …
```

(note that there's no `ice` subcommand - that is currently being fully allowed)

## The Alternative Syntaxes

However, ZI supports also other syntaxes: the equal (`=`) syntax:

```zsh
zi wait=1 from=gh-r atload="print Hello World"
zi load …
```

the colon (`:`) syntax:

```zsh
zi wait:1 from:gh-r atload:"print Hello World"
zi load …
```

and also – with conjunction with all of the above – the GNU syntax:

```zsh
zi --wait=1 --from=gh-r --atload="print Hello World"
zi load …
```

## Summary

It's up to the user which syntax to choose. The original motivation behind the
standard syntax was: to utilize the syntax highlighting of editors like Vim –
and have the strings following ice names colorized with a distinct color and
this way separated from them. However, with the
[zi/zi-vim-syntax](https://github.com/z-shell/zi-vim-syntax)
syntax definition this motivation can be superseded with the ZI-specific
highlighting, at least for Vim. NOTE: the Vim syntax doesn't yet support the
alternate syntaxes, it will soon (PR welcomed).
