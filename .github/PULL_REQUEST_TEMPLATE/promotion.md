# Promotion readiness record

Use this template only for a same-repository `next` to `main` promotion.
Ordinary work continues to target `next`; urgent production fixes use a
same-repository `hotfix-*` branch.

## Candidate identity

- Prior `main` SHA: `____________________________`
- Candidate `next` SHA: `____________________________`
- Complete compare:
  [`main...next`](https://github.com/z-shell/zi/compare/BASE_SHA...HEAD_SHA)

Replace `BASE_SHA` and `HEAD_SHA` in the compare link with the exact SHAs above.
The PR head SHA must still equal the recorded candidate SHA before merge.

## Required validation

The `Promotion gate` check is the ruleset context. It directly depends on every
constituent below and fails if any constituent fails, is cancelled, or is
skipped.

| Validation                                | Stable job name             | Result  |
| ----------------------------------------- | --------------------------- | ------- |
| Zsh syntax and compile                    | `Zsh syntax and compile`    | Pending |
| ZD ZUnit integration                      | `ZD integration`            | Pending |
| Trunk                                     | `Trunk`                     | Pending |
| CodeQL                                    | `CodeQL`                    | Pending |
| Exact-candidate clean install and startup | `Clean install and startup` | Pending |
| Aggregate                                 | `Promotion gate`            | Pending |

- [ ] `z-shell/zd#95` is merged and the reusable workflow pin represents its
      immutable Zi-SHA contract.
- [ ] `z-shell/zd#96` is merged and the reusable workflow pin includes its
      focused compatibility tests.
- [ ] The candidate SHA has not changed since all required checks completed.

## Readiness review

### Unresolved issues

List each unresolved issue and its disposition. Write `None` only after checking
the promotion candidate and linked release work.

### User-facing and migration notes

Summarize behavioral changes. If no migration is required, state why.

### Public-contract follow-ups

Link documentation and consumer follow-ups identified by the
[#376 public-contract impact review](https://github.com/z-shell/zi/issues/376).
Write `None` only with a rationale.

## Rollback readiness

- Rollback owner: `@________________`
- Observable rollback criteria:
  - `____________________________________________________________`
- [ ] The prior `main` SHA above is confirmed immediately before merge.
- [ ] The owner can open a same-repository `hotfix-*` PR that reverts the
      promotion commit through protected `main`.
- [ ] The revert PR will run `Guard main branch source` and `Promotion gate`.
- [ ] After a revert, clean install and startup will be confirmed at the new
      `main` head.

Never force-push `main`. Roll back with a reviewed revert commit through the
protected-branch hotfix path so the incident and recovery remain auditable.

## Publication boundary

Merging this promotion updates the Git-consumed `main` branch. It does not
create a semantic tag or GitHub release. Tagging remains a separately approved
publication action under [#346](https://github.com/z-shell/zi/issues/346), with
its own release notes and green validation.

## Bootstrap and post-merge ruleset change

Do not change repository settings from the implementation PR. GitHub evaluates
`pull_request` workflow definitions from the default branch, so merging this
file only into `next` cannot activate it for a `next` to `main` PR.

After the implementation and both ZD dependencies are merged:

1. Create `hotfix-377` from `main`.
2. Copy the reviewed promotion workflow and templates from `next` without other
   pending `next` changes.
3. Open the same-repository hotfix PR into protected `main`. The existing exact
   context `Guard main branch source` must pass. Do not bypass or force-push.
4. Merge the bootstrap PR, then open the `next` to `main` promotion PR. Confirm
   that all constituent jobs and the exact context `Promotion gate` run.
5. Update only the active `main` ruleset's required status checks: keep
   `Guard main branch source` and add `Promotion gate`.
6. Keep strict required-status-check policy disabled unless maintainers approve
   a separate policy change.
7. Do not add constituent contexts; `Promotion gate` owns their dependency
   semantics, and the ZD reusable workflow expands to matrix checks.

Leave the `next` ruleset unchanged. Promotion validation runs only for PRs into
`main`, so ordinary PRs into `next` remain lightweight. After the promotion,
reconcile `main` back into `next` through the protected pull-request process.
