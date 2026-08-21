# Blacksmith — `afk`: the sanctioned merge exception

The one flag in this skill that lets the orchestrator merge a PR without a human clicking merge. Loaded by Step 8 whenever a blocking PR is ready and `afk` is set.

## Manual verification recipe

A blocking PR with a red CI check, run under `afk`. Expected: no merge — check 2 of the verify checklist below fails immediately — a notification that the PR is red and parked, and the task stays parked. The next poll re-evaluates the same checklist from scratch; there is no retry loop waiting on this one check to turn green.

## Default — merge authority is human

Without `afk`, the orchestrator notifies the user that a blocking PR is ready, and parks. It never merges. This is the default for every run, `automode` included, and it preserves forge's stated hard floor — never auto-commit, auto-push, or write back to a tracker, even under `automode` — unchanged. Orchestrating many runs at once does not relax that floor for any single one of them.

## With `afk`

`afk` replaces the indefinite park with a bounded wait: notify → a 5-minute quiet timeout (no user message in the session, and the notification itself unacknowledged) → the orchestrator self-verifies the PR against the checklist below. The timeout exists so a user actively driving the session is never overridden mid-thought by an automatic merge they had no chance to weigh in on; silence for the full window is what stands in for that chance having passed.

## The verify checklist

Merging requires **every** item to pass, verbatim from spec §8:

1. the PR is mergeable with no conflicts;
2. CI is green for the PR head SHA across all required checks;
3. that task's forge review loop converged to zero actionable findings, read from the ledger;
4. there are zero unresolved human review comments or change requests;
5. the diff's file list is a subset of the approved proposal's file list;
6. `/goal` verifies green in the worktree at the PR head;
7. the base branch permits the merge.

Any single failure keeps the PR parked and notifies; there is no merge retry loop — the checks are simply re-evaluated on the next poll, exactly as they would be for a PR with no `afk` verification pending at all.

## Scope limits

`afk` merges **only PRs that block another task.** A terminal PR — one nothing in this run waits on — is always left for the user, even under `afk automode`; there is no wave gated on a terminal PR's merge, so nothing about the run's own progress requires it to land on any particular schedule, and taking merge authority the user never delegated for work that was not slowing anything down would spend the exception on a case it was never written to cover.

On a host with no PR CLI at all — `gh` or `glab` absent or unauthenticated — there is no PR for `afk` to act on in the first place: components produce local branches instead of PRs, per [relay.md](relay.md)'s "Without a host CLI" section, and `afk` is inert there and says so. This is not a degraded form of the exception; it is the exception having nothing to attach to, the same way a checklist item cannot fail against a PR that does not exist.

## Why this exception exists

`afk` is the **single sanctioned exception** to forge's no-auto-push floor, stated here, in `SKILL.md`, and in [flags.md](flags.md) wherever the floor itself is stated, so the exception cannot be read in one place and missed in another. It is opt-in and never a default — the flag has to be named on the invocation, and its absence leaves every run at the Default above, human merge authority, unconditionally. It is written down with its reasoning, rather than left as an emergent behavior of some other flag, precisely so the exception is auditable: a reviewer of this skill's prose can find every place forge's hard floor is touched by reading `flags.md`'s composition rules and this file, instead of discovering a silent contradiction of the README by watching a run merge something nobody approved.
