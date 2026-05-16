# Contributing to zi

Thank you for contributing! Please follow the guidelines below to keep the project history clean and easy to navigate.

## Branch model

```
main  ←─── production (tagged releases only)
  ↑
next  ←─── integration branch  ← open all PRs here
  ↑
  ├── feat/<name>      new features
  ├── fix/<name>       bug fixes
  ├── perf/<name>      performance improvements
  ├── refactor/<name>  code refactors
  ├── docs/<name>      documentation updates
  └── ci/<name>        CI / workflow changes
```

1. **Always branch from `next`**: `git checkout -b fix/my-issue next`
2. **Open PRs targeting `next`** — never target `main` directly
3. `next` → `main` happens via a release PR once `next` is stable

## Commit message format

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): short description

Optional body — explain what and why, not how.
Wrap at 72 characters.

Optional footer(s):
Fixes #123
BREAKING CHANGE: description of what breaks
```

**Allowed types:** `feat` `fix` `perf` `refactor` `docs` `test` `ci` `chore` `revert`

**Rules:**
- Subject line: imperative mood, ≤72 characters, no trailing period
- Breaking changes: use `!` suffix (`feat!:`) and add `BREAKING CHANGE:` footer
- **No AI co-author trailers** — do not add `Co-authored-by: Copilot` or similar

To clean up commits before opening a PR: `git rebase -i $(git merge-base HEAD next)`

## What not to add

- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, or any AI-specific config files
- Secrets, credentials, or tokens of any kind

## Discussion and issues

Before starting significant work, [open an issue](https://github.com/z-shell/zi/issues/new/choose) to discuss the change.

See also the [community contributing guidelines](https://github.com/z-shell/community/blob/main/docs/CONTRIBUTING_GUIDELINES.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).

