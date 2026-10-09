# Protected-main migration

The coordinated migration is tracked in [z-shell/.github#771](https://github.com/z-shell/.github/issues/771), with policy in [#772](https://github.com/z-shell/.github/issues/772) and implementation in [zi#628](https://github.com/z-shell/zi/issues/628). [ADR-0039](https://github.com/z-shell/.github/blob/main/decisions/0039-zi-main-integration-and-signed-milestones.md) requires maintainer acceptance on main and verified cutover before ordinary contribution targets change.

## Verified staging delivery

- ADR-0039 was accepted through [organization policy #773](https://github.com/z-shell/.github/pull/773). [Zi #629](https://github.com/z-shell/zi/pull/629) staged replacement qualification and signed milestones under the existing next rules.
- [Promotion #630](https://github.com/z-shell/zi/pull/630) delivered candidate `4a91dbb1b401df7c52a125f0ee1cbb53e1f700ae` as verified merge `6840325cf4974c82324c08fdcbee004b0fc9274b`, with prior main `199bbcafddde93ab22f3fcf9e000e81ac3a75385` as its first parent and the candidate as its second. The candidate tree `208b3063ca68d0b9d07409c62c4e0184cfedce6c` was retained. All main content and historical tags were preserved; no back-merge, reset or force-push was needed.
- The real main PR passed [full stable qualification](https://github.com/z-shell/zi/actions/runs/37931912734), including all six Linux/macOS Zsh legs and ZD compatibility. The actual aggregate command rejects each failed, cancelled or skipped constituent in focused regression tests.
- [Historical issue reconciliation](https://github.com/z-shell/zi/actions/runs/37948678641) found no unqualified closing clause outstanding in the final promoted PRs. A read-only local replay agreed. Issue #628 remains open for the coordinated cutover.
- An isolated existing clone at prior main self-updated through the public main remote to `6840325c`, reloaded that revision, preserved its checkout and loaded revision after a failed fetch, and succeeded on retry. This observation used Linux Zsh 5.9.2; hosted macOS validation is separate evidence.

The source-policy removal is a cutover candidate until its fork PR qualification and live replacement rules are verified. Post-merge qualification, fresh installation on the final cutover SHA, downstream policy/wiki/tracking synchronization and separately authorized retirement of next remain required. Retain next and its protection while those steps are pending.

## Stage replacement qualification

Use the current next/promotion rules to deliver the migration. The stable qualification workflow keeps its file, workflow name and required `Promotion gate` context so existing main protection continues to work. It now runs on every main PR and push, calls the full Zsh matrix and ZD compatibility, and requires all six constituent results to succeed. The Zsh PR trigger covers both main and next during transition. Existing policy/contract/Trunk/CodeQL/Zsh/routing checks on next remain applicable until cutover.

Automatic promotion release publication is removed before ordinary main PRs are admitted. Release planning is read-only and milestone publication requires a separately authorized signed tag. Renovate's target changes to main; coordinate its scheduling with the guard cutover so a transitional bot PR can be retargeted rather than bypassing checks.

## Verify and switch protection

1. Record both live branch SHAs, trees and unique commits, tags, open PR heads/targets, rulesets and required context names. Main-only promotion commits with identical trees do not justify a back-merge. Preserve unmerged topic work and task owners.
2. On a real main PR from next under the current source guard, observe the full qualification results and exact head. Test fork execution and rejection of failed, skipped or cancelled constituents; revalidate when the base changes. Do not treat local workflow lint as hosted enforcement proof.
3. Preserve `Promotion gate` and the applicable policy, contract, Trunk, CodeQL, Zsh and routing contexts from the integration ruleset on protected main, with signed commits, resolved review threads, applicable review of record and force-push/deletion protection. Prove each context is emitted before requiring it. Existing approval counts are not a waiver of organization review policy.
4. After those checks work, remove `Guard main branch source` from the main ruleset and retire its workflow, script and focused test in the owning change. Remove the retired test's Zsh workflow registration. Do not bypass protection to merge the migration.
5. Confirm ordinary same-repository and fork topic PRs target main, pass the required checks and cannot merge with failed qualification. Retarget open next PRs with their owners. Prefer the organization merge policy for short-lived topics; do not rewrite historical promotion merges.
6. Update the meta-repository Zi tracking declaration, active task bases, actionable wiki/src references and bot targets. Remove obsolete next triggers from Zsh, ZD, Trunk, CodeQL, commit lint, routing and benchmark workflows after contributors switch.

## Delivery, retirement and rollback

Verify fresh installation and startup and existing-clone self-update on the delivered main SHA, including failure preservation and recovery. Existing loader/install/update main defaults remain unchanged. Any tag-based user channel needs a separate product migration.

Reconcile issues from historical next PRs using their merge-time bodies and delivered main ancestry before retiring `promotion-issue-closure.yml`, `scripts/close-promoted-issues.zsh`, `tests/promoted-issue-closure.zsh` and its test registration. Preserve evidence of ambiguous or manually handled issues. Once retained history, open PRs and external references are accounted for, separately authorize removal of remote next and its obsolete ruleset; no unrelated topic branch is a cleanup target.

If replacement checks fail before cutover, keep the existing branch policy and repair the staged change. After cutover, repair or revert through reviewed PRs into protected main. Never reset or force-push stable history or move a published tag. Restoring a persistent next branch requires a separate scope decision and restored policy, qualification and enforcement.
