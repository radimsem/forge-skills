# Forge — `/forge pr <N>` entry mode

A new top-level entry verb. `/forge pr <N>` enters the lifecycle at Step 8 against an existing pull request's diff instead of starting from an issue. Used when the user wants to review someone else's PR (or their own pre-merge) with the full forge reviewer pipeline.

## Manual verification recipe

```
/forge pr 47
```

Expected: Step 1 resolves PR #47 via the repo's host CLI (`gh pr view`, `glab mr view`, …). Step 2 fetches the PR body, comments, and diff. Step 3 checks out the PR's head ref locally (in-place switch by default, or worktree with the `worktree` flag). Steps 4–7 are **skipped**. Step 8 runs the full review loop against the PR's diff. Steps 9–11 follow as appropriate. Step 12 closing offers PR-review-specific options (leave-comment-only, push-fixup-commits, request changes, approve).

## Grammar

```
/forge pr <N>            # the canonical form
/forge pr #N             # also accepted (the # is decorative)
forge pr 47              # without leading slash, same as above
```

The `pr` keyword between `forge` and the number distinguishes this mode from `/forge <N>` (issue mode). A trailing number without the `pr` keyword still routes to issue mode per the existing grammar.

## When it fires

Step 1 routing detects the `pr` keyword first, before the issue/Jira-key shape match. PR-entry mode replaces Steps 4–7 with PR-context steps.

## Step modifications

| Step | Default forge | `/forge pr <N>` |
|---|---|---|
| Step 1 | Resolve issue/ticket ref via tracker | Resolve PR via host CLI (`gh pr view <N>`, `glab mr view <N>`, …) |
| Step 2 | Fetch issue body + comments | Fetch PR title + body + comments + diff |
| Step 3 | Branch off base, optional in-place switch | Check out the PR's head ref; worktree if `worktree` set |
| Steps 4-7 | Interview, propose, gate, implement | **Skipped** — there is no implementation; the diff already exists |
| Step 8 | Review loop against in-progress implementation | Review loop against the PR's existing diff |
| Step 9 | Refactor opportunities | Refactor opportunities surfaced as PR comments (not direct commits without user approval) |
| Step 10 | Spinoff issues | Same; spinoff items become PR comments or new issues per user choice |
| Step 11 | Self-evolution | Same |
| Step 12 | Closing menu (commit/push/Jira-write-back/etc.) | Closing menu shifts (see below) |

## Step 12 closing menu (PR-review mode)

Different options than issue mode:

```
PR-review done — how should the findings land?
  - Leave the findings as PR comments only, no fixup commits (Recommended)
  - Push fixup commits for the must-fix findings to the PR's head ref + leave comments for the rest
  - Approve the PR (requires zero remaining must-fix from Step 8)
  - Request changes on the PR with the Step 8 finding summary
  - Write the full review (findings + suggested commits) to /tmp/forge-pr-<N>.md and stop
  - Hold — leave the working tree as-is for manual review
```

The `ci-watch` flag is meaningful here too: if the user picked option 2 (push fixup commits), `ci-watch` polls the PR's CI for the new HEAD.

## Allowed and ignored flags

Flags that operate **at Step 8 or later** apply in PR-entry mode:

- `automode` — applies (no user gates)
- `codex` / `codex challenge` — applies (swaps generic reviewer)
- `secure` — applies (post-Step-8 security pass)
- `changelog` — applies (drafts entry for the fixup commits if option 2)
- `ci-watch` — applies (polls CI after option 2 push)
- `coderabbit` — applies

Flags that operate **before Step 8** are ignored with a one-line warning:

- `docs` — no plan to source from
- `tdd` — no implementation step
- `worktree` — actually composes: use worktree for the PR head checkout. Not ignored — see composition table below.
- `lookup` — no proposal to ground

## Composition with other flags

| Combination | Effect |
|---|---|
| `/forge pr <N>` + `automode` | Skip closing menu; emit review summary to `/tmp/forge-pr-<N>.md`; no auto-push of fixup commits. |
| `/forge pr <N>` + `codex challenge` | Codex `adversarial-review` runs against the PR diff; arguably the highest-leverage combination for design critique on a peer PR. |
| `/forge pr <N>` + `secure` | Security pass runs after the regular reviewer loop converges. Must-fix → can be addressed via option 2 fixup commits. |
| `/forge pr <N>` + `worktree` | The PR head checkout happens in a sibling worktree, not in-place. Useful when the user has uncommitted work in the original tree. |
| `/forge pr <N>` + `ci-watch` + option 2 | Push fixup commits, poll the PR's CI; on red, re-enter Step 8 against the now-failing state. |
