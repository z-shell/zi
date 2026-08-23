<p align="center">
  <img src="docs/images/logo.svg" alt="Zi logo" width="96" height="96">
</p>

<h1 align="center">Zi</h1>

<p align="center">
  <strong>A high-performance plugin manager and toolkit for Zsh.</strong>
</p>

<p align="center">
  Install plugins, snippets, completions, themes, and command-line tools with precise control over how they are
  downloaded, configured, and loaded.
</p>

<p align="center">
  <a href="https://github.com/z-shell/zi/releases"><img src="https://img.shields.io/github/v/release/z-shell/zi?display_name=tag&sort=semver" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/z-shell/zi" alt="MIT License"></a>
  <a href="https://www.zsh.org/"><img src="https://img.shields.io/badge/shell-Zsh-1f6feb" alt="Zsh"></a>
</p>

<p align="center">
  <a href="#quick-start"><strong>Quick start</strong></a>
  &nbsp;&middot;&nbsp;
  <a href="https://wiki.zshell.dev/"><strong>Documentation</strong></a>
  &nbsp;&middot;&nbsp;
  <a href="https://github.com/z-shell/zi/releases"><strong>Releases</strong></a>
  &nbsp;&middot;&nbsp;
  <a href="https://github.com/orgs/z-shell/discussions"><strong>Discussions</strong></a>
</p>

Zi is the Z-Shell ecosystem's plugin manager. It can source a single remote
script, manage a complete plugin, install a binary release, run build steps, or
defer work until after the first prompt. Zi was formerly known as zplugin and
zinit.

## Built for real Zsh setups

| Capability             | What it gives you                                                                                             |
| :--------------------- | :------------------------------------------------------------------------------------------------------------ |
| **Responsive startup** | Turbo mode defers plugin work until after the prompt without giving up declarative configuration.             |
| **Flexible sources**   | Load Git repositories, standalone scripts, Oh My Zsh and Prezto snippets, completions, and release artifacts. |
| **Precise control**    | Ice modifiers describe download, build, selection, loading, and update behavior for each dependency.          |
| **Tool management**    | Install command-line tools and packages without root access, then expose them through your shell environment. |
| **Extensible design**  | Annexes add focused capabilities without expanding the core into a monolith.                                  |

## Quick start

### 1. Install Zi

Run the minimal installer. It downloads Zi and adds the minimal setup to your
`.zshrc`:

```sh
sh -c "$(curl -fsSL get.zshell.dev)" --
```

> Review the
> [installer source](https://raw.githubusercontent.com/z-shell/src/main/public/sh/install.sh)
> and its published [SHA-256 checksum](https://raw.githubusercontent.com/z-shell/src/main/public/checksum.txt)
> before running a remote installation script.

### 2. Add your first plugins

Add Zi commands to `.zshrc`. This example loads an Oh My Zsh snippet, command
suggestions, and fast syntax highlighting:

```zsh
# ~/.zshrc
zi snippet OMZ::plugins/git/git.plugin.zsh
zi light zsh-users/zsh-autosuggestions
zi light z-shell/F-Sy-H
```

`snippet` loads a standalone script. `light` loads a plugin without tracking
and reporting overhead.

### 3. Reload Zsh

```zsh
exec zsh -il
```

Run `zi -h` to explore the available commands. For alternate installers,
manual setup, completions, and post-install steps, see the full
[installation guide](https://wiki.zshell.dev/docs/getting_started/installation/).

## Learn by task

| I want to...                                     | Read...                                                                    |
| :----------------------------------------------- | :------------------------------------------------------------------------- |
| Understand plugin and snippet loading            | [General overview](https://wiki.zshell.dev/docs/getting_started/overview/) |
| Control how a dependency is installed and loaded | [Ice modifiers](https://wiki.zshell.dev/docs/guides/syntax/ice-modifiers/) |
| Customize Zi paths and behavior                  | [Configuration](https://wiki.zshell.dev/docs/guides/customization/)        |
| Explore commands and maintenance workflows       | [Commands](https://wiki.zshell.dev/docs/guides/commands/)                  |
| Discover plugins, annexes, and packages          | [Ecosystem](https://wiki.zshell.dev/ecosystem/)                            |

## Community and support

- Ask usage questions in [Z-Shell Discussions](https://github.com/orgs/z-shell/discussions).
- Report reproducible defects through [Zi issues](https://github.com/z-shell/zi/issues/new/choose).
- Browse releases and changelogs on the [releases page](https://github.com/z-shell/zi/releases).
- Explore the wider [Z-Shell organization](https://github.com/z-shell).

## Contributing

Contributions are welcome. Read the [contribution guide](docs/CONTRIBUTING.md)
before opening an issue or pull request. Development work targets the `next`
branch, while `main` contains production releases.

## Security

Please follow the
[Z-Shell security policy](https://github.com/z-shell/.github/security/policy)
to report vulnerabilities privately. Do not disclose a vulnerability in a
public issue before a fix is available.

## License

Zi is available under the [MIT License](LICENSE).
