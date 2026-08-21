# Blacksmith — the battle plan and the gate

The literal format of the one artifact Step 5 emits, and the approval semantics that govern it. Loaded by Step 5. This is the orchestrator's analogue of forge's `proposal-template.md`: the format below is a contract, not an example — an agent assembling the battle plan follows it verbatim.

## Manual verification recipe

Run any invocation with two or more tasks and `dry` set. Expected: the battle plan is emitted in full, in the format below, and the run stops there — no worktree is created, no ledger is written and no agent is dispatched, regardless of any other flag present in the same invocation (`afk` and `budget` are both reported as inert on the plan itself, per [flags.md](flags.md)'s composition rules, rather than silently having no visible effect).

## Format

The gate emits exactly one artifact and waits for one approval.

```
BATTLE PLAN — 4 tasks, 2 waves, split topology

  wave 1 (parallel, 3 worktrees)
    #42 parser rewrite   Opus   × full   wt-42   scout
    #51 docs typo        Haiku  × patch  wt-51   plan #task-1
    #60 CLI flag         Sonnet × lite   wt-60   scout
  wave 2 (blocked)
    #43 parser BOM fix   Sonnet × full   wt-43   plan #task-2
        blocked on #42 — hard overlap, src/parser.ts:parseHeader

  relay:  #43 releases when #42's changes are proven on its base
  merge:  human (no `afk`) — you are notified when #101 is ready
  commit: approving this plan authorizes Step 12 commit + PR for #42, #43, #51, #60
  budget: no ceiling set
  stale:  none

  open questions (2) — answer before approving
    #60  Which module owns the new flag?  (Recommended: src/cli/config.ts)
    #42  Keep legacy BOM behaviour behind a flag?  (Recommended: no)

  [ yes, forge them ]   [ amend … ]   [ drop a task ]
```

## Free-form task split

When any task in the run entered through the free-form route, the battle plan renders the split before the wave listing: one line per proposed task, each showing the fragment of the original goal it was derived from, so the user can see and correct a decomposition they never wrote — per [entry-routes.md](entry-routes.md#free-form-decomposition), this rendering is not optional for that route and does not depend on how confident the split felt.

```
  free-form split — "add auth, fix the parser, bump deps"
    T1  add auth            ← "add auth"
    T2  fix the parser      ← "fix the parser"
    T3  bump deps           ← "bump deps"
```

Under `automode`, the gate itself is skipped (see Approval semantics below), but the split is still recorded — as a **named assumption**, not as an ordinary battle-plan line, because under `automode` nobody reviews the split before it drives dispatch:

```
  assumptions
    free-form split assumed (automode, unreviewed) — 3 tasks from 1 goal:
      T1  add auth            ← "add auth"
      T2  fix the parser      ← "fix the parser"
      T3  bump deps           ← "bump deps"
```

## Required elements

Every task's ref, title, tier, depth, worktree and analysis route; every edge with its overlap grade and the exact file or symbol that produced it; the topology decision; any plan slice flagged stale; the merge-authority mode in force; the commit-and-PR authorization this approval will grant — every task it covers, named explicitly, and none it does not (see Commit-and-PR authorization below); anything `budget` will defer; and the consolidated interview.

A batch run accumulates undetermined and out-of-run conditions from every reference this step composes — `symbols undeterminable` and `declared blocker outside this run: <ref>` from [collision-graph.md](collision-graph.md), `difficulty undeterminable: <ref>` and `blastRadius undeterminable: <ref>` from [triage.md](triage.md), `freshness unverified: plan not yet committed` from `plan-sourced.md`, and `unified (mixed kind)` from [scheduling.md](scheduling.md). These are one class, not a list to duplicate here: any condition a task or edge carries when it reaches the gate is rendered on the line for the task or edge it describes, in the wording its owning reference already defines, never re-derived or re-worded at this step. Battle-plan assembly does not invent a parallel vocabulary for a condition an earlier step already named — it renders what it is handed.

## Commit-and-PR authorization

Approving the plan is also the Step 12 selection forge requires before any dispatched run may commit or open a PR: "yes, forge them" said against a plan that names every task is that selection, made once for all of them rather than once per run — the same relay Step 7 already performs when it supplies the scout's proposal as an already-approved Step 5 plan. The plan states this on its face, in the `commit:` line above, naming exactly the tasks the approval covers, so the human sees what they are authorizing before they say yes; an amendment that adds or drops a task changes what that line covers and re-asks for approval like any other amendment.

Under `automode`, no human says "yes, forge them" — the gate is skipped, not answered — so this authorization is never granted by default, and every dispatched run's own Step 12 stops at its plan-only output instead: see `automode`'s row in [flags.md](flags.md) and [afk.md](afk.md) for the one flag, `afk`, that grants it anyway.

## Approval semantics

**"yes, forge them"** is the only phrase that provisions worktrees. Nothing short of it — not silence, not a question answered, not an amendment accepted — starts Step 6.

An amendment — re-tier, re-depth, re-group, drop a task, or force an edge the graph missed — revises the plan and re-asks; the revised plan is a new artifact requiring its own approval, not an implicit continuation of the one before it.

Under `automode` the gate is skipped, `(Recommended)` answers are taken for every open question, and the battle plan is emitted as a record rather than a question — the same plan, the same required elements, but printed after the fact rather than awaited.

`dry` emits the plan and stops regardless of any other flag: it outranks `automode` for the purpose of stopping the run (there is still no gate to skip, because there is nothing past it to run), and it makes `afk` and `budget` inert per [flags.md](flags.md)'s composition rules.
