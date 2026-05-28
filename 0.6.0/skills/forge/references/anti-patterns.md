# Forge — Anti-patterns & Red Flags

Patterns that cause forge to misbehave or ship the wrong work. Skim before invoking the skill; refresh if a pass surprises you. New rules learned during a forge session land here, not in `SKILL.md`.

Both sections bind under `automode` too — `automode` lifts user gates, not safety floors.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Editing code before "yes, implement" (no `automode`) | Stop. Re-read Step 6. Revert. |
| Full-codebase sweep before proposing | Inventory already-loaded context first; read only issue-named + top candidate files (Step 4). |
| Hardcoding branch prefixes when the repo has a git guide | Repo guide wins (Step 3). |
| Open free-text interview questions | Propose 2–4 answers, mark `(Recommended)`, let the user select. |
| Sourcing `/grill-me` under `automode` | Forbidden — grilling interviews the user. Record assumptions instead. |
| Restating `/goal` in the ⟲ block | `/goal` is set once (Step 7); ⟲ is `/compact` + karpathy only. |
| Assuming GitHub / `gh` | Detect the host, pick the CLI (Step 1). |
| `.claude/` / `CLAUDE.md` as the only config | Use the agent-general guide/dir for your runtime. |
| One giant squash commit by default | Propose a small atomic history matching the branch (Step 12); repo guide can still override. |
| Auto-committing under `automode` | `automode` lifts gates but never the no-auto-commit floor. |
| Reading only the issue body, not comments | Latest comment usually has the real spec. |
| Bare number → Jira ticket | Bare `N` = git-host; Jira needs key-shape or `ticket` keyword (grammar). |
| Silent continue when Jira MCP absent | Warn, then 3-choice fallback (Step 2). Even under `automode`. |
| `Skill(codex:review)` / `Skill(codex:rescue)` | `disable-model-invocation` — drive `codex-companion.mjs` over Bash (§8a); rescue = **Agent** subagent `codex:codex-rescue` (§8b). |
| Codex flag under non-Claude-Code runtime | Ignore + warn once; generic reviewer stays `superpowers:requesting-code-review` (Parameters, §8a). |
| Telling Codex to "source /karpathy-guidelines" | Codex can't run Claude skills — inline principles as prompt constraints (§8b). |
| `codex` replacing project reviewer agents | `codex` swaps only the *generic* reviewer; project agents always run (Step 8). |
| Both Codex review + adversarial-review | `codex challenge` implies `codex`, replaces the pass — never both (§8a). |
| Forcing `PROJ-123` into commit subjects | Repo guide wins; default = key in branch only (Step 3). |
| Proposing commits without running `/goal` | Step 12 verify gate — run pass criteria + repo checks, show output, green first. Binds under `automode` too. |
| Re-running the full Step 8 loop (⟲ + both reviewers) for pure trim cleanup after a clean substantive pass | Apply the trims inline, run the repo verify command, move to Step 9. The 3-pass cap is for non-convergence, not for nit verification. Trim = doc-comment edits, blank-line grouping, naming touch-ups; no logic touched. |
| Writing implementation code before observing the failing test under the `tdd` flag | Compose `superpowers:test-driven-development` per the [modes/tdd.md](modes/tdd.md) contract: write the test first, run it, confirm red, then implement. `automode` does not lift this discipline; the agent runs the test itself and confirms red before any implementation edit. |
| Leaving the worktree behind after Step 12 closes (`git worktree list` fills with stale entries; disk usage grows) | Read the Step 12 closing addendum; run `git worktree remove <path>` (or `git worktree prune` if the branch was deleted) when the changes are merged or discarded. Cleanup never auto-runs, even under `automode` — losing in-progress state on inferred completion is the wrong default. See [modes/worktree.md](modes/worktree.md). |
| Relying on training-data recall for library-specific API claims when `lookup` is available | If the issue mentions a library/framework/SDK/CLI/cloud service and the proposal makes specific API claims, set `lookup` so the proposal is grounded in fetched current docs. Training data ages; library APIs do not stand still. Skip `lookup` only when the issue is pure business logic with no library surface. See [modes/lookup.md](modes/lookup.md). |
| Using the deprecated `with docs` spelling in `/forge` invocations | Update to `docs`. The alias was removed in 0.3.0; `with docs` no longer parses. See [flags.md](flags.md). |
| Running `security-review` only as the last check rather than as a Step 8 gate under `secure` | The post-Step-8 placement is deliberate. Security findings must be addressed before Step 9/12, not surfaced after close when re-opening the diff is costly. See [modes/secure.md](modes/secure.md). |
| Drafting the `changelog` entry before `/goal` verifies green | The entry must reflect what actually shipped. If the verify gate fails and Step 8 reopens, the previous draft is stale; redraft after re-convergence. Never include a changelog entry in a commit list whose verify failed. See [modes/changelog.md](modes/changelog.md). |
| Setting `ci-watch` without choosing a push option (Step 12 menu options 2 or 3) | Polling has no target; the flag becomes inert. Pick option 2 or 3 deliberately, or unset `ci-watch`. See [modes/ci-watch.md](modes/ci-watch.md). |
| Using `/forge pr <N>` to "re-review" the PR you just finished with `/forge <issue>` | The forge run already executed Step 8 against the same diff; rerunning burns reviewer budget without new signal. Use `/forge pr <N>` for PRs you did not produce in this session. See [modes/pr-entry.md](modes/pr-entry.md). |
| Forcing the Jira/Linear disambiguation prompt to repeat for the same key in one session | If both trackers are configured and the user already picked one for `<KEY>-N`, remember the choice for the session. Re-prompt only for a different key prefix. See [trackers/linear.md](trackers/linear.md). |
| Cherry-picking `backport` targets before the primary PR lands | The flag opens the backport PRs immediately at Step 12. If the primary PR changes during review, the backports go stale. Verify the primary review is converged before merging anything. See [modes/backport.md](modes/backport.md). |
| Rebasing a `stacked` branch with `git rebase <new-base>` instead of `git rebase --onto <new-base>` | The plain form clobbers the base PR's new commits. Use `git rebase --onto <new-base-head> <old-base-head> <stacked-branch>`, or let Graphite/spr handle the multi-PR sync. Do not mix manual rebase with tool-driven sync. See [modes/stacked.md](modes/stacked.md). |
| Combining `codex` and `coderabbit` flags in one `/forge` invocation | Both replace the generic reviewer slot. Combination aborts before Step 1 with an explicit error. Pick exactly one (or neither, for the default). See [reviewers/coderabbit.md](reviewers/coderabbit.md). |

## Red Flags — STOP

- "I'll just start with the obvious change." → propose first (unless `automode`).
- "User said /forge, that means implement." → it means *propose* (unless `automode`).
- "Let me read the codebase first to be safe." → use already-sourced context + issue-named files only; unknowns go in Risks (Step 4).
- "The repo's CONTRIBUTING says X but my default says Y." → the repo wins.
- "I'll grill the user even though it's `automode`." → no — record the assumption.
- "Refactor looks good, I'll just commit it." → Step 12 proposes; it never commits.
- "No Atlassian MCP — I'll guess the ticket from context." → no; warn + 3-choice fallback (Step 2).
- "Codex unavailable, skip the review pass." → no; degrade to `superpowers:requesting-code-review`, keep the loop (§8a).
- "Not Claude Code but I'll run codex anyway." → no; codex plugin is CC-only — ignore flag, warn, generic reviewer.
- "Codex proposed a fix, commit its diff from the loop." → re-review in Step 8 first; Step 12 proposes, never commits.
- "Tests probably pass, I'll propose the commits." → no; Step 12 verify gate runs `/goal` + repo checks and shows output before any proposal.
- "I'll comment on the Jira ticket to keep it updated." → only on the explicit Step 12 write-back pick; never else, never `automode`.
