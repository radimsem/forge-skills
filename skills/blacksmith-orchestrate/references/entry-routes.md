# Blacksmith — work sources and entry routes

How `/blacksmith-orchestrate <work-source>` becomes one canonical task list. Loaded by Steps 1 and 2.

## Manual verification recipe

```
/blacksmith-orchestrate 42 43 plan docs/superpowers/plans/2026-08-21-auth.md dry
```

Expected: Step 1 emits a single task list carrying three or more tasks — `#42` and `#43` tagged with the `refs` route, plus one task per task heading in the plan file tagged with the `plan` route — and no task loses its route tag on the way to Step 3. Because `dry` is set, Step 5 prints the battle plan and the run stops there: no worktree is provisioned and no forge run is dispatched.

## Work sources

Five routes converge on one canonical task list. This mirrors forge's Step 1, whose target grammar routes six ref and entry-verb shapes into one workflow.

| Form | Route | Example |
|---|---|---|
| One or more refs | each ref becomes one task, using forge's existing ref grammar verbatim | `/blacksmith-orchestrate 42 43 PROJ-7` |
| `milestone <x>` / `epic <KEY>` / `label <name>` | expand the container into an issue list via the tracker, then treat as refs | `/blacksmith-orchestrate milestone 3` |
| `plan <path\|glob>` | plan-sourced route (`references/plan-sourced.md`) | `/blacksmith-orchestrate plan docs/superpowers/plans/2026-08-21-auth.md` |
| A quoted free-form goal | orchestrator splits the prose into distinct tasks, always surfaces that split at the gate, then materializes refs (Step 2) | `/blacksmith-orchestrate "add auth, fix the parser, bump deps"` |
| `resume [run-id]` | resume from a ledger (`references/ledger.md`) | `/blacksmith-orchestrate resume` |

Ref shapes are forge's, not new ones: a bare number, `#N` or `issue N` is a git-host issue, a key-shaped token is a Jira or Linear issue, and the `ticket` and `linear` keywords force their tracker. Read forge's own target grammar in [../../forge/SKILL.md](../../forge/SKILL.md) rather than re-deriving it here — a second, drifting copy of the ref grammar is exactly the duplication this skill exists to avoid.

## Normalization

Routes may combine. Refs and a `plan` may appear in one invocation, and a container may be mixed with loose refs. **Every task carries its own route**, recorded on the task and preserved through Steps 2 through 5, because Step 3 decides between the plan-sourced path and a scout fan-out **per task, not per run** — a plan covering three of five tasks scouts only the other two, and that decision is impossible if the route was collapsed into a single run-level mode.

Deduplicate by resolved ref after every route has been expanded, not before: a milestone and a loose ref frequently name the same issue, and running that issue twice would put two agents in two worktrees on the same files with no collision edge between them, since the collision graph reasons about distinct tasks.

Two tasks from *different* routes that cannot be proven to be the same ref are treated as two tasks, even when they look like the same work — for example a plan slice and an issue that describe the same fix. Do not silently merge them. Name both at the Step 5 gate and let the user drop one, because merging on a guess would drop work the user asked for, while the duplicate is visible and cheap to remove at the gate.

If a route expands to zero tasks — an empty milestone, a glob matching no plan file, a free-form goal that yields no distinct task — stop and report which route came back empty. Do not continue on the remaining routes as though the invocation were complete: the user asked for that source, and quietly orchestrating a subset produces a close-out report that looks successful while missing the work.

## Free-form decomposition

Free-form is the weakest of the five routes above and is treated as such. A ref names a task someone already wrote down, a container is a list the tracker maintains, and a plan carries task boundaries `writing-plans` defined deliberately. A quoted goal carries none of that: where one task ends and the next begins exists only in the orchestrator's reading of one sentence, and there is no ground truth to check that reading against. Two agents given `"fix the parser and clean up auth"` may reasonably produce two tasks or five, and both are defensible.

**The split is therefore always surfaced before anything is filed or dispatched.** The proposed task list appears in the Step 5 battle plan with, for each task, the fragment of the original goal it was derived from, so the user can see and correct a decomposition they never wrote. This is not optional for the free-form route and does not depend on how confident the split felt.

**When the split is not clear-cut, do not pick one.** A single sentence that could be one task or three, or a conjunction that might be one change or two, goes into the consolidated Step 5 interview as a proposed-answer question offering the candidate splits, with the **coarser** split marked `(Recommended)`. Coarser is the safer default because under-splitting leaves one forge run that can still handle the whole change and spin off the remainder through its own Step 10, whereas over-splitting fabricates boundaries nobody drew: it invents collision edges between halves of one change, opens PRs for fragments that only make sense together, and merging them back after dispatch means discarding provisioned worktrees.

**Under `automode`, a free-form split is never filed to the tracker.** `automode` lifts the Step 5 gate, which removes the exact safeguard this route depends on, so the two rules below apply together:

1. the split is recorded as an explicit assumption in the battle plan, named as an assumption rather than presented as a finding;
2. its tasks run under synthetic `T1..Tn` IDs and are **not** filed, unless the user named the split themselves — for example by enumerating the tasks in the goal, or by re-invoking with refs once they have seen the recorded split.

This is the one place where forge's "under `automode`, post them directly" is too eager, and the difference is what the issue body contains. Forge's Step 10 drafts spin-off issues from a human-written issue body, so a person authored the thing being described and `automode` is only automating the filing. Here the issue bodies would be the orchestrator's own guess at a boundary nobody stated. An unreviewed guess written into a shared tracker is not reversible by the person who has to clean it up: closing N wrong issues is manual work that lands on someone else's queue, and the notifications have already gone out. A synthetic ID costs nothing, leaves the tracker untouched, and still lets the run proceed — so the safe branch is also the cheap one.

## Materializing refs

Step 2's job. Ref and container routes already carry real refs and need nothing further.

The plan and free-form routes do not, so they are given real issue refs via **`/to-tickets`**: draft one issue per task, show the drafts, and file them on an explicit user yes. Under `automode`, file the plan route's issues directly, matching forge's Step 10 behavior for spin-off issues — a plan is a human-written document, so the drafted bodies describe boundaries a person actually set. The free-form route is the exception and is never filed under `automode`; see Free-form decomposition above for the rule and its reasoning. Tickets filed this way carry a bonus the synthetic path cannot: `/to-tickets` has each ticket declare the tickets that **block** it, so the filed set arrives with its dependency edges already stated — Step 4 reads them into `declaredBlockers` (see [collision-graph.md](collision-graph.md)) instead of inferring the ordering from file overlap alone.

If the user declines filing, assign synthetic IDs `T1..Tn` in task-list order. A synthetic ID is local to this run: it names the task in the battle plan, the ledger, the worktree name and the dispatched forge run, and **it never reaches a tracker on its own**. Any later step that would write to a tracker for such a task — a forge Step 12 write-back, a Jira transition, an issue-closing keyword in a commit or PR body — skips that write and names the skip in the Step 9 close-out. Writing `T3` to a tracker would either fail or, worse, resolve against an unrelated real issue, and the close-out line is what keeps the skipped write from looking like a completed one.

That refusal covers automatic write-back. A user can still ask, later, to file a synthetic task explicitly — and that request is not answered the same way for every synthetic ID. Before filing any synthetic task on request, consult its `syntheticIdReason` in the ledger ([ledger.md](ledger.md)'s "Synthetic task IDs"): `declined-filing` may be filed on request, since the task was already human-stated and the user is only reversing an earlier decline; `automode-freeform` is refused until the user has seen and accepted the split, because that split was the orchestrator's own guess, and an unreviewed guess written into a shared tracker is not reversible by whoever has to clean it up.

Synthetic IDs are never reused across runs and never renumbered mid-run. `resume` reads them back from the ledger unchanged, since the worktrees and branches provisioned in Step 6 are already named after them.

## Container expansion

`milestone`, `epic` and `label` expand through the tracker that forge already supports for this repo, routed exactly as forge's Step 1b/1c routes a single ref:

| Tracker | Forge reference to reuse |
|---|---|
| GitHub (incl. GH Enterprise) | [../../forge/references/trackers/github.md](../../forge/references/trackers/github.md) |
| GitLab (incl. self-hosted) | [../../forge/references/trackers/gitlab.md](../../forge/references/trackers/gitlab.md) |
| Jira | [../../forge/references/trackers/jira.md](../../forge/references/trackers/jira.md) |
| Linear | [../../forge/references/trackers/linear.md](../../forge/references/trackers/linear.md) |

Expansion reuses those references' own fetch commands and REST fallbacks; it does not add fetch logic of its own. A container is a list query against the same host and the same auth a single-ref fetch already uses, so a second implementation would drift from forge's on host detection, enterprise URLs and auth failure handling without buying anything.

If the tracker cannot be reached or the container cannot be resolved, stop and report it exactly as forge's Step 2 does for an unreachable source, including under `automode`. Guessing at a container's contents would fabricate the task list the entire run is built on.

If the tracker is reachable but the container resolves to a single issue, continue with a one-task run and say so once, then let the user decide whether `/forge <ref>` is the better tool. Do not abort: the user's request was well-formed, and the orchestrator degrades to a single dispatched forge run without any loss.
