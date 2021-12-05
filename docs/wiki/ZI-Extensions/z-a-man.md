## Introduction

A ZI [extension](../Annexes/) that automatically generates:

- man pages for all plugins and snippets (out of plugin README.md files by
  using [ronn](https://github.com/rtomayko/ronn) converter),
- code-documentation manpages (by using
  [zshelldoc](https://github.com/z-shell/zshelldoc) project).

Man extension is being activated at clone of a plugin and also at update of it
and it then generates the manpages. To view them there's a `zman` command:

```zsh
# View README.md manpage in the terminal
zman z-a-man
# View the code documentation (via the full plugin name, as demonstrated)
zman -c z-shell/z-a-man
```

## Examples

Main manual (of the project):

![README](https://raw.githubusercontent.com/z-shell/z-a-man/main/images/zman-readme.png)

Code documentation for the plugin.zsh file (of the project):

![Code documentation](https://raw.githubusercontent.com/z-shell/z-a-man/main/images/zman-cd.png)

## Installation

Simply load like any other plugin, i.e.: the following command will install the
extension within ZI:

```zsh
zi light z-shell/z-a-man
```
