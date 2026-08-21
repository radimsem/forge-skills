# Blacksmith — the plan-sourced analysis route

How Step 3 turns a written implementation plan into forge dispatches without spawning a scout for any task the plan already answers. Loaded by Step 3 and by the `rescout` flag row.

## Manual verification recipe

```
/blacksmith-orchestrate plan docs/superpowers/plans/2026-08-21-auth.md dry
```

Expected against a fresh plan (paths current, base SHA matching `HEAD`): zero scout agents spawned. Every task in the battle plan is annotated `route: plan-sourced` and dispatches through `/forge plan <path>#<task-heading-slug>`.

```
/blacksmith-orchestrate plan docs/superpowers/plans/2020-01-01-stale-example.md dry
```

Expected against a plan naming a path that no longer exists: the affected task is flagged **stale** on the battle plan with the diverged path named, and Step 3 routes that task to a scout instead — the rest of the plan's tasks, if their own paths are still current, stay plan-sourced.

## Detection order

A task's plan source is resolved in this order, and the first hit wins:

1. An explicit `plan <path|glob>` argument in the invocation.
2. `docs/superpowers/plans/*.md`.
3. `docs/superpowers/specs/*-design.md`.
4. A plan location named by the repo's own `CLAUDE.md` / `AGENTS.md` — an explicit path or glob the guide states. If the guide names a location that resolves to no existing file or directory, this tier is skipped with a one-line note rather than treated as a match; an unresolvable configured path degrades, it does not stall the run.

A task that matches none of these has no plan source and goes straight to the Step 3b scout fan-out; that is not a failure, it is the expected outcome for refs, containers, and free-form tasks that never claimed a plan.

**A tier that matches more than one file is ambiguous, not resolved.** Tiers 2–4 are globs over directories that normally hold many files once a few features have shipped, so matching several plans is a routine outcome, not an edge case. Ambiguity is not-dispatch-ready, and not-dispatch-ready means scout: the orchestrator does not guess which of several candidates governs this task. It lists the candidate files and asks which plan applies, in the Step 5 proposed-answer format. Under `automode`, where it cannot ask: if exactly one candidate contains a task that corresponds to the work source, use it and record the assumption on the battle plan; otherwise fall back to Step 3b scouting for that task. Falling back costs one scout run; guessing wrong costs implementing a plan written for different work — the same trade the dispatch-ready ladder already makes everywhere else: when a cheap check cannot establish an answer, the fallback is to scout, not to improvise.

## Task boundaries come from the plan

`writing-plans` defines a task as "the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate." The orchestrator does not re-decompose a plan's task list against that or any other rule — the plan author already drew the boundaries, and a plan is exactly the case in Step 1's grammar where boundary-drawing is not the orchestrator's job. Slice addressing follows forge's own plan-entry grammar: `<path>#<task-heading-slug>` for one task within a multi-task plan, or the whole file for a single-task plan.

## Dispatch-ready check

A task is dispatch-ready — eligible to skip the scout and go straight to `/forge plan <path>` — only when all three hold:

1. The plan slice names a concrete file list for the task (not "various files" or an unstated scope). Naming a list is necessary but not sufficient on its own — whether those paths still exist on disk *today* is a separate, ongoing check; see the Freshness guard below.
2. The plan slice states pass criteria for the task — `Run:`/`Expected:` lines or an equivalently concrete deliverable.
3. The plan slice's scope boundary is unambiguous — nothing in the task's own description implies work outside the file list in condition 1.

Each condition can fail independently, and each failure degrades differently rather than falling back to a full scout by default:

| Missing | Degradation |
|---|---|
| File list | Cheap hydration: a targeted grep pass scoped to that task alone — not a scout, not a repo sweep — to recover a file list before dispatch. |
| Pass criteria | The orchestrator derives pass criteria from the task's own text and confirms the derivation at the Step 5 gate. This never skips confirmation, because `/goal` is a hard floor forge refuses to proceed without, and a guessed `/goal` that nobody confirmed is worse than one that cost a gate round-trip. |
| Scope boundary | Full scout. An ambiguous boundary is not a gap a grep pass or a derived criterion can safely close — the orchestrator cannot tell what it doesn't know is out of scope, so only a forge Part 1 pass, run against the live tree, resolves it. |

This is the same situation forge's own `plan-entry.md` describes as the **not-dispatch-ready fallback**, seen from the other caller: standalone `/forge plan <path>` falls back to its own Part 1 (Steps 4–6) when a slice fails a Step P check; here the orchestrator falls back to scouting that task instead. Both rules exist because implementing on a check that failed is exactly the failure the check exists to catch, and both resolve the same way — stop dispatching against the unverified assumption, spend one cheap pass to ground it, and only then proceed. Nothing in either file should be read as contradicting the other; they are the same rule with the caller swapped.

## Plan task order is a declared dependency edge

A plan's task list is assumed to be a blocker chain — task 2 depends on task 1 having landed — unless one of two conditions lifts the assumption:

- The plan explicitly marks tasks independent, or
- Two tasks' file sets are disjoint **and** the plan's File Structure section shows no shared interface between them.

Both conditions must hold for the second case; disjoint file sets alone are not enough; a shared interface described only in prose and not the file list still creates a real edge that a `filesToTouch` diff would miss.

## Triage inputs for a plan-sourced task

A plan-sourced task never runs a scout, so `difficulty`, `blastRadius` and `symbols` are never populated the scouted way — and [triage.md](triage.md)'s and [collision-graph.md](collision-graph.md)'s undeterminable defaults are not meant to be the common case for a route that exists specifically to be cheap. The orchestrator grades both triage axes and lists the symbols from the slice text itself before Step 4 sees the task: the files the slice already names (condition 1 of the dispatch-ready check above) for file count and symbol candidates, the plan's own File Structure section and prose for new-interface and algorithmic-content signals that inform `difficulty`, and the surface the slice's deliverable touches — user-facing, auth/payment-adjacent, public API, migration, existing test coverage — for `blastRadius`. This is the same grading [triage.md](triage.md) already describes, done by reading the plan instead of by dispatching a scout to rediscover it.

The undeterminable defaults — `difficulty: high`, `blastRadius: high`, `symbols: []` — apply to a plan-sourced task only when the slice genuinely does not say, the same standard the dispatch-ready check above already applies to a missing file list or missing pass criteria: silence in the text, not merely the absence of a scout run. Grading every plan-sourced task to the undeterminable defaults by default would put every one of them at `opus × full` with every edge hard, which defeats the entire reason this route exists — a written plan is supposed to be *cheaper* to dispatch from than a scout, not more conservatively triaged than one.

## Freshness guard

A plan-sourced task's dispatch-readiness is void the moment its plan slice no longer describes the tree it will run against:

- Every path the slice names must still exist.
- The slice's stamp — a recorded base SHA where the plan states one, otherwise the plan file's own last commit — is compared against current `HEAD` for the paths the slice names.
- Any changed path in that comparison flags the task **stale**. A stale task falls back to scouting rather than dispatching against a plan written for a tree state that has since moved; scouting rebuilds the file list and scope from the live tree instead of trusting a description that stopped matching it.

**When no base SHA can be determined at all** — no `Base:` line in the plan, and the plan file itself has no commit yet — the second bullet has nothing to compare against. This is not an exotic case; it is the *most common* one, because the natural workflow is brainstorm → write plan → orchestrate in a single session, before the plan file is ever committed. A slice in this state cannot be *proven* fresh, but it must not be treated as **stale** either — blocking here would break the exact workflow this route exists to serve. Fall back to the path-existence check alone (the first bullet), record the gap on the battle plan as a stated assumption — `freshness unverified: plan not yet committed` — and proceed. An uncommitted plan is almost always one just written, so the risk the stamp check guards against, a plan written against a tree state that has since moved, barely applies here; surfacing the assumption costs one line on the battle plan, while blocking costs the user their whole flow.

This is forge's own `docs` stamp check — the same staleness test `/forge plan <path>` runs against a single slice at its own Step P, including its own no-determinable-base-SHA fallback — applied here across a set of tasks before any of them is scheduled.
