# forge-skills 0.5.0

Phase 4 of the redesign tracked in [`../docs/specs/2026-05-28-forge-redesign.md`](../docs/specs/2026-05-28-forge-redesign.md). Adds lifecycle entry variants: a second tracker, a new top-level entry verb, and two Step-12/Step-3 flags for branch-aware release flows.

## What's new since 0.4.0

| Addition | Type | Touches | Detail |
|---|---|---|---|
| `/forge pr <N>` | Entry verb | Step 1 grammar + new step semantics | Review-existing-PR mode. Skips Steps 4–7; enters Step 8 against the PR diff. PR-specific Step 12 menu (comment-only / fixup commits / approve / request changes). |
| Linear tracker | Tracker | Step 1c grammar | Sits alongside Jira at `references/trackers/linear.md`. Shares key shape with Jira; both-installed setups get a disambiguation prompt. New `linear` keyword forces routing. |
| `backport` flag | Flag | Step 12 (post-push) | Cherry-picks merged commits onto additional base branches and opens follow-up PRs. Targets from flag value, `.backport-branches`, env, `CONTRIBUTING.md`, or interview. Conflicts pause (or abort that target under `automode`). |
| `stacked` flag | Flag | Step 3 (branch) + Step 12 (push) | Branches off another in-flight PR's head instead of the repo base. Auto-detects Graphite (`gt`) and spr. `stacked + worktree` is the recommended pairing. |

Five anti-pattern rows landed in `references/anti-patterns.md` (one per new flag/verb plus the Jira/Linear disambiguation-repeat rule). Four `automode` composability rows landed in `references/autonomy.md`. `references/flags.md` gained an entry-verbs subsection and updated status for `backport`/`stacked`.

## What changes next

0.6.0 (Phase 5) adds reviewer-ecosystem flags: `coderabbit` (generic-reviewer swap) and `coderabbit:autofix` (rework path parallel to the existing `codex:codex-rescue`). 1.0.0 cuts after Phase 5 soaks.

## Version invariants

- The `version` field in `.claude-plugin/plugin.json` MUST equal the directory name (`0.5.0`).
- The `skills` array in `plugin.json` MUST reference `./skills/forge` only; the package ships exactly one skill at this stage.
- A new minor version = a sibling directory (`0.6.0/`), not an in-place edit.
