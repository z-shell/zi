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
3. Use `hotfix-<id>` only for urgent fixes created in this repository,
   branched from `main`, and targeting `main`. Fork pull requests must target
   `next`.
4. Promote `next` to `main` once the integration branch is stable. Use **Create
   a merge commit**, never squash or rebase, so the reviewed candidate remains
   a parent of stable `main`.
5. A successful promotion needs no routine back-merge. After a direct `main`
   hotfix, merge `main` forward into `next` before ordinary work continues.

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

To clean up commits before opening a PR, rebase against the intended target:
`next` for ordinary work and `main` for hotfixes.

Repository rules intentionally omit linear-history requirements on both
persistent branches so promotion and hotfix synchronization can preserve their
merge commits.

## Releases

A promotion to `main` publishes nothing. It updates the Git-consumed stable ref
and stops there.

**A signed annotated tag is the sole publication authorization.** Nothing else
creates a release: not a merge, not a green pipeline, not the automated
proposal.

1. After a promotion reaches `main`, `Release Prepare` opens or updates a
   proposal issue with the next semantic version computed from Conventional
   Commits and a draft changelog. It never creates a tag.
2. A maintainer reviews the proposed version, adjusts it if the computed bump
   does not describe the change, and pushes a signed annotated tag:

   ```text
   git switch main && git pull --ff-only
   git tag -s vX.Y.Z -F <notes-file>
   git push origin vX.Y.Z
   ```

3. `scripts/verify-release-tag.zsh` rejects the tag unless every one of the
   following holds: it matches `vX.Y.Z`, it is annotated rather than
   lightweight, GitHub reports its signature as verified, its target is the
   current `origin/main`, and the `Zsh`, `ZD Integration`, `CodeQL` and
   `Trunk Code Quality` workflows all succeeded on that exact commit.
4. Only then is a GitHub release published, idempotently, with generated notes.

The repository stores no version file. `ZI[VERSION]` is derived at runtime from
`git describe --tags --exact-match`, so the tag is the version and there is
nothing to keep in step with it.

Closing a proposal issue without tagging skips that release; the next promotion
opens a new proposal.

## What not to add

- Root `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, or duplicate agent policy files.
  Extend the repository's `AGENTS.md` instead.
- Secrets, credentials, or tokens of any kind

## Discussion and issues

Before starting significant work, [open an issue](https://github.com/z-shell/zi/issues/new/choose) to discuss the change.

See also the [community contributing guidelines](https://github.com/z-shell/community/blob/main/docs/CONTRIBUTING_GUIDELINES.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).
