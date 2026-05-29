# Forge — `coderabbit` flag (and `coderabbit:autofix` rework path)

Composes the `coderabbit:code-review` skill as a Step 8 generic reviewer, replacing the default `superpowers:requesting-code-review`. Composes with the `codex` flag — set both and both engines run in the same pass.

The companion `coderabbit:autofix` skill is invoked from Step 8b as the rework delegation path when `coderabbit` is the active reviewer — symmetric to how the `codex` flag uses `codex:codex-rescue` in Step 8b.

## Manual verification recipe

```
/forge issue 42 coderabbit
```

Expected: Step 8 dispatches project reviewer subagents in parallel with `coderabbit:code-review`. Project subagents still run; `coderabbit` adds to the generic-reviewer set. On findings, Step 8 fix-and-rerun cycle applies as usual. If the rework needed is too large for inline application, Step 8b delegates to `coderabbit:autofix` foreground.

## Claude Code only

The CodeRabbit plugin is Claude Code-exclusive. Non-Claude-Code runtimes: forge ignores `coderabbit` with a one-line warning and stays on the default `superpowers:requesting-code-review`. Same degradation pattern as the `codex` flag.

## Composing with `codex`

Both flags add an engine to the Step 8 generic-reviewer set. Set both and both run in the same pass, each contributing findings to the shared pass budget. Step 8b rework routes per finding: codex findings to `codex:codex-rescue`, coderabbit findings to `coderabbit:autofix`. Inline or ambiguous fixes stay agent-discretion.

## Step 8a — Generic CodeRabbit reviewer

Engine selection at Step 8 (when `coderabbit` is set):

| Slot | Engine |
|---|---|
| Project reviewer subagents (`.agents/agents/` matched to diff) | Always run (unchanged by `coderabbit`) |
| Generic reviewer | `coderabbit:code-review` |
| Sub-pass (suspected bug / perf regression) | `/diagnose` (unchanged) |
| Fallback (no project reviewers, PR exists) | `/greploop` (unchanged) |

Dispatch the CodeRabbit reviewer in parallel with the project subagents where possible. Collect findings; apply Step 8 termination (zero actionable) and 3-pass cap rules unchanged.

## Step 8b — Rework delegation (`coderabbit:autofix`)

When Step 8 surfaces findings that require non-trivial implementation work — multiple files, cross-cutting refactors, or a category of fix the regular pass cannot complete inline — delegate the rework to `coderabbit:autofix`, mirroring the existing `codex:codex-rescue` path.

Before delegating, run the re-hydrate block (per the standard pass discipline) and inline the karpathy constraints in the rework prompt. `coderabbit:autofix` runs as a foreground subagent dispatch with `--wait` semantics so the next Step 8 re-review has the rework diff available.

After delegation returns: re-enter Step 8 with the rework diff as a new pass input. Apply the 3-pass cap to subsequent passes. If `coderabbit:autofix` itself fails or returns no usable diff, surface the failure and pause (or pick safest finding under `automode`).

## Behavior change vs default

| Stage | Default | With `coderabbit` |
|---|---|---|
| Step 8 generic reviewer | `superpowers:requesting-code-review` | `coderabbit:code-review` |
| Step 8b rework delegation | (n/a or codex-rescue if `codex` set) | `coderabbit:autofix` |
| Findings format | Per the reviewer's contract | Per CodeRabbit's contract; map severity → must-fix/should-fix/nit per the file in coderabbit:code-review |

## Composition with other flags

| Combination | Effect |
|---|---|
| `coderabbit` + `automode` | Reviewer runs unprompted. Step 8b rework delegates without user confirmation; failures pick safest path. |
| `coderabbit` + `secure` | After CodeRabbit converges, `security-review` runs as the post-Step-8 gate (per the `secure` contract). Both must clear before Step 9. |
| `coderabbit` + project subagents | Project subagents always run; `coderabbit` is the generic-reviewer companion. Both engines contribute findings to the same pass budget. |
| `coderabbit` + `/forge pr <N>` | PR-review mode uses CodeRabbit as the engine for the existing PR's diff. The reviewer's PR-specific features (line comments, summaries) compose naturally. |
| `coderabbit` + `codex` | Both engines run in the same Step 8 pass; rework routes per finding (codex → `codex:codex-rescue`, coderabbit → `coderabbit:autofix`). |
