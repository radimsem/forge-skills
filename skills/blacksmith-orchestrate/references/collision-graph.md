# Blacksmith — the collision graph

How Step 4 turns each task's scout fields — `filesToTouch`, `symbols`, `declaredBlockers`, `blastRadius` — into a directed graph of who must wait for whom, before triage or scheduling sees a single task. Loaded by Step 4.

## Manual verification recipe

**Case 1 — hard overlap.** Two tasks in the run whose scout returns both name `src/parser.ts` in `filesToTouch` and both name `parseHeader` in `symbols`.
Expected: one edge between the two tasks, graded **hard**. Orientation picks the blocker by the four-step priority below, and the dependent parks — it is not dispatched into a wave until the blocker's PR has landed and relayed.

**Case 2 — soft overlap.** The same two tasks, but with disjoint `symbols` — one names only `parseHeader`, the other only `stripBom`, both still against `src/parser.ts`.
Expected: the same edge, graded **soft** instead of hard. The default schedule still serializes it — soft is a conservative default, not a free pass to parallelize — so the dependent still waits for its wave.

**Case 3 — the same soft pair, re-run with `stack`.** Expected: both tasks dispatch in wave 1. The dependent's worktree bases off the blocker's branch rather than off the run's base, and its PR opens stacked on the blocker's, per `stack`'s effect in [flags.md](flags.md).

**Case 4 — `declaredBlockers` edge, no file overlap.** Two tasks whose `filesToTouch` sets are entirely disjoint, but one names the other in `declaredBlockers`.
Expected: an edge is drawn anyway, graded **hard**, oriented in the declared direction — the dependent parks even though nothing about their file lists would have connected them on file overlap alone.

**Case 5 — plan-order edge, no file overlap.** Two plan-sourced tasks from the same plan, sequential in the plan's task list, whose `filesToTouch` sets are disjoint, and the plan neither marks them independent nor shows the disjoint-and-no-shared-interface exception from `plan-sourced.md`.
Expected: an edge is drawn from plan task order alone, graded **hard**, dependent parks — the same outcome as Case 4, sourced from plan order instead of `declaredBlockers`, since neither task's scout ever ran to populate `declaredBlockers` in the first place.

**Case 6 — undeterminable symbols.** Two tasks against the same file, but one task's scout returns `symbols: []` — a whole-file rewrite.
Expected: hard-vs-soft cannot be decided from symbols, so the edge defaults to **hard**, with `symbols undeterminable` surfaced on the battle plan — not soft, and not parallel under `stack`, unless the user explicitly overrides the grade at the gate.

## Edges

Two tasks draw an edge in any of three ways: their `filesToTouch` sets intersect; one task names the other in `declaredBlockers`; or, for plan-sourced tasks, the plan's task order implies one comes before the other. The first is inferred evidence of a dependency; the other two are stated evidence — an issue author naming a blocker and a plan author sequencing tasks are both stating a dependency the same way — and stated beats inferred, so a `declaredBlockers` or plan-order edge is drawn even when the two tasks' files never touch. Call the latter two **stated edges**, as distinct from the **overlap edges** file intersection draws; both kinds of stated edge are graded **hard** regardless of file overlap, per Overlap grades below — there is no discounted "soft stated" edge, because a stated dependency does not earn a lighter grade for happening to also avoid a shared file.

Plan-order edges are subject to the same lifting conditions `plan-sourced.md` already states, not a separate rule here: see [plan-sourced.md#plan-task-order-is-a-declared-dependency-edge](plan-sourced.md#plan-task-order-is-a-declared-dependency-edge) for the two conditions — explicit independence marking, or disjoint file sets **and** no shared interface in the plan's File Structure section — that lift the default blocker-chain assumption between consecutive plan tasks. That rule is not restated here so the two files cannot drift apart. This mechanism matters most exactly where it is easy to miss: a plan-sourced task is never scouted, so it may never populate `declaredBlockers` at all, and without a plan-order edge a dependency `plan-sourced.md` insists must survive would have no other way to reach this graph.

One shared path, or one stated-edge mention, is enough to draw an edge; a task's `filesToTouch` set never needs to match another's exactly to collide by file overlap, and two tasks whose file sets are merely overlapping and two tasks whose file sets are identical both draw exactly the one edge that intersection draws, never several. This graph has no notion of "how much" two tasks overlap on files, only whether they do, so a one-file overlap and a six-file overlap on the same pair both produce one edge, distinguished only by the overlap grade below — identical file sets are not automatically graded hard on that basis alone; absent a stated edge, that grade still depends on symbol overlap, per Overlap grades.

A task whose `filesToTouch` set is empty and which carries no stated-edge relationship to any other task in the run cannot form an edge with anything, because there is nothing to intersect and nothing stated. This is not a state Step 4 is meant to see: Step 3's dispatch-ready check (3a, condition 1) and the scout schema's field validation (3b) both require a concrete, non-empty file list before a task reaches Step 4. If an empty set arrives anyway and the task is not otherwise connected by a stated edge, Step 4 does not silently schedule that task into its own isolated component as though its scope were confirmed empty — it stops and names the task by ref, because dispatching a task nothing was ever checked to collide with is dispatching against an unverified scope, exactly the situation the dispatch-ready check exists to prevent.

**A `declaredBlockers` entry — or a plan's task order — naming a predecessor outside this run's task set cannot draw an edge** — there is no node for that ref in this graph, because it was never scheduled into this run. Step 4 does not block on it: a task cannot be made to wait forever on work that was never dispatched, so the run proceeds without that dependency rather than stalling on one indefinitely. It surfaces prominently on the battle plan as an unmet stated dependency (`declared blocker outside this run: <ref>`, or `plan predecessor outside this run: <ref>`) naming the task and the missing ref, precisely because dropping it silently would hide a real dependency someone wrote down or sequenced. If the user wants that ordering honored, the fix is to add the missing ref to the run — the orchestrator does not guess at scheduling work nobody asked it to run.

## Orientation

Edges are always oriented, never left undirected, by a single deterministic priority, verbatim from spec §4:

1. an explicitly declared blocker (`declaredBlockers`, or plan task order) wins;
2. else larger blast radius goes first;
3. else more files touched goes first;
4. else lower ref number.

Because orientation follows one total order, **overlap-derived edges are acyclic by construction** — there is no cycle-breaking case and no deadlock detection for that part of the graph.

Stated edges — `declaredBlockers` and plan task order alike — are the exception, and the reason is the same property that makes them valuable: their direction is *stated*, not computed from the total order, so two or more of them can disagree with each other. The two-node case is a task naming, or a plan sequencing, a blocker that a lower tier would have ordered the other way — that is tier 1 working as designed, not a conflict, because tier 1 exists precisely to let stated intent outrank the heuristic proxies below it. But a **cycle among stated edges** is a different situation: not one declaration outranking a heuristic, but declarations that outrank each other. The simplest case is two tasks each naming the other in `declaredBlockers`; the general case is any chain that closes on itself through stated edges, mixing `declaredBlockers` and plan-order legs freely — A blocks B by declaration, B blocks C by priority, C blocks A by plan order is still a cycle, because the two stated legs alone contradict the order the third leg would otherwise impose.

Step 4 checks the stated edges for a cycle. When it finds one, it drops every edge in that cycle back to priority order (tiers 2 through 4) for orientation, and flags the cycle on the battle plan, naming the tasks and the contradicting declarations. This resolves the cycle without picking a side quietly: a cycle among stated edges means the source issues or the plan contradict themselves about which comes first, and that is information the user needs to see, not something the orchestrator should resolve on its own authority. The mutual two-task case reads as the two-node instance of this same check, not a special case with its own logic.

The exception stays bounded. Only stated edges participate in the cycle check; every overlap-derived edge, and every stated edge not part of a cycle, is still oriented by the same total order as before. Once a cycle's edges are dropped back to priority order, tiers 2 through 4 close the graph again exactly as they do everywhere else — tier 4 alone is a strict order over distinct ref numbers, so it always terminates. The graph as a whole is therefore acyclic once the stated-edge cycle check has run, even though that guarantee no longer follows from the total order alone.

## Overlap grades

File-level matching over-serializes, so overlap has two grades:

| Grade | Condition | Default |
|---|---|---|
| Hard | same file **and** overlapping symbols or regions | serialize — dependent parks |
| Soft | same file, disjoint symbols | serialize (conservative default); runs parallel under `stack` |

Grade is decided per file pair by symbol overlap, never by how many files two tasks share: two tasks sharing one file with overlapping symbols on it are graded exactly as hard as two tasks sharing every file with overlapping symbols on at least one of them, because a single genuine collision is enough to require serialization.

**When either side's `symbols` list is empty, or the overlap is otherwise undeterminable — a whole-file rewrite is the obvious case — hard-vs-soft cannot be decided from symbols at all, and the grade defaults to hard, not soft.** The reason (`symbols undeterminable`) is surfaced on the battle plan so the user can override it. This is not an arbitrary caution: a soft grade authorizes two agents to edit the same file concurrently once `stack` is set, and granting that on missing information would trade a correctness risk for a throughput gain on the worst possible basis for that trade — the absence of the very data the grade is supposed to be decided from. The user can still force parallelism explicitly at the gate; the point is that going soft on missing data has to be a decision, not a fallthrough.

Stated edges (`declaredBlockers` and plan task order) are graded hard unconditionally, by the same default regardless of whether the files overlap at all, per Edges above — stated evidence does not need a shared file, or even known symbols, to earn a hard grade.

The battle plan always states which grade produced each edge, so an over-serialization is visible and correctable at the gate.

## Semantic conflicts

Disjoint file sets do not prove independence: task A can change an interface that task B's untouched file calls, and neither file-set intersection, `declaredBlockers`, nor plan task order catches it unless someone thought to write or sequence the dependency down — a scout or plan author has to have known enough to name it. No file-level or stated-edge signal can force that knowledge into existence when nobody supplied it.

The defense against the conflicts no signal in this graph can see is behavioral rather than static: **every worktree rebases onto the current base and re-runs its `/goal` before its PR is treated as ready.** A PR is verified against the base it will land on, never the base it forked from.
