# Blacksmith — flag matrix

The full set of flags the orchestrator understands, with composition rules and conflict handling. Forge's own flags are not repeated here; they pass through, and their matrix stays in [../../forge/references/flags.md](../../forge/references/flags.md).

## Flags

Each flag is consumed by the orchestrator and never forwarded to a dispatched forge run. `plan <path>` and `resume` are work-source selectors as well as flags — they occupy the `<work-source>` position in the grammar and are listed here so the matrix is complete; their routing is in [entry-routes.md](entry-routes.md).

| Flag | Effect | Detail |
|---|---|---|
| `afk` | After a 5-minute quiet timeout, self-verify and merge **blocking PRs only** — the single documented exception to forge's never-auto-push floor | `afk.md` |
| `resume` | Resume a run from its ledger instead of starting a new one | `ledger.md` |
| `budget <n>` | Token ceiling for the run, with a deterministic degradation ladder | `scheduling.md` |
| `strict` | No depth downgrade; every task runs full forge | `triage.md` |
| `stack` | Blocked tasks base off the blocker's branch and open stacked PRs | `scheduling.md` |
| `rescout` | Force scout analysis even where dispatch-ready plans exist | `plan-sourced.md` |
| `max <n>` | Concurrent implementation agents; default `4` | `scheduling.md` |
| `dry` | Emit the battle plan and stop; dispatch nothing | `battle-plan.md` |
| `unified` / `split` | Override worktree grouping — one PR per coupled cluster, or one PR per task | `scheduling.md` |
| `plan <path>` | Source tasks from a written implementation plan; each plan task becomes one orchestration task | `plan-sourced.md` |

## `afk` and the no-auto-push floor

Forge states a hard floor that even `automode` does not lift: never auto-commit, auto-push, or write back to a tracker. Orchestrating N runs does not relax it. Every dispatched run inherits it verbatim, and by default the orchestrator notifies the user that a blocking PR is ready and parks rather than merging.

`afk` is the **single sanctioned exception**, and it is deliberately narrow: it merges only PRs that block another task, only after a self-verification checklist passes in full, and never a terminal PR that nothing waits on — not even under `afk automode`. It is written down here, in `SKILL.md` and in `afk.md` with its reasoning, so that the exception is auditable rather than a quiet contradiction of the documented floor. Any single failed check keeps the PR parked and notifies; there is no merge retry loop.

## Forge flag pass-through

Every flag forge understands passes through unchanged to every dispatched forge run: `automode`, `docs`, `tdd`, `lookup`, `secure`, `changelog`, `ci-watch`, `compress`, `codex`, `codex challenge`, `codex impl`, and `coderabbit`. A pass-through flag applies to all tasks in the run; there is no per-task flag syntax.

Two of forge's flags are overridden rather than passed through as written:

- **`worktree` is always implied and orchestrator-managed.** Step 6 provisions, names and tracks every worktree, and Step 9 reports each one for cleanup, so the decision cannot be delegated to the individual runs. Passing it explicitly is accepted with a one-line note rather than rejected, because the user is asking for behavior that is already in force and an error would be pedantry.
- **`automode` lifts the Step 5 battle-plan gate** exactly as it lifts forge's Step 6 gate, and still passes through to each dispatched run. It lifts no hard floor: no run auto-commits, auto-pushes or writes back to a tracker, each run's Step 12 `/goal` verification still has to pass, and terminal PRs are still left for the user.

A runtime that cannot honour a pass-through flag degrades exactly as forge does — the reviewer flags `codex`, `codex challenge`, `codex impl` and `coderabbit` are Claude Code only and are ignored with a one-line warning elsewhere. The orchestrator emits that warning once for the run, not once per dispatched task, since N identical warnings tell the user nothing the first one did not.

## Composition rules

| Rule | Why |
|---|---|
| `strict` beats `budget` | Under both, a budget squeeze reduces pool width and defers tasks; it never downgrades depth. |
| `dry` makes `afk` and `budget` inert | Nothing is dispatched, so there is nothing to merge or spend. Both are reported as inert in the battle plan rather than silently dropped, so the user can see the flag had no effect. |
| `stack` reduces but does not replace `afk` | Stacking removes most parks; `afk` still governs any blocking PR that must actually land. |
| `rescout` supersedes plan-sourced dispatch for the tasks it re-scouts | A scout produces its own proposal; the plan is shown as context and any disagreement is surfaced at the gate. |
| `unified` / `split` are mutually exclusive | Passing both is an error, not a silent precedence: they ask for opposite PR topologies, so Step 1 stops and reports the conflict instead of picking one and hiding which shape shipped. |
