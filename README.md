<p align="center">
  <img src="docs/images/logo.svg" alt="Zi logo" width="80" height="80">
</p>

# Zi

Zi is a fast, flexible plugin manager and shell toolkit for
[Zsh](https://www.zsh.org/). It installs and manages plugins, snippets,
completions, themes, and packages while giving you precise control over when
and how they load.

Zi was formerly known as zplugin and zinit.

## Why Zi?

- Load plugins and snippets from GitHub and other sources.
- Defer work with Turbo mode to keep interactive shell startup responsive.
- Install command-line tools and packages without requiring root access.
- Customize downloads, builds, loading, and updates with ice modifiers.
- Extend Zi through annexes maintained across the Z-Shell ecosystem.

## Get started

Follow the
[installation guide](https://wiki.zshell.dev/docs/getting_started/installation/)
to install Zi and load your first plugin.

```zsh
zi light zsh-users/zsh-autosuggestions
zi snippet OMZP::git
```

The [Zi documentation](https://wiki.zshell.dev/) covers configuration, commands,
ice modifiers, Turbo mode, package management, migration, and troubleshooting.

## Project links

- [Documentation](https://wiki.zshell.dev/)
- [Releases](https://github.com/z-shell/zi/releases)
- [Issues](https://github.com/z-shell/zi/issues)
- [Discussions](https://github.com/orgs/z-shell/discussions)
- [Z-Shell organization](https://github.com/z-shell)

## Contributing

Contributions are welcome. Read the [contribution guide](docs/CONTRIBUTING.md)
before opening an issue or pull request. Development work targets the `next`
branch.

## Security

Please follow the
[Z-Shell security policy](https://github.com/z-shell/.github/security/policy)
to report vulnerabilities privately. Do not disclose a vulnerability in a
public issue before a fix is available.

## License

Zi is available under the [MIT License](LICENSE).
