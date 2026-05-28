# Forge — `backport` flag

At Step 12, after the primary push completes, cherry-picks the merged commits onto additional base branches and opens follow-up PRs to each. The flag never auto-merges the backport PRs — the user reviews and merges them in order.

## Manual verification recipe

```
/forge issue 42 backport:release-1.0,release-2.0
```

Or, if your repo has a backport config:

```
/forge issue 42 backport
```

Expected: Steps 1–11 run unchanged. Step 12 verifies green and pushes the primary branch (per menu option 2 or 3). Then for each target base branch, forge creates a worktree on that base, cherry-picks the new commits, pushes the backport branch, and opens a follow-up PR. The primary close menu item completes; the backport PRs are surfaced as a one-line "Backports opened: <urls>" addendum.

## Specifying targets

| Source | Format | Example |
|---|---|---|
| Flag value | `backport:branch1,branch2` (comma-separated, no spaces) | `backport:release-1.0,release-2.0` |
| Repo config file | `.backport-branches` at repo root, one branch per line | `release-1.0\nrelease-2.0\n` |
| Env | `BACKPORT_BRANCHES` (comma-separated) | `BACKPORT_BRANCHES=release-1.0,release-2.0` |
| `CONTRIBUTING.md` | A `### Backport` or `## Backport branches` section listing branches as a bullet list | see project doc |
| User prompt | Step 12 interview when no source provided | Forge surfaces the candidate list from `git branch -r` filtered for release-shaped names and asks |

Detection order: flag value → `.backport-branches` → env → `CONTRIBUTING.md` → user prompt. First hit wins.

## When it fires

Step 12, after the primary push (option 2 or 3 from the closing menu) completes. Skipped if option 1 (no push) was picked — backport requires the primary branch to exist on the remote.

## Behavior change vs default

| Stage | Default | With `backport` |
|---|---|---|
| Step 12 push | Push the primary branch, open the primary PR | Same, then for each backport target: worktree → cherry-pick → push → open PR |
| Backport conflicts | (n/a) | Surface the conflict; do NOT auto-resolve. Pause and surface the conflict to the user. Under `automode`, abort the backport for that target (other targets continue) and record the abort in the closing summary. |
| Closing message | Per the chosen menu option | Adds "Backports opened: <pr-1>, <pr-2>, …" addendum |
| CI on backports | Per repo CI config | If `ci-watch` is set, the polling runs against the primary push only (per the existing `ci-watch` contract); backport PRs ship without polling |

## Composition with other flags

| Combination | Effect |
|---|---|
| `backport` + `automode` | Targets must come from a non-interactive source (flag value / config file / env). If only the user-prompt source would apply, abort with "backport: no target source available under `automode`". |
| `backport` + `ci-watch` | `ci-watch` polls the primary push only. To watch backport CI separately, re-invoke `/forge pr <backport-pr>` against each backport. |
| `backport` + `worktree` | Backport already creates worktrees per target; the user's `worktree` flag for the primary still applies separately. |
| `backport` + `changelog` | Changelog entry is included in the primary commits (which get cherry-picked, so each backport carries the entry too). If the changelog format requires per-version entries, the cherry-pick may need a follow-up edit — surface this once if detected. |
| `backport` + `stacked` | Compose freely. The primary stack ships first, then backports run against each stacked PR's tip. |
| `/forge pr <N>` + `backport` | Applies only if PR-mode option 2 (push fixup commits) was picked. Backports the fixup commits, not the original PR diff. |

## Anti-pattern (encoded in [anti-patterns.md](../anti-patterns.md) by PR 4e)

Cherry-picking backports before the primary branch lands. If the primary PR gets changes during review, the backports are stale. The flag's "open follow-up PRs immediately" behavior assumes the primary is final at Step 12 — verify the primary review is converged before the user actually merges.

## `automode` behavior

See [autonomy.md](../autonomy.md). Under `automode`, targets MUST come from a non-interactive source; backport conflicts abort the failing target while letting other targets continue.
