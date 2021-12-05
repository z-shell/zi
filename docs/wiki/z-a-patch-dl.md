## Introduction

A Zsh-ZI extension (i.e. an
[annex](../Annexes/)) that downloads files and
applies patches. It adds two ice modifiers:

```zsh
zi ice dl'{URL} [-> {optional-output-file-name}]; …' …
```

and

```zsh
zi ice patch'{file-name-with-the-patch-to-apply}; …' …
```

The annex (i.e. ZI extension) will download the given `{URL}` under the
path `{optional-output-file-name}` (if no file name given, then it is taken from
last segment of the URL) in case of the `dl''` ice-mod, and apply a patch given
by the `{file-name-with-the-patch-to-apply}` in case of the `patch''` ice-mod.

You can use this functionality to download and apply patches. For example, to
install `fbterm`, two patches are being needed, one to fix the operation, the
other one to fix the build:

```zsn
zi ice \
    as"command" pick"$ZPFX/bin/fbterm" \
    dl"https://bugs.archlinux.org/task/46860?getfile=13513 -> ins.patch" \
    dl"https://aur.archlinux.org/cgit/aur.git/plain/0001-Fix-build-with-gcc-6.patch?h=fbterm-git" \
    patch"ins.patch; 0001-Fix-build-with-gcc-6.patch" \
    atclone"./configure --prefix=$ZPFX" \
    atpull"%atclone" \
    make"install" reset
zi load izmntuk/fbterm
```

This command will result in:

![fbterm
example](https://raw.githubusercontent.com/z-shell/z-a-patch-dl/main/images/fbterm-ex.png)

## Installation

Simply load like a plugin, i.e. the following will add the annex to ZI:

```zsh
zi light z-shell/z-a-patch-dl
```

After executing this command you can then use the `dl''` and `patch''` ice-mods.
