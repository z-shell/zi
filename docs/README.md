<h2 align="center">
  <a href="https://github.com/z-shell/zi">
    <img src="images/logo.svg" alt="Logo" width="80" height="80">
  </a>
❮ ZI ❯ 
  </h2><div align="center">
  
[![Project license](https://img.shields.io/github/license/z-shell/zi.svg?style=flat-square)](../LICENSE) [![Version][ver-badge]][ver-link] [![Pull Requests welcome](https://img.shields.io/badge/PRs-welcome-ff69b4.svg?style=flat-square)](https://github.com/z-shell/zi/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
[![Tweet][twitter-badge]][twitter-link]
  
  <a href="https://github.com/z-shell/zi/issues/new?assignees=&labels=bug+%F0%9F%90%9E&template=01_bug_report.yml&title=bug%3A+">《 Report an issue 》</a>
  · <a href="https://github.com/z-shell/zi/issues/new?assignees=&labels=feature-request+%F0%9F%92%A1&template=02_feature_request.yml&title=feat%3A+">《 Request a Feature 》</a>
  · <a href="https://github.com/z-shell/zi/discussions">《 Ask a Question 》</a>
</div>
<div align="center">
<br />
</div>

<details open="open">
<summary>Table of Contents</summary>

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [Interactive install](#interactive-install-beta)
    - [Quick install](#quick-install)
    - [Manual install](#manual-install)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Authors & contributors](#authors--contributors)
- [Project assistance](#project-assistance)
- [Security](#security)
- [About](#about)
- [Acknowledgements](#acknowledgements)
- [Roadmap](#roadmap)
- [Support](#support)

</details>

## About
  
  <h3 align="center">

  [**ZI**](https://github.com/z-shell/zi) is an interactive, feature-rich plugin manager for [**Zsh**](https://zsh.sourceforge.io/) - [Unix shell](https://en.wikipedia.org/wiki/Unix_shell).
  
  </h3>
  
- [Annexes](https://github.com/z-shell/zannex)
  - [Meta Plugins](https://github.com/z-shell/z-a-meta-plugins)
- Capabilities: [0fuUpiPs](https://github.com/z-shell/zi/wiki/Zsh-Plugin-Standard#9-global-parameter-holding-the-plugin-managers-capabilities)
  
## Documentation

- [ZI Wiki](https://github.com/z-shell/zi/wiki)
- [Code Documentation](https://github.com/z-shell/zi/wiki/Code-Documentation)

> **Tip:** [Advanced search](https://github.com/search/advanced?q=user%3Az-shell&type=Users)
>
> Curentlly we are working on how to improve and unify documentation in to one place.
> If you know how we could improve it, please let us know. Any feedback, **greatly appreciated**.

## Getting Started

### Prerequisites

> Work in progress.

### Installation

> Interactive installation currently in development mode.

#### ZI Loader

Forthcoming releases will introduce ZI profiles that allow changing the Zsh environment or configuration files with a single command. The specified way of installation is a part of the upcoming profiles loader.

Create a configuration files directory:

```zsh
zi_config="${XDG_CONFIG_HOME:-$HOME/.config}/zi"
command mkdir -p $zi_config
```

Download:

```zsh
curl -fsSL https://git.io/zi-loader -o ${zi_config}/init.zsh
```

Add at the top of your `.zshrc`:

```zsh
if [[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/zi/init.zsh" ]]; then
  source "${XDG_CONFIG_HOME:-$HOME/.config}/zi/init.zsh" && zzinit
fi
```

- This will:
  - Clone and install ZI if missing.
  - If install successful or not required will load ZI.
  - Enable ZI completions.

- All can be accomplished individually or skipped. The functionality will be attached in documentation subsequently.
- Post-install we recommend:
  - Run: `exec zsh` and `zi self-update`.
  - Visiting Wiki:
    - [Introduction](https://github.com/z-shell/zi/wiki/Introduction)
    - [ZI Annex meta plugins](https://github.com/z-shell/zi/wiki/z-a-meta-plugins)
    - [Oh My Zsh integration](https://github.com/z-shell/zi/wiki/Oh-My-Zsh-setup)
    - [Gallery](https://github.com/z-shell/zi/wiki/Gallery)

#### Interactive install (beta)

> Requires: `bash`, `git`, `curl`.

```shell
bash <(curl -fsSL https://git.io/zi-setup)
```

#### Quick install

```shell
bash <(curl -fsSL https://git.io/zi-install)
```

#### Manual install

> Requires: `git`.

  Clone repository:

```zsh
zi_home="${HOME}/.zi" && command mkdir -p $zi_home
command git clone https://github.com/z-shell/zi.git "${zi_home}/bin"
```

  Source `zi.zsh` from your `.zshrc`:

```zsh
zi_home="${HOME}/.zi"
source "${zi_home}/bin/zi.zsh"
# Next two lines must be below the above two
autoload -Uz _zi
(( ${+_comps} )) && _comps[zi]=_zi
```

## Roadmap

See the [open issues](https://github.com/z-shell/zi/issues) for a list of proposed features (and known issues).

- [Top Feature Requests](https://github.com/z-shell/zi/issues?q=label%3Aenhancement+is%3Aopen+sort%3Areactions-%2B1-desc) (Add your votes using the 👍 reaction)
- [Top issues](https://github.com/z-shell/zi/issues?q=is%3Aissue+is%3Aopen+label%3Abug+sort%3Areactions-%2B1-desc) (Add your votes using the 👍 reaction)
- [Newest issues](https://github.com/z-shell/zi/issues?q=is%3Aopen+is%3Aissue+label%3Abug)

## Contributing

First off, thanks for taking the time to contribute! Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make will benefit everybody else and are **greatly appreciated**.

Please read [our contribution guidelines](CONTRIBUTING.md), and thank you for being involved!

Further releases of ❮ ZI ❯ will have Visual Studio Code workspace pre-configured, which allows easy workspace integration locally or directly in the browser.

[![Open in Visual Studio Code](https://open.vscode.dev/badges/open-in-vscode.svg)](https://open.vscode.dev/z-shell/zi)

## Project assistance

If you want to say **thank you** or/and support active development of Z-Shell ZI :

- Add a [GitHub Star](https://github.com/z-shell/zi) to the project.
- [Tweet][twitter-link] about the ZI.
- Write interesting articles about the project on [Dev.to](https://dev.to/), [Medium](https://medium.com/) or your personal blog.

Together, we can make Z-Shell ZI **better**!

## Security

- Z-Shell ZI follows good practices of security, but 100% security cannot be assured.
- Z-Shell ZI is provided **"as is"** without any **warranty**. Use at your own risk.

_For more information and to report security issues, please refer to our [security documentation](../docs/SECURITY.md)._

## Acknowledgements

The [**Z-Shell**](https://github.com/z-shell) was created to recover the `zdharma` organization project which was deleted by the owner.
We don't want to depend on an unreliable source.
[**ZI**](https://github.com/z-shell/zi), formerly known as zplugin, zinit, is an open source community project released under the [MIT License](../LICENSE).

### Authors & contributors

The original setup of this repository is by [Z-Shell ZI Community](https://github.com/z-shell).

For a full list of all authors and contributors, see [the contributors page](https://github.com/z-shell/zi/contributors).

## Support
  
Reach out to the maintainers at one of the following places:

- [GitHub Discussions](https://github.com/z-shell/zi/discussions)
- Contact options listed on [this GitHub profile](https://github.com/z-shell)


[ver-badge]: https://img.shields.io/github/tag/z-shell/zi.svg
[ver-link]: https://github.com/z-shell/zi/releases
[twitter-badge]: https://img.shields.io/twitter/url/http/shields.io.svg?style=social
[twitter-link]: https://twitter.com/intent/tweet?text=Interactive%20feature-rich%20plugin%20manager&url=https://github.com/z-shell/zi&hashtags=zsh,zi,zshell
[asciinema-preview]: https://asciinema.org/a/QcC3gmoOqIkMdPJ7J9v6hiWGf.svg
[asciinema-link]: https://asciinema.org/a/QcC3gmoOqIkMdPJ7J9v6hiWGf

