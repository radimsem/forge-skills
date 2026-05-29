# Forge — Autonomy & `automode` matrix

`automode` lifts user gates so forge can run end-to-end without prompts. It never lifts the **hard floors** — actions whose blast radius makes silent execution unsafe. Inline `automode:` notes in `SKILL.md` Steps 1–12 stay in place; this file is the single source you cross-check when you need the full picture.

## Default vs `automode`, step by step

| Step | Default behavior | Under `automode` | Hard floor (never lifts) |
|---|---|---|---|
| Step 4 (context check) | Interview user on each missing required field; 2–4 proposed answers, `(Recommended)` marked | Skip interview; pick `(Recommended)`; record the assumption in the proposal | — |
| Step 4a (risky-fork grilling) | `/grill-me` or `/grill-with-docs` if a design fork is ambiguous AND expensive to get wrong | Never grill — grilling interviews the user. Record fork + chosen branch as an explicit proposal assumption | — |
| Step 5 (propose) | End the proposal with next-turn options; wait for user pick | No options, no wait → straight to Step 7 (with `docs`: after writing `CONTEXT.md`) | — |
| Step 6 (the gate) | Do not edit any file until explicit approval (`yes, implement` / `go ahead` / `do it` / `ship it`) | Gate skipped — proposal → Step 7 directly | — |
| Step 7 (implement) | `/goal` set + `/karpathy-guidelines` re-source, then edit the approved plan | Same | — |
| Step 8 (review loop) | Project reviewers + generic reviewer; terminate at zero actionable findings; cap 3 passes; not converged → summarize, ask user | Same engines + cap; not converged → pick safest finding to act on, continue (no user prompt) | 3-pass cap |
| Step 8 — Jira-absent fallback | Warn + 3-choice prompt (paste / auth / abort) | Same — the fallback **still binds** under `automode` because a missing data source is not a gate | Jira-absent fallback |
| Step 9 (refactor) | `/improve-codebase-architecture` surfaces opportunities; user approves | Agent decides — apply only clearly net-positive, in-scope refactors; otherwise continue | — |
| Step 10 (spinoff issues) | Draft via `/to-issues`, show drafts, post on explicit user yes | Post drafts directly | — |
| Step 11 (self-evolution) | Propose `/write-a-skill` or agent-config edit; show diff + path; confirm before write | Apply the smaller-blast-radius option (prefer rule/guide edit over a new skill unless the pattern is clearly broad) | — |
| Step 12 — verify | Run `/goal` pass criteria + repo standard pre-commit checks; show output; green first | Same — agent runs the checks itself and proceeds only on green | `/goal` verification gate |
| Step 12 — closing | Ask the closing question (6-option menu) | Skip the question; emit the proposed small-commit history as a plan only (to `/tmp/forge-<ref>.md` under `docs`, else inline); stop | Never auto-commit / auto-push / Jira write-back |
| Throughout | Stop at substantive gates listed above (Steps 6, 9, 10, 11, 12) | No user gates between Steps 7–11; only hard floors bind | All hard floors above |

## Why these hard floors do not lift

| Floor | Reason |
|---|---|
| No auto-commit / auto-push / Jira write-back | These are externally visible and hard to reverse. The 3rd option in the Step 12 closing menu is the only path that touches Jira; it requires explicit user selection. |
| Step 12 `/goal` verification gate | An unproven "done" is the one failure mode forge must not ship. Verification is cheap; lying is expensive. |
| Step 2 Jira-absent fallback | A missing data source means we cannot trust the issue body. Proceeding silently means proposing against the wrong spec. |
| Step 8 3-pass cap | Past three passes, reviewer disagreement is the signal — not "try harder." |

## Composability with other flags

| Combination | Effect |
|---|---|
| `automode` + `docs` | No interview; write `CONTEXT.md` directly; Step 12 emits plan to `/tmp/forge-<ref>.md` |
| `automode` + `codex` (or `codex challenge`) | Codex review/adversarial-review runs without user prompts; Step 8b rescue delegation auto-decides |
| `automode` + project reviewer subagents missing + no PR | `/greploop` cannot run (needs a PR). Skip to Step 9 with the unmet condition noted. |
| `automode` + `tdd` | TDD discipline binds. The agent writes the test, runs it, confirms red itself, then implements. No user prompt; the failing-test observation is the agent's own. See [modes/tdd.md](modes/tdd.md). |
| `automode` + `worktree` | Worktree is created without prompting. Step 12 cleanup never auto-runs — losing in-progress state on inferred completion is the wrong default. See [modes/worktree.md](modes/worktree.md). |
| `automode` + `lookup` | Fetches happen without prompts. Failures (rate limit, network) become Risks in the proposal, not blockers. See [modes/lookup.md](modes/lookup.md). |
| `automode` + `secure` | Security pass runs unprompted. Must-fix findings apply via the regular `automode` Step 8 pick-safest path. Pass-budget rule still binds. See [modes/secure.md](modes/secure.md). |
| `automode` + `changelog` | Entry is drafted without prompt at Step 12. The commit list is emitted as a plan (per `automode` Step 12 behavior); the changelog entry rides along in that plan. See [modes/changelog.md](modes/changelog.md). |
| `automode` + `ci-watch` | Functionally inert. `automode` skips the closing menu and emits a plan only — no push, so nothing to poll. Combination is valid but no work happens. See [modes/ci-watch.md](modes/ci-watch.md). |
| `automode` + `/forge pr <N>` | Skip the PR-review closing menu; emit the review summary as a plan to `/tmp/forge-pr-<N>.md` and stop. No auto-push of fixup commits, no auto-approve, no auto-request-changes. See [modes/pr-entry.md](modes/pr-entry.md). |
| `automode` + Linear (or Jira/Linear ambiguity) | Cannot interview to disambiguate; attempt Linear first if both trackers connected, record assumption, abort if Linear lookup 404s. See [trackers/linear.md](trackers/linear.md). |
| `automode` + `coderabbit` | Reviewer runs unprompted; Step 8b rework delegation to `coderabbit:autofix` auto-decides. Composes with `codex` — both engines run, rework routes per finding. See [reviewers/coderabbit.md](reviewers/coderabbit.md). |

(This table grows as new flags land. Each flag's reference file states its `automode` behavior in a single row and links here.)
