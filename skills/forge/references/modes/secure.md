# Forge — `secure` flag

Composes the `security-review` skill after Step 8 converges (zero actionable findings from the regular reviewers). Security findings re-enter Step 8 as must-fix; the loop reopens until they're addressed.

## Manual verification recipe

```
/forge issue 42 secure
```

Expected: Step 8 runs to convergence as usual. On zero actionable findings, forge composes `security-review` against the same diff. Each finding is classified must-fix or should-fix. Must-fix → loop reopens with the security finding as the new pass-1 input. Zero security findings → proceed to Step 9.

## When it fires

Step 8, after the standard reviewer loop terminates at zero actionable findings, before Step 9 (refactor). The security pass is a separate, post-convergence gate — not a parallel engine within the regular pass.

## What it composes

`security-review` skill. Read that skill's contract for the categories it surfaces (injection, secrets handling, authn/authz, etc.) — the `secure` flag routes one Step 8 post-pass through it.

## Behavior change vs default

| Stage | Default | With `secure` |
|---|---|---|
| Step 8 termination | Zero actionable findings → Step 9 | Zero actionable findings → `security-review` pass → re-evaluate |
| Security must-fix found | (security-review never runs) | Pass cap resets by one (security gets a dedicated pass budget of 1); apply the fix, re-run security-review, advance only on green |
| Security should-fix found | (n/a) | Treated as a should-fix in the regular Step 8 sense: apply if cheap, else surface in the Step 12 proposal Risks section |
| Step 9 entry | After Step 8 zero actionable | After both Step 8 zero actionable AND security-review zero must-fix |

## Where the pass-budget comes from

The Step 8 3-pass cap (see [review-loop.md](../review-loop.md)) covers regular reviewers. `secure` adds **one dedicated security pass** on top — security findings do not exhaust the regular cap, but a single security pass also does not become a free re-litigation budget. If the security pass surfaces must-fix and the fix in turn triggers regular reviewer findings, those count against the regular cap.

## Composition with other flags

| Combination | Effect |
|---|---|
| `secure` + `automode` | Security pass runs without prompts. Must-fix findings are applied automatically per the regular `automode` Step 8 path (pick safest finding, continue). The pass-budget rule still binds. |
| `secure` + `codex` / `codex challenge` | Codex runs in the regular Step 8 passes; `security-review` runs after Codex converges. The two reviewers have different angles (Codex: correctness/design; security-review: vulnerability classes). Both must converge before Step 9. |
| `secure` + `tdd` | Compose freely. Security findings may require new tests; if so, those tests follow TDD discipline (red first). |
| `secure` + `coderabbit` | Same composition pattern as with `codex`. CodeRabbit handles regular Step 8; security-review handles the security pass. |
