# Blacksmith — the collision graph

How Step 4 turns each task's scout fields — `filesToTouch`, `symbols`, `declaredBlockers`, `blastRadius` — into a directed graph of who must wait for whom, before triage or scheduling sees a single task. Loaded by Step 4.

## Manual verification recipe

**Case 1 — hard overlap.** Two tasks in the run whose scout returns both name `src/parser.ts` in `filesToTouch` and both name `parseHeader` in `symbols`.
Expected: one edge between the two tasks, graded **hard**. Orientation picks the blocker by the four-step priority below, and the dependent parks — it is not dispatched into a wave until the blocker's PR has landed and relayed.

**Case 2 — soft overlap.** The same two tasks, but with disjoint `symbols` — one names only `parseHeader`, the other only `stripBom`, both still against `src/parser.ts`.
Expected: the same edge, graded **soft** instead of hard. The default schedule still serializes it — soft is a conservative default, not a free pass to parallelize — so the dependent still waits for its wave.

**Case 3 — the same soft pair, re-run with `stack`.** Expected: both tasks dispatch in wave 1. The dependent's worktree bases off the blocker's branch rather than off the run's base, and its PR opens stacked on the blocker's, per `stack`'s effect in [flags.md](flags.md).

**Case 4 — declared-only edge, no file overlap.** Two tasks whose `filesToTouch` sets are entirely disjoint, but one names the other in `declaredBlockers`.
Expected: an edge is drawn anyway, graded **hard**, oriented in the declared direction — the dependent parks even though nothing about their file lists would have connected them on file overlap alone.

## Edges

Two tasks draw an edge in either of two ways: their `filesToTouch` sets intersect, or one task names the other in `declaredBlockers`, whether or not the file sets overlap at all. File overlap is inferred evidence of a dependency; a declared blocker is stated evidence — a person (or a plan) who understood both pieces of work said one comes first — and stated evidence beats inferred evidence, so a `declaredBlockers` edge is drawn even when the two tasks' files never touch. A declared edge is graded **hard** regardless of file overlap, per Overlap grades below: there is no discounted "soft declared" edge, because a stated dependency does not earn a lighter grade for happening to also avoid a shared file.

One shared path, or one `declaredBlockers` mention, is enough to draw an edge; a task's `filesToTouch` set never needs to match another's exactly to collide by file overlap, and two tasks whose file sets are merely overlapping and two tasks whose file sets are identical both draw exactly the one edge that intersection draws, never several. This graph has no notion of "how much" two tasks overlap on files, only whether they do, so a one-file overlap and a six-file overlap on the same pair both produce one edge, distinguished only by the overlap grade below — identical file sets are not automatically graded hard on that basis alone; absent a declared edge, that grade still depends on symbol overlap, per Overlap grades.

A task whose `filesToTouch` set is empty and which carries no `declaredBlockers` relationship to any other task in the run cannot form an edge with anything, because there is nothing to intersect and nothing declared. This is not a state Step 4 is meant to see: Step 3's dispatch-ready check (3a, condition 1) and the scout schema's field validation (3b) both require a concrete, non-empty file list before a task reaches Step 4. If an empty set arrives anyway and the task is not otherwise connected by a declared edge, Step 4 does not silently schedule that task into its own isolated component as though its scope were confirmed empty — it stops and names the task by ref, because dispatching a task nothing was ever checked to collide with is dispatching against an unverified scope, exactly the situation the dispatch-ready check exists to prevent.

**A `declaredBlockers` entry naming a ref outside this run's task set cannot draw an edge** — there is no node for that ref in this graph, because it was never scheduled into this run. Step 4 does not block on it: a task cannot be made to wait forever on work that was never dispatched, so the run proceeds without that dependency rather than stalling on one indefinitely. It surfaces prominently on the battle plan as an unmet declared dependency (`declared blocker outside this run: <ref>`) naming the task and the missing ref, precisely because dropping it silently would hide a real dependency someone wrote down. If the user wants that ordering honored, the fix is to add the missing ref to the run — the orchestrator does not guess at scheduling work nobody asked it to run.

## Orientation

Edges are always oriented, never left undirected, by a single deterministic priority, verbatim from spec §4:

1. an explicitly declared blocker (`declaredBlockers`, or plan task order) wins;
2. else larger blast radius goes first;
3. else more files touched goes first;
4. else lower ref number.

Because orientation follows one total order, **overlap-derived edges are acyclic by construction** — there is no cycle-breaking case and no deadlock detection for that part of the graph.

Declared edges are the exception, and the reason is the same property that makes them valuable: their direction is *stated*, not computed from the total order, so two or more of them can disagree with each other. The two-node case is a task naming a blocker that a lower tier would have ordered the other way — that is tier 1 working as designed, not a conflict, because tier 1 exists precisely to let stated intent outrank the heuristic proxies below it. But a **cycle among declared edges** is a different situation: not one declaration outranking a heuristic, but declarations that outrank each other. The simplest case is two tasks each naming the other in `declaredBlockers`; the general case is any chain that closes on itself through declared edges — A blocks B by declaration, B blocks C by priority, C blocks A by declaration is still a cycle, because the two declared legs alone contradict the order the third leg would otherwise impose.

Step 4 checks the declared edges for a cycle. When it finds one, it drops every edge in that cycle back to priority order (tiers 2 through 4) for orientation, and flags the cycle on the battle plan, naming the tasks and the contradicting declarations. This resolves the cycle without picking a side quietly: a cycle among declared blockers means the source issues (or the plan) contradict each other about which comes first, and that is information the user needs to see, not something the orchestrator should resolve on its own authority. The mutual two-task case reads as the two-node instance of this same check, not a special case with its own logic.

The exception stays bounded. Only declared edges participate in the cycle check; every overlap-derived edge, and every declared edge not part of a cycle, is still oriented by the same total order as before. Once a cycle's edges are dropped back to priority order, tiers 2 through 4 close the graph again exactly as they do everywhere else — tier 4 alone is a strict order over distinct ref numbers, so it always terminates. The graph as a whole is therefore acyclic once the declared-edge cycle check has run, even though that guarantee no longer follows from the total order alone.

## Overlap grades

File-level matching over-serializes, so overlap has two grades:

| Grade | Condition | Default |
|---|---|---|
| Hard | same file **and** overlapping symbols or regions | serialize — dependent parks |
| Soft | same file, disjoint symbols | serialize (conservative default); runs parallel under `stack` |

Grade is decided per file pair by symbol overlap alone, never by how many files two tasks share: two tasks sharing one file with overlapping symbols on it are graded exactly as hard as two tasks sharing every file with overlapping symbols on at least one of them, because a single genuine collision is enough to require serialization. A `declaredBlockers` edge is graded hard by the same default regardless of whether the files overlap at all, per Edges above — declared evidence does not need a shared file to earn a hard grade.

The battle plan always states which grade produced each edge, so an over-serialization is visible and correctable at the gate.

## Semantic conflicts

Disjoint file sets do not prove independence: task A can change an interface that task B's untouched file calls, and neither `filesToTouch` intersection nor `declaredBlockers` catches it unless someone thought to write the dependency down — a scout or plan author has to have known enough to name it. No file-level or declaration-level signal can force that knowledge into existence when nobody supplied it.

The defense against the conflicts neither signal can see is behavioral rather than static: **every worktree rebases onto the current base and re-runs its `/goal` before its PR is treated as ready.** A PR is verified against the base it will land on, never the base it forked from.
