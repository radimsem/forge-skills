# Anti-patterns & red flags

Canonical home for blueprint lessons; add new ones here, not to SKILL.md.

| Anti-pattern | Correction |
|---|---|
| Generic-framework mockups that could be any app | No screen before harvest; every fragment leans on `.brainstorm/style.css` |
| Re-improvising the frame or composer inline | Interactive machinery ships in `scripts/`; fragments carry content only |
| Reusing a screen filename | New file per revision (`layout-v2.html`); the server serves the newest |
| Accepting a paste with a stale `[blueprint:…]` header | Stop and ask; never guess which round an answer belongs to |
| Leaving a resolved screen up during terminal discussion | Push a fresh `waiting-N.html` |
| Implementation before the Step 6 gate | Hard stop — the gate has no bypass in this skill |
| Hand-writing flag chips into the handoff builder | Metadata is generated from the two skills' `flags.md` at recap time |
| Pushing screens with heredocs | File-creation tool only; heredocs dump noise into the terminal |
