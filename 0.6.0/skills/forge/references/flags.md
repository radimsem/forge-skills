# Forge — Flag matrix

The full set of flags the forge skill understands, with composition rules and conflict handling. Status column tracks what's shipped today; planned rows describe the post-Phase-5 target per the [design spec](../../../../docs/specs/2026-05-28-forge-redesign.md) §5.

## Flags

| Flag | Status | Effect | Detail |
|---|---|---|---|
| `automode` | ✓ 0.1.0 | No user gates; auto-decide Steps 6/9/10/11; emit Step 12 as plan only | [autonomy.md](autonomy.md) |
| `docs` | ✓ 0.2.0 (was `with docs`; alias dropped in 0.3.0) | Source plan from `CONTEXT.md`; Step 12 proposal → `/tmp/forge-<ref>.md` | — |
| `codex` | ✓ 0.1.0 | Generic reviewer → Codex (resolve via `scripts/resolve-codex.py`). Claude Code only | [reviewers/codex.md](reviewers/codex.md) |
| `codex challenge` | ✓ 0.1.0 | Codex `review` → `adversarial-review`. Implies `codex` | [reviewers/codex.md](reviewers/codex.md) |
| `tdd` | ✓ 0.3.0 (PR 2a) | Compose `superpowers:test-driven-development` at Step 7; observe failing test before implementation | [modes/tdd.md](modes/tdd.md) |
| `worktree` | ✓ 0.3.0 (PR 2b) | Compose `superpowers:using-git-worktrees` at Step 3 instead of in-place branch switch | [modes/worktree.md](modes/worktree.md) |
| `lookup` | ✓ 0.3.0 (PR 2c) | Compose `find-docs` (+ `context7` MCP if available) at Step 4 for library-specific facts | [modes/lookup.md](modes/lookup.md) |
| `secure` | ✓ 0.4.0 (PR 3a) | Compose `security-review` after Step 8 convergence; findings re-enter Step 8 as must-fix | [modes/secure.md](modes/secure.md) |
| `changelog` | ✓ 0.4.0 (PR 3b) | At Step 12, draft a changelog entry per repo convention | [modes/changelog.md](modes/changelog.md) |
| `ci-watch` | ✓ 0.4.0 (PR 3c) | After Step 12 push, poll CI; on red, re-enter Step 8 with the failure as a finding | [modes/ci-watch.md](modes/ci-watch.md) |
| `backport` | ✓ 0.5.0 (PR 4c) | At Step 12, cherry-pick merged commits onto additional base branches | [modes/backport.md](modes/backport.md) |
| `stacked` | ✓ 0.5.0 (PR 4d) | Step 3 branches off another in-flight PR's HEAD; Step 12 push targets the stacked-PR convention | [modes/stacked.md](modes/stacked.md) |
| `coderabbit` | ✓ 0.6.0 (PR 5a) | Generic reviewer → CodeRabbit. §8b rework path uses `coderabbit:autofix`. Claude Code only. **XOR with `codex`** | [reviewers/coderabbit.md](reviewers/coderabbit.md) |

## Entry verbs

In addition to the flags above, the skill supports an entry-mode verb:

| Verb | Status | Effect | Detail |
|---|---|---|---|
| `/forge pr <N>` | ✓ 0.5.0 (PR 4a) | Skip Steps 4–7; enter Step 8 against the existing PR diff. Pre-Step-8 flags are ignored; Step-8-or-later flags apply | [modes/pr-entry.md](modes/pr-entry.md) |

## Composition rules

| Rule | Why |
|---|---|
| `codex` and `coderabbit` are mutually exclusive | Both replace the generic reviewer slot. Ambiguous in combination; abort before Step 1 with a one-line error. |
| `codex challenge` implies `codex` | Preserved from 0.1.0. |
| `ci-watch` requires the Step 12 push option | Polling without a published target is pointless. Silently skip if user picked a non-push Step 12 option. |
| `backport` requires the Step 12 push option | Same reasoning. |
| `stacked` + `worktree` compose freely | Worktree is the recommended scaffold for stacked PR work. |
| `tdd` discipline binds under `automode` | The "observe failing test before implementing" rule is the point of the flag; under `automode` the agent runs the test itself and confirms red. |
| `/forge pr <N>` (Phase 4 entry mode) ignores all lifecycle flags except `automode` and reviewer flags | PR-review mode skips Step 7 implementation; only Step 8 reviewer engines and the `automode` no-gates property apply. |

## Conflicting-flag handling

On invocation parse, if two mutually exclusive flags are present, abort before Step 1 with:

```
Error: flags `<a>` and `<b>` cannot be combined. <reason>.
```

No silent precedence. The user must re-invoke. Guessing wrong is non-trivial — wrong reviewer can change which findings surface.
