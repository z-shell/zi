# Code documentation

Here is `Asciidoc` code documentation generated using [Zshelldoc](https://github.com/z-shell/zshelldoc).
There are `4` ZI's source files, the main one is [zinit.zsh](zinit.zsh.adoc). The documentation
lists all functions, interactions between them, their comments and features used.

Github allows to directly view `Asciidoc` documents:

- [zinit.zsh](zinit.zsh.adoc) – always loaded, in `.zshrc` ([pdf](https://z-shell.github.io/zi/wiki/zinit.zsh))
- [side.zsh](side.zsh.adoc) – common functions, loaded by `*-install` and `*-autoload` scripts ([pdf](https://z-shell.github.io/zi/wiki/side.zsh))
- [install.zsh](install.zsh.adoc) – functions used only when installing a plugin or snippet ([pdf](https://z-shell.github.io/zi/wiki/install.zsh))
- [autoload.zsh](autoload.zsh.adoc) – functions used only in interactive `ZI` invocations ([pdf](https://z-shell.github.io/zi/wiki/autoload.zsh/))

# PDFs, man pages, etc.

Formats other than `Asciidoc` can be produced by using provided Makefile. For example, issuing
`make pdf` will create and populate a new directory `pdf` (requires `asciidoctor`, install with
`gem install asciidoctor-pdf --pre`). `make man` will create man pages (requires package `asciidoc`,
uses its command `a2x`, which is quite slow).
