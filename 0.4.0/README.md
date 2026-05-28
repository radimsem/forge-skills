# forge-skills 0.4.0

Phase 3 of the redesign tracked in [`../docs/specs/2026-05-28-forge-redesign.md`](../docs/specs/2026-05-28-forge-redesign.md). Adds three post-implementation gates that operate at or after Step 8 and Step 12.

## What's new since 0.3.0

| Flag | Composes | Fires at | Detail |
|---|---|---|---|
| `secure` | `security-review` skill | Post-Step-8 (after regular convergence) | Must-fix security findings reopen Step 8 with one dedicated security pass. Required before Step 9. |
| `changelog` | None (internal logic) | Step 12 (after `/goal` verifies green) | Drafts a changelog entry per the repo's existing format and includes it in the proposed commit list. Skips silently if no changelog file is detected. |
| `ci-watch` | None (host CI CLI: `gh run`, `glab ci`, …) | After Step 12 push (menu options 2 or 3) | Polls CI for the pushed HEAD. On red, re-enters Step 8 with the failure as a must-fix finding. Inert under `automode` or with non-push menu options. |

Each flag has a reference file under `skills/forge/references/modes/`. Three matching anti-pattern rows landed in `references/anti-patterns.md`. The `automode` matrix in `references/autonomy.md` gained three composability rows; `references/flags.md` status column updated.

## Threshold note

`anti-patterns.md` now sits at 53 lines / ~7.3 KB — past the §11 6 KB threshold. The spec's planned split into `mistakes.md` + `red-flags.md` is held until it can ship as its own atomic PR rather than bundled with a flag addition.

## What changes next

0.5.0 (Phase 4) adds lifecycle entry variants: `/forge pr <N>` (review-existing-PR mode), Linear tracker, `backport` flag, `stacked` flag.

See the spec for the full per-phase delta.

## Version invariants

- The `version` field in `.claude-plugin/plugin.json` MUST equal the directory name (`0.4.0`).
- The `skills` array in `plugin.json` MUST reference `./skills/forge` only; the package ships exactly one skill at this stage.
- A new minor version = a sibling directory (`0.5.0/`), not an in-place edit.
