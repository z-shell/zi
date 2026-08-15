<!--
  Thanks for contributing to zi! Please read the checklist below.

  Branch model:
    - Ordinary work: create feature-<id> or bug-<id> from next and target next
    - Urgent production fixes: use a same-repository hotfix-<id> from main to main
    - Promote next to main only after integration checks pass

  Commit messages must follow Conventional Commits:
    type(scope): short description   (≤72 chars, imperative mood)
    Types: feat  fix  perf  refactor  docs  test  ci  chore  revert
    Example: fix(self-update): correctly propagate exit code on failure

  See .github/copilot-instructions.md for full guidelines.
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
- [ ] `ci` — CI/workflow change
- [ ] `chore` — maintenance / dependency bump

## Checklist

- [ ] Ordinary work targets `next`; only same-repository hotfixes target `main`
- [ ] Commit messages follow Conventional Commits format
- [ ] No AI co-author trailers in commit messages
- [ ] I have read [CONTRIBUTING.md](docs/CONTRIBUTING.md)
- [ ] Existing tests pass (`zsh -n zi.zsh` / Trunk checks)
- [ ] Documentation updated if needed
