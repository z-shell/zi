<h1 align="center">
  <a href="https://github.com/z-shell/zi">
    <img src="images/logo.svg" alt="Logo" width="80" height="80">
  </a>
❮ ZI ❯
  </h1>

<h4 align="center">
Nightly Release
</h4>

<div align="center">
  <a href="https://github.com/z-shell/zi/issues/new?assignees=&labels=bug+%F0%9F%90%9E&template=01_bug_report.yml&title=bug%3A+">《 Report an issue 》</a>
  · <a href="https://github.com/z-shell/zi/issues/new?assignees=&labels=feature-request+%F0%9F%92%A1&template=02_feature_request.yml&title=feat%3A+">《 Request a Feature 》</a>
  · <a href="https://github.com/z-shell/zi/discussions">《 Ask a Question 》</a>
</div>

<div align="center">
<br />

[![Project license](https://img.shields.io/github/license/z-shell/zi.svg?style=flat-square)](../LICENSE) [![Version][ver-badge]][ver-link] [![Pull Requests welcome](https://img.shields.io/badge/PRs-welcome-ff69b4.svg?style=flat-square)](https://github.com/z-shell/zi/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
[![Tweet][twitter-badge]][twitter-link]

</div>

<details open="open">
<summary>Table of Contents</summary>

- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [Interactive install](#interactive-install)
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

---

[![asciicast](https://asciinema.org/a/QcC3gmoOqIkMdPJ7J9v6hiWGf.svg)](https://asciinema.org/a/QcC3gmoOqIkMdPJ7J9v6hiWGf)


## Getting Started

### Prerequisites

> **[?]**
> Work in progress.

### Installation

> **[?]**
> Interactive installation currently in development mode.
>
> After installing and reloading the shell run: zi self-update

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

- Clone repository:

```zsh
ZI_HOME="${HOME}/.zi" && mkdir -p "$(dirname $ZI_HOME)"
git clone https://github.com/z-shell/zi.git "${ZI_HOME}/bin"
```

- Source `zi.zsh` from your `.zshrc`:

```zsh
ZI_HOME="${HOME}/.zi"
source "${ZI_HOME}/bin/zi.zsh"
# Next two lines must be below the above two
autoload -Uz _zi
(( ${+_comps} )) && _comps[zi]=_zi
```

## Documentation

All [documentation](https://github.com/z-shell/zi/wiki) can be viewed on our wiki pages. If you know how we could improve it, please let us know. We highly appreciated any feedback.

## Contributing

First off, thanks for taking the time to contribute! Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make will benefit everybody else and are **greatly appreciated**.

Please read [our contribution guidelines](CONTRIBUTING.md), and thank you for being involved!

Further releases of ❮ ZI ❯ will have Visual Studio Code workspace pre-configured, which allows easy workspace integration locally or directly in the browser.

[![Open in Visual Studio Code](https://open.vscode.dev/badges/open-in-vscode.svg)](https://open.vscode.dev/z-shell/zi)

## Authors & contributors

The original setup of this repository is by [Z-Shell ZI Community](https://github.com/z-shell).

For a full list of all authors and contributors, see [the contributors page](https://github.com/z-shell/zi/contributors).

## Project assistance

If you want to say **thank you** or/and support active development of Z-Shell ZI :

- Add a [GitHub Star](https://github.com/z-shell/zi) to the project.
- Tweet about the ❮ ZI ❯.
- Write interesting articles about the project on [Dev.to](https://dev.to/), [Medium](https://medium.com/) or your personal blog.

Together, we can make Z-Shell ZI **better**!

## Security

- Z-Shell ZI follows good practices of security, but 100% security cannot be assured.
- Z-Shell ZI is provided **"as is"** without any **warranty**. Use at your own risk.

_For more information and to report security issues, please refer to our [security documentation](../docs/SECURITY.md)._

## About

[**ZI**](https://github.com/z-shell/zi) (formerly zplugin, zinit) is an interactive and flexible plugin manager for Z shell [**(Zsh)**](https://zsh.sourceforge.io/) - [Unix shell](https://en.wikipedia.org/wiki/Unix_shell) (not directly related). Z-Shell [**ZI**](https://github.com/z-shell/zi) is an open source community project released under the [MIT License](../LICENSE).

## Acknowledgements

The [Z-Shell](https://github.com/z-shell) was created to recover the `zdharma` organization project which was deleted by the owner.
We don't want to depend on an unreliable source. For this reason started maintaining all tools, everyone interested is welcome join.

## Roadmap

See the [open issues](https://github.com/z-shell/zi/issues) for a list of proposed features (and known issues).

- [Top Feature Requests](https://github.com/z-shell/zi/issues?q=label%3Aenhancement+is%3Aopen+sort%3Areactions-%2B1-desc) (Add your votes using the 👍 reaction)
- [Top issues](https://github.com/z-shell/zi/issues?q=is%3Aissue+is%3Aopen+label%3Abug+sort%3Areactions-%2B1-desc) (Add your votes using the 👍 reaction)
- [Newest issues](https://github.com/z-shell/zi/issues?q=is%3Aopen+is%3Aissue+label%3Abug)

## Support
  
Reach out to the maintainers at one of the following places:

- [GitHub Discussions](https://github.com/z-shell/zi/discussions)
- Contact options listed on [this GitHub profile](https://github.com/z-shell)

  
[ver-badge]: https://img.shields.io/github/tag/z-shell/zi.svg
[ver-link]: https://github.com/z-shell/zi/releases
[twitter-badge]: https://img.shields.io/twitter/url/http/shields.io.svg?style=social
[twitter-link]: https://twitter.com/intent/tweet?text=Z-shell%20-%20ZI%20plugin%20manager&url=https://github.com/z-shell/zi&hashtags=zsh,zi,plugin,z-shell
