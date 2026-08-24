# Forge — `implement` flag

Loaded on demand by SKILL.md Step 7 **only when the `implement` flag is set**. Default runs never read this file.

Delegates Step 7 implementation to **`/implement`** (from `mattpocock/skills`): it builds the work described by a spec or ticket set, driving `/tdd` at pre-agreed seams. Forge keeps everything around it — the gate, the review loop, `/goal` verification — and hands the skill only the step it owns.

## Contract

1. **After the opener.** The Step 7 opener still runs first: `/goal` is set and `/karpathy-guidelines` re-sourced before any delegation, exactly as for inline implementation.
2. **Scope is the approved plan.** Dispatch `/implement` against the Step 5 approved proposal (or the plan slice under `/forge plan`), plus the Step 2 issue/ticket body. It implements that plan — not the spec it might re-derive on its own. Out-of-scope work it proposes is declined and recorded as a Step 10 candidate.
3. **Closeout is suppressed.** `/implement` normally closes with `/code-review` before committing. Both halves of that closeout belong to forge: instruct the dispatched run to skip its own review closeout and to stage nothing — forge's Step 8 owns review, and Step 12 owns the commit proposal. If the `code-review` flag is also set, that same engine runs anyway — at Step 8, under forge's pass discipline, per [../reviewers/code-review.md](../reviewers/code-review.md).
4. **Conformance-check the result.** Before entering Step 8, diff the returned work against the approved plan, exactly as `codex impl` does for a Codex diff. Deviations are findings, not silently accepted improvements.

## Composition

| Combination | Effect |
|---|---|
| `implement` + `codex impl` | **Conflict — stop and report.** Two engines cannot own the same Step 7, and silently applying a precedence would hide which engine actually built the diff. |
| `implement` + `tdd` | Redundant, accepted with a one-line note: `/implement` already drives `/tdd` at pre-agreed seams, so the discipline is not doubled. The observed-red rule binds either way. |
| `implement` + `/forge pr <N>` | Inert — PR mode has no Step 7. One-line note, no error; same rule as `codex impl`. |
| `implement` + `automode` | The delegation runs unprompted. The conformance check is the agent's own, and deviations enter Step 8 as findings without a user prompt. |

## Degradation

If the `/implement` skill is not installed on this runtime, warn once, ignore the flag, and implement inline — the same graceful degradation every optional engine flag follows. Never stall Step 7 on a missing delegate.

## Manual verification recipe

1. In a repo with forge installed, run `/forge <ref> implement` on a small issue and approve the Step 5 proposal.
2. Confirm the Step 7 transcript shows the opener (`/goal` + `/karpathy-guidelines`) **before** the `/implement` dispatch, and that the dispatch names the approved plan as its scope.
3. Confirm no `/code-review` closeout ran inside the delegated work, and that Step 8 review started only after a conformance check against the plan.
4. Run `/forge <ref> implement codex impl` and confirm forge stops at Step 1 reporting the engine conflict instead of dispatching either.
5. Uninstall (or rename) the `implement` skill and re-run: Step 7 must warn once and implement inline.
