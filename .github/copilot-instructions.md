# GitHub Copilot Instructions for zi

## Commit messages

- Use **Conventional Commits** format: `type(scope): short description`
- Allowed types: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `ci`, `chore`, `revert`
- Subject line: imperative mood, ≤72 characters, no trailing period
- Body: wrap at 72 characters, explain *what* and *why* (not *how*)
- **Never add AI co-author trailers** — do not append `Co-authored-by: Copilot`, `Co-authored-by: Claude`, `Co-authored-by: GitHub Copilot`, or any AI-generated attribution to commit messages
- Breaking changes: add `!` after the type (`feat!:`) and include `BREAKING CHANGE:` in the footer

Examples:
```
feat(loader): add lazy-loading for completions

Defer completion setup until first TAB press to cut startup time
for users with large fpath trees.

BREAKING CHANGE: ZI_COMPLETION_LAZY must be set before zi is sourced.
```

```
fix(self-update): correctly set exit code on network failure
```

## Branch model

```
main  ← production releases (tags only, squash-merged from next)
next  ← integration branch (PR target for all work)
  └─ feat/<name>    feature branches
  └─ fix/<name>     bug-fix branches
  └─ perf/<name>    performance improvements
  └─ docs/<name>    documentation updates
  └─ ci/<name>      CI/workflow changes
  └─ chore/<name>   maintenance, refactors
```

- **All branches must be created from `next`**, not `main`
- Open PRs **targeting `next`**, never `main` directly
- `next` → `main` is the only path to production; it requires all CI checks to pass

## AI-generated files

- Do **not** suggest adding `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.cursorrules`, `.aider*`, or similar AI-specific config files to this repository
- Copilot configuration lives **only** in `.github/copilot-instructions.md`

## Code style

- Zsh files: 2-space indent, `# vim: ft=zsh sw=2 ts=2 et` modeline, LF endings
- Every plugin entry file must resolve `$0` via the ZERO pattern
- Follow the [Z-Shell Plugin Standard](https://wiki.zshell.dev/community/zsh_plugin_standard)
