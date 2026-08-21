# Blacksmith — the relay

How a blocked task's park ends: the proof a blocker's changes are actually reachable from the dependent's base, and the rebase that follows it. Loaded by Step 8, and by [scheduling.md](scheduling.md) whenever it needs to know when a blocked task's wave is recomputed.

## Manual verification recipe

A blocking PR merged by squash. Expected: the SHA ancestor check (`git merge-base --is-ancestor <blocker-head-sha> origin/<base>`) fails, because squash rewrites the head SHA into a new commit that never existed on the blocker's branch; the `git log --grep` fallback then succeeds, matching the PR number in the squash commit's message on `origin/<base>`; and the relay releases on that positive proof.

## The relay

When a blocker's PR merges, the dependent is not released on the PR page's say-so. A merged label on a host UI is a claim about the host's state, not a proof about the dependent's worktree, and the two can disagree — the base can move again before the dependent rebases, or the merge can be reverted. The orchestrator proves the code is actually present on the base the dependent is about to build on:

```sh
git -C <dependent-worktree> fetch origin
git -C <dependent-worktree> merge-base --is-ancestor <blocker-head-sha> origin/<base>
git -C <dependent-worktree> rebase origin/<base>
```

A non-ancestor result does **not** release the relay — it means the blocker's commit is not reachable from the base yet, whatever the host UI claims, and the dependent stays parked. Squash-merges and rebase-merges both rewrite SHAs, so a squash- or rebase-merged blocker will *always* fail the ancestor check even after a real, successful merge — that is expected, not a signal of a stuck relay, and it is exactly why the ancestor check is not the only proof this mechanism has. The fallback proof is a `git log --grep` for the PR number on the base, plus a content assertion drawn from the blocker's proposal — a symbol or line the blocker was specified to introduce, checked for its presence on the base. Only a positive proof — the ancestor check, or the grep-plus-content fallback — releases the relay; a negative or inconclusive result on both leaves the task parked and re-checked on the next poll, exactly as an unmerged PR would.

A blocking PR closed without merging never produces a positive proof by either path: there is no commit to be an ancestor, and no merge commit for the grep to match on the base. The dependent stays parked, and the park is reported at close-out as blocked on a PR that closed unmerged — this is not treated as a relay failure to retry, because there is nothing left to retry: closing a blocking PR without merging it is the blocker task not completing, and the fix is for a human to reopen it, supersede it, or drop the dependent, not for the orchestrator to keep polling a proof that structurally cannot resolve.

A blocker branch that was force-pushed after the dependent already rebased onto an earlier state of it is caught by the same ancestor check, run again: the dependent's next relay attempt fetches the current `origin/<base>` and re-proves ancestry against whatever is there now, so a force-push that dropped the commit the dependent built on shows up as the ancestor check failing on a commit it previously passed. This is the same conservative default this graph applies everywhere information is missing or has changed underneath it — a stale rebase is not assumed still valid, it is re-proven every time the relay is asked to release.

## Parking

Parked is not blocked-forever: every unblocked wave keeps running while a task parks. A parked task is waiting on one specific proof, not on the whole run, so its wave being idle never idles any other wave — [scheduling.md](scheduling.md)'s wave gating already treats this as the ordinary case, not a stall.

## Without a host CLI

If `gh` or `glab` is absent or unauthenticated, no PRs are opened at all. Components produce local branches instead, the ancestor proof runs against the local base branch — `<local-base>` in place of `origin/<base>` in the commands above, since there is no remote host state to fetch — and close-out reports the branches for the user to publish. `afk` is inert in this mode and says so: there is no PR for it to notify about, self-verify, or merge, since `afk`'s entire mechanism operates on a host PR, and a host with no CLI at all offers `afk` nothing to act on.

## Without a landable commit (`automode`, no `afk`)

Under the three-way commit-and-PR rule stated in `SKILL.md`'s Overview and Step 7, an `automode` run without `afk` never reaches its own Step 12 commit: every dispatched run stops at a plan-only file, exactly as a standalone `automode` forge run does. That leaves a blocked task's relay with nothing to prove ancestry against — no commit exists anywhere the blocker's worktree could be fetched from, so the ancestor check and its grep-plus-content fallback both have no target to test, not merely an unmet one. A dependent task behind a blocker dispatched under this combination stays `parked` for the remainder of the run: this is not a stall the relay is expected to resolve later, and it is not a relay failure to retry the way a closed-without-merging blocking PR is — it is the reported outcome of the flag combination itself, named explicitly at close-out by ref rather than discovered by the user only when nothing ever un-parks. See [ledger.md](ledger.md)'s "`pr-open` and `merged` under `automode` without `afk`" for the matching ledger-state consequence.
