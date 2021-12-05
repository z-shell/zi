## Introduction

An annex (i.e. an extension for ZI – [more information](../Annexes/))
that allows ZI to clone additional submodules when installing a plugin or
snippet. The submodules are then automatically updated on the `zi update …`
command.

This annex adds `submods''` ice to ZI which has the following syntax:

```zsh
submods'{user}/{plugin} -> {output directory}; …'
```

An example command utilizing the annex and its ice:

```zsh
# Load zsh-autosuggestions plugin via Prezto module: autosuggestions
zi ice svn submods'zsh-users/zsh-autosuggestions -> external'
zi snippet PZT::modules/autosuggestions
```

![screenshot](img/z-p-submods.png)

## Installation

Simply load as a plugin. The following command will install the annex within
ZI:

```zsh
zi light z-shell/z-a-submods
```

After executing this command you can then use the `submods''` ice. The command
should be placed in `~/.zshrc`.
