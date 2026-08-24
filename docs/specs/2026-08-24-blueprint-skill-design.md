# Blueprint — visual/interactive brainstorming skill

**Date:** 2026-08-24
**Status:** Approved design (brainstorm gate passed; core UI variants verified visually via companion session)
**Repo placement:** `skills/blueprint/` — third skill in this repo, completing the pipeline: **blueprint** (design it) → **forge** (ship one task) → **blacksmith-orchestrate** (ship many).

## 1. What blueprint is

A standalone brainstorming workflow skill for UI/UX work, modeled on the logic of `superpowers:brainstorming` but rebuilt around two ideas proven in the AutoLab sessions of 2026-08-23/24:

1. **High-fidelity proposals in the browser.** Mockups are drawn from the target project's *real* design language (DESIGN.md-class docs plus tokens and components harvested from code), so what the user approves is what the app will actually look like.
2. **Clipboard as the return channel.** Option cards, notes, and nit flags are interactive; a **Copy response** action assembles one human-readable prompt the user pastes back into the agent session. The browser never talks to the agent — the human is the transport. This removes the stateful event-channel server of the superpowers companion and its failure modes.

Blueprint owns the whole arc: classify → harvest → interactive proposal rounds → hard approval gate → spec → handoff to plans / tickets / blacksmith. `superpowers:brainstorming` remains untouched for non-visual work.

## 2. Workflow — 8 steps, one gate

```
Part 1 — Setup (1–3):    classify → harvest design language → start companion
Part 2 — Rounds (4–5):   push proposal screen → read pasted response, ledger it   (loop)
Part 3 — Close (6–8):    [GATE] recap + approval → write spec → handoff
```

- **Step 1 — Classify & parse.** Confirm the topic has a visual dimension; if not (pure backend/API design), say so in one line and defer to plain brainstorming. Parse flags. Enumerate the UI items in scope (sessions typically batch 3–6; each is a track through the rounds).
- **Step 2 — Design harvest.** See §5. No screen may be pushed before the harvest exists.
- **Step 3 — Start the companion.** Launch `scripts/serve.mjs`, open the tab, verify alive via `.brainstorm/server-info`. Headless or `terminal` flag → terminal fallback (§8), announced in one line.
- **Step 4 — Push a round.** Author a content fragment (questions, option cards, mockups importing the harvested style), write it to `.brainstorm/screens/`, summarize in the terminal what's on screen. **HARD GATE inherited verbatim from brainstorming: nothing touches the codebase before Step 6 approval.**
- **Step 5 — Resolve the round.** User clicks selections/notes/nits, hits Copy response, pastes into the terminal. Agent parses the paste (§4 contract), appends decisions to the ledger (§6), then revises (new screen version) or advances. Screen discipline: never reuse filenames; push a `waiting-N.html` when returning to terminal-only discussion.
- **Step 6 — GATE: recap.** Final screen renders the decision ledger; user approves in the terminal (or clicks the recap's Approve button, which copies the approval phrase). No approval → no spec, no further steps.
- **Step 7 — Spec.** Write the design doc from the ledger to `docs/specs/YYYY-MM-DD-<topic>-design.md`; run the four-check self-review (placeholders, contradictions, scope, ambiguity); commit.
- **Step 8 — Handoff.** Recap screen flips to handoff mode (§7).

### Flags (orthogonal, parsed from anywhere in the invocation)

| Flag | Behavior |
|---|---|
| `fresh` | Force a full design re-harvest, ignoring the cache |
| `terminal` | Skip the browser entirely; run the terminal fallback for every round |
| `resume` | Continue from an existing ledger: read it, restart the server, re-push the last unresolved screen |

## 3. Browser stack — shipped assets

Three dependency-free files under `skills/blueprint/scripts/` (Node stdlib + vanilla JS only; no package manager, matching repo rules). The interactive machinery is versioned code; per-session the agent authors only content fragments.

**`serve.mjs` — live-reload server (~150 lines).** `node serve.mjs --project-dir <repo> [--port N] [--open]`.
- Serves the newest `*.html` fragment from `<project>/.brainstorm/screens/`, wrapped in `frame.html` (fragments starting `<!DOCTYPE` are served as-is).
- `fs.watch` on the screens dir; reload pushed over SSE. No WebSocket, no polling.
- Serves `.brainstorm/style.css` at a stable path every frame imports.
- Writes `.brainstorm/server-info` (port, pid) on start, removes on exit; aliveness check is one file stat. Port persisted per project → restart reconnects the already-open tab (paused overlay, then resumes).
- **No idle timeout by default** (the 4-hour auto-exit was a proven friction source); `--idle-timeout-minutes` opt-in.
- **Zero ingestion:** no POST endpoints, no events file, no state beyond "newest file". Death mid-session loses nothing; ledger and screens are on disk.

**`frame.html` — shell.** Header (topic + round name), connection dot, harvested `style.css` import, fragment slot, `composer.js`. Themed by the harvested tokens, not a generic theme.

**`composer.js` — interaction engine.** Verified UI decisions from the companion session in **bold**:
- **Selection:** elements with `data-q="<question-id>" data-choice="<letter>"` are selectable cards; one choice per question, re-click to change; `data-multi` on the container enables multi-select.
- **Notes:** per-question optional note field, collapsed behind ✎ until used.
- **Nit-flagging — alt-click model (verified A):** elements with `data-region="<stable-id>"` outline on hover; **alt-click** flags the region (dashed outline + note field). Invisible until invoked; each screen carries a one-line hint teaching the gesture.
- **Tray — fixed bottom bar (verified A):** always-visible full-width bar: `N selections · M notes · K nits` plus the **Copy response** button. `navigator.clipboard` with `execCommand` fallback; flashes "copied — paste it in the terminal".
- **Recap/handoff mode:** fragment declares `data-mode="recap"`; tray buttons become approval/handoff prompt-copiers. Handoff prompts and flag metadata arrive in the fragment as `data-copy`/JSON payloads — **prose decides content, code handles the click**; composer.js never composes prompts itself.

## 4. Clipboard prompt contract

Canonical format defined once in `references/composer.md`; cited by both `composer.js` and the agent-side parsing instructions:

```
[blueprint:briefing-hero-options]
1) Status card → A
2) Detail layout → A — note: replace the em dash with something more human
Nit on run-config.precision-row: align the precision value right like the other rows
```

- First line names the screen. A paste whose header names a different round than the current one is a **stop-and-ask**, never a guess.
- Body is human-readable prose (numbered per question, notes inline, nits by region id) — the user sees what they're sending, can edit it inline in the terminal, and the terminal-fallback answers look identical, so downstream workflow prose never branches on mode.
- Agent-side rule: the paste is the user's authoritative answer; merge with any surrounding free text they typed.

## 5. Design harvest

Owned by `references/harvest.md`. Source priority:

1. **Design docs** — `DESIGN.md`, `docs/DESIGN.md`, `docs/design/**` (globbed, case-insensitive). These carry the rules.
2. **Token sources in code** — tailwind config, CSS custom properties, theme files, font imports, the icon library actually imported.
3. **2–3 representative components from the surface being brainstormed** — real components beat prose for idioms (card chrome, spacing rhythm, empty states).

Cached output in the target project:
- `.brainstorm/style.css` — real CSS variables, font stacks, radii, shadows, spacing scale, plus mockup utility classes named after the project's own idioms.
- `.brainstorm/design-notes.md` — prose rules CSS can't carry, each with a source pointer back to the file it came from.

Freshness: later sessions re-check only the pointed-at sources (mtime/short diff) and refresh what changed; `fresh` rebuilds. Gitignore guidance: ignore `.brainstorm/screens/`, ledgers, and `server-info`; **commit** `style.css` + `design-notes.md` (shared team assets; screens and ledgers are session ephemera — the committed spec supersedes the ledger).

## 6. Ledger

`.brainstorm/<YYYY-MM-DD>-<topic>.md`, owned by `references/ledger.md`. Append-only during rounds; per resolved round: round name, screen filename, question, options considered (one-liners), **chosen option with full description**, notes, nits with resolutions.

Consumers:
- **Recap screen** renders directly from it — what the user approves at the gate is provably what was recorded.
- **Spec (Step 7)** is assembled from it: "Design decisions" from the chosen-option blocks reorganized per UI item, plus a "Rejected alternatives" appendix (one line each, so implementing forge runs don't reintroduce rejected variants).
- **`resume` flag** — the ledger *is* the session state.

## 7. Handoff — three routes + invocation builder

Recap screen's handoff mode, owned by `references/handoff.md`:

1. **"Write the implementation plans"** — copies a prompt naming the spec path and invoking the plans skill.
2. **"Spin off tickets"** — copies a prompt prefixed with the **`/to-tickets`** skill invocation pointing at the committed spec (one issue per decided UI item, preserving chosen-option detail and rejected alternatives; tail pre-filled from the ledger). Feeds blacksmith's issue-sourced entry route.
3. **"Dispatch to blacksmith" — toggle-chip builder (verified A):**
   - Work-source segmented control: `plan (<path>)` vs the Route-2 ticket set; enablement follows which routes ran.
   - **Two chip groups mirroring the invocation grammar** — orchestrator flags before the `-` separator, forge pass-through flags after it. Suggested flags arrive pre-toggled with one-line reasoning shown under each suggestion.
   - **Live command preview** re-assembled on every toggle; **Copy invocation** copies exactly the preview.
   - Flag metadata (names, descriptions, defaults, reasoning, grammar slots) is generated by the agent **from the two skills' actual `flags.md` files at recap time** and embedded as JSON in the fragment — the builder can never drift from the real flag matrix. Assembly grammar: `<verb> <work-source> <orchestrator-flags> - <passthrough-flags>`.

Note: this spec references `/to-tickets` (current name of the renamed Matt Pocock skill, formerly `to-issues`). Forge's own skill-routing references are updated in a separate later pass.

## 8. Terminal fallback

Trigger: `terminal` flag, no display/browser, or `serve.mjs` fails to bind twice. The workflow does not branch — same rounds, ledger, gate, handoff. Rendering degrades: options become terminal multiple-choice (host question UI where available, numbered lists otherwise); mockups become ledger-grade prose plus small ASCII sketches where genuinely helpful; the handoff builder becomes a printed suggested invocation with an ask-which-flags-to-flip exchange. Because clipboard prompts are already human prose, answers are format-identical across modes.

## 9. Anti-patterns (seed set for `references/anti-patterns.md`)

| Anti-pattern | Correction |
|---|---|
| Generic-Tailwind mockups | No screen before harvest; every fragment imports `.brainstorm/style.css` |
| Re-improvising composer/frame inline | Interactive machinery ships in `scripts/`; fragments carry content only |
| Reusing a screen filename | New file per revision (`layout-v2.html`); server serves newest |
| Accepting a paste with a stale `[blueprint:…]` header | Stop and ask; never guess the round |
| Leaving a resolved screen up during terminal discussion | Push `waiting-N.html` |
| Implementation before the Step 6 gate | Hard stop — HARD-GATE inherited verbatim |
| Hand-writing flag toggles into the builder | Metadata generated from the skills' `flags.md` at recap time |

## 10. Repo integration

```
skills/blueprint/
  SKILL.md                  # 8-step workflow, Parameters (fresh/terminal/resume), When-to-Use
  references/
    flags.md                # canonical flag matrix (fresh/terminal/resume), composition rules
    harvest.md              # source priority, cache freshness, style.css/design-notes contract
    screens.md              # fragment authoring: data-q/data-choice/data-region, waiting screens
    composer.md             # clipboard prompt contract (canonical), tray behavior
    ledger.md               # ledger schema, resume contract
    handoff.md              # three routes, flag-builder metadata shape, assembly grammar
    anti-patterns.md
  scripts/
    serve.mjs               # live-reload server (SSE, no ingestion, stable port, no default idle timeout)
    frame.html              # shell template
    composer.js             # selection/notes/nits/tray/flag-builder engine
```

- `tests/docs_test.sh` extends to blueprint: relative links resolve, no placeholders, flag-table three-way sync (`SKILL.md` / `references/flags.md` / `README.md`), manual verification recipe per reference file.
- New: `tests/blueprint_test.sh` smoke-tests `serve.mjs` with Node only (starts, serves newest fragment wrapped in frame, writes/cleans `server-info`).
- `install.sh`: untouched `deps_table` — blueprint has no install-time dependencies (`/to-tickets` and blacksmith are handoff *targets*); blueprint ships as part of the repo-source install, preserving the "forge installs last" invariant.
- `README.md`: blueprint section + the blueprint → forge → blacksmith pipeline story.
- Repo `.gitignore`: add `.superpowers/` (companion sessions run against this repo persist there).

## 11. Verified decisions record

From the companion session run against this design (2026-08-24), terminal answers matching browser events one-for-one:

| Question | Chosen | Rejected |
|---|---|---|
| Composer tray | **A — fixed full-width bottom bar** | B — floating expandable pill |
| Nit-flagging | **A — alt-click region + hint line** | B — hover-revealed 🚩 buttons |
| Handoff builder | **A — grammar-grouped toggle chips** | B — flat checklist table with reasoning column |
