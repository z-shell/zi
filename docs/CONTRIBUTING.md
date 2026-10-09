# Contributing to zi

Thank you for contributing! Please follow the guidelines below to keep the project history clean and easy to navigate.

## Branch model

The [protected-main migration](MAIN_MIGRATION.md) is staged. Until maintainer acceptance of ADR-0039 and verified cutover, follow the existing `next` procedure below. After cutover, branch ordinary work from current `main` (`git switch -c bug-123 origin/main`) and target protected `main`, including fork PRs. Keep one coherent change per topic branch and preserve reviewed history. Use `Closes #N` only when the PR completes the issue and `Refs #N` for partial work; issue closure occurs when the default-branch PR merges.

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

The stable qualification workflow runs on every `main` PR and push. It runs the full Zsh suite on the exact candidate, ZD including compatibility, full Trunk and CodeQL checks, clean startup and real-object install/update/unload/delete checks. It retains the `Promotion gate` required context during staged cutover and fails on failed, skipped or cancelled constituents. Revalidate against a changed base. Post-merge checks are additional evidence: users can consume `main` immediately, before a tag is published. Repository settings must require the appropriate checks; workflow files alone do not enforce merging rules.

Keep long-form user guidance in the canonical wiki. Changes to installation or commands must also check the README and `docs/man/zi.1`, which `zi man` opens directly. That roff file is the maintained offline source, not a generated README copy. Update it alongside commands; `zsh -f tests/manual.zsh` checks command coverage and renders it with groff. Check semantics against the dispatcher and help, because rendering and inventory checks cannot prove that descriptions are correct.

## Releases

A milestone is a separately authorized signed annotated tag on an exact current protected `main` SHA. Ordinary merges do not authorize a tag or release, and automatic promotion publication is removed. This transition supersedes ADR-0028 only after maintainer acceptance and verified cutover under ADR-0039.

1. Run read-only `Release Plan` for the full current `main` SHA using its `candidate-sha` dispatch input, or run `RELEASE_NOTES_FILE=/path/to/notes.md zsh -f scripts/release-plan.zsh <full-sha>` locally. Review the deterministic notes and proposed tag. PR plans are previews; review the final main SHA before tagging. Breaking changes produce a major bump, `feat` a minor bump, and `fix` or `perf` a patch bump; a no-op plan produces no tag or release.
2. Separately authorize the displayed version, notes and exact SHA, then push its signed annotated `vX.Y.Z` tag through the protected tag rules. No personal signing key is stored in Actions.
3. The tag publisher requires GitHub-verified signature and exact current `main` target, plus the latest push runs of `Zsh`, `ZD Integration`, `CodeQL`, `Trunk Code Quality` and `Promotion Readiness` on that exact SHA. A failed, pending, skipped or cancelled latest run blocks publication; an older successful run cannot substitute.
4. The verifier recomputes the semantic plan while excluding the newly pushed tag and rejects a mismatched version or no-op range. The publisher uses those deterministic notes and treats an existing release idempotently. Existing signed tags and historical promotion ancestry remain intact.

The repository stores no version file. `ZI[VERSION]` is derived at runtime from `git describe --tags --exact-match`, so the tag is the version and there is nothing to keep in step with it.

For recovery, rerun the failed tag workflow after repairing its cause and rechecking the exact target and current validation. Never move or delete an existing milestone tag to conceal a failure. If `main` moves, the verifier blocks a stale tag; decide a new milestone explicitly.

## What not to add

- Root `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, or duplicate agent policy files. Extend the repository's `AGENTS.md` instead.
- Secrets, credentials, or tokens of any kind

## Discussion and issues

Before starting significant work, [open an issue](https://github.com/z-shell/zi/issues/new/choose) to discuss the change.

See also the [organization contributing guidelines](https://github.com/z-shell/.github/blob/main/.github/CONTRIBUTING.md) and the [Code of Conduct](https://github.com/z-shell/.github/blob/main/.github/CODE_OF_CONDUCT.md).
