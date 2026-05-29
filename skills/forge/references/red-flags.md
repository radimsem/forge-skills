# Forge — Red Flags

Phrases that should make you STOP. If a thought matches one of these, the corrective is in the second clause — apply it, do not rationalize.

Both this file and [mistakes.md](mistakes.md) bind under `automode` — `automode` lifts user gates, not safety floors.

- "I'll just start with the obvious change." → propose first (unless `automode`).
- "User said /forge, that means implement." → it means *propose* (unless `automode`).
- "Let me read the codebase first to be safe." → use already-sourced context + issue-named files only; unknowns go in Risks (Step 4).
- "The repo's CONTRIBUTING says X but my default says Y." → the repo wins.
- "I'll grill the user even though it's `automode`." → no — record the assumption.
- "Refactor looks good, I'll just commit it." → Step 12 proposes; it never commits.
- "No Atlassian MCP — I'll guess the ticket from context." → no; warn + the Jira-absent fallback (Step 2).
- "Codex unavailable, skip the review pass." → no; degrade to `superpowers:requesting-code-review`, keep the loop (Step 8a).
- "Not Claude Code but I'll run codex anyway." → no; codex plugin is CC-only — ignore flag, warn, generic reviewer.
- "Codex proposed a fix, commit its diff from the loop." → re-review in Step 8 first; Step 12 proposes, never commits.
- "Tests probably pass, I'll propose the commits." → no; Step 12 verify gate runs `/goal` + repo checks and shows output before any proposal.
- "I'll comment on the Jira ticket to keep it updated." → only on the explicit Step 12 write-back pick; never else, never `automode`.
- "Tests exited 0, we're green." → confirm tests actually ran; "no tests collected" is not a pass (Step 12).
- "Reviewer returned nothing, converged." → confirm it ran; an errored or empty reviewer is not a clean pass (Step 8).
- "git switch failed, I'll pick another branch name." → no; surface the error and ask (Step 3).
