# Blacksmith — the collision graph

How Step 4 turns each task's scout fields — `filesToTouch`, `symbols`, `declaredBlockers`, `blastRadius` — into a directed graph of who must wait for whom, before triage or scheduling sees a single task. Loaded by Step 4.

## Manual verification recipe

**Case 1 — hard overlap.** Two tasks in the run whose scout returns both name `src/parser.ts` in `filesToTouch` and both name `parseHeader` in `symbols`.
Expected: one edge between the two tasks, graded **hard**. Orientation picks the blocker by the four-step priority below, and the dependent parks — it is not dispatched into a wave until the blocker's PR has landed and relayed.

**Case 2 — soft overlap.** The same two tasks, but with disjoint `symbols` — one names only `parseHeader`, the other only `stripBom`, both still against `src/parser.ts`.
Expected: the same edge, graded **soft** instead of hard. The default schedule still serializes it — soft is a conservative default, not a free pass to parallelize — so the dependent still waits for its wave.

**Case 3 — the same soft pair, re-run with `stack`.** Expected: both tasks dispatch in wave 1. The dependent's worktree bases off the blocker's branch rather than off the run's base, and its PR opens stacked on the blocker's, per `stack`'s effect in [flags.md](flags.md).

## Edges

Two tasks collide when their `filesToTouch` sets intersect. One shared path is enough to draw an edge, and a task's set never needs to match another's exactly to collide — two tasks whose file sets are merely overlapping and two tasks whose file sets are identical both draw exactly the one edge that intersection draws, never several. This graph has no notion of "how much" two tasks overlap, only whether they do, so a one-file overlap and a six-file overlap on the same pair both produce one edge, distinguished only by the overlap grade below — identical file sets are not automatically graded hard; that grade still depends only on symbol overlap, per Overlap grades.

A task whose `filesToTouch` set is empty cannot form an edge with anything, because there is nothing to intersect. This is not a state Step 4 is meant to see: Step 3's dispatch-ready check (3a, condition 1) and the scout schema's field validation (3b) both require a concrete, non-empty file list before a task reaches Step 4. If an empty set arrives anyway, Step 4 does not silently schedule that task into its own isolated component as though its scope were confirmed empty — it stops and names the task by ref, because dispatching a task nothing was ever checked to collide with is dispatching against an unverified scope, exactly the situation the dispatch-ready check exists to prevent.

## Orientation

Edges are always oriented, never left undirected, by a single deterministic priority, verbatim from spec §4:

1. an explicitly declared blocker (`declaredBlockers`, or plan task order) wins;
2. else larger blast radius goes first;
3. else more files touched goes first;
4. else lower ref number.

Because orientation follows one total order, **the graph is acyclic by construction** — there is no cycle-breaking case and no deadlock detection.

An earlier tier always overrides a later one, on purpose: tier 1 exists precisely to let a plan author's or a user's stated intent about ordering outrank the heuristic proxies below it, even when that intent runs against what blast radius or file count alone would have picked. A task naming a blocker that a lower tier would otherwise have ordered the other way around is tier 1 working as designed, not a conflict to resolve.

Two situations need their own handling before tier 1 can be trusted to fire:

- **A `declaredBlockers` entry naming a ref outside this run's task set.** There is no node for that ref in this graph, so tier 1 cannot orient against it — but Step 4 does not treat the entry as though it named nothing. It records the external dependency on the battle plan (`declared blocker outside this run: <ref>`) so the user sees it instead of having it silently dropped, and orientation for any edge that *does* exist for that task falls through to tier 2, exactly as if no declared blocker had fired.
- **Two tasks each naming the other in `declaredBlockers`.** Both directions cannot be true, so tier 1 cannot supply an answer for that edge and is skipped for it, the same as if neither task had declared anything; orientation falls through to tier 2. The contradiction is also flagged on the battle plan, because a scout or plan disagreeing with itself about which task blocks which is usually a real error worth a human's eyes, not a case to resolve quietly. Tiers 2 through 4 still terminate in a strict order — tier 4 breaks any remaining tie on distinct ref numbers — so this contradiction cannot reopen the cycle tier 1's guarantee closed.

## Overlap grades

File-level matching over-serializes, so overlap has two grades:

| Grade | Condition | Default |
|---|---|---|
| Hard | same file **and** overlapping symbols or regions | serialize — dependent parks |
| Soft | same file, disjoint symbols | serialize (conservative default); runs parallel under `stack` |

Grade is decided per file pair by symbol overlap alone, never by how many files two tasks share: two tasks sharing one file with overlapping symbols on it are graded exactly as hard as two tasks sharing every file with overlapping symbols on at least one of them, because a single genuine collision is enough to require serialization.

The battle plan always states which grade produced each edge, so an over-serialization is visible and correctable at the gate.

## Semantic conflicts

Disjoint file sets do not prove independence: task A can change an interface that task B's untouched file calls. No file-level graph sees this — including a `declaredBlockers` relationship between two tasks whose files never intersect, which the Edges rule above never draws as an edge in the first place. That dependency is real; this graph simply does not carry it as an edge, and downstream wave scheduling is expected to still honor it from the field directly rather than from a graph edge that was never drawn. Step 4 does not invent an edge here to make the dependency visible in a place it does not belong.

The defense against the conflicts no file-level graph can see is behavioral rather than static: **every worktree rebases onto the current base and re-runs its `/goal` before its PR is treated as ready.** A PR is verified against the base it will land on, never the base it forked from.
