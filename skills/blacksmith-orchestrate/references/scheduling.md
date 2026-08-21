# Blacksmith — scheduling: worktree topology, waves, budget

How Step 4 turns the oriented, graded collision graph from [collision-graph.md](collision-graph.md) into worktree groups and dispatch waves, and how Step 6 provisions from that plan. Loaded by Steps 4 and 6.

## Manual verification recipe

Four tasks, one hard edge between two of them (the other two are unconnected to anything). Expected: three connected components — the hard-edge pair, and the two singletons — so three worktrees. The hard-edge pair's dependent is blocked, so wave 1 dispatches the two singletons plus the hard-edge pair's blocker: three worktrees in wave 1. The hard-edge pair's dependent enters wave 2, once its blocker has relayed.

## Grouping

The connected components of the collision graph are the unit — tasks in different components share no files by construction, since an edge is exactly what would put them in the same component, and the graph has no other way to connect two tasks. Component membership is read straight off the graph Step 4 already built; scheduling does not recompute file overlap or re-derive an edge, it only asks which tasks a hard or soft edge — of either kind, overlap-derived or stated — puts in the same component.

| Component shape | Topology |
|---|---|
| one task | own worktree, own branch, own PR |
| two tasks, tightly coupled, same kind | **unified** — one worktree, tasks run sequentially as ordinary commits on one branch, one PR |
| larger | **split** — one worktree per task, with the [relay](relay.md) |

Unification is the cheap win: it converts an entire park → notify → merge → rebase cycle into two sequential commits in the same worktree, with no PR-to-PR relay in between. Splitting is the default past two tasks because six colliding tasks landing in one PR is a bad review artifact, even though it would merge more easily than six separate ones — a reviewer cannot usefully hold six tasks' worth of intent in one diff, and the relay's per-edge granularity is what keeps a large component reviewable at all. `unified` and `split` force the choice globally, overriding the shape rule above for every component in the run, not just the one that prompted the flag.

A component larger than `max` is not held back from dispatch on that basis alone — `max` bounds wave-1 *concurrency*, not component size, and a component is one unit that either all dispatches together (unified) or fans out across a wave with its own internal ordering (split); a single component's tasks compete for the same `max` concurrency slots as every other component's, exactly like any other tasks. What a component larger than `max` changes is how many of its own tasks can be in wave 1 at once: if a five-task split component has no internal blockers, at most `max` of its five dispatch together and the rest wait for a slot in the same wave's rolling window, not for a later wave — a component is never treated as blocked by its own size.

`unified` forced on a component whose tasks are different kinds is not silently honored as though the component still matched the middle row of the table above — the table's `unified` row describes "two tasks, tightly coupled, same kind" for a reason: unifying two different-kind tasks (for example a docs task and a parser rewrite) into one worktree and one PR would put unrelated intents behind a single review, exactly the bad-review-artifact outcome splitting exists to avoid, just at component size two instead of six. The forced unification still happens — `unified` forces the choice globally, as stated above — but the battle plan names the component as `unified (mixed kind)` so the mismatch is visible at the gate rather than looking like an ordinary same-kind pairing the user would have chosen anyway.

## Waves

Tasks with no unsatisfied blockers form wave 1 and dispatch in parallel up to `max` (default `4`). A task enters a later wave when every blocker it depends on has released its relay — not when the blocker's PR merges, and not when the blocker's wave finishes; release is [relay.md](relay.md)'s ancestor proof passing, which can happen after the blocker's PR merges or, without a host CLI, after its branch lands on the local base.

Wave gating reads only hard versus soft off each edge, never which of the three mechanisms in [collision-graph.md](collision-graph.md) produced it — file overlap, `declaredBlockers`, or plan task order are all the same to scheduling once the graph has graded and oriented the edge. A hard edge parks the dependent until release; a soft edge parks it too under the default schedule (soft is a conservative default, not a free pass to parallelize), unless `stack` is set, in which case the dependent dispatches in the same wave as its blocker, based off the blocker's branch, with its PR opened stacked on the blocker's.

A wave where every task is parked is not a stall condition scheduling treats specially — it is the ordinary result of every remaining task having an unreleased blocker at that point in the run, and it resolves itself the instant one of those blockers relays and its dependent's wave is recomputed. There is nothing to dispatch in such a wave and nothing is dispatched; the run's forward progress that tick is at the blocker still in flight, not at scheduling, so this is not reported as an error or a degraded state — only the ordinary case of Parking in [relay.md](relay.md) applies, unchanged: parked is not blocked-forever, and any *other* wave with an unblocked task keeps running regardless of how many tasks are parked in this one.

## Budget degradation ladder

`budget <n>` applies a token ceiling to the run, in this order:

1. reduce pool width toward 1 — costs wall-clock, not quality;
2. defer the lowest-priority remaining tasks to a follow-up run and report them explicitly;
3. only if `strict` is not set, downgrade `full → lite` on low-blast-radius tasks;
4. never cross the four floors in [triage.md](triage.md).

If the budget is exhausted mid-run with tasks still unstarted after all four rungs have been applied — pool width is already 1, every deferrable task is deferred, every eligible downgrade has been taken, and the floors still block going further — the run does not stop silently or attempt to squeeze a floor to finish the batch. The remaining unstarted tasks are deferred exactly as rung 2 already defers tasks, named individually in the close-out report, and the run closes out with whatever wave is in flight left to finish under its already-committed budget. A task already dispatched when the budget runs out is not aborted mid-flight; degradation only ever changes what starts next, never what is already running.

Silent truncation is forbidden: anything deferred or downgraded by this ladder is named in the close-out report, by ref, with which rung deferred or downgraded it.
