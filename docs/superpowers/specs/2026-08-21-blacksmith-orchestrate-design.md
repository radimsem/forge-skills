# blacksmith-orchestrate — Design

**Status:** approved design, pre-implementation
**Date:** 2026-08-21
**Depends on:** `skills/forge` (this repo), `superpowers:writing-plans`, `superpowers:using-git-worktrees`

## Summary

`blacksmith-orchestrate` is a multi-agent orchestration wrapper around the `forge` skill. Given a set of tasks, it decides **which run, in what order, at what depth, by which model, in which worktree** — then dispatches one forge run per task and shepherds the resulting PRs to completion.

It is a wrapper, not a fork. It never reimplements a forge step. Nearly every decision it makes is layered over a contract forge or `writing-plans` already establishes:

| Orchestrator need | Existing contract it reuses |
|---|---|
| Which files will a task touch? | forge Step 5 proposal, "Files to touch" |
| Where does one task end and the next begin? | `writing-plans` Task Right-Sizing |
| What proves a task is done? | forge `/goal`, sourced from the plan's testable deliverable |
| Can the implementing model review itself? | `codex impl`'s cross-model review rule |
| How is a pre-written plan consumed safely? | forge `docs` mode's stamp check, at N-scale |

## Goals

1. Detect which tasks collide on the same files and schedule colliding work sequentially, without over-serializing work that merely lives in the same directory.
2. Spend the right amount of model and review effort per task — small models and shallow lifecycles for easy, low-stakes work; full forge for anything with real blast radius.
3. Isolate every task's work in a git worktree, producing either one PR per task or one PR per tightly-coupled cluster.
4. Keep merge authority human by default, with one explicitly flagged, auditable exception for unattended runs.
5. Consume already-written implementation plans directly, skipping both the analysis and the planning halves of the workflow.

## Non-goals

- Replacing forge, or duplicating any of its twelve steps.
- Semantic (non-file-level) conflict prediction. See "Semantic conflicts" for the defense used instead.
- Cross-repository orchestration. One repo per run.
- Long-lived daemon behavior. A run is bounded by the session plus its ledger.

---

## 1. Entry contract

```
/blacksmith-orchestrate <work-source> [orchestrator-flags] [forge-flags]
```

### Work sources

Four routes converge on one canonical task list. This mirrors forge's Step 1, which routes four ref shapes into one fetch.

| Form | Route | Example |
|---|---|---|
| One or more refs | each ref becomes one task, using forge's existing ref grammar verbatim | `/blacksmith-orchestrate 42 43 PROJ-7` |
| `milestone <x>` / `epic <KEY>` / `label <name>` | expand the container into an issue list via the tracker, then treat as refs | `/blacksmith-orchestrate milestone 3` |
| `plan <path\|glob>` | plan-sourced route (§3) | `/blacksmith-orchestrate plan docs/superpowers/plans/2026-08-21-auth.md` |
| A quoted free-form goal | orchestrator splits the prose into distinct tasks, then materializes refs (§2) | `/blacksmith-orchestrate "add auth, fix the parser, bump deps"` |
| `resume [run-id]` | resume from a ledger (§10) | `/blacksmith-orchestrate resume` |

Routes may combine: refs and a `plan` may appear in one invocation. Every task carries its own route, and routing decisions in §3 are made **per task**, not per run.

### Orchestrator flags

| Flag | Effect |
|---|---|
| `afk` | 5-minute quiet timeout → verify-and-merge **blocking PRs only** (§8) |
| `resume` | resume a run from its ledger |
| `budget <n>` | token ceiling for the run, with a deterministic degradation ladder (§6) |
| `strict` | no depth downgrade; every task runs full forge |
| `stack` | blocked tasks base off the blocker's branch and open stacked PRs |
| `rescout` | force scout analysis even where dispatch-ready plans exist |
| `max <n>` | concurrent implementation agents; default `4` |
| `dry` | emit the battle plan and stop; dispatch nothing |
| `unified` / `split` | override worktree grouping (§6) |

### Forge flag pass-through

Every forge flag (`automode`, `docs`, `tdd`, `lookup`, `secure`, `changelog`, `ci-watch`, `compress`, `codex`, `codex challenge`, `codex impl`, `coderabbit`) passes through to every dispatched forge run, with two overrides:

- `worktree` is always implied and orchestrator-managed. Passing it explicitly is accepted with a one-line note.
- `automode` lifts the battle-plan gate (§7) exactly as it lifts forge's Step 6 gate, and passes through to each dispatched run.

### Flag composition and conflicts

| Rule | Reason |
|---|---|
| `strict` beats `budget` | Under both, a budget squeeze reduces pool width and defers tasks; it never downgrades depth. |
| `dry` makes `afk` and `budget` inert | Nothing is dispatched, so there is nothing to merge or spend. |
| `stack` reduces but does not replace `afk` | Stacking removes most parks; `afk` still governs any blocking PR that must actually land. |
| `rescout` supersedes plan-sourced dispatch for the tasks it re-scouts | A scout produces its own proposal; the plan is shown as context and any disagreement is surfaced at the gate. |
| `unified` / `split` are mutually exclusive | Passing both is an error, not a silent precedence. |

---

## 2. Workflow

Nine numbered steps, split by one gate, deliberately mirroring forge's shape.

```
Part 1 — Plan (1–5):     normalize → materialize → analyze → schedule → [GATE] battle plan
Part 2 — Execute (6–9):  provision → dispatch waves → relay → close-out

  gate held: no worktree is created and no forge Part 2 runs until "yes, forge them"
```

| Step | Action |
|---|---|
| 1 | Parse the invocation; split orchestrator flags from pass-through forge flags; route the work source into a canonical task list |
| 2 | Materialize refs — spec-file and free-form routes get real issue refs via `/to-issues`, or synthetic `T1..Tn` IDs if the user declines filing |
| 3 | Analyze — route each task to §3a (plan-sourced) or §3b (scout fan-out) |
| 4 | Build the collision graph, triage matrix and worktree grouping → scheduling waves |
| 5 | **[GATE]** one battle plan, one approval |
| 6 | Provision worktrees; write the run ledger |
| 7 | Dispatch waves — one `Agent` per task at its assigned tier × depth |
| 8 | Relay — prove a blocker's changes are on the dependent's base, rebase, release |
| 9 | Close-out — aggregate report, PR list, worktree cleanup reminders, self-evolution |

### Scouts never interview

A scout that hits a forge Step 4 gap returns the open question instead of asking it. The orchestrator batches every task's open questions into **one** consolidated interview attached to the Step 5 gate, using forge's proposed-answer format (`(Recommended)` marked, "Other" implicit). Under `automode`, the `(Recommended)` answer is taken and the assumption recorded, exactly as forge does.

---

## 3. Analysis (Step 3)

Step 3 is routed per task, not per run. A plan covering three of five tasks scouts only the other two.

| Route | When | Cost |
|---|---|---|
| **3a — plan-sourced** | a dispatch-ready plan slice covers the task | zero agent spawns |
| **3b — scout fan-out** | no plan, plan not dispatch-ready, or `rescout` | one forge Part 1 per task |

### 3a — Plan-sourced

**Detection order:** an explicit `plan <path|glob>` argument → `docs/superpowers/plans/*.md` → `docs/superpowers/specs/*-design.md` → a plan location named by the repo's own `CLAUDE.md` / `AGENTS.md`.

**Task boundaries come from the plan.** `writing-plans` defines a task as "the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate," ending in an independently testable deliverable. That is precisely the orchestration unit; the orchestrator does not re-decompose. A plan slice is addressed as `<path>#<task-heading-slug>`, or as the whole file when the plan describes a single task.

**Dispatch-ready check.** A plan slice qualifies only if it yields all three:

1. a concrete file list whose paths **exist on disk today**;
2. pass criteria — the plan's testable deliverable becomes forge's `/goal`;
3. an unambiguous scope boundary (one plan task = one orchestration task).

Degradation ladder when a slice falls short:

| Missing | Fallback |
|---|---|
| (1) file list | cheap hydration pass for that task alone — grep for the named symbols; no full forge Part 1 |
| (2) pass criteria | orchestrator derives them and surfaces them at the gate for confirmation; **never skipped**, because `/goal` is a hard floor |
| (3) scope boundary | full 3b scout for that task |

**Plan task order is a declared dependency edge.** `writing-plans` emits staged tasks that routinely build on each other, so a plan's task list is assumed to be a blocker chain. The assumption is lifted only when the plan explicitly marks tasks independent, **or** their file sets are disjoint *and* the plan's File Structure section shows no shared interface between them.

**Freshness guard.** Skipping the scout means nothing re-validated the plan against the repo, so before the gate:

- every path the plan names must exist;
- the plan's stamped base SHA — or, absent a stamp, its file's last commit — is compared against current `HEAD` for those paths;
- any path changed since is flagged **stale** on the battle plan, and stale tasks fall back to 3b rather than dispatching blind.

This is forge's `docs` stamp check applied to a set. Forge already learned this lesson for one task ("on a mismatch, warn and re-propose rather than implement a stale plan"); a batch multiplies the blast radius of ignoring it.

### 3b — Scout fan-out

One Workflow script, `parallel()` over the tasks, one agent per task running forge Part 1 (Steps 1–6) and stopping at its gate. Each returns a schema-validated object:

```jsonc
{
  "ref": "42",
  "title": "Parser fails on UTF-16 BOM",
  "kind": "bug",
  "filesToTouch": ["src/parser.ts", "src/lexer.ts"],
  "symbols": ["parseHeader", "stripBom"],
  "plan": "...",
  "passCriteria": "...",
  "difficulty": "high",
  "blastRadius": "medium",
  "declaredBlockers": ["#40"],
  "openQuestions": [],
  "risks": []
}
```

Schema validation is enforced at the tool layer, so a malformed return is retried by the runtime rather than parsed defensively.

---

## 4. Collision graph (Step 4)

**Edges.** Two tasks collide when their `filesToTouch` sets intersect, or when one names the other in `declaredBlockers` — file overlap is inferred evidence of a dependency, a declared blocker is stated evidence, and stated beats inferred, so a declared edge is drawn whether or not the files overlap and is graded hard regardless.

**Orientation.** Edges are always oriented, never left undirected, by a single deterministic priority:

1. an explicitly declared blocker (`declaredBlockers`, or plan task order) wins;
2. else larger blast radius goes first;
3. else more files touched goes first;
4. else lower ref number.

Because orientation follows one total order, **overlap-derived edges are acyclic by construction** — no cycle-breaking case, no deadlock detection. Declared edges are the exception: their direction is stated rather than computed, so a chain of them can close into a cycle (the two-node case is two tasks each naming the other). Step 4 checks declared edges for cycles and, on finding one, drops that cycle's edges back to priority order and flags it on the battle plan — a declared cycle means the source issues contradict each other, which is for the user to see, not for the orchestrator to resolve quietly.

**Overlap grades.** File-level matching over-serializes, so overlap has two grades:

| Grade | Condition | Default |
|---|---|---|
| Hard | same file **and** overlapping symbols or regions | serialize — dependent parks |
| Soft | same file, disjoint symbols | serialize (conservative default); runs parallel under `stack` |

The battle plan always states which grade produced each edge, so an over-serialization is visible and correctable at the gate.

### Semantic conflicts

Disjoint file sets do not prove independence: task A can change an interface that task B's untouched file calls. No file-level graph sees this. The defense is behavioral rather than static — **every worktree rebases onto the current base and re-runs its `/goal` before its PR is treated as ready.** A PR is verified against the base it will land on, never the base it forked from.

---

## 5. Triage (Step 4)

Two independent axes. They correlate but are not the same: a one-line change to an auth check is trivial to implement and catastrophic to get wrong.

### Axis 1 — difficulty → model tier

Signals: file count, new interface vs existing pattern, algorithmic content, number of open risks.

| Difficulty | Agent model | Under `codex impl` pass-through |
|---|---|---|
| high | Opus 5 | `gpt-5.6-sol`, effort `high` |
| medium | Sonnet 5 | `gpt-5.6-terra`, effort `xhigh` |
| low | Haiku 4.5 | `gpt-5.6-luna`, effort `xhigh` |

### Axis 2 — blast radius → forge depth

Signals: user-facing surface, auth/payment/security adjacency, public API or migration, caller count of touched symbols, existing test coverage.

| Depth | Forge steps run | Review |
|---|---|---|
| `full` | 1–12, or P + 7–12 plan-sourced | loop to convergence, normal pass cap |
| `lite` | 7, 8, 12 | one review pass, project reviewers only; skips 9, 10, 11 |
| `patch` | 7, 12 | orchestrator reads the diff itself; no reviewer subagent |

### The four floors

1. **Step 12 `/goal` verification runs at every depth.** `patch` means "verified without a review loop," never "unverified." Forge's hard floor is inherited unchanged.
2. **High blast radius can never be assigned `lite` or `patch`,** whatever difficulty says. This is the entire reason the axes are separate.
3. **Rigor-increasing flags are sticky.** `secure` and `tdd` survive a depth downgrade.
4. **The implementer is never the only reviewer.** Generalized from `codex impl`: a Haiku-implemented task is reviewed at Sonnet or above; a same-family review is at minimum a distinct agent instance, and a different family is preferred where a reviewer flag makes one available.

### Runtime promotion

Triage is a prediction, so it self-corrects. If a `patch` or `lite` task fails its `/goal`, or its diff escapes the file list its plan declared, the orchestrator **promotes it one depth and re-dispatches once**, bumping the tier if the failure looks like a capability limit. A task that fails after promotion parks for the user rather than looping.

---

## 6. Scheduling and worktree topology (Steps 4, 6, 7)

**Grouping rule: the connected components of the collision graph are the unit.** Tasks in different components share no files by construction.

| Component shape | Topology |
|---|---|
| one task | own worktree, own branch, own PR |
| two tasks, tightly coupled, same kind | **unified** — one worktree, tasks run sequentially as ordinary commits on one branch, one PR |
| larger | **split** — one worktree per task, with the §8 relay |

Unification is the cheap win: it converts an entire park → notify → merge → rebase cycle into two sequential commits. Splitting is the default past two tasks because six colliding tasks in one PR is a bad review artifact even though it merges more easily. `unified` / `split` force the choice globally.

**Waves.** Tasks with no unsatisfied blockers form wave 1 and dispatch in parallel up to `max` (default `4`). A task enters a later wave when every blocker it depends on has released its relay.

**Budget degradation ladder** (`budget <n>`), applied in this order:

1. reduce pool width toward 1 — costs wall-clock, not quality;
2. defer the lowest-priority remaining tasks to a follow-up run and report them explicitly;
3. only if `strict` is not set, downgrade `full → lite` on low-blast-radius tasks;
4. never cross the four floors in §5.

Silent truncation is forbidden: anything deferred or downgraded is named in the close-out report.

---

## 7. Battle plan and the gate (Step 5)

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
  budget: no ceiling set
  stale:  none

  open questions (2) — answer before approving
    #60  Which module owns the new flag?  (Recommended: src/cli/config.ts)
    #42  Keep legacy BOM behaviour behind a flag?  (Recommended: no)

  [ yes, forge them ]   [ amend … ]   [ drop a task ]
```

**Required elements.** Every task's ref, title, tier, depth, worktree and analysis route; every edge with its overlap grade and the exact file or symbol that produced it; the topology decision; any plan slice flagged stale; the merge-authority mode in force; anything `budget` will defer; and the consolidated interview from §2.

**Approval semantics.** "yes, forge them" is the only phrase that provisions worktrees. An amendment — re-tier, re-depth, re-group, drop a task, or force an edge the graph missed — revises the plan and re-asks. Under `automode` the gate is skipped, `(Recommended)` answers are taken, and the battle plan is emitted as a record rather than a question. `dry` emits it and stops regardless of any other flag.

## 8. Relay and merge authority (Step 8)

### The relay

When a blocker's PR merges, the dependent is not released on the PR page's say-so. The orchestrator proves the code is present on the base it is about to build on:

```sh
git -C <dependent-worktree> fetch origin
git -C <dependent-worktree> merge-base --is-ancestor <blocker-head-sha> origin/<base>
git -C <dependent-worktree> rebase origin/<base>
```

A non-ancestor result does **not** release the relay. Squash-merges and rebase-merges rewrite SHAs, so the fallback proof is a `git log --grep` for the PR number on the base, plus a content assertion drawn from the blocker's proposal (a symbol or line the blocker was specified to introduce). Only a positive proof releases the relay.

Parked is not blocked-forever: every unblocked wave keeps running while a task parks.

### Merge authority

**Default:** the orchestrator notifies the user that a blocking PR is ready, and parks. It never merges. This preserves forge's stated hard floor — *never auto-commit, auto-push, or write back to a tracker, even under `automode`* — unchanged.

**With `afk`:** notify → 5-minute quiet timeout (no user message in the session and the notification unacknowledged) → the orchestrator self-verifies the PR. It merges only if **every** check passes:

1. the PR is mergeable with no conflicts;
2. CI is green for the PR head SHA across all required checks;
3. that task's forge review loop converged to zero actionable findings (read from the ledger);
4. there are zero unresolved human review comments or change requests;
5. the diff's file list is a subset of the approved proposal's file list;
6. `/goal` verifies green in the worktree at the PR head;
7. the base branch permits the merge.

Any single failure keeps the PR parked and notifies; there is no merge retry loop — the checks are simply re-evaluated on the next poll.

**Two deliberate scope limits:**

- `afk` merges **only PRs that block another task.** Terminal PRs — ones nothing waits on — are always left for the user, even under `afk automode`.
- `afk` is documented in `references/afk.md` and the flag matrix as **the single sanctioned exception to forge's no-auto-push floor**, with the reasoning written down, so the exception is auditable rather than a quiet contradiction of the README.

### Without a host CLI

If `gh` / `glab` is absent or unauthenticated, no PRs are opened. Components produce local branches, the relay's ancestor proof runs against the local base branch instead of `origin/<base>`, and close-out reports the branches for the user to publish. `afk` is inert and says so.

---

## 9. Close-out (Step 9)

The orchestrator emits one aggregate report: per task, its PR or branch, final state, depth, tier and `/goal` result; every task deferred or downgraded by `budget`, named explicitly; every parked task and precisely what it waits on; and a worktree cleanup reminder per worktree. Cleanup is never auto-run, inheriting forge's `worktree` rule that losing in-progress state on inferred completion is the wrong default.

**Two forge steps are hoisted to the orchestrator**, because running them per task would produce N conflicting writes to the same targets:

| Forge step | Dispatched run does | Orchestrator does |
|---|---|---|
| Step 10 — spin-off issues via `/to-issues` | collects candidates and reports them; files nothing | dedupes across all tasks, then files once under forge's normal rules |
| Step 11 — self-evolution | reports candidate lessons; writes nothing | dedupes, and proposes a single skill, rule, guide or memory edit |

Orchestrator-level self-evolution has its own subject matter: triage misses that required runtime promotion, edges the graph over- or under-serialized, and plan slices that proved stale. Those lessons belong in `references/anti-patterns.md`, which is this skill's canonical home for them exactly as it is forge's.

The ledger is written to its final state before the report, so a run that is reported is always a run that can be resumed or audited.

## 10. Ledger and resume

Location: `$(git rev-parse --git-common-dir)/blacksmith/run-<id>.json`. Inside `.git`, so it is shared by every linked worktree, never committed, and survives branch switches and `/compact`.

```jsonc
{
  "runId": "2026-08-21-a3f9",
  "invocation": "/blacksmith-orchestrate 42 43 51 60 automode afk",
  "flags": { "orchestrator": ["afk"], "forge": ["automode"] },
  "grouping": "split",
  "tasks": [
    {
      "id": "42", "route": "scout", "title": "Parser rewrite",
      "tier": "opus", "depth": "full",
      "worktree": "../repo-fix-parser-utf16", "branch": "fix/parser-utf16",
      "files": ["src/parser.ts", "src/lexer.ts"],
      "blockers": [], "pr": 101, "state": "pr-open"
    },
    {
      "id": "43", "route": "plan",
      "planSlice": "docs/superpowers/plans/2026-08-21-parser.md#task-2",
      "tier": "sonnet", "depth": "full",
      "worktree": "../repo-fix-parser-bom", "branch": "fix/parser-bom",
      "files": ["src/parser.ts"],
      "blockers": ["42"], "pr": null, "state": "parked"
    }
  ],
  "decisions": [
    { "at": "step-4", "note": "43 blocked on 42 — hard overlap on src/parser.ts:parseHeader" }
  ]
}
```

**Task states:** `planned → provisioned → running → review → pr-open → parked → merged → done`, with `failed` reachable from any running state.

**Resume contract.** `/blacksmith-orchestrate resume [run-id]` rebuilds wave state, worktree paths and PR numbers from the ledger. It re-verifies before continuing rather than trusting the file: each worktree must still exist and sit on its recorded branch, and each `pr-open` task's PR state is re-fetched. A worktree that has vanished puts its task back to `planned`. Resume never re-dispatches a task in `merged` or `done`.

---

## 11. Runtime and degradation

Claude-Code-first, following the same model as forge's `codex` / `coderabbit` flags.

| Surface | Used for | Why |
|---|---|---|
| Workflow tool | Step 3b scout fan-out | bounded parallel fan-out, schema-validated returns, keeps N proposals out of the orchestrator's context |
| Agent tool | Step 7 implementation dispatch | per-agent model selection, and the human gates and multi-hour parks live in the main loop |
| Ledger file | Steps 6–9 state | survives `/compact`, crash and resume |

On a non-Claude-Code runtime the skill degrades with a one-line warning to: sequential forge runs in dependency order, one worktree per component, no `afk`, no scout fan-out (the analysis runs inline). The degradation is stated in prose so the workflow stays portable even though the parallel path is not.

---

## 12. Required forge change: `/forge plan <path>`

A second entry verb in forge, mirroring `/forge pr <N>`.

```
/forge plan docs/superpowers/plans/2026-08-21-auth.md#task-3 [flags]
```

**Step P — plan validation**, replacing Steps 1, 2, 4, 5 and 6:

- resolve the plan slice and confirm its stamp matches this invocation;
- confirm every path the slice names exists;
- derive `/goal` from the slice's testable deliverable;
- treat the slice as the approved Step 5 proposal — the gate is considered satisfied by the plan's own approval.

**Step 3 still runs.** Branch naming, base selection and the clean-tree check are not optional just because a plan exists.

Steps 7–12 then run normally. Where the slice links an issue and lacks pass criteria, Step 2's fetch is permitted to fill that gap.

Deliverables for this change: a row in `SKILL.md`'s target-grammar table, a row in `references/flags.md`'s entry-verbs table, a new `references/modes/plan-entry.md` (with the Manual verification recipe block the repo's mode files use), and a README flag-table sync.

---

## 13. Repo integration

```
skills/blacksmith-orchestrate/
  SKILL.md                      # 9-step workflow + flag table + when-to-use
  references/
    flags.md                    # flag matrix, composition + conflicts
    entry-routes.md             # the four work sources → canonical task list
    plan-sourced.md             # §3a: detection, dispatch-ready, freshness
    collision-graph.md          # edges, orientation, hard vs soft overlap
    triage.md                   # the two axes, tier/depth tables, the four floors
    scheduling.md               # waves, components, unified vs split, budget ladder
    relay.md                    # ancestor proof, rebase, park semantics
    afk.md                      # the sanctioned floor exception + verify checklist
    ledger.md                   # schema, states, resume contract
    anti-patterns.md            # orchestration red flags
  scripts/                      # scout workflow script

skills/forge/references/modes/plan-entry.md    # new (§12)
```

`SKILL.md` stays terse and delegates detail to `references/`, matching forge's progressive-disclosure discipline.

**Documentation sync obligations** (imposed by this repo's `CLAUDE.md`):

- forge's `SKILL.md` target-grammar table and `references/flags.md` entry-verbs table gain the `plan` row;
- `README.md` gains a blacksmith section and flag table;
- `CLAUDE.md` changes, because the repo now ships **two** skills rather than one — the "What this repo is" section and the architecture tree both assume a single deliverable today.

**Installer.** `install.sh`'s `deps_table` gains blacksmith. The ordering invariant shifts from *forge installs last* to *local skills last, forge before blacksmith*, since blacksmith depends on forge being present. `tests/install_test.sh`'s exact row-count and tiering assertions are updated in the same change, per `CLAUDE.md`'s rule for adding a dependency.

---

## 14. Testing

Two conventions, both already established in this repo:

- **Installer:** shell assertions in `tests/install_test.sh` — updated `deps_table` row count, the new ordering invariant, and idempotent detection of an already-installed blacksmith.
- **Skill behavior:** a **Manual verification recipe** block at the top of each new reference file, matching `references/modes/worktree.md` and `references/modes/codex-impl.md`. Each states an invocation and the expected observable outcome.

Minimum recipes to write: plan-sourced dispatch with a fresh plan; plan-sourced dispatch with a deliberately stale plan (must fall back to scouting); a two-task hard collision (must serialize and park); a two-task soft collision under `stack` (must run parallel); a high-blast-radius, low-difficulty task (must not receive `lite` or `patch`); `dry` (must dispatch nothing); `resume` after an interrupted run.

---

## 15. Anti-patterns and red flags

Canonical list for `references/anti-patterns.md`:

| Red flag | Why it is wrong |
|---|---|
| Dispatching before battle-plan approval | The gate is the wrapper's contract, exactly as Step 6 is forge's. |
| Treating any file overlap as hard | Over-serializes; the two grades exist precisely to avoid this. |
| Merging because the PR page says green | The ancestor proof, not the PR UI, releases a relay. |
| Downgrading depth on high blast radius | Floor 2. The auth-one-liner case is the reason the axes are separate. |
| Letting the implementing model be the only reviewer | Floor 4, generalized from `codex impl`. |
| Dispatching a plan-sourced task without the freshness check | Nothing else re-validated that plan against the repo. |
| Treating disjoint file sets as proof of independence | Semantic conflicts exist; the rebase-then-`/goal` rule is the defense. |
| Auto-removing worktrees | Inherited from forge's `worktree` flag: losing in-progress state on inferred completion is the wrong default. |
| Silent truncation under `budget` | Anything deferred or downgraded must be named in the close-out. |

---

## 16. Assumptions open to revision

1. `afk` merges only blocking PRs; terminal PRs always await the user. Widening this to "ship every PR" is a one-line change to §8 but a materially larger floor exception.
2. Default pool width is `4`, chosen for worktree disk cost, review noise and rate limits rather than measured throughput.
3. The AFK timeout is 5 minutes of session quiet, as specified. It is not adaptive.
4. Unification triggers at two tightly-coupled tasks. The threshold is a judgment call, not a measured optimum.
5. Free-form goal decomposition has no ground truth to check against; it is the weakest of the four entry routes and always surfaces its task split at the gate.
