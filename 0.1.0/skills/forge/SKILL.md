---
name: forge
description: Use when the user invokes /forge with an issue or Jira-ticket reference, or asks to investigate, fix, resolve, triage, solve, or work on a specific issue ID or ticket in the current repo (any git host — GitHub, GitLab, etc. — or Atlassian Jira). Triggers on phrases like "forge issue 42", "solve issue 42", "fix #123", "work on issue 7", "solve ticket PROJ-123", "forge ticket 42", or any direct issue-number / Jira-key reference paired with intent to make changes — including the optional modifiers "automode" (no user gates), "with docs" (doc-driven), "codex" (Codex review loop) and "codex challenge" (Codex adversarial review), e.g. "forge issue 47 automode with docs codex challenge". Covers the full lifecycle: propose → gated approval → implement → review-loop → refactor → spin-off issues → self-evolve.
---

# Forge

> Forge an issue into a shipped fix: heat (implement) → hammer (review loop) → temper (refactor).

## Overview

Turn an issue/ticket ref into a verified, branch-correct, user-approved plan — then, only on confirmation (or immediately under `automode`), run the implementation lifecycle.

Two parts, **one numbered workflow** (Steps 1–12):

- **Part 1 — The gate (Steps 1–6).** Nothing touches the codebase until the user says "yes, implement". The contract; do not weaken it. `automode` = only sanctioned bypass.
- **Part 2 — Lifecycle (Steps 7–12).** Gate open → implement → review → refactor → spin-off issues → self-evolve → commit proposal, autonomously, stopping only at substantive gates (§Autonomy).

"The agent" = whatever agent runs this skill. Adapt every reference (config dir, agent guide, interview UI) to your runtime; nothing hardcoded to one assistant.

## Parameters

Parse invocation: `/forge <ref> [automode] [with docs] [codex | codex challenge]` (words anywhere in request count). `<ref>` → git-host issue **or** Jira ticket per grammar. Flags orthogonal, compose freely.

### Target grammar — `<ref>`

First reference-shaped token (or token after `ticket` keyword) = target. Routing = **keyword OR key-shape**:

| Form | → | Examples |
|---|---|---|
| bare number, `#N`, `issue N` | **git-host issue** (Step 1b) | `forge 42`, `fix #123`, `issue 7` |
| matches `[A-Z][A-Z0-9]+-\d+` | **Jira ticket** (Step 1c) | `forge PROJ-123`, `solve AB12-9` |
| after `ticket` keyword | **Jira ticket**; number-only → ask project key | `forge ticket PROJ-123`, `solve ticket 42` |

Bare number → Jira only if `ticket` precedes. Key-shaped ref → always Jira, keyword or not.

### Modifier flags

| Flag | Effect |
|---|---|
| *(none)* | Interview if needed → propose → wait at gate (Step 6). Review = project reviewer agents **+** `superpowers:requesting-code-review`. |
| `automode` | **No user gates.** Never source `/grill-me` / `/grill-with-docs`. Auto-decide Steps 9 & 11. Skip Step 6 (proposal → Step 7). Never Jira-writes-back / auto-commits / auto-pushes — hard floor, never lifts. |
| `with docs` | `/grill-with-docs` not `/grill-me`. Proposal → `CONTEXT.md` (repo root); Part 2 plan sourced from it. Step 12 proposal → `/tmp/forge-<ref>.md`. |
| `codex` | **Claude Code only** (codex plugin is CC-exclusive). Step 8 generic reviewer → Codex (`codex-companion.mjs review`) instead of `superpowers:requesting-code-review`. Project reviewer agents still run. Degrades gracefully if Codex absent (§8a). |
| `codex challenge` | **Implies `codex`.** Codex `review` → `adversarial-review` (challenges approach/design/assumptions, not just defects). |

Compose any order: `forge ticket PROJ-7 automode with docs codex challenge`. `automode`+`with docs` → write `CONTEXT.md` directly, no interview, → Step 7. **Non-Claude-Code runtime: `codex`/`codex challenge` ignored with a one-line warning; generic reviewer stays `superpowers:requesting-code-review`** (skill itself stays runtime-generic — only the Codex path is CC-bound).

## When to Use

- `/forge <ref>` (arg = issue or Jira-ticket ref).
- "forge issue 42", "solve issue 42", "fix #123", "look at issue 7".
- "solve ticket PROJ-123", "forge ticket 42", or a bare Jira key `PROJ-123`.
- Asks the agent to act on a specific issue/ticket in the repo.

**Don't use** when:
- No issue/ticket ref given — ask; don't guess.
- Asking *about* an issue/ticket, not to *resolve* it.

## Step 1 — Classify the ref, resolve the repo & tracker

### Step 1a — Classify `<ref>` (Parameters → Target grammar)

- Key-shaped (`[A-Z][A-Z0-9]+-\d+`) **or** after `ticket` keyword → **Jira** → Step 1c.
- Else (bare number, `#N`, `issue N`) → **git-host** → Step 1b.
- `ticket` + number, no key → ask project key first (proposed-answer if candidates inferable from `git remote` / `CONTEXT.md` / branch names; else single prompt). `automode`: infer most likely, record assumption.

Always `git remote get-url origin` (fallback `upstream`) regardless of ref kind — Part 2 commits/branches against this repo even for Jira.

### Step 1b — git-host issue

Map host → CLI:

| Host in remote URL | CLI | Issue fetch |
|---|---|---|
| `github.com` / GH Enterprise | `gh` | `gh issue view <N> --json number,title,body,state,labels,comments,author,url` |
| `gitlab.*` | `glab` | `glab issue view <N> -F json` (confirm flag via `glab issue view --help`) |
| other (Gitea, Bitbucket, …) | that host's CLI if present | its issue-view JSON command |
| any, no CLI / auth error | — | host REST API (see Step 2) |

If neither `origin` nor `upstream` resolves to a known issue host: stop, tell the user, do nothing else.

### Step 1c — Jira ticket

→ **[references/jira.md](references/jira.md)** (resolve + fetch + absent-fallback + key-in-branch + write-back). Load it now; the rest of Steps 1–3 and Step 12 defer their Jira specifics there. Git-host issues never read it.

## Step 2 — Fetch the issue / ticket

### git-host issue

Prefer the Step 1b CLI. Missing / auth error → host REST API, e.g. GitHub:

```bash
curl -sH "Accept: application/vnd.github+json" \
     ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
     "https://api.github.com/repos/owner/repo/issues/<N>"   # comments: same URL + "/comments"
```

(GitLab: `GET /projects/:id/issues/:iid` + `/notes`, token in `PRIVATE-TOKEN`.) Unauth REST is rate-limited — say so if you fall back.

Read **body + every comment** — latest comments often carry the missing repro / decision.

### Jira ticket

→ **[references/jira.md](references/jira.md)** §Step 2 (pull fields + comments) and §Jira-absent fallback ★ (warn + 3-choice paste/auth/abort; stops even under `automode`).

## Step 3 — Verify the branch

```bash
git branch --show-current
```

**If the repo ships a git/contribution guide, follow it verbatim** — branch naming, base branch, PR target. Look for: `CONTRIBUTING.md`, a git section in the project agent guide (`AGENTS.md` / your runtime's equivalent), `.agents/rules/git*`, `docs/*git*`, or the runtime equivalent. The repo's own rules win over everything below.

**Only if no such guide exists**, fall back to this default: `<prefix>/<slug>` where `<prefix>` ∈ `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `perf`, `ci`, `build`, `style`.

- Pick `<prefix>` from the issue: bug-shaped → `fix`; new behavior → `feat`; docs → `docs`; deps/CI/tooling → `chore`; ambiguous → ask.
- `<slug>`: from the title, lowercase ASCII kebab-case, drop stop-words, ≤ 50 chars. *"Parser fails on UTF-16 BOM"* → `fix/parser-fails-utf-16-bom`.

**Jira — key in branch & commits** → **[references/jira.md](references/jira.md)** §Step 3 (repo guide wins; else branch `<prefix>/<KEY>-<slug>`, key not forced into subjects).

Compare to the current branch:
- Match → continue.
- Mismatch → show both, ask: **"Switch to a new branch `<prefix>/<slug>` forked off `<base>`? (y/n)"**. Pick `<base>` per the repo guide, else probe `dev` → `develop` → `main` → `master`.
- On `y`: confirm the tree is clean (`git status --short`); if dirty, surface the files and ask before any switch. Then `git switch -c <prefix>/<slug> <base>`.

## Step 4 — Check context sufficiency

**Use context you already have — do not sweep the codebase.** Inventory what's *already in the context window* first: the agent guide / memory / rulesets the runtime loaded at startup (`AGENTS.md` / `CLAUDE.md` / `GEMINI.md` / `CONTEXT.md` / `.agents/rules/*` / equivalents). Usually enough for the *design*. Only then read, in order, no further:

1. files the issue names;
2. at most a few top candidates from **targeted search** (def/callers of the named symbol) — never a directory walk or full-tree read.

Stop reading once you can write Step 5. Residual uncertainty → **Risks**, not more reading. Full-codebase sweep before a proposal = Red Flag — it wastes context the runtime already gave you.

Before proposing, the issue must answer:

| For a bug | For a feature |
|---|---|
| Steps to reproduce | Acceptance criteria |
| Expected vs actual | Affected surface (API, CLI, UI) |
| Environment (version, OS) | Backwards-compat expectations |
| Suspected component (optional) | Out-of-scope clarifications |

**Acceptance criteria / expected-vs-actual** = the `/goal` pass-conditions in Step 7 — capture precisely. Jira: mine from description + AC field + comments; a missing field is a Step 4 interview gap exactly as for a git issue; the pasted-text fallback (Step 2) is treated identically.

Required field missing → **interview the user**, never open free-text. Per gap: **2–4 proposed answers**, most likely marked **`(Recommended)`**, user picks. Runtimes with a selection UI (e.g. Claude Code's interview TUI): user highlights + Enter; "Other" free-type always implicitly available.

```
Q1: <gap, one line>
  - <option A> (Recommended)
  - <option B>
  - <option C>
```

Never invent the chosen answer — propose, user selects. Never continue past this step on unanswered required gaps.

`with docs` → interview run by `/grill-with-docs` (challenges plan vs repo domain model/docs). `automode` → skip interview; proceed on the issue as written, picking the `(Recommended)` answer per gap, noting the assumption in the proposal. `automode`+`with docs` → no interview; → Step 5 CONTEXT.md write.

### Step 4a — Optional grilling for risky design forks

Step 4 interview = *missing facts*. Context sufficient to propose **but a design/approach fork is genuinely ambiguous and a wrong pick = expensive rework** → deeper interview before the proposal:

- default → **`/grill-me`**
- `with docs` → **`/grill-with-docs`**
- `automode` → **never** (both interview the user); record the fork + chosen branch as an explicit proposal assumption.

Only when getting the approach wrong is costly. Clear low-risk fix → straight to Step 5.

## Step 5 — Propose the solution

Emit **one** proposal:

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

Verify file paths exist (Read/Grep) before listing; drop `:line` if you haven't opened the file.

**`with docs`:** write the proposal to `CONTEXT.md` (repo root) instead of / in addition to chat; Part 2 sources the plan from `CONTEXT.md`, not chat scrollback.

**Next-turn options.** End the proposal stating the user's choices:

- `yes, implement` — open the gate → Step 7.
- `interview me on risky questions` — **only if a risky design fork is still unanswered**; runs Step 4a grilling (proposed-answer, Step 4 structure), re-proposes.
- otherwise: any adjustment → revise, re-propose.

**`automode`:** no options, no wait — straight to Step 7 (with `with docs`: after writing `CONTEXT.md`).

## Step 6 — The gate ★

Unless `automode` is set, **do not edit any file** until the user explicitly approves.

- "yes, implement" / "go ahead" / "do it" / "ship it" → Step 7.
- "interview me on risky questions" → Step 4a, then re-propose.
- Plan change → revise, re-ask. Silence/questions → wait.

This is the most important rule of the skill. Skip it (outside `automode`) and the skill is worthless.

---

# Part 2 — Post-Approval Lifecycle (Steps 7–12)

Telegraphic by design. Each step delegates to a referenced skill — read that skill, don't restate it.

### Re-hydrate block ⟲

Referenced by Steps 8, 9. Two actions, in order:

```
/compact  →  re-source /karpathy-guidelines
```

Run *before touching code* on every non-converged review pass and before approved refactor work. Purpose: shed stale reviewer-transcript tokens, reload clean-code discipline. **`/goal` NOT restated here** — set once, Step 7.

## Step 7 — Implement

Open with, in order:

1. Set **`/goal`** = desired result + Step 4/5 pass criteria (exact build/test/behavior that proves done). Set once; never restate.
2. Re-source **`/karpathy-guidelines`**.

`with docs` → load plan from `CONTEXT.md`. Implement the approved plan — minimal, surgical, in scope. No edits before both 1 and 2 done.

## Step 8 — Review loop

Pick engine:

- **Primary:** project reviewer subagents from the agent config dir (`.agents/agents/` or runtime equivalent e.g. `.claude/agents/`) matched to the diff, **+** the **generic reviewer** — `superpowers:requesting-code-review` by default, or **Codex** under `codex`/`codex challenge` (→ [references/codex.md](references/codex.md), Claude Code only). **Project subagents always run** — `codex` swaps only the generic reviewer, never replaces project agents.
- **Fallback** (no project reviewer agents) **+ PR exists:** `/greploop` (needs the pushed PR — never auto-push to get one; Step 12).
- **Branch:** suspected bug / perf regression → `/diagnose`, return to loop.

Terminate at **zero actionable (must-fix / should-fix) findings** — nits don't block. Cap **3 passes**; not converged → summarize remainder, ask user (`automode`: pick safest, continue).

Each non-converged pass: **⟲**, fix findings, re-review.

### Step 8a/8b — Codex reviewer (`codex` / `codex challenge`)

→ **[references/codex.md](references/codex.md)** — §8a generic Codex reviewer (resolve via `scripts/resolve-codex.py`, foreground `review`/`adversarial-review`, graceful degrade) + §8b optional rework delegation to `codex:codex-rescue` (⟲ first, inline karpathy constraints, foreground `--wait`). **Claude Code only**; non-CC runtime → ignore the flag, warn once, stay on `superpowers:requesting-code-review`, don't load the file.

## Step 9 — Refactor (propose-only)

Run **`/improve-codebase-architecture`**.

- Default: surface opportunities; user approves → **⟲**, re-enter Step 8 **once** on the refactor diff. None / not approved → Step 10.
- `automode`: agent decides — apply only clearly net-positive, in-scope refactors; applied → **⟲**, re-enter Step 8 once; else continue.

Never silently rewrite beyond the issue's scope.

## Step 10 — Out-of-scope findings → `/to-issues`

Bugs/improvements in a **separate issue scope** → draft via **`/to-issues`**, show drafts, **post only on explicit user yes** (`automode`: post directly). Nothing qualifies → skip silently.

## Step 11 — Self-evolution

A caveat **automatable for future agentic sessions** → propose **`/write-a-skill`** or an edit to project agent config (agent guide / rules / reviewer-agent dir for the runtime) — show exact diff + path, confirm before write. `automode`: agent applies the smaller-blast-radius option (prefer rule/guide edit over a new skill unless the pattern is clearly broad). Nothing automatable → skip silently.

## Step 12 — Closing

**Verify `/goal` before anything else ★.** Before assembling the proposal: run the Step 7 `/goal` pass criteria **and** the repo's standard pre-commit checks (build/test/lint per the repo guide). Show the exact command(s) + their output. Any failure (or you cannot run them) → **you are not done**: return to Step 8 with the failure as a finding. Never assemble a commit proposal on unverified `/goal` — an unproven "done" is the one failure mode forge must not ship. `automode` does not lift this gate; it runs the checks itself and only proceeds on green.

Then assemble the **commit/PR proposal**. Default = **small atomic commits** matching the branch's existing granularity + message style (inspect `git log --oneline <base>..HEAD`) — **not** one squashed mega-commit. Repo git/contribution guide (Step 3) still wins: mandates another shape (e.g. squash-on-merge) → follow it, say why.

Then ask **one** closing question, Step 4 proposed-answer format (user selects; `(Recommended)` marked; "Other" implicit):

```
Forge is done — how should the changes land?
  - Lay down the proposed small-commit history on this branch, push nothing (Recommended)
  - Lay down that history, push to origin, and open a PR to the base branch
  - Lay down that history, push, open the PR, and comment + transition <KEY> on Jira   ← Jira target only
  - Walk me through the implementation at a high level first — run /zoom-out, then re-ask
  - Write the whole proposal (commit plan + diff summary) to /tmp/<name>.md and stop
  - Hold — leave the working tree uncommitted for my own manual review
```

Act only on the selected option. Option 2 follows the repo guide for base branch + PR target.

**Jira write-back (3rd option)** → **[references/jira.md](references/jira.md)** §Step 12 (opt-in only; comment + confirmed transition; never on other options, never under `automode`). Show the 3rd menu line only when the target was a Jira ticket.

**Never auto-commit, auto-push, or write back to Jira** outside an explicit selection.

- `with docs`: still ask, but pre-mark the `/tmp/<name>.md` option `(Recommended)` over option 1.
- `automode`: skip the question — emit the proposed small-commit history as a **plan only** (to `/tmp/forge-<ref>.md` under `with docs`, else inline), then stop. `automode` never executes commits, pushes, or Jira write-backs.

### Autonomy

Default: after "yes, implement", run autonomously, stopping **only** at the substantive gates — Step 6 entry · Step 9 refactor · Step 10 spinoff-issue post · Step 11 self-evolution · Step 12 commit proposal. No "may I continue?" between steps.

`automode` lifts those gates but never the hard floors: no auto-commit / auto-push / Jira write-back; Step 12 `/goal` verify still runs; Step 2 Jira-absent fallback still triggers.

→ **[references/autonomy.md](references/autonomy.md)** for the full per-step matrix, the rationale behind each hard floor, and `automode` composability with other flags.

---

## Anti-patterns & Red Flags

→ **[references/anti-patterns.md](references/anti-patterns.md)** — common mistakes table + red-flag stop list. Both bind under `automode` too; the file is the canonical home for new rules learned during a forge session.
