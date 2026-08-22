# Zi repository guidance

This repository follows the
[Z-Shell organization guidelines](https://github.com/z-shell/.github/blob/main/AGENTS.md).

Zi is the canonical Zsh plugin manager for the organization. Changes can affect
annexes, plugins, documentation, installers, and test environments.

## Branch model

- `next` is the development and integration branch.
- Ordinary work branches from and targets `next`.
- Use `feature-<id>`, `bug-<id>`, or `hotfix-<id>` branch names.
- `next` promotes to `main`; `hotfix-*` branches may target `main` directly.
- Keep `delete_branch_on_merge` disabled because `next` is persistent.

## Implementation

- Write Zsh-first code and avoid Bash-only syntax.
- Run the existing Zsh syntax, integration, and focused tests for changed paths.
- Keep user-facing documentation in the canonical wiki when practical.
- Follow the organization commit policy and never add `Co-authored-by` trailers.
