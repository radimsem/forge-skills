# forge-skills 0.1.0

Initial packaged release of the **forge** skill. This is the Phase 0 baseline — a verbatim copy of the previously-shipped `~/.claude/skills/forge/` tree, brought under version control to enable the five-phase redesign tracked in [`../docs/specs/2026-05-28-forge-redesign.md`](../docs/specs/2026-05-28-forge-redesign.md).

## What's in this version

- `skills/forge/SKILL.md` — the 350-line orchestrator (Steps 1–12, two-part gate-then-lifecycle structure).
- `skills/forge/references/jira.md` — Jira specifics extracted at v0 (already a reference, not in the spine).
- `skills/forge/references/codex.md` — Codex reviewer specifics (§8a/§8b).
- `skills/forge/scripts/resolve-codex.py` — helper that locates the local Codex CLI for the `codex` flag path.

## What changes next

0.2.0 lands the Phase 1 structural split — six atomic PRs that extract `anti-patterns.md`, `autonomy.md`, `proposal-template.md`, `review-loop.md`, regroup `references/{trackers,reviewers,modes}/`, and rename the `with docs` flag to `docs` (alias preserved for one release). No behavior changes in 0.2.0 — the baseline-only PR for the new layout is the safest first ship.

See the design doc for the full per-phase delta.

## Version invariants

- The `version` field in `.claude-plugin/plugin.json` MUST equal the directory name (`0.1.0`).
- The `skills` array in `plugin.json` MUST reference `./skills/forge` only; the package ships exactly one skill at this stage.
- A new minor version = a sibling directory (`0.2.0/`), not an in-place edit. The previous version stays for rollback until explicitly removed.
