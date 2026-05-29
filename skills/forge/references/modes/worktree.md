# Forge — `worktree` flag

Composes the `superpowers:using-git-worktrees` skill at Step 3. The branch is created in a sibling worktree directory rather than switched in-place, so your editor can keep the original working tree open while forge works.

## Manual verification recipe

```
/forge issue 42 worktree
```

Expected: Step 3 detects the flag, creates a sibling worktree (e.g. `../<repo>-<slug>/`) on the chosen branch instead of switching in-place. Subsequent edits and commits target that worktree path. Step 12 closing reminds the user to remove the worktree once the changes land or are discarded.

## When it fires

Step 3, after the branch name is resolved (per repo guide or the default `<prefix>/<slug>` fallback) and before the `git switch -c` decision.

## What it composes

`superpowers:using-git-worktrees`. Read that skill for the worktree creation, layout, and cleanup conventions — this flag routes Step 3 through it.

## Behavior change vs default

| Stage | Default | With `worktree` |
|---|---|---|
| Step 3 branch creation | `git switch -c <prefix>/<slug> <base>` in the current tree | `git worktree add <path> -b <prefix>/<slug> <base>` (path per the worktree skill's convention) |
| Edits | Apply to the current working tree | Apply to the worktree directory; the original tree is untouched |
| Step 12 | Commit and (optionally) push from the current branch | Commit and (optionally) push from the worktree; closing menu adds a cleanup reminder |
| Cleanup | Switch back to base branch when done | Run `git worktree remove <path>` (or accept the closing-menu reminder to do so) |

## Composition with other flags

| Combination | Effect |
|---|---|
| `worktree` + `automode` | Worktree is created without prompting. Cleanup at Step 12 stays opt-in even under `automode` — the worktree lives until the user removes it (`automode` never deletes user state). |
| `worktree` + `tdd` | Compose freely. Tests run inside the worktree; the original tree is unaffected by red/green output. |
| `worktree` + `docs` | `CONTEXT.md` is written inside the worktree, not the original tree. |

## Step 12 closing addendum

When `worktree` was set, the Step 12 closing message appends one line:

> Worktree at `<path>` — run `git worktree remove <path>` (or `git worktree prune` if the branch was deleted) when you're done.

This addendum is informational. It does NOT auto-remove the worktree, even under `automode` — losing in-progress state because a flag inferred you were "done" is the wrong default.

## Anti-pattern (encoded in [anti-patterns.md](../anti-patterns.md))

Leaving the worktree behind after Step 12 closes. Disk fills with stale worktrees; `git worktree list` becomes noise. Read the closing addendum; remove the worktree once changes are merged or discarded.

## `automode` behavior

See [autonomy.md](../autonomy.md) — `worktree` composability row says creation is automatic, cleanup is not. Cleanup never runs under `automode`.
