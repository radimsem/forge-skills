# Forge — Anti-patterns

Patterns that cause forge to misbehave or ship the wrong work. Split into two files at 0.6.0 → 1.0.0 (the unified file crossed the size threshold from spec §11):

- **[mistakes.md](mistakes.md)** — Common Mistakes table. 33 rows covering pre-implementation discipline, the review loop, Step 12 closing, and per-flag mistakes. Lookup table for "I'm about to do X, is that wrong?"
- **[red-flags.md](red-flags.md)** — Red Flags STOP list. 12 bullets covering specific phrases that should halt forward motion. Pattern-match against your own reasoning out loud, not against the user's words.

Both bind under `automode` — `automode` lifts user gates, not safety floors.

## When to add a new entry

Add a row to **mistakes.md** when forge does the wrong thing and a corrective rule generalizes beyond a single session. Format: "What forge did wrong | What it should do instead (with reference link if applicable)".

Add a bullet to **red-flags.md** when there's a *rationalization* the agent should learn to recognize. Format: `"Quoted thought" → terse corrective.` (Quoted thought = first-person agent self-talk; corrective = action, not explanation.)

New rules should also link to the relevant reference file (`modes/<flag>.md`, `reviewers/<name>.md`, `trackers/<name>.md`) so the rule's context is one click away.

## Backwards compatibility

Pre-0.6.0 links pointing at `anti-patterns.md` resolve to this file; readers see this index and follow through to `mistakes.md` or `red-flags.md`. New cross-references should point at the leaf file directly when possible.
