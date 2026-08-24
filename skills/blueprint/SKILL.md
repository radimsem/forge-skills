---
name: blueprint
description: Brainstorm UI/UX changes into an approved design through interactive browser proposals rendered in the project's real design language. Option clicks assemble a response prompt copied to the user's clipboard. Use when the user runs /blueprint or wants to brainstorm, redesign, or visually verify UI/UX work before implementation.
---

# Blueprint

> Design it in the browser, approve it at the gate, hand the blueprint to the
> blacksmith: **blueprint → forge → blacksmith-orchestrate**.

## Overview

Blueprint owns the whole UI/UX brainstorming arc: harvest the project's real
design language, push interactive proposal screens, resolve rounds through
clipboard-pasted responses, gate on approval, write the spec, and hand off to
plans, tickets, or orchestration. The browser never talks back to the agent —
the user's paste is the only return channel, so the companion server keeps no
state and its death mid-session loses nothing.

The interactive machinery ships in [scripts/](scripts/serve.mjs) and is never
reimplemented inline; each session authors only HTML content fragments per
[references/screens.md](references/screens.md).

## Parameters

Flags compose and are parsed from anywhere in the invocation; the canonical
matrix with composition rules is [references/flags.md](references/flags.md).

| Flag | Effect |
|---|---|
| `fresh` | Force a full design re-harvest, ignoring the `.brainstorm/` cache |
| `terminal` | Skip the browser; run every round in the terminal fallback |
| `resume` | Continue from an existing ledger: restart the server, re-push the last unresolved screen |

## When to Use

Use for UI/UX brainstorming: new screens, redesigns, component-level polish,
anything where the user should *see* options before choosing. If the topic
has no visual dimension (pure backend or API design), say so in one line and
defer to a plain brainstorming workflow instead of forcing a browser on a
text problem.

## Workflow

    Part 1 — Setup (1–3):    classify → harvest → start companion
    Part 2 — Rounds (4–5):   push screen → read pasted response, ledger it   (loop)
    Part 3 — Close (6–8):    [GATE] recap + approval → spec → handoff

### Step 1 — Classify & parse

Confirm the topic is visual (see When to Use). Parse flags. Enumerate the UI
items in scope — sessions typically batch several; each becomes a track
through the rounds.

### Step 2 — Design harvest

Build or refresh `.brainstorm/style.css` and `.brainstorm/design-notes.md`
per [references/harvest.md](references/harvest.md). **No screen may be pushed
before the harvest exists.**

### Step 3 — Start the companion

Run `node <skill>/scripts/serve.mjs --project-dir <project> --open` in the
background. Verify aliveness by statting `.brainstorm/server-info`; share the
printed URL every round as fallback. If the server cannot start twice, or the
`terminal` flag is set, degrade per the terminal-fallback section of
[references/screens.md](references/screens.md) with a one-line warning.

### Step 4 — Push a round

Author a content fragment per [references/screens.md](references/screens.md)
into `.brainstorm/screens/`, then summarize in the terminal what is on
screen and ask the user to click and paste.

**HARD GATE: nothing touches the target codebase before Step 6 approval. No
flag bypasses this.**

### Step 5 — Resolve the round

Parse the pasted response per
[references/composer.md](references/composer.md): verify the screen header,
map answers by order, treat nits as change requests. Append decisions to the
ledger per [references/ledger.md](references/ledger.md). Revise (new `-vN`
screen) or advance; push a waiting screen when returning to terminal-only
discussion.

### Step 6 — GATE: recap and approval

Push a recap screen rendered from the ledger (`data-mode="recap"`). The user
approves in the terminal, or clicks **Copy approval** and pastes the phrase.
No approval → stop here.

### Step 7 — Spec

Assemble the design doc from the ledger into
`docs/specs/YYYY-MM-DD-<topic>-design.md`: design decisions per UI item plus
a one-line-each "Rejected alternatives" appendix. Self-review for
placeholders, contradictions, scope, ambiguity; fix inline; commit.

### Step 8 — Handoff

Push the handoff screen per
[references/handoff.md](references/handoff.md): plans route, `/to-tickets`
route, and the blacksmith invocation builder with generated flag chips.

## Anti-patterns

New lessons go to [references/anti-patterns.md](references/anti-patterns.md),
the canonical home — not into this file.
