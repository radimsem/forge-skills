# Forge — Common Mistakes

Anti-pattern table: things to avoid, with the fix in the second column. Each row is independent; skim in any order. Both this file and [red-flags.md](red-flags.md) bind under `automode` — `automode` lifts user gates, not safety floors.

| Mistake | Fix |
|---|---|
| Editing code before "yes, implement" (no `automode`) | Stop. Re-read Step 6. Revert. |
| Full-codebase sweep before proposing | Inventory already-loaded context first; read only issue-named + top candidate files (Step 4). |
| Hardcoding branch prefixes when the repo has a git guide | Repo guide wins (Step 3). |
| Open free-text interview questions | Propose 2–4 answers, mark `(Recommended)`, let the user select. |
| Sourcing `/grill-me` under `automode` | Forbidden — grilling interviews the user. Record assumptions instead. |
| Restating `/goal` in the re-hydrate block | `/goal` is set once (Step 7); the re-hydrate block is `/compact` plus karpathy only. |
| Assuming GitHub / `gh` | Detect the host, pick the CLI (Step 1). |
| `.claude/` / `CLAUDE.md` as the only config | Use the agent-general guide/dir for your runtime. |
| One giant squash commit by default | Propose a small atomic history matching the branch (Step 12); repo guide can still override. |
| Auto-committing under `automode` | `automode` lifts gates but never the no-auto-commit floor. |
| Reading only the issue body, not comments | Latest comment usually has the real spec. |
| Bare number → Jira ticket | Bare `N` = git-host; Jira needs key-shape or `ticket` keyword (grammar). |
| Silent continue when Jira MCP absent | Warn, then 3-choice fallback (Step 2). Even under `automode`. |
| `Skill(codex:review)` / `Skill(codex:rescue)` | `disable-model-invocation` — drive `codex-companion.mjs` over Bash (Step 8a); rescue = **Agent** subagent `codex:codex-rescue` (Step 8b). |
| Codex flag under non-Claude-Code runtime | Ignore + warn once; generic reviewer stays `superpowers:requesting-code-review` (Parameters, Step 8a). |
| Telling Codex to "source /karpathy-guidelines" | Codex can't run Claude skills — inline principles as prompt constraints (Step 8b). |
| `codex` replacing project reviewer agents | `codex` swaps only the *generic* reviewer; project agents always run (Step 8). |
| Both Codex review + adversarial-review | `codex challenge` implies `codex`, replaces the pass — never both (Step 8a). |
| Forcing `PROJ-123` into commit subjects | Repo guide wins; default = key in branch only (Step 3). |
| Proposing commits without running `/goal` | Step 12 verify gate — run pass criteria + repo checks, show output, green first. Binds under `automode` too. |
| Re-running the full Step 8 loop (the re-hydrate block plus both reviewers) for pure trim cleanup after a clean substantive pass | Apply the trims inline, run the repo verify command, move to Step 9. The 3-pass cap is for non-convergence, not for nit verification. Trim = doc-comment edits, blank-line grouping, naming touch-ups; no logic touched. |
| Writing implementation code before observing the failing test under the `tdd` flag | Compose `/tdd` per the [modes/tdd.md](modes/tdd.md) contract: write the test first, run it, confirm red, then implement. `automode` does not lift this discipline; the agent runs the test itself and confirms red before any implementation edit. |
| Leaving the worktree behind after Step 12 closes (`git worktree list` fills with stale entries; disk usage grows) | Read the Step 12 closing addendum; run `git worktree remove <path>` (or `git worktree prune` if the branch was deleted) when the changes are merged or discarded. Cleanup never auto-runs, even under `automode` — losing in-progress state on inferred completion is the wrong default. See [modes/worktree.md](modes/worktree.md). |
| Relying on training-data recall for library-specific API claims when `lookup` is available | If the issue mentions a library/framework/SDK/CLI/cloud service and the proposal makes specific API claims, set `lookup` so the proposal is grounded in fetched current docs. Training data ages; library APIs do not stand still. Skip `lookup` only when the issue is pure business logic with no library surface. See [modes/lookup.md](modes/lookup.md). |
| Using the deprecated `with docs` spelling in `/forge` invocations | Update to `docs`. The `with docs` alias no longer parses. See [flags.md](flags.md). |
| Running `security-review` only as the last check rather than as a Step 8 gate under `secure` | The post-Step-8 placement is deliberate. Security findings must be addressed before Step 9/12, not surfaced after close when re-opening the diff is costly. See [modes/secure.md](modes/secure.md). |
| Drafting the `changelog` entry before `/goal` verifies green | The entry must reflect what actually shipped. If the verify gate fails and Step 8 reopens, the previous draft is stale; redraft after re-convergence. Never include a changelog entry in a commit list whose verify failed. See [modes/changelog.md](modes/changelog.md). |
| Setting `ci-watch` without choosing a push option (Step 12 menu options 2 or 3) | Polling has no target; the flag becomes inert. Pick option 2 or 3 deliberately, or unset `ci-watch`. See [modes/ci-watch.md](modes/ci-watch.md). |
| Using `/forge pr <N>` to "re-review" the PR you just finished with `/forge <issue>` | The forge run already executed Step 8 against the same diff; rerunning burns reviewer budget without new signal. Use `/forge pr <N>` for PRs you did not produce in this session. See [modes/pr-entry.md](modes/pr-entry.md). |
| Forcing the Jira/Linear disambiguation prompt to repeat for the same key in one session | If both trackers are configured and the user already picked one for `<KEY>-N`, remember the choice for the session. Re-prompt only for a different key prefix. See [trackers/linear.md](trackers/linear.md). |
| Combining `codex` and `coderabbit` flags in one `/forge` invocation | Both replace the generic reviewer slot. Combination aborts before Step 1 with an explicit error. Pick exactly one (or neither, for the default). See [reviewers/coderabbit.md](reviewers/coderabbit.md). |
| Running `/compact` before recording the review findings | Capture the must-fix / should-fix list first; `/compact` sheds the transcript, not the list. Fix from the list (re-hydrate block). |
| Implementing a stale `CONTEXT.md` from an earlier run under `docs` | Stamp it with its ref at Step 5; check the stamp matches at Step 7; on mismatch, re-propose. |
