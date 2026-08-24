# Forge — `/code-review` reviewer reference

Loaded on demand by SKILL.md Step 8 **only when the `code-review` flag is set**. Default (no flag) runs never read this file.

**Any runtime** — unlike `codex` and `coderabbit`, this engine is a plain skill (`code-review` from `mattpocock/skills`), so it carries no Claude-Code-only degradation rule. If the skill is not installed, warn once, fall back to `superpowers:requesting-code-review` for this run, and continue the loop. Never stall.

## Step 8a — Two-axis generic reviewer

`/code-review` reviews the diff since a fixed point along two independent axes, each run as a parallel sub-agent where the runtime has them, sequentially where it does not:

- **Standards** — does the diff follow the repo's coding standards, plus a Fowler smell baseline?
- **Spec** — does the diff faithfully implement the originating issue, ticket, or spec?

Drive it with forge's own context so it does not re-derive what forge already holds:

1. **Fixed point**: the Step 3 base branch (or the worktree's fork point under `worktree`). Pass it explicitly; the skill's "diff since a fixed point" must match the diff Step 8 is reviewing, not the whole branch history.
2. **Originating spec**: the Step 5 approved proposal plus the Step 2 issue/ticket body. The Spec axis is only as good as the spec it is handed — hand it the same artifacts the gate approved.
3. Run the review; treat its findings verbatim as this pass's generic-reviewer findings. Merge with the project reviewer agents' findings; same must-fix/should-fix termination as Step 8.

## Step 8b — Rework

There is no dedicated rework skill for this engine. Findings are fixed in-pass: run the re-hydrate block (`/compact` → re-source `/karpathy-guidelines`), fix, then re-review. If `codex` or `coderabbit` is also set, their findings still route to their own rework paths; only `code-review`-raised findings stay inline.

## Composition and `automode`

| Combination | Effect |
|---|---|
| `code-review` + `codex` / `coderabbit` | All set engines run in the same Step 8 pass; each finding's rework routes to the engine that raised it (in-pass for this one). |
| `code-review` + `codex impl` | Valid — and useful: a non-Codex reviewer over a Codex-written diff satisfies the cross-model-review rule with a second independent axis pair. |
| `automode` | The review runs unprompted; non-convergence follows the regular `automode` Step 8 pick-safest path. The pass cap binds unchanged. |
