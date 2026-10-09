<!--
  Thanks for contributing to zi! Please read the checklist below.

  Branch ordinary work from current main and target protected main.
  Every merge is consumable; milestone publication is separately authorized.

  Commit messages must follow Conventional Commits:
    type(scope): short description   (≤72 chars, imperative mood)
    Types: feat  fix  perf  refactor  docs  test  build  ci  style  chore  revert
    Example: fix(self-update): correctly propagate exit code on failure

  See AGENTS.md for the repository contribution guidelines.
-->

## Description

<!-- Describe your changes clearly. What problem does this solve? -->

## Related issues

<!-- Closes #NNN  /  Part of #NNN  /  N/A -->

## Type of change

<!-- Put an `x` in all boxes that apply -->

- [ ] `fix` — bug fix (non-breaking)
- [ ] `feat` — new feature (non-breaking)
- [ ] `feat!` / `fix!` — breaking change
- [ ] `perf` — performance improvement
- [ ] `refactor` — code change with no functional impact
- [ ] `docs` — documentation only
- [ ] `test` — test addition or correction
- [ ] `build` — build system or dependency change
- [ ] `ci` — CI/workflow change
- [ ] `style` — formatting with no behavior change
- [ ] `chore` — maintenance / dependency bump
- [ ] `revert` — revert of an earlier change

## Checklist

Prefer omitting automatic tool credits; see the [contribution guidance](https://github.com/z-shell/.github/blob/main/.github/CONTRIBUTING.md#tool-attribution).

- [ ] Work branches from current `main` and targets protected `main`
- [ ] Full stable qualification passes on the current candidate; release authority is separate
- [ ] Commit messages follow Conventional Commits format
- [ ] I have read the [contribution guidelines](https://github.com/z-shell/.github/blob/main/.github/CONTRIBUTING.md)
- [ ] Native syntax/compilation and affected functional regressions pass; exact commands and compatibility limits are recorded
- [ ] Non-obvious Zsh behavior is checked against the organization scripting standard and relevant official manual sections
- [ ] Documentation updated if needed

## Migration plan

<!--
Required only when Public Contract Impact reports a destructive change.
Link or describe the migration, then add one line per reported impact:

[contract-impact:reported-id] updated here
[contract-impact:reported-id] follow-up issue linked: https://github.com/OWNER/REPO/issues/NNN
[contract-impact:reported-id] not affected: rationale
[contract-impact:reported-id] deprecated with removal target: version/date/issue
-->
