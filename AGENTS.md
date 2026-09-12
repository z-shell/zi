# Zi repository guidance

This repository follows the
[Z-Shell organization guidelines](https://github.com/z-shell/.github/blob/main/AGENTS.md).

Zi is the canonical Zsh plugin manager for the organization. Changes can affect
annexes, plugins, documentation, installers, and test environments.

## Branch model

- `next` is the development and integration branch.
- Ordinary work branches from and targets `next`.
- Use `feature-<id>`, `bug-<id>`, or `hotfix-<id>` branch names.
- Promote `next` to stable `main` with a merge commit, never squash or rebase.
- Neither `main` nor `next` may require linear history; both promotion and
  hotfix synchronization preserve merge ancestry.
- A successful promotion needs no routine back-merge. Merge a `main` hotfix
  forward into `next` before ordinary development continues.
- `hotfix-*` branches may target `main` directly.
- Keep `delete_branch_on_merge` disabled because `next` is persistent.

## Implementation

- Write Zsh-first code and avoid Bash-only syntax.
- Run the existing Zsh syntax, integration, and focused tests for changed paths.
- Keep user-facing documentation in the canonical wiki when practical.
- Follow the organization commit policy. A `Co-authored-by` trailer may credit a
  real human, including the pull-request author; never credit a bot, AI agent,
  or automation as a co-author.

## Code review

Use the shared [code-review skill](.github/skills/code-review/SKILL.md) with
the following Zi-specific context. Apply these checks to affected behavior;
trace callers and failure paths before proposing a change.

- **Public contracts and consumers:** Read
  [the public-contract manifest](contracts/public-contract-v1.json) for changes
  to commands, ice modifiers, annex/hook registration, compatibility wrappers,
  or message output. Check recorded downstream consumers and the
  [contract-impact workflow](.github/workflows/public-contract-impact.yml).
  Treat the manifest as an inventory, not exhaustive proof of compatibility:
  unchanged signatures can still conceal changes to ordering, return status,
  side effects, or output bytes. Report migration and downstream verification
  needs without expanding the edit scope.
- **Loading and shell state:** Check nested and deferred loads, hook ordering,
  autoload/completion paths, and propagation of failures through shared loaders.
  Verify that unload, reload, and failed initialization remove only state owned
  by the relevant plugin or annex, preserving caller state and other owners.
  Distinguish documented manager effects and explicit install/update commands
  from accidental state changes or network activity during passive sourcing.
- **Filesystem and update safety:** Trace user-controlled paths, URLs, archive
  entries, and command arguments through download, extraction, installation,
  update, and cleanup. Check quoting, destination boundaries, symlinks, partial
  failures, and concurrent updates. A failed operation must preserve existing
  usable installations and must not remove unrelated user data.
- **Verification:** Select focused regressions from
  [the Zsh workflow](.github/workflows/zsh-n.yml) and [tests](tests/), including
  ownership, nested/deferred loading, updates, or snippet mirrors as relevant.
  Inspect tests before executing them and use isolated runtime state. Separate
  native syntax/compilation results from behavioral tests and
  [ZD integration](.github/workflows/zd-integration.yml). Establish supported
  Zsh/platform versions from repository evidence; do not infer compatibility
  coverage from a green job whose matrix excludes it. Report exact checks run,
  missing coverage, and whether a regression test exercises the failing case.

Use available read-only GitHub context for linked acceptance criteria, affected
consumer contracts, and CI evidence. Repository files remain the fallback when
MCP is unavailable. Prioritize concrete correctness, compatibility, security,
and state-integrity findings; distinguish observed defects from untested risks.
