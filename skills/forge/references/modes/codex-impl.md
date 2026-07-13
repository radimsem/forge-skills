# Forge — `codex impl` flag

Loaded on demand by SKILL.md Step 7 **only when the `codex impl` flag is set**. Delegates implementation to Codex running the GPT-5.6 model family (Sol / Terra / Luna), auto-tiered by work class. The agent stays the orchestrator: it sets `/goal`, delegates, checks the returned diff for plan conformance, and runs the Step 8 review loop — GPT writes, the agent reviews.

**Claude Code only** — same constraint as the `codex` reviewer flag ([../reviewers/codex.md](../reviewers/codex.md)). Non-CC runtime: ignore the flag, warn once, implement inline. The rest of forge stays runtime-generic.

## Manual verification recipe

```
/forge issue 42 codex impl
```

Expected: Steps 1–6 unchanged. Step 7 opens with the standard ordering (`/goal` set, `/karpathy-guidelines` re-source), resolves the companion script, delegates the approved plan as one foreground `task --write` at the Sol tier, conformance-checks the returned diff, and enters Step 8 with the **default** generic reviewer (`superpowers:requesting-code-review`). Step 8b rework routes back to Codex at the Terra or Luna tier.

## Grammar & review split

- `codex` — reviewer only, unchanged ([../reviewers/codex.md](../reviewers/codex.md)).
- `codex impl` — Codex implements Step 7 and handles Step 8b rework. The Step 8 generic reviewer **reverts to the default** `superpowers:requesting-code-review`: the model family that wrote the diff must never be the only one reviewing it (cross-model review). Project reviewer agents always run, as everywhere.
- `codex impl challenge` — composes: implementation as above **plus** Codex `adversarial-review` added to the Step 8 reviewer set alongside the default reviewer. Self-review is acceptable here because it is an *additional* adversarial engine, never the only reviewer.

## Step 7 — delegated implementation

1. **Opener unchanged.** Set `/goal` and re-source `/karpathy-guidelines` first — delegation never skips the opener. With `tdd`, write and observe the failing test yourself *before* delegating; quote the red test in the delegation prompt as a pass criterion.
2. **Preflight once per run** via `<forge-skill-dir>/scripts/resolve-codex.py`, with the same semantics as the reviewer pass ([../reviewers/codex.md](../reviewers/codex.md) Step 8a). Output `UNAVAILABLE` → degrade gracefully: warn once, implement inline, and treat the rest of the run as if `impl` were not set. Never stall.
3. **Delegate the whole approved plan as one foreground task** with the resolved `<script>`:
   ```bash
   node <script> task --write --model gpt-5.6-sol --effort high "<prompt>"
   ```
   The prompt inlines, in order: (a) the karpathy constraints block — Codex cannot source Claude-side skills, same inlining rule as the Step 8b rescue path; (b) the Step 5 approved proposal verbatim (from `CONTEXT.md` under `docs`, stamp-checked); (c) the `/goal` pass criteria. Foreground, not `--background`: Step 8 needs the diff now.
4. **Conformance check before Step 8.** Diff the returned work against the plan: the files touched match the proposal's file list, nothing is out of scope, no unrelated rewrites. Revert or flag out-of-scope edits. A plan step Codex skipped or fumbled: finish inline if small, re-delegate once if large. Then enter the normal Step 8 loop.
5. **Task failure** (companion errors or returns nothing): implement inline, warn, continue — never stall, never retry more than once.

## Step 8b — tiered rework

When `impl` is set, Codex-delegated rework uses the same direct `task --write` mechanism as Step 7, at the tier the matrix below assigns — not the `codex:codex-rescue` subagent path, which stays the reviewer-only flag's rework route. The Step 8 re-hydrate block still runs before any rework pass, and the existing rule holds: trivial fixes stay inline with the agent and are not delegated at all.

## Tier matrix

Auto-tiered by work class; there is no user-facing tier syntax. Effort compensates the cheaper tiers.

| Work | Tier | `--model` | `--effort` |
|---|---|---|---|
| Step 7 — implement the approved plan | Sol | `gpt-5.6-sol` | `high` |
| Step 8b — substantive rework of a review finding | Terra | `gpt-5.6-terra` | `xhigh` |
| Step 8b — mechanical fix (typo, rename, lockstep edit, format) | Luna | `gpt-5.6-luna` | `xhigh` |

- The Step 8b classification is a judgment call. Luna is for mechanical work that is *voluminous* (many files, repetitive), not merely small — small fixes stay inline.
- If a future companion version adds an `ultra` effort level, Terra upgrades to `--effort ultra`; the mapping above is the ceiling of today's enum (`none…xhigh`).
- **Model-ID resilience:** if Codex rejects the model ID (older CLI, tier unavailable on the account), retry once with no `--model` flag (Codex's default) and note the downgrade. Verify accepted IDs against the live CLI, not this file.

## Degradation ladder

1. Non-Claude-Code runtime → ignore the flag, one-line warning (standard).
2. Preflight `UNAVAILABLE` → warn once; implement the whole run inline.
3. Model ID rejected → retry once without `--model`; note the downgrade.
4. Task fails or returns nothing → implement that unit inline, continue.

Each rung falls back to the agent implementing. Never stall the run on a delegation failure.

## Composition with other flags

| Combination | Effect |
|---|---|
| `codex impl` + `automode` | No special casing. Hard floors untouched: Codex writes to the working tree only; it never commits, pushes, or writes back to a tracker. |
| `codex impl` + `tdd` | The agent writes and observes the red test itself, then delegates; the failing test is a delegation pass criterion. The observe-red discipline stays agent-side and binds under `automode`. |
| `codex impl` + `docs` | The delegation prompt sources the plan from `CONTEXT.md` (stamp-checked) instead of the chat proposal. |
| `codex impl` + `worktree` | Composes transparently; the companion task runs in the worktree directory. |
| `codex impl` + `secure` | Unaffected; the security pass reviews the diff regardless of who wrote it. |
| `codex impl` + `coderabbit` | CodeRabbit joins the Step 8 reviewer set; CodeRabbit findings route to `coderabbit:autofix`, Codex-delegated rework routes to the tiered Step 8b path above. |
| `/forge pr <N>` + `codex impl` | Step 7 delegation is inert (PR mode has no Step 7) with a one-line note; the Step 8b rework tiering still applies, since PR mode enters at Step 8. See [pr-entry.md](pr-entry.md). |
