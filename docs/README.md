<h1 align="center">
  <a href="https://github.com/z-shell/zi">
    <img src="images/logo.svg" alt="Logo" width="80" height="80">
  </a>
❮ ZI ❯
  </h1><div align="center">
  
[![Pull Requests welcome](https://img.shields.io/badge/PRs-welcome-ff69b4.svg?style=flat-square)](https://github.com/z-shell/zi/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22)
[![MIT license](https://img.shields.io/badge/License-MIT-blue.svg)](../LICENSE) [![Version][ver-badge]][ver-link] 
[![Tweet][twitter-badge]][twitter-link] [![Visual Studio Code](https://img.shields.io/badge/--007ACC?logo=visual%20studio%20code&logoColor=ffffff)](https://code.visualstudio.com/) [![Vim](https://img.shields.io/badge/--019733?logo=vim)](https://github.com/z-shell/zi-vim-syntax/)

<a href="https://github.com/z-shell/zi/issues/new?assignees=&labels=bug+%F0%9F%90%9E&template=01_bug_report.yml&title=bug%3A+">《 Report an issue 》</a>
· <a href="https://github.com/z-shell/zi/issues/new?assignees=&labels=feature-request+%F0%9F%92%A1&template=02_feature_request.yml&title=feat%3A+">《 Request a Feature 》</a>
· <a href="https://github.com/z-shell/zi/discussions">《 Ask a Question 》</a>
</div>

<details open="open">
<summary>Table of Contents</summary>

- [Wiki](https://github.com/z-shell/zi/wiki)
  - [Installation](https://github.com/z-shell/zi/wiki/Installation)
  - [Introduction](https://github.com/z-shell/zi/wiki/Introduction)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Project assistance](#project-assistance)
- [Security](#security)
- [Acknowledgements](#acknowledgements)
- [Authors & contributors](#authors--contributors)
- [Support](#support)

</details>

---

<h3><div align="center">

**ZI is a fast and feature-rich plugin manager for [Zsh](https://zsh.sourceforge.io/) - [Unix shell](https://en.wikipedia.org/wiki/Unix_shell).**

</div></h3>

- Has a [turbo mode](https://github.com/z-shell/zi/wiki/Introduction#turbo-mode-zsh--53) which yields 50-80% [faster](https://github.com/z-shell/pm-perf-test) Zsh startup.

- Allow to install [**RubyGems**](https://rubygems.org/) [[1](https://github.com/z-shell/zi/wiki/z-a-bin-gem-node)] [[2](https://github.com/z-shell/any-gem)], [**Node modules**](https://www.npmjs.com/) [[1](https://github.com/z-shell/zi/wiki/z-a-bin-gem-node)] [[2](https://github.com/z-shell/any-node)], [**Rust packages**](https://crates.io/) [[1](https://github.com/z-shell/zi/wiki/z-a-rust)] and almost everything from [**GitHub**](https://github.com) [[1](https://github.com/z-shell/zi/wiki/z-a-meta-plugins)] [[2](https://github.com/z-shell/zi/wiki/Gallery)] [[3](https://github.com/z-shell/zi/wiki/Annexes)] [[4](https://github.com/z-shell/zi/wiki/Packages)].

- Supports loading [Oh My Zsh and Prezto](https://github.com/z-shell/zi/wiki/Introduction#oh-my-zsh-prezto) plugins and libraries, however, the implementation isn't framework-specific and doesn't bloat the plugin manager with such code. See our wiki on how to [migrate](https://github.com/z-shell/zi/wiki/Usage#migration) from other plugin managers.

- The dedicated [packages](https://github.com/z-shell/zi/wiki/Packages/) that offload the user from providing long and complex commands. See the [Z-Shell ZI](https://github.com/z-shell) organization for a complete list of packages.

- The specialized extensions — called [annexes](https://github.com/z-shell/zi/wiki/Annexes/) — allow to extend the plugin manager with new commands, URL-preprocessors (used by e.g.: [z-a-readurl](https://github.com/z-shell/z-a-readurl) annex), post-install and post-update hooks and much more.

- The system does not use `$FPATH`, loading multiple plugins don't clutter `$FPATH` with the same number of entries (e.g. `10`, `15` or more). Code is immune to `KSH_ARRAYS` and other options typically causing compatibility problems.

- Provides [reports and statistics](https://github.com/z-shell/zi/wiki/Commands#reports-and-statistics) about the plugins, such as describing what **aliases**, **functions**, **bindkeys**, **Zle widgets**, **zstyles**, [completions](https://github.com/z-shell/zi/wiki/Introduction#completion-management), variables, `PATH` and `FPATH` elements a plugin has set up. Allows to quickly [familiarize](https://github.com/z-shell/zi/wiki/Profiling-plugins) oneself with a new plugin and provides rich and easy-to-digest information that might be helpful on various occasions. supports the unloading of plugins and the ability to list, (un)install, and **selectively disable**, **enable** plugin's completions.

- Test configurations with docker at [playground](https://github.com/z-shell/playground)

- Capabilities: [0fuUpiPs](https://github.com/z-shell/zi/wiki/Zsh-Plugin-Standard#9-global-capabilities)

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


 [![Contributors over time](https://contributor-graph-api.apiseven.com/contributors-svg?chart=contributorOverTime&repo=z-shell/zi)](https://www.apiseven.com/en/contributor-graph?chart=contributorOverTime&repo=z-shell/zi)
  

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

## Authors & contributors

The original setup of this repository is by [Z-Shell ZI Community](https://github.com/z-shell).

For a full list of all authors and contributors, see [the contributors page](https://github.com/z-shell/zi/contributors).

## Support

Reach out to the maintainers at one of the following places:

- [GitHub Discussions](https://github.com/z-shell/zi/discussions)
- Contact options listed on [this GitHub profile](https://github.com/z-shell)

## Supporters

<a href="https://www.digitalocean.com/?refcode=090bdb63f800&utm_campaign=Referral_Invite&utm_medium=Referral_Program&utm_source=badge"><img src="https://web-platforms.sfo2.digitaloceanspaces.com/WWW/Badge%203.svg" alt="DigitalOcean Referral Badge" width="160" height="80" /></a>
<a href="https://cloudflare.com"><img src="https://github.com/ss-o/zi/raw/main/docs/images/cloudflare_shell_logo.png" alt="Cloudflare" width="160" height="80" /></a>

[ver-badge]: https://img.shields.io/github/tag/z-shell/zi.svg
[ver-link]: https://github.com/z-shell/zi/releases
[twitter-badge]: https://badgen.net/badge/icon/twitter?icon=twitter&label
[twitter-link]: https://twitter.com/intent/tweet?text=Interactive%20feature-rich%20plugin%20manager&url=https://github.com/z-shell/zi&hashtags=zsh,zi,zshell
