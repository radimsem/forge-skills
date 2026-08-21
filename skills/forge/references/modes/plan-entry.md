# Forge — plan-entry mode

Loaded on demand when the invocation is `/forge plan <path>`.

## Manual verification recipe

```
/forge plan docs/superpowers/plans/2026-08-21-auth.md#task-3
```

Expected: Steps 1, 2, 4, 5 and 6 collapse into a single Step P validation pass; Step 3 still resolves the branch; implementation begins at Step 7 with `/goal` derived from the slice's own `Run:`/`Expected:` lines and stated deliverable.

## The not-dispatch-ready fallback

**A slice that fails any Step P check other than anchor resolution is not dispatch-ready. When that happens, fall back to normal forge Part 1 (Steps 4–6: check context, propose, gate) instead of implementing.** Implementing on a check that failed is exactly the failure each check exists to catch; falling back costs one extra interview-and-propose pass, which is cheap next to shipping the wrong thing. The individual failure cases below all resolve to this rule; none of them repeat it.

The one exception is an unresolvable slice anchor (see Slice addressing) — that case stops and asks instead, because Part 1 needs to know *which* task to propose against, and forge cannot guess that.

## Step P — plan validation

Replaces Steps 1, 2, 4, 5 and 6. In order:

1. **Resolve the plan slice and confirm its stamp matches this invocation.** The stamp is whatever ties the plan to what it was written against, checked in this order: a `Spec:` line in the plan file naming the design doc it implements; failing that, a recorded base SHA (a `Base:` line or equivalent); failing both, the plan file's own last commit compared against current `HEAD` for the paths the slice names. On mismatch, warn, name what changed (the stale field or the diverged paths), and fall back per the rule above. Implementing a stale slice — one written against a codebase state that has since moved — is precisely the failure this check exists to prevent; proceeding anyway would silently implement against assumptions that no longer hold.
2. **Confirm every path the slice names exists.** On any missing path, warn, name the missing paths, and fall back per the rule above. Do not stop dead — a plan written before a refactor is a normal, recoverable case, and Part 1's interview can re-ground the slice against the current tree.
3. **Resolve the slice anchor and derive `/goal` from the slice's stated pass criteria.** See Slice addressing for anchor resolution. Derive `/goal` from the slice's own `Run:` / `Expected:` lines and its stated deliverable — the structural shape plan files in this repo actually use, not a paraphrase of the task title. If the slice carries neither `Run:`/`Expected:` lines nor a stated deliverable, it is not dispatch-ready: fall back per the rule above to establish pass criteria through the normal Step 4/5 interview. `/goal` itself never degrades once set — it is a hard floor, and Step 12 refuses to assemble a commit until it verifies green, so a vaguely-derived `/goal` is worse than falling back to get a precise one.
4. **Treat the slice as the approved Step 5 proposal.** Only once checks 1–3 have passed (or item 3's automode single-heading exception applied) does the slice's own approval satisfy the gate — Step 6 is not re-run.

Step 3 still runs: branch naming, base selection and the clean-tree check are not optional because a plan exists.

Where the slice links an issue and lacks pass criteria, Step 2's fetch is permitted to fill that gap before falling back — a linked issue with acceptance criteria can make the slice dispatch-ready without a full Part 1 pass.

## Slice addressing

`<path>#<task-heading-slug>` addresses one task within a multi-task plan file. Omit the fragment to address the whole file when the plan describes a single task.

If `<task-heading-slug>` matches no heading in the file, the anchor is unresolvable. This does not fall back to Part 1 — Part 1 still needs to know which task to propose against, and forge cannot guess that from an unresolvable fragment. Instead: stop, list the task headings found in the file, and ask the user which was meant. Under `automode`: if the file contains exactly one task heading, use it and record the assumption in the proposal; otherwise abort and report the mismatch, since guessing among multiple candidates risks implementing the wrong task unattended.

## Behavior change vs default

| Stage | Default forge | `/forge plan <path>` |
|---|---|---|
| Steps 1–2 | Classify `<ref>`, resolve repo/tracker, fetch issue body + comments | Skipped — Step P resolves the plan slice directly, no tracker fetch unless the slice links an issue lacking pass criteria |
| Step 3 | Branch off base, optional in-place switch | Unchanged — still runs; branch naming, base selection and the clean-tree check are not optional |
| Steps 4–6 | Check context sufficiency, propose the solution, gate on user approval | Skipped when the slice is dispatch-ready — Step P confirms stamp, paths and pass criteria and treats the slice's own approval as satisfying the gate. Otherwise Step P falls back to this range unchanged (see The not-dispatch-ready fallback) |
| Step 7 | Implement against the interviewed/proposed plan | Implements against the plan slice; `/goal` is derived from the slice's stated `Run:`/`Expected:` lines and deliverable |
| Step 12 | Closing menu per default forge | Unchanged — closing menu and `/goal` verification run as in default forge |

## Composition with other flags

| Flag | Effect under plan-entry |
|---|---|
| `docs` | Redundant — the plan slice *is* the sourced plan. Accepted with a one-line note; no separate `CONTEXT.md` sourcing occurs. |
| `tdd` | Composes normally — Step 7 still writes and observes the failing test before implementing. |
| `automode` | Unaffected — the gate is already satisfied by the plan's own approval, so `automode` changes nothing about Step P. The one place `automode` does change behavior is the anchor-resolution exception in Slice addressing. |
| `codex impl` | Delegates the plan slice to Codex at Step 7 exactly as it would delegate a chat-approved proposal. |
