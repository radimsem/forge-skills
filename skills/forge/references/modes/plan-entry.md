# Forge — plan-entry mode

Loaded on demand when the invocation is `/forge plan <path>`.

## Manual verification recipe

```
/forge plan docs/superpowers/plans/2026-08-21-auth.md#task-3
```

Expected: Steps 1, 2, 4, 5 and 6 collapse into a single Step P validation pass; Step 3 still resolves the branch; implementation begins at Step 7 with `/goal` derived from the plan slice's testable deliverable.

## Step P — plan validation

Replaces Steps 1, 2, 4, 5 and 6. In order:

1. Resolve the plan slice and confirm its stamp matches this invocation.
2. Confirm every path the slice names exists.
3. Derive `/goal` from the slice's testable deliverable.
4. Treat the slice as the approved Step 5 proposal — the plan's own approval satisfies the gate.

Step 3 still runs: branch naming, base selection and the clean-tree check are not optional because a plan exists.

Where the slice links an issue and lacks pass criteria, Step 2's fetch is permitted to fill that gap.

## Slice addressing

`<path>#<task-heading-slug>` addresses one task within a multi-task plan file. Omit the fragment to address the whole file when the plan describes a single task.

## Behavior change vs default

| Stage | Default forge | `/forge plan <path>` |
|---|---|---|
| Steps 1–2 | Classify `<ref>`, resolve repo/tracker, fetch issue body + comments | Skipped — Step P resolves the plan slice directly, no tracker fetch unless the slice links an issue lacking pass criteria |
| Step 3 | Branch off base, optional in-place switch | Unchanged — still runs; branch naming, base selection and the clean-tree check are not optional |
| Steps 4–6 | Check context sufficiency, propose the solution, gate on user approval | Skipped — Step P confirms slice paths exist and treats the slice's own approval as satisfying the gate |
| Step 7 | Implement against the interviewed/proposed plan | Implements against the plan slice; `/goal` is derived from the slice's testable deliverable |
| Step 12 | Closing menu per default forge | Unchanged — closing menu and `/goal` verification run as in default forge |

## Composition with other flags

| Flag | Effect under plan-entry |
|---|---|
| `docs` | Redundant — the plan slice *is* the sourced plan. Accepted with a one-line note; no separate `CONTEXT.md` sourcing occurs. |
| `tdd` | Composes normally — Step 7 still writes and observes the failing test before implementing. |
| `automode` | Unaffected — the gate is already satisfied by the plan's own approval, so `automode` changes nothing about Step P. |
| `codex impl` | Delegates the plan slice to Codex at Step 7 exactly as it would delegate a chat-approved proposal. |
