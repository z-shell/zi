# Contributing

When contributing to this repository, please first discuss the change you wish to make via issue, email, or any other method with the owners of this repository before making a change.
Please note we have a [code of conduct](CODE_OF_CONDUCT.md), please follow it in all your interactions with the project.

## Knowledge Base

- [ZI Wiki](https://github.com/z-shell/zi/wiki)
- [Zsh Plugin Standard](https://z-shell.github.io/docs/zsh/Zsh-Plugin-Standard.html)
- [Zsh Native Scripting Handbook](https://z-shell.github.io/docs/zsh/Zsh-Native-Scripting-Handbook.html)

###  Zsh Official
- [Zsh Site](http://zsh.sourceforge.net/)
  - [Zsh FAQ](https://zsh.sourceforge.io/FAQ/)
  - [Zsh Documentation](https://zsh.sourceforge.io/Doc/)
  - [The Z Shell Manual](https://zsh.sourceforge.io/Doc/Release/index.html#Top) 
### Useful
-   [Bash 2 Zsh](http://www.bash2zsh.com/)
-   [Zsh tips](http://www.zzapper.co.uk/zshtips.html)
-   [101 Powerful & Practical ZSH GLOBS](http://www.zzapper.co.uk/101ZshGlobs.php)
-   [Practical differences between Bash ans Zsh](https://apple.stackexchange.com/questions/361870/what-are-the-practical-differences-between-bash-and-zsh/361957#361957)
>
-   [zshdb - a gdb-like debugger for zsh](https://zshdb.readthedocs.io/en/latest/index.html)
-   [Debian Bug report logs: Bugs in package zsh](https://bugs.debian.org/cgi-bin/pkgreport.cgi?pkg=zsh)

## Development environment setup

**Notes:**
  - Any files to support prefered editor should be collaborated and respected across repositories. e.g. [.editorconfig](https://gist.github.com/ss-o/1e8d9f3a710f78330a09ccc47ef6ddb2).
  - [Doxygen For Shell Scripts](https://github.com/z-shell/zsdoc) - parses Zsh and Bash scripts. 

### Clean Pull Request guidelines

  Contributing is also a great way to learn more about social coding on Github, new technologies and and their ecosystems and how to make constructive, helpful bug reports, feature requests and the noblest of all contributions: a good, clean pull request.

-   Create a personal fork of the project on Github.
-   Clone the fork on your local machine. Your remote repo on Github is called `origin`.
    -   `git clone https://github.com/{YOUR-USERNAME}/zi`
-   Add the original repository as a remote called `upstream`.
    -   `git remote add upstream https://github.com/z-shell/zi.git`
-   If you created your fork a while ago be sure to pull upstream changes into your local repository.
-   Create a new branch to work on! Branch from `develop` if it exists, else from `main`.
-   Implement/fix your feature, comment your code.
-   Follow the code style of the project, including indentation.
-   If there is related tests please run them.
-   Write or adapt tests as needed.
-   Add or change the documentation as needed.
-   Squash your commits into a single commit with git's [interactive rebase](https://help.github.com/articles/interactive-rebase). Create a new branch if necessary.
-   Push your branch to your fork on Github, the remote `origin`.
-   From your fork open a pull request in the correct branch. Target the project's `develop` branch if there is one, else go for `main`!
-   Once the pull request is approved and merged you can pull the changes from `upstream` to your local repo and delete
    your extra branch(es).

> Always write your commit messages in the present tense. Your commit message should describe what the commit, when applied, does to the code – not what you did to the code. ([examples](https://www.google.com/search?q=english+"present+tense+example"))

## Issues and feature requests

You've found a bug in the source code, a mistake in the documentation or maybe you'd like a new feature?Take a look at [GitHub Discussions](https://github.com/z-shell/zi/discussions) to see if it's already being discussed. You can help us by [submitting an issue on GitHub](https://github.com/z-shell/zi/issues). Before you create an issue, make sure to search the issue archive -- your issue may have already been addressed!

Please try to create bug reports that are:

-   _Reproducible._ Include steps to reproduce the problem.
-   _Specific._ Include as much detail as possible: which version, what environment, etc.
-   _Unique._ Do not duplicate existing opened issues.
-   _Scoped to a Single Bug._ One bug per report.

**Even better: Submit a pull request with a fix or new feature!**

### How to submit a Pull Request

1. Search our repository for open or closed
   [Pull Requests](https://github.com/z-shell/zi/pulls)
   that relate to your submission. You don't want to duplicate effort.
2. Fork the project
3. Create your feature branch (`git checkout -b feat/amazing_feature`)
4. Commit your changes (`git commit -m 'feat: add amazing_feature'`) Z-Shell ZI uses [conventional commits](https://www.conventionalcommits.org), so please follow the specification in your commit messages.
5. Push to the branch (`git push origin feat/amazing_feature`)
6. [Open a Pull Request](https://github.com/z-shell/zi/compare?expand=1)
