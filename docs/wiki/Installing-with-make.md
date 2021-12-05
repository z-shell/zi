```zsh
zi ice as"program" pick"$ZPFX/bin/git-*" make"PREFIX=$ZPFX"
zi light tj/git-extras
```

- `Makefile` of this project has only one needed target – `install`, which is called by default,
- it also does building of the scripts that it installs, so it does 2 tasks,
- for `Makefile` with 2 targets, one could use `make"all install PREFIX=…"`,
- `pick'…'` will `chmod +x` all matching files and add `$ZPFX/bin/` to `$PATH`,
- `$ZPFX` is provided by ZI, it is `~/.zi/polaris` by default, can be also customized.
