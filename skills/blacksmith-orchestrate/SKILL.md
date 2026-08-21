---
name: blacksmith-orchestrate
description: "Orchestrate many forge runs at once: analyze which tasks collide on the same files, schedule the colliding ones sequentially, and run the rest in parallel worktrees at the right model tier and review depth. Use when the user runs /blacksmith-orchestrate or asks to ship several issues, a milestone, or a written implementation plan in one go."
---

# Blacksmith Orchestrate

> Decide **which tasks run, in what order, at what depth, by which model, in which worktree** — then dispatch one forge run per task.

## Overview

This is a wrapper around `forge`, not a fork of it. It never reimplements a forge step: every task it dispatches runs the ordinary twelve-step forge workflow, and everything this skill adds is a decision *about* those runs — which ones may run at the same time, how deep each one goes, and where each one's work lives.

Nine numbered steps, split by one gate, deliberately mirroring forge's shape:

```
Part 1 — Plan (1–5):     normalize → materialize → analyze → schedule → [GATE] battle plan
Part 2 — Execute (6–9):  provision → dispatch waves → relay → close-out

  gate held: no worktree is created and no forge Part 2 runs until "yes, forge them"
```

| Step | Action |
|---|---|
| 1 | Parse the invocation; split orchestrator flags from pass-through forge flags; route the work source into a canonical task list |
| 2 | Materialize refs — spec-file and free-form routes get real issue refs via `/to-issues`, or synthetic `T1..Tn` IDs if the user declines filing |
| 3 | Analyze — route each task to the plan-sourced path or the scout fan-out |
| 4 | Build the collision graph, triage matrix and worktree grouping → scheduling waves |
| 5 | **[GATE]** one battle plan, one approval |
| 6 | Provision worktrees; write the run ledger |
| 7 | Dispatch waves — one agent per task at its assigned model tier and forge depth |
| 8 | Relay — prove a blocker's changes are on the dependent's base, rebase, release |
| 9 | Close-out — aggregate report, PR list, worktree cleanup reminders, self-evolution |

Forge's hard floors are inherited unchanged, and orchestrating many runs never relaxes them: no dispatched run auto-commits, auto-pushes, or writes back to a tracker, and every run's Step 12 `/goal` verification still has to pass before that run assembles a commit. The one documented exception is the `afk` flag, which lets the orchestrator merge a PR that is *blocking another task* after a self-verification checklist; it is labelled as the single sanctioned exception everywhere it appears, so the exception stays auditable instead of becoming a quiet contradiction. Terminal PRs, worktree cleanup and tracker write-backs stay with the user under every flag combination, `afk` included.

"The agent" means whatever agent runs this skill, and "one agent per task" means whatever subagent or parallel-run mechanism the runtime exposes. Adapt every reference — config directory, agent guide, interview UI, host CLI — to your runtime, exactly as forge does. If the runtime cannot run work in parallel at all, say so and fall back to running the waves sequentially rather than pretending to fan out.

## Parameters

Parse the invocation as `/blacksmith-orchestrate <work-source> [orchestrator-flags] [forge-flags]`. Flag words are orthogonal and can appear anywhere in the request, exactly as in forge. The `<work-source>` is one of five routes — one or more issue refs, a tracker container such as a milestone or epic or label, `plan <path>`, a quoted free-form goal, or `resume` — and routes may combine in a single invocation, so every task carries the route it arrived by. Read **[references/entry-routes.md](references/entry-routes.md)** for the route table, how the routes normalize into one task list, and how containers expand.

Full flag matrix (effects, composition rules, conflicts): **[references/flags.md](references/flags.md)**.

### Orchestrator flags

These are consumed by the orchestrator and are never passed through to a forge run. Each row's detail file owns that flag's behavior.

| Flag | Effect | Detail |
|---|---|---|
| `afk` | After a 5-minute quiet timeout, self-verify and merge **blocking PRs only** — the single documented exception to forge's never-auto-push floor | `references/afk.md` |
| `resume` | Resume a run from its ledger instead of starting a new one | `references/ledger.md` |
| `budget <n>` | Token ceiling for the run, with a deterministic degradation ladder | `references/scheduling.md` |
| `strict` | No depth downgrade; every task runs full forge | `references/triage.md` |
| `stack` | Blocked tasks base off the blocker's branch and open stacked PRs | `references/scheduling.md` |
| `rescout` | Force scout analysis even where dispatch-ready plans exist | `references/plan-sourced.md` |
| `max <n>` | Concurrent implementation agents; default `4` | `references/scheduling.md` |
| `dry` | Emit the battle plan and stop; dispatch nothing | `references/battle-plan.md` |
| `unified` / `split` | Override worktree grouping — one PR per coupled cluster, or one PR per task | `references/scheduling.md` |
| `plan <path>` | Source tasks from a written implementation plan; each plan task becomes one orchestration task | `references/plan-sourced.md` |

Every other flag forge understands passes through unchanged to every dispatched run: `automode`, `docs`, `tdd`, `lookup`, `secure`, `changelog`, `ci-watch`, `compress`, `codex`, `codex challenge`, `codex impl`, and `coderabbit`. Two of forge's flags are overridden rather than passed through as written. `worktree` is always implied and orchestrator-managed, because Step 6 provisions, names and tracks every worktree itself and a run-level worktree decision cannot be delegated to the individual runs; passing it explicitly is accepted with a one-line note rather than treated as an error, since the user is asking for what already happens. `automode` lifts the Step 5 battle-plan gate exactly as it lifts forge's Step 6 gate, and still passes through to each dispatched run; it does not lift any hard floor named in the Overview.

## When to Use

- `/blacksmith-orchestrate <refs>` with two or more issue or ticket refs.
- "ship this milestone", "implement this plan", "fix these five issues".
- A written implementation plan whose tasks should all land in one sitting.
- Any request to run several forge-shaped pieces of work together, where the ordering between them matters.

**Don't use** when:
- A single issue, ticket or PR is in scope. Use `/forge <ref>`: with one task there is no collision graph, no wave to schedule and no topology to choose, so the wrapper adds a second gate and buys nothing.
- No work source is given. Ask which issues, milestone or plan is meant rather than inferring a task list from the repo, for the reason in Step 1.

## Step 1 — Parse the invocation and normalize the work source

Split the invocation into three parts: the work source, the orchestrator flags from the Parameters table, and every remaining flag, which is forge pass-through. Route the work source into one canonical task list in which each task records the route it came from, because Step 3 chooses its analysis path per task rather than per run; the five routes, their combination rules and deduplication are in **[references/entry-routes.md](references/entry-routes.md)**. If no work source resolves — a bare invocation, or flags with nothing to act on — stop and ask which issues, milestone or plan is meant; inferring a batch from the repo would dispatch work nobody asked for across several worktrees at once, which is far more expensive to undo than one question is to ask. If both `unified` and `split` are present, stop and report the conflict instead of applying a precedence, because the two ask for opposite PR topologies and silently honouring one would hide from the user which shape actually shipped.

## Step 2 — Materialize refs

Every task needs a stable identifier before analysis, because the battle plan, the ledger, the worktree names and each dispatched forge run all address tasks by ref. Ref and container routes already have one; the plan and free-form routes do not, so file real issues for those tasks with **`/to-issues`** and adopt the returned refs, or fall back to synthetic `T1..Tn` IDs when the user declines filing — a synthetic ID is local to this run and never reaches a tracker, so any later step that would write to a tracker for such a task skips that write and names the skip in the Step 9 report. If a ref does not resolve to something its tracker can return, name it and ask whether to continue without it; under `automode`, drop it and record the omission in Step 9, because a silently missing task is indistinguishable from one that was never requested, and that is the single failure a batch run must never hide. Route mechanics — the `/to-issues` handoff, container expansion and which trackers are supported — are in **[references/entry-routes.md](references/entry-routes.md)**.

### Scouts never interview

This rule is stated here because it governs every ref Step 2 hands onward. A scout dispatched in Step 3 that hits a forge Step 4 context gap returns the open question rather than asking it, and never blocks waiting for an answer. The orchestrator batches every task's open questions into **one** consolidated interview attached to the Step 5 gate, using forge's proposed-answer format with the most likely option marked `(Recommended)` and "Other" implicit. A scout that interviewed on its own would stall a parallel fan-out behind N separate prompts and would split into N approvals the single approval the gate exists to collect. Under `automode` the `(Recommended)` answer is taken for every open question and the assumption is recorded in the battle plan, exactly as forge does at its own Step 4.
