# forge-skills 0.6.0

Phase 5 of the redesign tracked in [`../docs/specs/2026-05-28-forge-redesign.md`](../docs/specs/2026-05-28-forge-redesign.md). The reviewer-ecosystem phase — adds CodeRabbit as a generic-reviewer alternative to Codex, with its own rework-delegation path.

## What's new since 0.5.0

| Addition | Type | Touches | Detail |
|---|---|---|---|
| `coderabbit` flag | Flag | Step 8 generic-reviewer slot | Swaps `superpowers:requesting-code-review` for `coderabbit:code-review`. Project subagents still run. **Mutually exclusive with `codex` / `codex challenge`** — combination errors before Step 1. Claude Code only. |
| `coderabbit:autofix` rework path | §8b path | Step 8 rework delegation | Mirror of `codex:codex-rescue` for the CodeRabbit reviewer. ⟲ first, inline karpathy constraints, foreground `--wait`. |
| Reviewer matrix in review-loop.md | Reference doc | `references/review-loop.md` | The §8a engine table and §8b rework delegation table now cover all three reviewer modes (default / codex / coderabbit) in one place. SKILL.md mirrors the matrix in the §8a/§8b section. |

One new anti-pattern row (`codex` + `coderabbit` collision). One new `automode` composability row (`automode` + `coderabbit`).

## Status

All 13 planned flags are now shipped. `references/flags.md` shows 13/13 ✓ in the status column.

`anti-patterns.md` is at ~55 lines / ~8 KB. The split into `mistakes.md` + `red-flags.md` is queued for the polish PR that precedes the 1.0.0 cut.

## What's next

1.0.0 cuts after a polish PR (SKILL.md description sync + anti-patterns split) and a brief soak. Post-1.0, breaking flag changes become major bumps; non-breaking flag additions and reference updates can be minor bumps.

## Version invariants

- The `version` field in `.claude-plugin/plugin.json` MUST equal the directory name (`0.6.0`).
- The `skills` array in `plugin.json` MUST reference `./skills/forge` only; the package ships exactly one skill at this stage.
- A new minor version = a sibling directory (`0.7.0/` or `1.0.0/`), not an in-place edit.
