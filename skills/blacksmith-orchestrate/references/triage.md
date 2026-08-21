# Blacksmith — triage

How Step 4 grades each task on two independent axes — implementer tier and forge depth — before scheduling ever sees a single task. Consumes Step 3's `difficulty` and `blastRadius` fields; produces the tier and depth values Step 6's ledger and Step 7's dispatch key on. Loaded by Step 4.

## Manual verification recipe

**Case 1 — trivial but dangerous.** A one-line change to an auth check: `difficulty: low` (one line, existing pattern), `blastRadius: high` (auth adjacency).
Expected: `haiku × full`. Low difficulty picks Haiku 4.5, but high blast radius floors the depth at `full` regardless of what difficulty says; never `lite`, never `patch`.

**Case 2 — hard but contained.** A multi-file parser rewrite: many files, algorithmic content, several open risks, no auth/payment/public-API adjacency, but a wide caller count on the symbols it touches.
Expected: `opus × full`. High difficulty picks Opus 5; the caller count alone is enough blast-radius signal to floor the depth at `full` too, so both axes agree here even though they were graded independently.

**Case 3 — trivial and contained.** A docs typo: one line, no new interface, no user-facing surface, no callers.
Expected: `haiku × patch`. Both axes clear to their lowest grade, so the depth downgrades all the way to `patch` and Haiku 4.5 implements it with the orchestrator reading the diff itself.

Two independent axes. They correlate but are not the same: a one-line change to an auth check is trivial to implement and catastrophic to get wrong.

## Axis 1 — difficulty → model tier

Signals: file count, new interface vs existing pattern, algorithmic content, number of open risks.

| Difficulty | Agent model | Under `codex impl` pass-through |
|---|---|---|
| high | Opus 5 | `gpt-5.6-sol`, effort `high` |
| medium | Sonnet 5 | `gpt-5.6-terra`, effort `xhigh` |
| low | Haiku 4.5 | `gpt-5.6-luna`, effort `xhigh` |

The three rows above map onto the canonical tier tokens `opus`, `sonnet`, `haiku` — the exact strings Step 7 dispatch and the Step 6 ledger schema key on; `Opus 5` / `Sonnet 5` / `Haiku 4.5` name which agent model each token resolves to on this run.

`difficulty` is scout-supplied and can arrive absent, or carrying a value outside `high`/`medium`/`low`. Missing or malformed data is never read as an implicit "safe to run cheap": the safe branch is the conservative one, so a task with no usable `difficulty` is graded `high` — top tier — until a human overrides it, and the battle plan surfaces `difficulty undeterminable: <ref>` so that default is visible at the gate rather than silently assumed. A returned `difficulty` that visibly contradicts its own evidence — `low` on a task whose file list runs to dozens of files, or that introduces a new public interface — is not silently corrected either: Step 4 does not second-guess the scout's classification on its own authority, any more than it silently resolves a stated-edge cycle in the collision graph. It flags the mismatch on the battle plan (`difficulty flagged: low vs <n> files touched`) and leaves the resolution to the user at the gate.

## Axis 2 — blast radius → forge depth

Signals: user-facing surface, auth/payment/security adjacency, public API or migration, caller count of touched symbols, existing test coverage.

| Depth | Forge steps run | Review |
|---|---|---|
| `full` | 1–12, or P + 7–12 plan-sourced | loop to convergence, normal pass cap |
| `lite` | 7, 8, 12 | one review pass, project reviewers only; skips 9, 10, 11 |
| `patch` | 7, 12 | orchestrator reads the diff itself; no reviewer subagent |

`blastRadius` is subject to the same rule as `difficulty`. Missing or out-of-enum `blastRadius` grades to `high` — forcing `full` depth via floor 2 below — until the user overrides it, surfaced as `blastRadius undeterminable: <ref>` on the battle plan; grading to `high` is the only default that cannot silently under-review a task, since `full` is a strict superset of what `lite` and `patch` run. A returned `low` that contradicts strong evidence — auth or payment adjacency, a public API touched, zero existing test coverage on a wide caller count — is flagged the same way (`blastRadius flagged: low vs <signal>`) rather than corrected in place.

## The four floors

1. **Step 12 `/goal` verification runs at every depth.** `patch` means "verified without a review loop," never "unverified." Forge's hard floor is inherited unchanged.
2. **High blast radius can never be assigned `lite` or `patch`,** whatever difficulty says. This is the entire reason the axes are separate.
3. **Rigor-increasing flags are sticky.** `secure` and `tdd` survive a depth downgrade.
4. **The implementer is never the only reviewer.** Generalized from `codex impl`: a Haiku-implemented task is reviewed at Sonnet or above; a same-family review is at minimum a distinct agent instance, and a different family is preferred where a reviewer flag makes one available.

Floor 4 does not require a second model family to exist on the host — it requires a second reviewer. When the host offers only one model family, "a different family is preferred where a reviewer flag makes one available" fails on availability, not on the floor itself: the review still runs, at the same family but a distinct agent instance from the one that implemented, exactly as the same-family clause already allows. A single-model-family host is a degraded case of floor 4, not an exception to it — it never licenses skipping the review or letting the implementer review its own diff.

## Runtime promotion

Triage is a prediction, so it self-corrects. If a `patch` or `lite` task fails its `/goal`, or its diff escapes the file list its plan declared, the orchestrator promotes it one depth and re-dispatches once, bumping the tier if the failure looks like a capability limit. A task that fails after promotion parks for the user rather than looping.

Both axes have a ceiling this mechanism runs into. A task already at `full` has nowhere to promote: a `/goal` failure at `full` is handled by the ordinary Step 8 review loop already running at that depth, under its own pass cap, not by this mechanism — if that loop caps out without converging, it parks for the user, the same outcome promotion produces, reached by the review loop's own rule rather than this one. A task already at the top tier (Opus 5) that fails for what looks like a capability limit has no tier left to bump into either: the orchestrator re-dispatches it once more at the same tier with the failure appended to context, and if it fails again it parks for the user — the fails-twice-parks rule holds even when one of the two dimensions a retry could move on is already exhausted.

`strict` disables the depth *downgrade* triage would otherwise apply; it says nothing about promotion, because under `strict` every task starts at `full`, so the `patch`-or-`lite` failure that triggers promotion can never occur in the first place. There is no case where `strict` is left holding a task down that this mechanism would otherwise have raised — the failure branch it would interact with never fires.
