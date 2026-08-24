# Forge — Proposal & Interview Templates

The literal block formats forge uses at three user-visible touchpoints. `SKILL.md` Steps 4 / 5 / 12 reference this file for the exact text to emit; the surrounding step prose holds the contract (when to emit, what each slot means, what `automode` does).

## Step 4 — Interview question format

When a required field (acceptance criteria, repro, affected surface, …) is missing, emit one block per gap. Never open free-text. Mark the most likely answer `(Recommended)`. "Other" is implicitly always available.

```
Q1: <gap, one line>
  - <option A> (Recommended)
  - <option B>
  - <option C>
```

Rules:

- 2–4 options per gap. Fewer is too rigid; more becomes decision fatigue.
- One block per question, one question at a time.
- The user picks; never invent the answer.
- Runtimes with a selection UI: the user highlights + Enter; the agent does not parse free text against the option set.
- Never continue past this step on an unanswered required gap.

## Step 5 — Proposal block

Emit exactly one proposal block per `/forge` invocation. Verify file paths exist (Read/Grep) before listing; drop `:line` if you have not opened the file.

```
**Issue #<N>: <title>**

**Restated:** <one sentence>

**Root cause / design:** <2–4 sentences>

**Files to touch:**
- path/to/file.ext:<lineish> — <what changes>

**Plan:**
1. <step>
2. <step>

**Pass criteria (→ /goal):** <exact build/test/behavior that must hold>

**Tests:** <added or updated>

**Risks / open questions:** <unsure points; mark any UNANSWERED risky design fork>
```

`docs` mode writes the proposal to `CONTEXT.md` (repo root) instead of / in addition to chat; Part 2 sources the plan from `CONTEXT.md`, not chat scrollback.

### Step 5 next-turn options

End the proposal stating the user's choices:

- `yes, implement` — open the gate → Step 7.
- `interview me on risky questions` — only if a risky design fork is still unanswered; runs Step 4a grilling, re-proposes.
- otherwise: any adjustment → revise, re-propose.

`automode`: no options, no wait — straight to Step 7 (with `docs`: after writing `CONTEXT.md`).

## Step 12 — Closing menu

Ask one closing question after `/goal` verifies green. Step 4 proposed-answer format: user selects; `(Recommended)` marked; "Other" implicit.

```
Forge is done — how should the changes land?
  - Lay down the proposed small-commit history on this branch, push nothing (Recommended)
  - Lay down that history, push to origin, and open a PR to the base branch
  - Lay down that history, push, open the PR, and comment + transition <KEY> on Jira   ← Jira target only
  - Walk me through the implementation at a high level first — run /wait-what, then re-ask
  - Write the whole proposal (commit plan + diff summary) to /tmp/<name>.md and stop
  - Hold — leave the working tree uncommitted for my own manual review
```

Rules:

- Show the 3rd line only when the target was a Jira ticket.
- `docs` mode pre-marks the `/tmp/<name>.md` option `(Recommended)` over option 1.
- Act only on the selected option. Option 2 follows the repo guide for base branch + PR target.
- Jira write-back (3rd option) is opt-in only; never on other options, never under `automode`.
- `automode` skips this question entirely and emits the small-commit plan only — see [autonomy.md](autonomy.md) Step 12 closing.
