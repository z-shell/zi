<!--
  Thanks for contributing to zi! Please read the checklist below.

  Branch model:
    - Ordinary work: create feature-<id> or bug-<id> from next and target next
    - Urgent production fixes: use a same-repository hotfix-<id> from main to main
    - Promote next to main only after integration checks pass, using a merge
      commit rather than squash or rebase
    - For next-to-main promotions, use:
      ?template=promotion.md

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

- [ ] Ordinary work targets `next`; only same-repository hotfixes target `main`
- [ ] A `next` to `main` promotion uses a merge commit and records both parent SHAs
- [ ] Commit messages follow Conventional Commits format
- [ ] Any `Co-authored-by` trailer credits a real human, never a bot, AI agent,
      or automation
- [ ] I have read the [contribution guidelines](https://github.com/z-shell/.github/blob/main/.github/CONTRIBUTING.md)
- [ ] Existing tests pass (`zsh -n zi.zsh` / Trunk checks)
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
