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
6. Write `Closes #N` in a pull request into `next` only when it fully resolves the issue, ending the sentence or line there. GitHub ignores the keyword on `next`; `Promotion Issue Closure` closes the issue when the promotion reaches `main`. Use `Refs #N` for partial work.

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

**Allowed types:** `feat` `fix` `perf` `refactor` `docs` `test` `build` `ci` `style` `chore` `revert`

**Rules:**

- Subject line: imperative mood, ≤72 characters, no trailing period
- Breaking changes: use `!` suffix (`feat!:`) and add `BREAKING CHANGE:` footer
- **No AI co-author trailers** — do not add `Co-authored-by: Copilot` or similar

To clean up commits before opening a PR, rebase against the intended target: `next` for ordinary work and `main` for hotfixes.

Repository rules intentionally omit linear-history requirements on both persistent branches so promotion and hotfix synchronization can preserve their merge commits.

## Zsh implementation and verification

Read the [organization Zsh scripting standard](https://github.com/z-shell/.github/blob/main/.github/instructions/zsh/scripting.instructions.md), [testing guidance](https://github.com/z-shell/.github/blob/main/.github/instructions/quality/testing.instructions.md), and [review criteria](https://github.com/z-shell/.github/blob/main/.github/instructions/quality/code-review.instructions.md). The [official released Zsh manual](https://zsh.sourceforge.io/Doc/Release/index.html) is authoritative for shell semantics. For non-obvious or version-sensitive behavior, cite the relevant manual section in the review and show a regression that exercises the interpretation.

`zi.zsh` is the manager entry point; `lib/zsh/` contains its sourced implementation, `lib/_zi` its completion, `contracts/` its public interfaces, and `tests/` its focused regressions. Classify the execution context before applying scripting rules; a sourced manager and a standalone test have different state responsibilities.

Run native syntax on changed Zsh files, for example `zsh -f -n zi.zsh`, then the affected tests, for example `zsh -f tests/ice-tokenizer.zsh`. Read tests before running them and isolate any inherited installation prefixes such as `ZPFX`. The [Zsh workflow](../.github/workflows/zsh-n.yml) lists every focused test and compiles the selected sources. `zsh -f tests/ci-registration.zsh` checks that no test is omitted and that promotion calls the full suite. A syntax pass alone is not a functional test.

The focused suite runs on exact Zsh 5.8.1, 5.9 and 5.9.2 builds on Linux and macOS, installed through the organization's pinned setup action. Every matrix leg must pass the Zsh Gate, including during promotion. This is the tested matrix, not a claim about every plugin or untested older versions, BSD or Cygwin. Preserve existing version fallbacks; a support-floor increase is a separate compatibility decision. Native-valid code must not be rewritten solely to satisfy a supplemental parser or formatter.

The required promotion gate runs the full Zsh suite on the exact candidate, plus ZD integration and clean-install/real-object checks. Post-merge release checks are additional evidence: users can consume `main` immediately, before a tag is published. Repository settings must require the appropriate checks; workflow files alone do not enforce merging rules.

Keep long-form user guidance in the canonical wiki. Changes to installation or commands must also check the README and `docs/man/zi.1`, which `zi man` opens directly. That roff file is the maintained offline source, not a generated README copy. Update it alongside commands; `zsh -f tests/manual.zsh` checks command coverage and renders it with groff. Check semantics against the dispatcher and help, because rendering and inventory checks cannot prove that descriptions are correct.

## Releases

A same-repository `next` to `main` promotion is the normal publication authorization. Reviewers see the deterministic version and release-note plan on the promotion pull request before deciding whether to merge.

1. `Release Plan` computes the next semantic version from Conventional Commits since the latest `vX.Y.Z` tag. A breaking change produces a major bump, `feat` produces a minor bump, and `fix` or `perf` produces a patch bump. A promotion with none of those commits is an explicit no-op.
2. Merging the reviewed promotion authorizes publication of that displayed plan. The merge still updates the Git-consumed stable `main` ref immediately.
3. The automatic publisher proves that the exact merge commit came from the reviewed same-repository `next` pull request and is still current `main`. It waits for `Zsh`, `ZD Integration`, `CodeQL`, and `Trunk Code Quality` to succeed on that exact SHA.
4. The publisher creates an annotated tag and the GitHub release in one idempotent workflow. It fails closed if `main` moves, the promotion identity cannot be proven, validation fails, or the proposed tag already targets another commit. A `main` commit merged by another pull request, such as a hotfix or a Dependabot security update, is not a promotion: the publisher reports that there is nothing to publish and succeeds without creating a tag.

The repository stores no version file. `ZI[VERSION]` is derived at runtime from `git describe --tags --exact-match`, so the tag is the version and there is nothing to keep in step with it.

The signed manual-tag flow remains available for recovery or exceptional publication. A maintainer may push a signed annotated `vX.Y.Z` tag to the exact current `main`; `scripts/verify-release-tag.zsh` then requires a valid GitHub signature, the exact target, and the same four successful workflows before it creates the release. No personal signing key is stored in Actions.

## What not to add

- Root `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, or duplicate agent policy files. Extend the repository's `AGENTS.md` instead.
- Secrets, credentials, or tokens of any kind

## Discussion and issues

Before starting significant work, [open an issue](https://github.com/z-shell/zi/issues/new/choose) to discuss the change.

See also the [organization contributing guidelines](https://github.com/z-shell/.github/blob/main/.github/CONTRIBUTING.md) and the [Code of Conduct](https://github.com/z-shell/.github/blob/main/.github/CODE_OF_CONDUCT.md).
