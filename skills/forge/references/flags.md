# Forge — Flag matrix

The full set of flags the forge skill understands, with composition rules and conflict handling.

## Flags

| Flag | Effect | Detail |
|---|---|---|
| `automode` | No user gates; auto-decide Steps 6/9/10/11; emit Step 12 as plan only | [autonomy.md](autonomy.md) |
| `docs` | Source plan from `CONTEXT.md`; Step 12 proposal → `/tmp/forge-<ref>.md` | — |
| `codex` | Add Codex to the generic-reviewer set (resolve via `scripts/resolve-codex.py`). Claude Code only | [reviewers/codex.md](reviewers/codex.md) |
| `codex challenge` | Codex `review` → `adversarial-review`. Implies `codex` | [reviewers/codex.md](reviewers/codex.md) |
| `codex impl` | Codex (GPT-5.6 auto-tiered: Sol/Terra/Luna) implements Step 7 and handles Step 8b rework; the generic reviewer reverts to the default. Claude Code only | [modes/codex-impl.md](modes/codex-impl.md) |
| `tdd` | Compose `/tdd` at Step 7; observe failing test before implementation | [modes/tdd.md](modes/tdd.md) |
| `worktree` | Compose `superpowers:using-git-worktrees` at Step 3 instead of in-place branch switch | [modes/worktree.md](modes/worktree.md) |
| `lookup` | Query the `context7` MCP/resources at Step 4 for library-specific facts | [modes/lookup.md](modes/lookup.md) |
| `secure` | Compose `security-review` after Step 8 convergence; findings re-enter Step 8 as must-fix | [modes/secure.md](modes/secure.md) |
| `changelog` | At Step 12, draft a changelog entry per repo convention | [modes/changelog.md](modes/changelog.md) |
| `ci-watch` | After Step 12 push, poll CI; on red, re-enter Step 8 with the failure as a finding | [modes/ci-watch.md](modes/ci-watch.md) |
| `compress` | Before Step 1, source a token-saving output skill for the session: `ponytail` if installed, else `caveman`, else ignore the flag with a one-line note | [modes/compress.md](modes/compress.md) |
| `coderabbit` | Add CodeRabbit to the generic-reviewer set. Step 8b rework path uses `coderabbit:autofix`. Claude Code only | [reviewers/coderabbit.md](reviewers/coderabbit.md) |

## Entry verbs

In addition to the flags above, the skill supports an entry-mode verb:

| Verb | Effect | Detail |
|---|---|---|
| `/forge pr <N>` | Skip Steps 4–7; enter Step 8 against the existing PR diff. Pre-Step-8 flags are ignored; Step-8-or-later flags apply | [modes/pr-entry.md](modes/pr-entry.md) |

## Composition rules

| Rule | Why |
|---|---|
| `codex` and `coderabbit` compose | Both run in the same Step 8 pass; each finding's rework routes to the engine that raised it. |
| `codex challenge` implies `codex` | Challenge mode is a variant of the Codex reviewer pass. |
| `codex impl` reverts the generic reviewer to the default | The model family that wrote the diff must never be the only reviewer (cross-model review). `codex impl challenge` re-adds Codex adversarial review as an *additional* engine, never the only one. |
| `codex impl` is inert at Step 7 under `/forge pr <N>` | PR mode has no Step 7; the Step 8b rework tiering still applies. One-line note, no error. |
| `ci-watch` requires the Step 12 push option | Polling without a published target is pointless. Silently skip if user picked a non-push Step 12 option. |
| `tdd` discipline binds under `automode` | The "observe failing test before implementing" rule is the point of the flag; under `automode` the agent runs the test itself and confirms red. |
| `/forge pr <N>` ignores all lifecycle flags except `automode` and reviewer flags | PR-review mode skips Step 7 implementation; only Step 8 reviewer engines and the `automode` no-gates property apply. |
| `compress` composes with every flag and entry mode, including `pr` | It shapes session output, not the lifecycle; no step depends on it. Inert (one-line note) when neither `ponytail` nor `caveman` is installed. |
