# Blacksmith — the run ledger

How Step 6 records provisioning before Step 7 dispatches anything, how Step 7 and Step 8 keep it current, and what `resume` reads back — and re-verifies rather than trusts. Loaded by Steps 6, 7 and 9, and by the `resume` flag.

## Manual verification recipe

Start a run with four or more tasks across at least two waves. Let wave 1 reach `pr-open` for every one of its tasks, then interrupt the session before wave 2 dispatches. Re-invoke `/blacksmith-orchestrate resume`. Expected: wave 1's PRs are untouched — no new commits, no re-dispatch, no duplicate worktree — because their ledger rows already read `pr-open` or later and the resume contract below never re-dispatches a task past that point; wave 2 is re-planned from the ledger's recorded blockers and dispatches normally once each blocker has relayed, exactly as it would have if the run had never been interrupted.

## Location

```
$(git rev-parse --git-common-dir)/blacksmith/run-<id>.json
```

Inside `.git`, not the working tree, for three reasons that all follow from the same fact: `git rev-parse --git-common-dir` resolves to one shared location regardless of which linked worktree asks. The ledger is therefore shared by every worktree this run provisions rather than living in one of them arbitrarily; it is never committed, because nothing under `.git` is tracked by the repository it governs; and it survives both a branch switch in any worktree and a `/compact` of the agent's own context, since it is a file on disk that neither operation touches.

## Schema

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

`tier` and `depth` are the exact tokens [triage.md](triage.md) produces — `tier` is `opus`, `sonnet` or `haiku`, `depth` is `full`, `lite` or `patch`, always lowercase. Triage.md's "Opus 5" / "Sonnet 5" / "Haiku 4.5" are the display names those tokens resolve to on this run, not values that ever appear in the ledger; the ledger keys on the token, not the model name a future run of this repo might resolve it to.

### Synthetic task IDs

Neither task in the example above is synthetic, so neither shows the one field that only applies to a task whose `id` is a `T1..Tn` value assigned per [entry-routes.md](entry-routes.md):

```jsonc
{ "id": "T2", "syntheticIdReason": "declined-filing", "...": "..." }
```

`syntheticIdReason` is one of two values, and it exists because the two routes to a synthetic ID carry different restrictions on filing it later — a restriction that is silently lost the moment a resumed run forgets which route produced the ID:

| `syntheticIdReason` | How it arose | What `resume` must still refuse |
|---|---|---|
| `declined-filing` | The user was offered `/to-issues` filing for a real, human-stated task and declined it — entry-routes.md's "Materializing refs" | Nothing beyond the ordinary rule: a synthetic ID never reaches a tracker on its own, but filing it later, on request, is always available. |
| `automode-freeform` | The task came from an `automode` free-form goal split — entry-routes.md's "Free-form decomposition" | Filing outright. The split itself was the orchestrator's own guess, made without the Step 5 gate that would otherwise have shown it to a person; it must not be filed until a human has actually seen the split, not merely until one is asked. |

A task with a real ref never carries `syntheticIdReason` — the field's absence is itself meaningful, not an omission. `resume` reads the field back unchanged rather than re-deriving it from the task's route, because the route alone does not distinguish the two cases (both can originate from a free-form task) and re-deriving it risks quietly relaxing the `automode-freeform` restriction on a run that already recorded it correctly the first time.

## Task states

```
planned → provisioned → running → review → pr-open → parked → merged → done
```

`failed` is reachable from any running state — a task's forge run can error, or exhaust [triage.md](triage.md)'s runtime-promotion retries, from `running`, `review` or `pr-open` alike, and the ledger records whichever state it failed out of rather than collapsing the history.

The chain above is the common path, not a strict single line: `parked` is reachable from two different points, and both land on the same state because both mean the same thing — this task is waiting on something outside its own dispatched agent's control, and no amount of running that agent again would change it.

| State | Meaning |
|---|---|
| `planned` | In the battle plan; no worktree exists yet. |
| `provisioned` | Step 6 created the worktree and wrote this row; no agent has been dispatched. |
| `running` | Step 7 dispatched the agent; its forge run is in flight, before the review loop. |
| `review` | The dispatched run's own forge Step 8 review loop is in progress. |
| `pr-open` | The dispatched run opened a PR (or, without a host CLI, a branch — [relay.md](relay.md)'s "Without a host CLI"). |
| `parked` | Reached from `provisioned` when the task has an unreleased blocker and its wave has not opened yet ([scheduling.md](scheduling.md)'s wave gating); or reached from `pr-open` when the PR blocks another task and is waiting on merge authority — the default notify-and-wait, or `afk`'s 5-minute quiet timeout ([afk.md](afk.md)). |
| `merged` | The PR merged, or the branch landed on the base, and [relay.md](relay.md)'s ancestor proof passed for anything that depended on it. |
| `done` | Closed out: nothing further depends on this task, and it is reported as finished at Step 9. |
| `failed` | The dispatched run errored, or failed its `/goal` past [triage.md](triage.md)'s one runtime-promotion retry, and parked for the user rather than looping. |

### `pr-open` and `merged` under `automode` without `afk`

Under `automode` without `afk`, `pr-open` and `merged` are unreachable states for every task in the run. Per the three-way commit-and-PR rule stated in `SKILL.md`'s Overview and Step 7, no dispatched run's own Step 12 ever commits or opens a PR in that combination — every run stops at its plan-only output, exactly as a standalone `automode` forge run does. A task that completes under this combination is recorded `done` directly from `review` (or from `running`, at a depth that skips review), with `pr: null` and its plan-file path standing in for the PR the schema above shows; Step 9's close-out, not the state name, is what carries the caveat that nothing was pushed. A task with an unreleased blocker under the same combination never reaches `pr-open` either, for a different reason: [relay.md](relay.md)'s "Without a landable commit" section — there is nothing for the relay to prove ancestry against, so it stays `parked` for the remainder of the run instead of resolving.

## Resume contract

`/blacksmith-orchestrate resume [run-id]` rebuilds wave state, worktree paths and PR numbers from the ledger, but it **re-verifies before continuing rather than trusting the file** — the file is a record of what Step 6 and Step 7 believed was true when they last wrote it, not a live view of the worktrees or the host:

- Every worktree a `provisioned` or later task names must still exist and still sit on its recorded branch. A worktree that has vanished — removed by the user, by another tool, or by a cleanup the user ran manually — puts that task back to `planned`, on the same conservative footing as a task resume has never touched, rather than assuming the missing directory means the work is somehow further along.
- Every `pr-open` task's PR state is re-fetched from the host rather than read off the ledger's last snapshot, because the PR may have merged, closed, or gained CI results since the ledger was last written.
- `resume` never re-dispatches a task already at `merged` or `done` — re-running a task past those states would either duplicate a shipped change or spend an agent on a task the run had already finished with.
- A task's `syntheticIdReason`, where present, carries over unchanged; see "Synthetic task IDs" above for why it must not be re-derived.

**A run id that does not resolve to a ledger is not a fresh-run request.** `resume <run-id>` names one specific ledger file; if no `run-<run-id>.json` exists under the location above, the orchestrator stops and reports that the id does not resolve, listing whatever run ids *are* present as candidates, rather than silently falling through to starting a new run under that id — a resume that quietly became a fresh run would provision a second, unrelated set of worktrees under a name the user believed already pointed at the run they meant to continue, and the mistake would not surface until the two runs' branches collided. The same stop applies, for the same reason, to a ledger file that exists but fails to parse: a corrupt ledger is data that cannot be trusted, not evidence the run never started, so the orchestrator does not attempt to reconstruct partial state from it — the file is reported as unreadable and resume goes no further.

**A bare `resume` with more than one candidate ledger is ambiguous, not resolved**, in exactly the sense [plan-sourced.md](plan-sourced.md) uses that word for a plan-tier glob that matches several files: guessing which run the user meant risks resuming the wrong one and dispatching into worktrees for tasks nobody is waiting on right now. List every candidate — run id, original invocation, and current wave/state summary — and ask which one to resume. This stop is not lifted by `automode`: choosing among several plausible runs on no further information is the same class of guess Step 1 already refuses to make when a route resolves to nothing, and `automode` lifts approval gates, not the disambiguation this skill was never licensed to perform silently. A bare `resume` with exactly one candidate ledger resumes it without asking, since there is nothing left to disambiguate.
