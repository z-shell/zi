# Contributing to zi

Thank you for contributing! Please follow the guidelines below to keep the project history clean and easy to navigate.

## Branch model

```text
main       production and consumable ref
  |-- hotfix-<id>   urgent fixes that may target main
  ^
next       integration branch; ordinary PRs target here
  ^
  |-- feature-<id>  new features
  `-- bug-<id>      bug fixes
```

1. Branch ordinary work from `next`: `git switch -c bug-123 next`.
2. Target `next` from `feature-<id>` and `bug-<id>` branches.
3. Use `hotfix-<id>` only for urgent fixes created in this repository, branched from `main`, and targeting `main`. Fork pull requests must target `next`.
4. Promote `next` to `main` once the integration branch is stable. Use **Create a merge commit**, never squash or rebase, so the reviewed candidate remains a parent of stable `main`.
5. A successful promotion needs no routine back-merge. After a direct `main` hotfix, merge `main` forward into `next` before ordinary work continues.

## Commit message format

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
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

To clean up commits before opening a PR, rebase against the intended target: `next` for ordinary work and `main` for hotfixes.

Repository rules intentionally omit linear-history requirements on both persistent branches so promotion and hotfix synchronization can preserve their merge commits.

## Releases

A same-repository `next` to `main` promotion is the normal publication authorization. Reviewers see the deterministic version and release-note plan on the promotion pull request before deciding whether to merge.

1. `Release Plan` computes the next semantic version from Conventional Commits since the latest `vX.Y.Z` tag. A breaking change produces a major bump, `feat` produces a minor bump, and `fix` or `perf` produces a patch bump. A promotion with none of those commits is an explicit no-op.
2. Merging the reviewed promotion authorizes publication of that displayed plan. The merge still updates the Git-consumed stable `main` ref immediately.
3. The automatic publisher proves that the exact merge commit came from the reviewed same-repository `next` pull request and is still current `main`. It waits for `Zsh`, `ZD Integration`, `CodeQL`, and `Trunk Code Quality` to succeed on that exact SHA.
4. The publisher creates an annotated tag and the GitHub release in one idempotent workflow. It fails closed if `main` moves, the promotion identity cannot be proven, validation fails, or the proposed tag already targets another commit.

The repository stores no version file. `ZI[VERSION]` is derived at runtime from `git describe --tags --exact-match`, so the tag is the version and there is nothing to keep in step with it.

The signed manual-tag flow remains available for recovery or exceptional publication. A maintainer may push a signed annotated `vX.Y.Z` tag to the exact current `main`; `scripts/verify-release-tag.zsh` then requires a valid GitHub signature, the exact target, and the same four successful workflows before it creates the release. No personal signing key is stored in Actions.

## What not to add

- Root `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, or duplicate agent policy files. Extend the repository's `AGENTS.md` instead.
- Secrets, credentials, or tokens of any kind

## Discussion and issues

Before starting significant work, [open an issue](https://github.com/z-shell/zi/issues/new/choose) to discuss the change.

See also the [community contributing guidelines](https://github.com/z-shell/community/blob/main/docs/CONTRIBUTING_GUIDELINES.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).
