# Loading Plugins From Private Repositories And Not Only

## Introduction

In order to install and load a plugin whose repository is private - i.e.:
requires providing credentials in order to log in – use the `from''` ice in the
following way:

```zsh
zi ice from"psprint@github.com"
zi load psprint/fsh-auto-themes
```

## Explanation

The point is that when the `from''` ice isn't one of `gh`, `github`, `gl`,
`gitlab`, `bb`, `bitbucket`, `nb`, `notabug`, `gh-r`, `github-rel` then **it is
treaten as a domain name** and inserted into the domain position into the clone
url. I.e.: the following (more or less) `git clone` command is being run:

```zsh
git clone https://{from-ice-contents}/user/plugin
```

In order to change the protocol, use the `proto''` ice.

## Summary

By using this method you can clone plugins from e.g. GitHub Enterprise or embed
the passwords as plain text in `.zshrc`.
