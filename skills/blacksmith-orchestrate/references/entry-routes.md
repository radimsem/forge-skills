# Blacksmith — work sources and entry routes

How `/blacksmith-orchestrate <work-source>` becomes one canonical task list. Loaded by Steps 1 and 2.

## Manual verification recipe

```
/blacksmith-orchestrate 42 43 plan docs/superpowers/plans/2026-08-21-auth.md dry
```

Expected: Step 1 emits a single task list carrying three or more tasks — `#42` and `#43` tagged with the `refs` route, plus one task per task heading in the plan file tagged with the `plan` route — and no task loses its route tag on the way to Step 3. Because `dry` is set, Step 5 prints the battle plan and the run stops there: no worktree is provisioned and no forge run is dispatched.

## Work sources

Five routes converge on one canonical task list. This mirrors forge's Step 1, which routes four ref shapes into one fetch.

| Form | Route | Example |
|---|---|---|
| One or more refs | each ref becomes one task, using forge's existing ref grammar verbatim | `/blacksmith-orchestrate 42 43 PROJ-7` |
| `milestone <x>` / `epic <KEY>` / `label <name>` | expand the container into an issue list via the tracker, then treat as refs | `/blacksmith-orchestrate milestone 3` |
| `plan <path\|glob>` | plan-sourced route (`references/plan-sourced.md`) | `/blacksmith-orchestrate plan docs/superpowers/plans/2026-08-21-auth.md` |
| A quoted free-form goal | orchestrator splits the prose into distinct tasks, then materializes refs (Step 2) | `/blacksmith-orchestrate "add auth, fix the parser, bump deps"` |
| `resume [run-id]` | resume from a ledger (`references/ledger.md`) | `/blacksmith-orchestrate resume` |

Ref shapes are forge's, not new ones: a bare number, `#N` or `issue N` is a git-host issue, a key-shaped token is a Jira or Linear issue, and the `ticket` and `linear` keywords force their tracker. Read forge's own target grammar in [../../forge/SKILL.md](../../forge/SKILL.md) rather than re-deriving it here — a second, drifting copy of the ref grammar is exactly the duplication this skill exists to avoid.

## Normalization

Routes may combine. Refs and a `plan` may appear in one invocation, and a container may be mixed with loose refs. **Every task carries its own route**, recorded on the task and preserved through Steps 2 through 5, because Step 3 decides between the plan-sourced path and a scout fan-out **per task, not per run** — a plan covering three of five tasks scouts only the other two, and that decision is impossible if the route was collapsed into a single run-level mode.

Deduplicate by resolved ref after every route has been expanded, not before: a milestone and a loose ref frequently name the same issue, and running that issue twice would put two agents in two worktrees on the same files with no collision edge between them, since the collision graph reasons about distinct tasks.

Two tasks from *different* routes that cannot be proven to be the same ref are treated as two tasks, even when they look like the same work — for example a plan slice and an issue that describe the same fix. Do not silently merge them. Name both at the Step 5 gate and let the user drop one, because merging on a guess would drop work the user asked for, while the duplicate is visible and cheap to remove at the gate.

If a route expands to zero tasks — an empty milestone, a glob matching no plan file, a free-form goal that yields no distinct task — stop and report which route came back empty. Do not continue on the remaining routes as though the invocation were complete: the user asked for that source, and quietly orchestrating a subset produces a close-out report that looks successful while missing the work.

## Materializing refs

Step 2's job. Ref and container routes already carry real refs and need nothing further.

The plan and free-form routes do not, so they are given real issue refs via **`/to-issues`**: draft one issue per task, show the drafts, and file them on an explicit user yes. Under `automode`, file them directly, matching forge's Step 10 behavior for spin-off issues.

If the user declines filing, assign synthetic IDs `T1..Tn` in task-list order. A synthetic ID is local to this run: it names the task in the battle plan, the ledger, the worktree name and the dispatched forge run, and **it never reaches a tracker**. Any later step that would write to a tracker for such a task — a forge Step 12 write-back, a Jira transition, an issue-closing keyword in a commit or PR body — skips that write and names the skip in the Step 9 close-out. Writing `T3` to a tracker would either fail or, worse, resolve against an unrelated real issue, and the close-out line is what keeps the skipped write from looking like a completed one.

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
