# Promotion readiness record

Use this template only for a same-repository `next` to `main` promotion.
Ordinary work continues to target `next`; urgent fixes use a same-repository
`hotfix-*` branch from `main`.

## Candidate identity

- Prior `main` SHA: `____________________________`
- Candidate `next` SHA: `____________________________`
- Candidate tree SHA: `____________________________`
- Complete compare:
  [`main...next`](https://github.com/z-shell/zi/compare/BASE_SHA...HEAD_SHA)

Replace `BASE_SHA` and `HEAD_SHA` with the exact SHAs above. Immediately before
merge, fetch again and confirm the pull request base and head still equal the
recorded SHAs.

- [ ] `git diff --name-only <candidate-next>...<prior-main>` produces no output.
- [ ] `git rev-parse '<candidate-next>^{tree}'` equals the recorded tree SHA.

Do **not** test whether `<prior-main>` is an ancestor of `<candidate-next>`.
That check cannot pass once any promotion has landed, because the promotion
merge commit exists only on `main`. The empty three-dot diff is the real
precondition: it confirms `main` holds no content the candidate lacks, and it
still fails when a genuine stable-only commit is missing.

If the diff is not empty, stop. Identify the omitted commit with
`git log --oneline <candidate-next>..<prior-main>` and merge the stable-only
hotfix or other commit forward into `next` through a reviewed pull request
first.

## Required validation

The `Promotion gate` check directly depends on every constituent below and
fails if any constituent fails, is cancelled, or is skipped.

| Validation                                | Stable job name             | Result  |
| ----------------------------------------- | --------------------------- | ------- |
| Zsh syntax and compile                    | `Zsh syntax and compile`    | Pending |
| ZD ZUnit integration                      | `ZD integration`            | Pending |
| Trunk                                     | `Trunk`                     | Pending |
| CodeQL                                    | `CodeQL`                    | Pending |
| Exact-candidate clean install and startup | `Clean install and startup` | Pending |
| Aggregate                                 | `Promotion gate`            | Pending |

- [ ] The candidate SHA has not changed since every required check completed.
- [ ] The `Guard main branch source` and `Promotion gate` required contexts pass.
- [ ] The complete file and commit compare contains only reviewed work.

## Readiness review

### Unresolved issues

List each unresolved issue and its disposition. Write `None` only after checking
the promotion candidate and linked work.

### User-facing and migration notes

Summarize behavioral changes. If no migration is required, state why.

### Public-contract follow-ups

Link documentation and consumer follow-ups identified by the public-contract
impact check. Write `None` only with a rationale.

- [ ] If the candidate introduces monitoring for a contract surface absent
      from the base, manually inventory that surface across the complete
      compare. The detector cannot classify changes that predate its baseline.

## Merge contract

Promotion must use **Create a merge commit**. Never squash or rebase the
persistent `next` branch into `main`.

Example maintainer command after all checks pass:

```sh
gh pr merge <number> --repo z-shell/zi --merge --admin \
  --subject "chore: promote next to main (#<number>)" \
  --body "Promotes the reviewed next candidate with preserved ancestry."
```

After merge, fetch both branches and verify the exact result:

```sh
git fetch origin main next
prior_main=<recorded-main-sha>
candidate_next=<recorded-next-sha>
candidate_tree=<recorded-tree-sha>

test "$(git rev-list --parents -n 1 origin/main | awk '{ print NF - 1 }')" -eq 2
test "$(git rev-parse 'origin/main^1')" = "$prior_main"
test "$(git rev-parse 'origin/main^2')" = "$candidate_next"
test "$(git rev-parse 'origin/main^{tree}')" = "$candidate_tree"
git merge-base --is-ancestor origin/next origin/main
git show-ref --verify refs/remotes/origin/next
```

- [ ] The resulting commit message has no bot, AI-agent, or automation
      `Co-authored-by` trailer.
- [ ] `delete_branch_on_merge` is still `false` and remote `next` still exists.
- [ ] The `main` ruleset allows only merge commits and does not require linear
      history.
- [ ] The `next` ruleset does not require linear history.

A successful promotion needs no routine back-merge. A later critical hotfix on
`main` must be merged forward into `next` before the next promotion.

## Rollback readiness

- Rollback owner: `@________________`
- Observable rollback criteria:
  - `____________________________________________________________`
- [ ] The owner can open a same-repository `hotfix-*` pull request that reverts
      the promotion merge through protected `main`.
- [ ] The revert pull request will run `Guard main branch source` and
      `Promotion gate`.
- [ ] After a revert, clean install and startup will be confirmed at the new
      `main` head, then the hotfix will be merged forward into `next`.

Never force-push either persistent branch. Roll back with a reviewed revert
commit so the incident and recovery remain auditable.

## Stable consumption boundary

Merging this promotion updates the Git-consumed stable `main` ref. It does not
create a semantic tag or GitHub release. Any later tag is a separately approved
action with its own release notes and exact-ref validation.
