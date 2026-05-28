# forge-skills 0.3.0

Phase 2 of the redesign tracked in [`../docs/specs/2026-05-28-forge-redesign.md`](../docs/specs/2026-05-28-forge-redesign.md). Adds three pre-implementation safety flags; each composes an existing user-installed skill at a different Step.

## What's new since 0.2.0

| Flag | Composes | Fires at | Detail |
|---|---|---|---|
| `tdd` | `superpowers:test-driven-development` | Step 7 | Failing test first, observe red, then implement. Discipline binds under `automode`. |
| `worktree` | `superpowers:using-git-worktrees` | Step 3 | Sibling worktree instead of in-place switch. Step 12 closing appends cleanup reminder; cleanup never auto-runs. |
| `lookup` | `find-docs` (+ `context7` MCP if available) | Step 4 | Fetch current library docs for any library/framework/SDK/CLI/cloud service the issue mentions. Failures become Risks, not blockers, under `automode`. |

Each flag has a reference file under `skills/forge/references/modes/` documenting the contract, manual verification recipe, composition rules, and `automode` behavior. Three matching anti-pattern rows landed in `references/anti-patterns.md`. The `automode` matrix in `references/autonomy.md` gained three composability rows.

A central `skills/forge/references/flags.md` matrix now tracks the full 13-flag plan, with a status column distinguishing shipped flags (✓) from planned ones.

## Breaking change

The deprecated `with docs` alias for the `docs` flag has been removed. Invocations that used the old spelling no longer parse. The anti-patterns table includes a row pointing migrators at the replacement.

## What changes next

0.4.0 (Phase 3) adds three post-implementation gates — `secure`, `changelog`, `ci-watch` — operating at or after Step 8 and Step 12.

See the spec for the full per-phase delta.

## Version invariants

- The `version` field in `.claude-plugin/plugin.json` MUST equal the directory name (`0.3.0`).
- The `skills` array in `plugin.json` MUST reference `./skills/forge` only; the package ships exactly one skill at this stage.
- A new minor version = a sibling directory (`0.4.0/`), not an in-place edit.
