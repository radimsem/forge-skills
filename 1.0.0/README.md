# forge-skills 1.0.0

Stable release. The five-phase redesign tracked in [`../docs/specs/2026-05-28-forge-redesign.md`](../docs/specs/2026-05-28-forge-redesign.md) is complete.

## What 1.0.0 contains

The full surface, end-to-end:

| Surface | Count | Detail |
|---|---|---|
| Lifecycle steps | 12 | Numbered Steps 1–12 in `skills/forge/SKILL.md`, split into Part 1 (the gate, 1–6) and Part 2 (the post-approval lifecycle, 7–12). |
| Flags | 13 | `automode`, `docs`, `tdd`, `worktree`, `lookup`, `secure`, `changelog`, `ci-watch`, `backport`, `stacked`, `codex`, `codex challenge`, `coderabbit`. Full matrix in `skills/forge/references/flags.md`. |
| Entry verbs | 2 | `/forge <ref>` (issue/ticket) and `/forge pr <N>` (PR-review mode). |
| Trackers | 2 | Jira (`skills/forge/references/trackers/jira.md`) and Linear (`skills/forge/references/trackers/linear.md`). |
| Reviewers | 3 | Default `superpowers:requesting-code-review`, Codex (`skills/forge/references/reviewers/codex.md`), CodeRabbit (`skills/forge/references/reviewers/coderabbit.md`). `codex` and `coderabbit` are XOR. |
| Reference files | 15 | `skills/forge/references/` holds `flags.md`, `autonomy.md`, `proposal-template.md`, `review-loop.md`, `mistakes.md`, `red-flags.md`, `anti-patterns.md` (index), plus subdirs `trackers/`, `reviewers/`, `modes/`. |
| Scripts | 1 | `skills/forge/scripts/resolve-codex.py` for the `codex` flag's CLI resolution. |

## Stability promise (post-1.0)

- Flag renames and removals are major-version changes.
- New flags or modes ship as minor bumps (e.g. 1.1.0).
- Reference-only updates (anti-patterns, autonomy edits, doc clarifications) ship as patch bumps.
- The `/forge <ref>` and `/forge pr <N>` entry verbs are stable; new entry verbs are minor bumps.
- `automode` semantics are stable; expanding the hard-floor list is a minor bump (more conservative) but contracting it is a major bump (less safe).

## Upgrade from 0.x

The `with docs` alias was removed in 0.3.0; if you have invocations using it, update to `docs`. No other breaking changes between 0.6.0 and 1.0.0.

## Version invariants

- The `version` field in `.claude-plugin/plugin.json` MUST equal the directory name (`1.0.0`).
- The `skills` array in `plugin.json` MUST reference `./skills/forge` only; the package ships exactly one skill at this stage.
- Future versions live in sibling directories (`1.1.0/`, `2.0.0/`, etc.).

## Install

```sh
/plugin install /path/to/forge-skills/1.0.0
```
