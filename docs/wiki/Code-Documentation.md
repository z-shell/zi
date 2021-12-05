# Code documentation

Here are `4` ZI's source files, the main one is zi.zsh. The documentation lists all functions,
interactions between them, their comments and features used.

- [zi.zsh](zi.zsh) ([**pdf**](https://github.com/z-shell/wiki/raw/main/pdf/zi.zsh.pdf)) - always loaded, in `.zshrc`
- [lib/zsh/side.zsh](side.zsh) ([**pdf**](https://github.com/z-shell/wiki/raw/main/pdf/side.zsh.pdf)) - functions, loaded by `*install` and `*autoload` scripts
- [lib/zsh/install.zsh](install.zsh) ([**pdf**](https://github.com/z-shell/wiki/raw/main/pdf/install.zsh.pdf)) - functions used only when installing a plugin or snippet
- [lib/zsh/autoload.zsh](autoload.zsh) ([**pdf**](https://github.com/z-shell/wiki/raw/main/pdf/autoload.zsh.pdf)) - functions used only in interactive `ZI` invocations

## PDFs, man pages, etc.

Formats other than `Asciidoc` can be produced by using provided Makefile. For example, issuing
`make pdf` will create and populate a new directory `pdf` (requires `asciidoctor`, install with
`gem install asciidoctor-pdf --pre`). `make man` will create man pages (requires package `asciidoc`,
uses its command `a2x`, which is quite slow).
