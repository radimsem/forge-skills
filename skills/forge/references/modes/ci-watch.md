# Forge — `ci-watch` flag

After Step 12 pushes the branch, polls the repo's CI for the pushed commit's status. On red, re-enters Step 8 with the CI failure as a finding so the loop can fix it. On green, reports the result and exits cleanly.

## Manual verification recipe

```
/forge issue 42 ci-watch
```
Then at the Step 12 closing menu, pick option 2 (push + PR) or option 3 (push + PR + Jira write-back).

Expected: after the push completes, forge polls the CI status for the pushed HEAD. On green, prints a one-line "CI green for `<sha>`" and exits. On red, re-enters Step 8 with the CI output as a must-fix finding; the loop applies the fix, pushes again, re-polls.

## When it fires

After Step 12 closing-menu actions complete the push. The polling only happens for menu options that actually push (2 and 3). Options 1, 4, 5, 6 silently skip `ci-watch` — polling without a published target is pointless.

## What it composes

No external skill. Uses the repo's host CLI for status checks:

| Host | Command |
|---|---|
| GitHub | `gh run list --branch <branch> --limit 5 --json status,conclusion,headSha,url` (poll until `status: completed`); then `gh run view <id>` for failure logs |
| GitLab | `glab ci status --branch <branch>` |
| Other | Host's status API or CI-provider CLI; if neither available, surface this once and skip |

If no CLI matches and no API path works, surface "ci-watch: no compatible CI surface detected" and exit cleanly (not a failure).

## Polling cadence

Initial wait: 30 seconds (give CI time to start). Then poll every 60 seconds. Cap at 30 minutes total wall-clock; past that, surface "ci-watch: timed out at <duration>, status still <pending|in_progress>" and exit. The user can re-check manually.

## Behavior change vs default

| Stage | Default | With `ci-watch` |
|---|---|---|
| Step 12 menu option 1, 4, 5, 6 | Execute as chosen | Same; `ci-watch` silently skips (no push to poll) |
| Step 12 menu option 2 or 3 | Push, open PR, exit | Push, open PR, poll CI; on green report and exit; on red re-enter Step 8 |
| Step 8 re-entry from CI red | (n/a) | Treat CI failure as a single must-fix finding; the regular 3-pass cap applies to the re-loop |

## Composition with other flags

| Combination | Effect |
|---|---|
| `ci-watch` + `automode` | At Step 12, `automode` skips the closing menu and emits a plan only (no push). With no push, `ci-watch` has nothing to poll — silently skips. Combination is valid but functionally inert under `automode`. |
| `ci-watch` + `secure` | If CI fails on a security check, the failure re-enters Step 8 as a regular must-fix; `secure`'s dedicated post-pass runs again after the regular loop reconverges. |
| `ci-watch` + `changelog` | Changelog entry was drafted before the push; if CI fails, the entry is already in the pushed commits. After re-fix, decide whether to update the entry — usually yes if the fix is non-trivial. |
| `ci-watch` + `backport` (Phase 4) | `ci-watch` polls the base-branch CI; `backport` runs only after base-branch CI is green. |
| `ci-watch` + `stacked` (Phase 4) | Poll the stacked PR's own CI, not the base PR's. |

## Anti-pattern (encoded in [anti-patterns.md](../anti-patterns.md) by PR 3d)

Setting `ci-watch` without choosing a push option at Step 12 closing. Polling has no target; the flag becomes a no-op. The combination is allowed (no error) but worth surfacing in advance so the user picks option 2 or 3 deliberately.

## `automode` behavior

See [autonomy.md](../autonomy.md). Under `automode`, `ci-watch` is functionally inert because `automode` skips the closing menu and emits the small-commit plan only — there is no push to poll.
