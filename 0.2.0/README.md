# forge-skills 0.2.0

Phase 1 of the redesign tracked in [`../docs/specs/2026-05-28-forge-redesign.md`](../docs/specs/2026-05-28-forge-redesign.md). Pure structural split — no observable behavior change. The forge skill still runs the same Steps 1–12 against the same invocations; what moved is *where each rule lives*.

## What's in this version

- `skills/forge/SKILL.md` — the spine. ~265 lines, down from the 0.1.0 baseline of ~350. Each Step holds the rule and points at a reference file for the literal block format or extended discussion.
- `skills/forge/references/anti-patterns.md` — Common Mistakes table + Red Flags stop list + the new trim-only-cleanup rule (encoded from prior-session memory).
- `skills/forge/references/autonomy.md` — the full per-step `automode` matrix, hard-floor rationale, and flag-composability rows.
- `skills/forge/references/proposal-template.md` — the literal Step 4 Q-block, Step 5 proposal block, Step 5 next-turn options, and Step 12 6-option closing menu.
- `skills/forge/references/review-loop.md` — Step 8 engine selection, termination rule, 3-pass cap, pass discipline, trim-only-cleanup skip rule.
- `skills/forge/references/trackers/jira.md` — Jira specifics (moved from `references/jira.md` for symmetry with the upcoming `linear.md` in Phase 4).
- `skills/forge/references/reviewers/codex.md` — Codex reviewer specifics (moved from `references/codex.md` for symmetry with the upcoming `coderabbit.md` in Phase 5).
- `skills/forge/scripts/resolve-codex.py` — helper that locates the local Codex CLI for the `codex` flag path.

## Flag changes since 0.1.0

`with docs` is now spelled `docs`. The original spelling is accepted as a deprecated alias for this release; the alias will be removed in 0.3.0.

## What changes next

0.3.0 (Phase 2) adds three pre-implementation safety flags — `tdd`, `worktree`, `lookup` — each composing a user-installed skill at a different Step.

See the spec for the full per-phase delta.

## Version invariants

- The `version` field in `.claude-plugin/plugin.json` MUST equal the directory name (`0.2.0`).
- The `skills` array in `plugin.json` MUST reference `./skills/forge` only; the package ships exactly one skill at this stage.
- A new minor version = a sibling directory (`0.3.0/`), not an in-place edit.
