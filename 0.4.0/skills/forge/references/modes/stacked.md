# Forge — `stacked` flag

Step 3 branches off another in-flight PR's HEAD instead of the repo's base branch, and Step 12 pushes to the stacked-PR convention so the new PR targets the base PR rather than main. Used when the current change logically depends on an in-review PR that has not merged yet.

## Manual verification recipe

```
/forge issue 42 stacked:47
```

Or, without a specified base PR:

```
/forge issue 42 stacked
```

Expected: Step 3 fetches PR #47, checks out its head ref (or creates a worktree if `worktree` is also set), then creates the new branch off that head ref instead of main. Step 12 push targets the stacked-PR convention (see "Step 12 stack handling" below). The resulting PR has PR #47 as its base, not main.

## Specifying the base PR

| Source | Format | Example |
|---|---|---|
| Flag value | `stacked:<N>` (PR number) | `stacked:47` |
| Stacked-PR tool detection | Graphite `gt log short` → top in-flight PR; spr → similar | (auto-resolved if tool present) |
| User prompt | Step 3 interview listing in-flight PRs from the user | "Stack onto which PR?" |

Detection order: flag value → tool detection → user prompt. Under `automode`, only the first two sources work; if neither resolves, abort with "stacked: no base PR specified under `automode`".

## When it fires

Step 3 (branch creation) and Step 12 (push + PR opening). No effect on Steps 4–11.

## Behavior change vs default

| Stage | Default | With `stacked` |
|---|---|---|
| Step 3 base | `git switch -c <prefix>/<slug> main` (or repo-guide base) | `git switch -c <prefix>/<slug> <base-pr-head-ref>` |
| Step 12 push target | `git push -u origin <branch>` | Same; PR opens against `<base-pr-head-ref>` instead of main |
| Step 12 PR creation | `gh pr create --base main` (or repo guide) | `gh pr create --base <base-pr-head-ref>` |
| If using Graphite/spr | (manual) | `gt create -m "<title>"` / `spr update` per the detected tool's contract |

## Step 12 stack handling

For native git/GitHub: the PR opens against the base PR's head ref. Reviewers see only the diff specific to this stack level. When the base PR merges, the stacked PR auto-rebases (GitHub does this).

For Graphite (`gt`): `gt submit` opens both PRs in the stack at once if needed. Run `gt log` first to confirm the stack state; forge surfaces the state before any push.

For spr: similar; `spr update` handles the multi-PR sync.

## Rebase discipline

The base PR can move during review. When that happens, the stacked PR is stale until rebased. Forge does NOT auto-rebase mid-Phase-2 work; if the user wants a fresh rebase, surface it at Step 8 entry: "Base PR <N> has moved; rebase now? (y/n)". Under `automode`, auto-rebase only if the rebase is a fast-forward; otherwise surface the conflict and pause (this is one of the rare automode pauses — a conflicting rebase needs human judgment).

## Composition with other flags

| Combination | Effect |
|---|---|
| `stacked` + `worktree` | **Recommended pairing.** Each stack level can live in its own worktree; the user keeps the original tree free. |
| `stacked` + `ci-watch` | Polls the stacked PR's CI, not the base PR's. Note CI status on a stacked PR can fail because of the base PR (race condition during base merge); surface the relationship in the report. |
| `stacked` + `backport` | Compose freely. Primary stack ships, then backports run against each stack tip. |
| `stacked` + `automode` | Base PR must be specified via flag value or tool detection; abort otherwise. Auto-rebase only on fast-forward conflicts. |
| `/forge pr <N>` + `stacked` | Ignored. PR-review mode already targets an existing PR; stacking would create a new layer that has no relationship to the review. |

## Anti-pattern (encoded in [anti-patterns.md](../anti-patterns.md) by PR 4e)

Rebasing the stack wrong and clobbering the base PR's commits. The base PR may have new commits since you stacked; `git rebase --onto <new-base-pr-head>` is the safe operation, not `git rebase <new-base-pr-head>`. If using Graphite/spr, the tool handles this — do not mix manual rebasing with tool-driven sync.

## `automode` behavior

See [autonomy.md](../autonomy.md). Base PR must come from a non-interactive source; rebase pauses on non-fast-forward conflict (one of the rare automode interrupts).
