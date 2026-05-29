# Forge — Step 8 Review Loop

Disciplined critique cycle. Runs after each implementation pass. Terminates when reviewers agree the diff is shippable; caps iterations to prevent infinite refinement.

## Engine selection

| Mode | Engines | When it runs |
|---|---|---|
| Default | Project reviewer subagents from `.agents/agents/` (or runtime equivalent, e.g. `.claude/agents/`) matched to the diff **+** generic reviewer `superpowers:requesting-code-review` | Every Step 8 pass |
| `codex` / `codex challenge` | Project subagents **+** Codex (`review` or `adversarial-review`) — see [reviewers/codex.md](reviewers/codex.md) | Step 8 when the flag is set; Claude Code runtime only |
| `coderabbit` | Project subagents **+** `coderabbit:code-review` — see [reviewers/coderabbit.md](reviewers/coderabbit.md) | Step 8 when the flag is set; Claude Code runtime only |
| Fallback (no project reviewer agents, PR exists) | `/greploop` against the pushed PR | When no project reviewers configured AND a PR exists. Never auto-push to create one. |
| Sub-pass (suspected bug or perf regression) | `/diagnose` | Surface findings, return to the main loop |

**Project subagents always run.** Reviewer flags (`codex`, `coderabbit`) swap only the generic reviewer slot; they never replace project agents. **`codex` and `coderabbit` are mutually exclusive** — combining errors before Step 1.

## Rework delegation (Step 8b paths)

Findings that exceed a single in-pass fix can be delegated to a companion rework skill before re-entering Step 8:

| Reviewer flag | Step 8b rework skill | Notes |
|---|---|---|
| Default (no flag) | none | In-pass fixes only |
| `codex` / `codex challenge` | `codex:codex-rescue` | re-hydrate first, inline karpathy constraints, foreground `--wait` |
| `coderabbit` | `coderabbit:autofix` | Same discipline as codex-rescue |

After the rework returns, re-enter Step 8 with the rework diff as a new pass input. The 3-pass cap applies to subsequent passes.

## Termination

Terminate at **zero actionable findings**. Actionable = must-fix **or** should-fix. Nits do not block. Stop the loop and proceed to Step 9.

## Pass cap

Cap **3 passes**. On each non-converged pass, run the re-hydrate block (defined in SKILL.md), fix the findings, then re-review. If pass 3 still has actionable findings, do not start pass 4 — summarize the remainder and ask the user. Under `automode`, pick the safest finding to act on and continue.

## Pass discipline

| Pass | Action |
|---|---|
| 1 | Implement → dispatch all configured engines in parallel where possible → collect findings |
| 2+ | re-hydrate first (`/compact` + re-source `/karpathy-guidelines`) → apply fixes → dispatch engines again |

The re-hydrate block exists to shed stale reviewer-transcript tokens and reload clean-code discipline. It does not restate `/goal`; `/goal` is set once at Step 7.

## Skip-the-rerun rule (trim-only cleanup)

After a clean substantive pass (project reviewers + generic reviewer return 0 must-fix / 0 should-fix on correctness / architecture), if the only remaining should-fixes are pure trims — doc-comment edits, blank-line grouping, naming touch-ups, no logic touched — apply them inline, run the repo verify command, and move to Step 9. Do not consume a pass on nit verification. The matching anti-pattern is in [anti-patterns.md](anti-patterns.md).

## `automode` behavior

See [autonomy.md](autonomy.md) Step 8 row. Same engines, same cap; non-convergence picks safest and continues instead of asking the user. The Jira-absent fallback still binds even under `automode`.

## Reviewer specifics

- [reviewers/codex.md](reviewers/codex.md) — Step 8a Codex reviewer resolution + graceful degrade; Step 8b rework delegation to `codex:codex-rescue`.
- [reviewers/coderabbit.md](reviewers/coderabbit.md) — Step 8a CodeRabbit reviewer; Step 8b rework delegation to `coderabbit:autofix`; XOR rule against `codex`.
