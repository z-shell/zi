<p align="center">
  <img src="images/logo.svg" alt="Zi logo" width="96" height="96">
</p>

<h1 align="center">Zi</h1>

<p align="center">
  <strong>Manage your Zsh plugins, snippets, and command-line tools.</strong>
</p>

<p align="center">
  <a href="https://github.com/z-shell/zi/releases"><img src="https://img.shields.io/github/v/release/z-shell/zi?display_name=tag&sort=semver" alt="Latest release"></a>
  <a href="../LICENSE"><img src="https://img.shields.io/github/license/z-shell/zi" alt="MIT License"></a>
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

Zi is the Z-Shell ecosystem's plugin manager, formerly known as zplugin and zinit.

## Features

- **Responsive startup:** defer plugin loading until after the first prompt with Turbo mode.
- **Flexible sources:** load plugins, scripts, completions, and release artifacts.
- **Control over loading:** use ice modifiers to configure downloads, builds, and updates.
- **Tool management:** install command-line tools without root access.
- **Extensions:** add capabilities through Zi annexes.

## Requirements

Use Zsh with Git available on `PATH`. The quick-start installer also uses `curl` and a POSIX shell. Plugins and tools you install may have their own dependencies.

## Quick start

### 1. Install Zi

The official installer installs Zi with the default loader profile and adds one short managed source entry to `.zshrc` (see the canonical [installation page](https://wiki.zshell.dev/docs/getting_started/installation/)):

```sh
sh -c "$(curl -fsSL get.zshell.dev)" --
```

> [!IMPORTANT]
> Review the [installer source](https://raw.githubusercontent.com/z-shell/src/main/public/sh/install.sh) and its published [SHA-256 checksum](https://raw.githubusercontent.com/z-shell/src/main/public/checksum.txt) before running a remote installation script.

### 2. Add your first plugins

Add these commands to `.zshrc` after the installer's managed source entry. This example loads an Oh My Zsh snippet, command suggestions, and fast syntax highlighting:

```zsh
# ~/.zshrc
zi snippet OMZ::plugins/git/git.plugin.zsh
zi light zsh-users/zsh-autosuggestions
zi light z-shell/F-Sy-H
```

`snippet` loads a standalone script. `light` loads a plugin. The first load downloads any missing repositories or snippets.

### 3. Reload Zsh

```zsh
exec zsh -il
```

Run `zi -h` to explore the available commands. For alternate installers, manual setup, completions, and post-install steps, see the full [installation guide](https://wiki.zshell.dev/docs/getting_started/installation/).

## Learn by task

- **Load plugins and snippets:** [general overview](https://wiki.zshell.dev/docs/getting_started/overview/).
- **Choose how dependencies load:** [ice modifiers](https://wiki.zshell.dev/docs/guides/syntax/ice-modifiers/).
- **Configure paths and behavior:** [configuration guide](https://wiki.zshell.dev/docs/guides/customization/).
- **Update, inspect, and unload:** [command reference](https://wiki.zshell.dev/docs/guides/commands/).
- **Find plugins and annexes:** [ecosystem catalog](https://wiki.zshell.dev/ecosystem/).
- **Understand shell startup:** [official Zsh startup-file reference](https://zsh.sourceforge.io/Doc/Release/Files.html).

For automated installers and terminal interfaces, use the [setup integration contract](https://github.com/z-shell/src/blob/main/docs/zi-setup-tui-contract.md), including plan/apply phases, results, and event handling.

## Community and support

- Ask usage questions in [Z-Shell Discussions](https://github.com/orgs/z-shell/discussions).
- Report reproducible defects through [Zi issues](https://github.com/z-shell/zi/issues/new/choose).
- Browse releases and changelogs on the [releases page](https://github.com/z-shell/zi/releases).
- Explore the wider [Z-Shell organization](https://github.com/z-shell).

## Contributing

Contributions are welcome. Read the [contribution guide](CONTRIBUTING.md) for the branch model and release process before opening an issue or pull request. See the [Zsh workflow](../.github/workflows/zsh-n.yml) for the syntax and focused regression checks used to verify a checkout. Development work targets the `next` branch, while `main` contains production releases.

## Security

Please follow the [Z-Shell security policy](https://github.com/z-shell/.github/security/policy) to report vulnerabilities privately. Do not disclose a vulnerability in a public issue before a fix is available.

## License

Zi is available under the [MIT License](../LICENSE).
