---
name: forge
description: "Forge an issue, ticket, or PR into a shipped fix: propose a plan, get it approved, then implement, review, and refactor. Use when the user runs /forge or asks to investigate, fix, resolve, triage, or solve one. See Parameters for modifier flags."
---

# Forge

> Forge an issue into a shipped fix: heat it (implement), hammer it (review loop), then temper it (refactor).

## Overview

Turn an issue or ticket reference into a verified, branch-correct, user-approved plan. Then, only after the user confirms (or immediately under `automode`), run the implementation lifecycle.

One numbered workflow (Steps 1–12), split by a single gate:

```
Part 1 — Gate (Steps 1–6):   classify → fetch → branch → context → propose → [GATE] approve
Part 2 — Lifecycle (7–12):   implement → review-loop → refactor → spin-off → self-evolve → close

  gate held: nothing touches the codebase until "yes, implement"  (automode = only sanctioned bypass)
```

- **Part 1 — The gate.** The contract; do not weaken it.
- **Part 2 — Lifecycle.** Runs autonomously after approval, stopping only at substantive gates (the Autonomy section).

"The agent" means whatever agent runs this skill. Adapt every reference (config directory, agent guide, interview UI) to your runtime. Nothing is hardcoded to one assistant.

## Parameters

Parse the invocation as `/forge <ref> [automode] [docs] [tdd] [worktree] [lookup] [secure] [changelog] [ci-watch] [codex | codex challenge] [coderabbit]`, or `/forge pr <N> [...]`. The words can appear anywhere in the request. A `<ref>` resolves to a git-host issue or a Jira ticket per the grammar below, and the `pr <N>` form selects PR-review entry mode. Flags are orthogonal and compose freely; some modes have their own allowed or ignored flags, listed in [references/modes/pr-entry.md](references/modes/pr-entry.md) for PR mode.

Full flag matrix (effects, composition rules, conflicts): **[references/flags.md](references/flags.md)**.

### Target grammar — `<ref>`

The target is the first reference-shaped token, or the token right after a `ticket` or `pr` keyword. Routing works by keyword or by key-shape:

| Form | Routes to | Examples |
|---|---|---|
| bare number, `#N`, `issue N` | **git-host issue** (Step 1b) | `forge 42`, `fix #123`, `issue 7` |
| matches `[A-Z]+-\d+` | **Jira ticket** OR **Linear issue** (disambiguate if both configured — see [references/trackers/linear.md](references/trackers/linear.md)) | `forge PROJ-123`, `solve ENG-42`, `forge AB12-9` |
| after `ticket` keyword | **Jira ticket**; number-only → ask project key | `forge ticket PROJ-123`, `solve ticket 42` |
| after `linear` keyword | **Linear issue** (forces Linear routing, skips disambiguation) | `forge linear ENG-42` |
| after `pr` keyword | **PR-review entry mode** (skips Steps 4–7; enters at Step 8 against the PR diff) | `forge pr 47`, `forge pr #123` |

A bare number routes to a tracker only if `ticket` or `linear` precedes it, and PR mode requires the `pr` keyword. A key-shaped ref is either Jira or Linear: when both trackers are configured, the agent disambiguates per the Jira/Linear disambiguation section in [references/trackers/linear.md](references/trackers/linear.md). Single-tracker setups skip the prompt.

Read **[references/modes/pr-entry.md](references/modes/pr-entry.md)** for the PR-entry mode step modifications, the allowed and ignored flags, and the PR-specific Step 12 closing menu.

### Modifier flags

Each line says what the flag does and where it acts; the linked file owns the details.

- *(none)* — interview the user if a required field is missing, propose, then wait at the gate. The review uses the project reviewer agents plus `superpowers:requesting-code-review`.
- `automode` — runs with no user gates and the agent decides Steps 6, 9, and 11. It never auto-commits, auto-pushes, or writes back to Jira; that is a hard floor. See [references/autonomy.md](references/autonomy.md).
- `docs` — works from documentation: the proposal goes to `CONTEXT.md` and the plan is sourced from it, and grilling uses `/grill-with-docs` instead of `/grill-me`.
- `tdd` — Step 7 writes the failing test first, observes it fail, then implements. See [references/modes/tdd.md](references/modes/tdd.md).
- `worktree` — Step 3 creates a sibling worktree instead of switching branch in place. See [references/modes/worktree.md](references/modes/worktree.md).
- `lookup` — Step 4 fetches current docs for every library the issue names. See [references/modes/lookup.md](references/modes/lookup.md).
- `secure` — adds a `security-review` pass at Step 8 once the regular review converges, before Step 9. See [references/modes/secure.md](references/modes/secure.md).
- `changelog` — Step 12 drafts a changelog entry in the repo's existing format. See [references/modes/changelog.md](references/modes/changelog.md).
- `ci-watch` — after a Step 12 push, polls CI; a red result reopens Step 8. See [references/modes/ci-watch.md](references/modes/ci-watch.md).
- `codex` / `codex challenge` — adds Codex as a Step 8 generic reviewer; `challenge` runs an adversarial review instead. Claude Code only. See [references/reviewers/codex.md](references/reviewers/codex.md).
- `coderabbit` — adds CodeRabbit as a Step 8 generic reviewer, with rework handled by `coderabbit:autofix`. Claude Code only; composes with `codex` (both run, rework routes per finding). See [references/reviewers/coderabbit.md](references/reviewers/coderabbit.md).

The reviewer flags add to the generic-reviewer set; the project reviewer agents always run alongside, and `codex` and `coderabbit` can both be set in one run. For example, `forge ticket PROJ-7 automode docs codex challenge coderabbit` is a valid invocation.

- `automode` with `docs` writes `CONTEXT.md` directly with no interview, then goes straight to Step 7.
- On a non-Claude-Code runtime, `codex`, `codex challenge`, and `coderabbit` are ignored with a one-line warning, and the generic reviewer stays `superpowers:requesting-code-review`.

## When to Use

- `/forge <ref>` (arg = issue or Jira-ticket ref).
- "forge issue 42", "solve issue 42", "fix #123", "look at issue 7".
- "solve ticket PROJ-123", "forge ticket 42", or a bare Jira key `PROJ-123`.
- Asks the agent to act on a specific issue/ticket in the repo.

**Don't use** when:
- No issue or ticket ref is given. Ask rather than guess.
- Asking *about* an issue/ticket, not to *resolve* it.

## Step 1 — Classify the ref, resolve the repo & tracker

### Step 1a — Classify `<ref>` (see Parameters, Target grammar)

- If the ref is key-shaped (`[A-Z][A-Z0-9]+-\d+`) or follows a `ticket` keyword, treat it as Jira and go to Step 1c.
- Otherwise (a bare number, `#N`, or `issue N`), treat it as a git-host issue and go to Step 1b.
- If `ticket` is followed by a number with no key, ask for the project key first. Offer proposed answers when candidates can be inferred from `git remote`, `CONTEXT.md`, or branch names; otherwise use a single prompt. Under `automode`, infer the most likely key and record the assumption.

Always run `git remote get-url origin` (falling back to `upstream`) regardless of the ref kind, because Part 2 commits and branches against this repo even for Jira tickets.

### Step 1b — git-host issue

Route by host in `origin` (fallback `upstream`):

| Host in remote URL | Reference |
|---|---|
| `github.com` / GH Enterprise | [references/trackers/github.md](references/trackers/github.md) |
| `gitlab.*` (incl. self-hosted) | [references/trackers/gitlab.md](references/trackers/gitlab.md) |
| other (Gitea, Bitbucket, …) | that host's CLI's issue-view JSON command if present; else host REST API |
| any, no CLI / auth error | host REST API per the loaded tracker ref (else generic curl) |

If neither `origin` nor `upstream` resolves to a known issue host: stop, tell the user, do nothing else.

### Step 1c — Jira ticket

Read **[references/trackers/jira.md](references/trackers/jira.md)**, which covers resolving the ticket, fetching it, the absent-source fallback, the key-in-branch convention, and write-back. Load it now; the rest of Steps 1 through 3 and Step 12 defer their Jira specifics to it. Git-host issues never read it.

## Step 2 — Fetch the issue / ticket

### git-host issue

Use the loaded tracker ref for the fetch command and the REST fallback: [references/trackers/github.md](references/trackers/github.md) Step 2 or [references/trackers/gitlab.md](references/trackers/gitlab.md) Step 2. For a host without a dedicated ref, run its CLI's issue-view JSON command if one exists, otherwise curl the host's REST API. Either way, read the body and every comment. If the number is a pull request, not an issue, stop and ask whether they meant `/forge pr <N>`.

### Jira ticket

Follow **[references/trackers/jira.md](references/trackers/jira.md)** Step 2 to pull the fields and comments, and its Jira-absent fallback section when the source is unreachable. The fallback warns the user and offers three choices (paste, authenticate, or abort), and it stops even under `automode`.

## Step 3 — Verify the branch

```bash
git branch --show-current
```

If the repo ships a git or contribution guide, follow it verbatim for branch naming, the base branch, and the PR target. Look in `CONTRIBUTING.md`, a git section in the project agent guide (`AGENTS.md` or your runtime's equivalent), `.agents/rules/git*`, `docs/*git*`, or the runtime equivalent. The repo's own rules win over everything below.

Only if no such guide exists, fall back to the default `<prefix>/<slug>`, where `<prefix>` is one of `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`, `build`, or `style`.

- Pick `<prefix>` from the issue: use `fix` for a bug, `feat` for new behavior, `docs` for documentation, and `chore` for dependencies, CI, or tooling. When it is ambiguous, ask.
- Build `<slug>` from the title: lowercase ASCII kebab-case, drop stop-words, and keep it to 50 characters or fewer. For example, *"Parser fails on UTF-16 BOM"* becomes `fix/parser-fails-utf-16-bom`.

For Jira, see **[references/trackers/jira.md](references/trackers/jira.md)** Step 3 for the key-in-branch and key-in-commit conventions. The repo guide still wins; otherwise the branch is `<prefix>/<KEY>-<slug>`, and the key is not forced into commit subjects.

Compare the chosen branch name to the current branch:
- If they match, continue.
- If they differ, show both and ask: **"Switch to a new branch `<prefix>/<slug>` forked off `<base>`? (y/n)"**. Pick `<base>` per the repo guide, otherwise probe `dev`, then `develop`, then `main`, then `master`.
- On `y`, confirm the tree is clean with `git status --short`. If it is dirty, surface the files and ask before any switch, then run `git switch -c <prefix>/<slug> <base>`. If the switch fails (branch exists, base missing), surface the git error and ask. Never invent a name or base.

When the **`worktree`** flag is set, create a sibling worktree on the chosen branch instead of switching in place. See **[references/modes/worktree.md](references/modes/worktree.md)**; it composes `superpowers:using-git-worktrees`, and the Step 12 closing appends a cleanup reminder.

## Step 4 — Check context sufficiency

Use the context you already have, and do not sweep the codebase. Inventory what is already in the context window first: the agent guide, memory, and rulesets the runtime loaded at startup, such as `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CONTEXT.md`, or `.agents/rules/*`. That is usually enough for the design. Only then read further, and no more than this:

1. the files the issue names;
2. at most a few top candidates from a targeted search for the definition or callers of the named symbol, never a directory walk or full-tree read.

Stop reading once you can write Step 5. Turn any residual uncertainty into a Risk rather than more reading. A full-codebase sweep before a proposal is a red flag: it wastes the context the runtime already gave you.

Before proposing, the issue must answer:

| For a bug | For a feature |
|---|---|
| Steps to reproduce | Acceptance criteria |
| Expected vs actual | Affected surface (API, CLI, UI) |
| Environment (version, OS) | Backwards-compat expectations |
| Suspected component (optional) | Out-of-scope clarifications |

The acceptance criteria and the expected-versus-actual behavior are the `/goal` pass-conditions used in Step 7, so capture them precisely. For Jira, mine them from the description, the acceptance-criteria field, and the comments. A missing field is a Step 4 interview gap exactly as it is for a git issue, and the pasted-text fallback from Step 2 is treated the same way.

When a required field is missing, interview the user rather than opening a free-text question. For each gap, offer a small set of proposed answers, mark the most likely one `(Recommended)`, and let the user pick. On a runtime with a selection UI, such as Claude Code's interview TUI, the user highlights an option and presses Enter, and an "Other" free-text choice is always implicitly available.

See **[references/proposal-template.md](references/proposal-template.md)** Step 4 for the literal question-block format. Never invent the chosen answer: propose the options and let the user select. Never continue past this step while a required gap is unanswered.

The flags change how the interview runs:

- `docs` runs the interview through `/grill-with-docs`, which challenges the plan against the repo's domain model and docs.
- `automode` skips the interview and proceeds on the issue as written, picking the `(Recommended)` answer for each gap and noting the assumption in the proposal.
- `automode` with `docs` runs no interview and goes to the Step 5 `CONTEXT.md` write.

When the **`lookup`** flag is set, fetch current docs for every library, framework, SDK, CLI, or cloud service the issue mentions, querying the `context7` MCP (or context7 resources if the MCP is not connected) before writing the proposal. See **[references/modes/lookup.md](references/modes/lookup.md)** for the attribution format, when to skip, and `automode` behavior.

### Step 4a — Optional grilling for risky design forks

The Step 4 interview is about missing facts. When the context is enough to propose but a design or approach fork is genuinely ambiguous and a wrong pick means expensive rework, run a deeper interview before the proposal:

- by default, run **`/grill-me`**;
- with `docs`, run **`/grill-with-docs`**;
- under `automode`, never grill, since both options interview the user; instead record the fork and the chosen branch as an explicit proposal assumption.

Do this only when getting the approach wrong is costly. For a clear, low-risk fix, go straight to Step 5.

## Step 5 — Propose the solution

Emit exactly one proposal. The block format is in **[references/proposal-template.md](references/proposal-template.md)** Step 5 and covers the issue line, the restated problem, the root cause or design, the files to touch, the plan, the pass criteria, the tests, and the risks. Verify that file paths exist with Read or Grep before listing them, and drop the `:line` suffix if you have not opened the file.

With **`docs`**, write the proposal to `CONTEXT.md` in the repo root, instead of or in addition to chat, since Part 2 sources the plan from `CONTEXT.md` rather than the chat scrollback. Stamp it with the ref it was written for, so a later run can tell it apart from a stale plan.

End the proposal by stating the user's next-turn choices, using the options in the template Step 5. Saying `yes, implement` opens the gate and moves to Step 7. Saying `interview me on risky questions` runs the Step 4a grilling and re-proposes, and is offered only when a risky design fork is still unanswered. Any other adjustment means revise and re-propose.

Under **`automode`**, there are no options and no wait: go straight to Step 7, and with `docs`, do so after writing `CONTEXT.md`.

## Step 6 — The gate

Unless `automode` is set, **do not edit any file** until the user explicitly approves.

- "yes, implement", "go ahead", "do it", or "ship it" moves to Step 7.
- "interview me on risky questions" goes back to Step 4a, then re-proposes.
- A requested plan change means revise and re-ask. Silence or questions mean wait.

This is the most important rule of the skill. Skip it (outside `automode`) and the skill is worthless.

---

# Part 2 — Post-Approval Lifecycle (Steps 7–12)

This part is deliberately terse. Each step delegates to a referenced skill, so read that skill rather than restating it here.

### Re-hydrate block

Steps 8 and 9 reference this block. It is two actions, in order:

```
/compact  →  re-source /karpathy-guidelines
```

Run it before touching code on every non-converged review pass and before approved refactor work. The point is to shed stale reviewer-transcript tokens and reload clean-code discipline. On a review pass, capture the must-fix and should-fix findings before `/compact` so they survive it, then fix from that list. Do not restate `/goal` here; it is set once, in Step 7.

## Step 7 — Implement

Open the step with two actions, in order:

1. Set **`/goal`** to the desired result plus the Step 4 and 5 pass criteria, that is, the exact build, test, or behavior that proves the work is done. Set it once and never restate it.
2. Re-source **`/karpathy-guidelines`**.

When the **`tdd`** flag is set, write the failing test first, run it, watch it fail, then implement. See **[references/modes/tdd.md](references/modes/tdd.md)**; it composes `/tdd`, and the discipline binds under `automode`.

With `docs`, load the plan from `CONTEXT.md` and check its stamp matches this ref; on a mismatch, warn and re-propose rather than implement a stale plan. Implement the approved plan and keep it minimal, surgical, and in scope. Make no edits before the opener is done, and before the observed-red test is done if `tdd` is set.

## Step 8 — Review loop

Run the project reviewer subagents (from `.agents/agents/` or the runtime equivalent) together with the generic reviewer. The generic reviewer is `superpowers:requesting-code-review` by default, or Codex under `codex` or `codex challenge`. The project subagents always run.

Terminate the loop at zero actionable findings; nits do not block. Cap the loop at a fixed number of passes. On each non-converged pass, run the re-hydrate block, fix the findings, then re-review.

See **[references/review-loop.md](references/review-loop.md)** for engine-selection details, the `/greploop` fallback and `/diagnose` sub-pass, pass discipline, the trim-only-cleanup skip rule, and `automode` behavior.

When the **`secure`** flag is set, run a `security-review` pass once there are zero actionable findings. Must-fix security findings reopen Step 8 with one dedicated security-pass budget. See **[references/modes/secure.md](references/modes/secure.md)**; security must clear before Step 9.

### Step 8a/8b — Generic reviewer swaps

A flag adds an engine to the Step 8 generic-reviewer set, replacing the default `superpowers:requesting-code-review` when at least one is set. Each engine brings its own Step 8a reviewer pass and Step 8b rework path mirrored to its companion skill. The project subagents always run alongside. The reviewer flags compose: set both and both engines run in the same pass; each finding's rework routes to the engine that raised it.

| Flag | Step 8a engine | Step 8b rework path |
|---|---|---|
| *(none — default)* | `superpowers:requesting-code-review` | (no dedicated rework skill; in-pass fixes only) |
| `codex` / `codex challenge` | Codex `review` / `adversarial-review` via `scripts/resolve-codex.py` foreground | `codex:codex-rescue` foreground `--wait` (re-hydrate first, inline karpathy constraints) |
| `coderabbit` | `coderabbit:code-review` | `coderabbit:autofix` foreground `--wait` (re-hydrate first, inline karpathy constraints) |

See **[references/reviewers/codex.md](references/reviewers/codex.md)** for Codex specifics and **[references/reviewers/coderabbit.md](references/reviewers/coderabbit.md)** for CodeRabbit specifics.

Both `codex` and `coderabbit` are Claude Code only. On other runtimes the flag is ignored with a one-line warning, and the default generic reviewer stays in place.

## Step 9 — Refactor (propose-only)

Run **`/improve-codebase-architecture`**.

- By default, surface the opportunities. If the user approves, run the re-hydrate block and re-enter Step 8 once on the refactor diff. If there are none, or the user does not approve, go to Step 10.
- Under `automode`, the agent decides: apply only refactors that are clearly net-positive and in scope. If it applies any, run the re-hydrate block and re-enter Step 8 once; otherwise continue.

Never silently rewrite beyond the issue's scope.

## Step 10 — Out-of-scope findings via `/to-issues`

For bugs or improvements that belong in a separate issue, draft them via **`/to-issues`**, show the drafts, and post only on an explicit user yes. Under `automode`, post them directly. If nothing qualifies, skip this step silently.

## Step 11 — Self-evolution

If you hit a caveat that could be automated for future agentic sessions, propose **`/write-a-skill`** or an edit to the project agent config (the agent guide, rules, or reviewer-agent directory for the runtime). Also consider recording the caveat in the agent's project memory so a later session does not repeat it. Use whatever memory store the runtime exposes for this project. If the user has installed an external memory provider they favor (a memory plugin or MCP seen earlier in the conversation), write there instead of the built-in store. Show the exact diff and path, and confirm before writing. Under `automode`, the agent decides on its own and applies the smaller-blast-radius option with no proposal or confirmation. Memory writes are included: it picks the built-in store or the user's preferred external provider and writes directly. It still prefers a rule or guide edit over a new skill unless the pattern is clearly broad. If nothing can be automated, skip this step silently.

## Step 12 — Closing

Verify `/goal` before anything else. Before assembling the proposal, run the Step 7 `/goal` pass criteria and the repo's standard pre-commit checks (build, test, and lint per the repo guide). Show the exact commands and their output. A command that exits 0 without running tests, such as "no tests collected" or empty output, does not prove `/goal`; treat it as not done. If anything fails, or you cannot run the checks, you are not done: return to Step 8 with the failure as a finding. Never assemble a commit proposal on an unverified `/goal`, because an unproven "done" is the one failure mode forge must not ship. `automode` does not lift this gate; it runs the checks itself and proceeds only on green.

Then assemble the commit or PR proposal. The default is small atomic commits that match the branch's existing granularity and message style, which you can inspect with `git log --oneline <base>..HEAD`, rather than one squashed mega-commit. The repo's git or contribution guide from Step 3 still wins: if it mandates another shape, such as squash-on-merge, follow it and say why.

When the **`changelog`** flag is set, draft a changelog entry in the repo's existing format after `/goal` verifies green and before assembling the commit list, and include it in the proposed history. See **[references/modes/changelog.md](references/modes/changelog.md)** for the file-detection order and entry conventions.

Then ask one closing question, using the closing menu in **[references/proposal-template.md](references/proposal-template.md)** Step 12. It follows the Step 4 proposed-answer format: the user selects, the recommended option is marked, and "Other" is implicit. Show the third line only when the target was a Jira ticket.

Act only on the selected option. Option 2 follows the repo guide for the base branch and PR target.

For the Jira write-back in the third option, follow **[references/trackers/jira.md](references/trackers/jira.md)** Step 12. It is opt-in only, posts a comment and a confirmed transition, and never runs on the other options or under `automode`. Show the third menu line only when the target was a Jira ticket.

**Never auto-commit, auto-push, or write back to Jira** outside an explicit selection.

When the **`ci-watch`** flag is set and a push option (2 or 3) was chosen, poll CI for the pushed HEAD once the push completes. On a red result, re-enter Step 8 with the CI failure as a must-fix finding. See **[references/modes/ci-watch.md](references/modes/ci-watch.md)** for polling cadence and host CLI selection. The flag is inert if no push option was chosen.

- With `docs`, still ask, but pre-mark the `/tmp/<name>.md` option `(Recommended)` over option 1.
- With `automode`, skip the question. Emit the proposed small-commit history as a plan only, written to `/tmp/forge-<ref>.md` under `docs` or inline otherwise, then stop. `automode` never executes commits, pushes, or Jira write-backs.
- With `worktree`, append a cleanup reminder to the closing message: "Worktree at `<path>`; run `git worktree remove <path>` when done." Cleanup never auto-runs, even under `automode`. See [references/modes/worktree.md](references/modes/worktree.md).

### Autonomy

By default, once the user says "yes, implement", run autonomously with no "may I continue?" between steps, and stop only at the substantive gates:

- Step 6, the gate entry;
- Step 9, the refactor approval;
- Step 10, the spinoff-issue post;
- Step 11, self-evolution;
- Step 12, the commit proposal.

`automode` lifts those gates but never the hard floors:

- it never auto-commits, auto-pushes, or writes back to Jira;
- the Step 12 `/goal` verify still runs;
- the Step 2 Jira-absent fallback still triggers.

See **[references/autonomy.md](references/autonomy.md)** for the full per-step matrix, the rationale behind each hard floor, and how `automode` composes with other flags.

---

## Anti-patterns & Red Flags

See **[references/anti-patterns.md](references/anti-patterns.md)** for the common-mistakes table and the red-flag stop list. Both bind under `automode` too, and that file is the canonical home for new rules learned during a forge session.
