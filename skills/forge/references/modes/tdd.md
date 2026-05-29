# Forge — `tdd` flag

Composes the `superpowers:test-driven-development` skill at Step 7. Implementation must follow an observed-red test, not precede it.

## Manual verification recipe

```
/forge issue 42 tdd
```

Expected: Step 6 gate opens normally. Step 7 (implement) opens with the standard ordering (`/goal` set, `/karpathy-guidelines` re-source), then composes the TDD skill, writes the failing test, runs it, surfaces red output, and only then writes implementation code. Step 8 review loop runs as usual against the implementation diff.

## When it fires

Step 7, after `/goal` is set and `/karpathy-guidelines` is sourced, before any implementation edit.

## What it composes

`superpowers:test-driven-development`. Read that skill's contract before using `tdd` — this flag does not duplicate the discipline, it routes Step 7 through it.

## Behavior change vs default

| Stage | Default | With `tdd` |
|---|---|---|
| Step 7 first edit | Implementation code per the approved plan | Failing test for the new behavior |
| Pre-implementation observation | None required | Run the test; confirm red output before any implementation edit |
| Implementation | Edit until plan is delivered | Edit until the test passes; stop |
| Step 8 entry | Triggered by completed implementation | Triggered by green test plus implementation |

## Composition with other flags

| Combination | Effect |
|---|---|
| `tdd` + `automode` | Discipline still binds. The agent writes the test, runs it, and confirms red itself before writing implementation. No user prompt; the failing-test observation is the agent's own. |
| `tdd` + `docs` | TDD discipline applies to the `CONTEXT.md`-sourced plan. Tests for each plan section are written first. |
| `tdd` + `codex` / `codex challenge` | Step 8 reviewer engines unchanged. Codex reviews the implementation diff plus the test diff; adversarial review may challenge the test design as well as the implementation. |
| `tdd` + `worktree` | Compose freely. Tests run inside the worktree. |
| `tdd` + `lookup` | Compose freely. Library lookups inform the test, not just the implementation. |

## Anti-pattern (encoded in [anti-patterns.md](../anti-patterns.md))

Writing implementation code before observing the failing test. `tdd` exists to enforce the red-green-refactor cycle; skipping the red observation defeats the flag.

## `automode` behavior

See [autonomy.md](../autonomy.md) — `tdd` adds a row stating the discipline binds even under `automode`. The agent runs the test, confirms red, and proceeds without prompting.
