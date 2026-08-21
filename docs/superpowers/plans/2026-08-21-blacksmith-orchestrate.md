# blacksmith-orchestrate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `skills/blacksmith-orchestrate`, a multi-agent orchestration wrapper that turns a set of tasks into scheduled, worktree-isolated forge runs, plus the one forge change it needs (`/forge plan <path>`).

**Architecture:** The deliverable is prose — a skill an agent reads and obeys — following forge's progressive-disclosure pattern: a terse `SKILL.md` holding the 9-step contract, with detail delegated to `references/*.md` loaded on demand. Because prose is the artifact, the test suite asserts *structural* invariants (links resolve, flag tables across `SKILL.md`/`README.md`/`flags.md` agree, no placeholder text, every mode file carries a verification recipe). A new `tests/docs_test.sh` provides those red-green cycles; `tests/install_test.sh` covers the installer change.

**Tech Stack:** POSIX `sh` (shellcheck-clean, no bashisms), Markdown, one Node.js Workflow script. No package manager, build step, or linter config.

**Spec:** `docs/superpowers/specs/2026-08-21-blacksmith-orchestrate-design.md`

## Global Constraints

- **POSIX `sh` only.** No bashisms. `shellcheck` is not installed here but scripts are written to pass it.
- **Test commands:** `sh tests/install_test.sh` and `sh tests/docs_test.sh`. Both exit non-zero when `FAILS>0`.
- **Progressive disclosure.** Step-level contract goes in `SKILL.md`; expandable detail goes in the matching `references/` file and is *linked*, never inlined.
- **Three-way sync.** The flag list appears in `SKILL.md`, `README.md`, and `references/flags.md`. They must not drift — `tests/docs_test.sh` enforces this from Task 1 onward.
- **`deps_table` is the single source of truth** for what gets installed. Changing it requires updating the corresponding assertions in `tests/install_test.sh` in the same commit.
- **Forge's hard floors must not weaken.** No auto-commit, auto-push, or tracker write-back; the Step 12 `/goal` verification always runs. The `afk` flag is the single documented exception and must be labelled as such wherever it appears.
- **Exact names:** skill directory `skills/blacksmith-orchestrate`, skill name `blacksmith-orchestrate`, install source `radimsem/forge-skills` (unchanged `FORGE_SOURCE`).
- **New lessons** learned during implementation go in the owning skill's `references/anti-patterns.md`, never scattered into `SKILL.md`.

---

## File Structure

**Created:**

| Path | Responsibility |
|---|---|
| `tests/docs_test.sh` | Structural invariants for all shipped skill prose |
| `skills/forge/references/modes/plan-entry.md` | The `/forge plan <path>` entry verb |
| `skills/blacksmith-orchestrate/SKILL.md` | 9-step orchestration contract, flag table, when-to-use |
| `.../references/entry-routes.md` | Four work sources → one canonical task list |
| `.../references/flags.md` | Flag matrix, composition and conflict rules |
| `.../references/plan-sourced.md` | Step 3a: detection, dispatch-ready ladder, freshness guard |
| `.../references/collision-graph.md` | Edges, orientation, hard vs soft overlap, semantic conflicts |
| `.../references/triage.md` | The two axes, tier/depth tables, the four floors, promotion |
| `.../references/scheduling.md` | Components, unified vs split, waves, budget ladder |
| `.../references/battle-plan.md` | Literal gate artifact format (analogue of forge's `proposal-template.md`) |
| `.../references/relay.md` | Ancestor proof, rebase, park semantics |
| `.../references/afk.md` | The sanctioned floor exception and its verify checklist |
| `.../references/ledger.md` | Ledger schema, task states, resume contract |
| `.../references/anti-patterns.md` | Orchestration red flags |
| `.../scripts/scout-fanout.mjs` | Workflow script for the Step 3b scout fan-out |

**Modified:** `skills/forge/SKILL.md`, `skills/forge/references/flags.md`, `install.sh`, `tests/install_test.sh`, `README.md`, `CLAUDE.md`, and the spec's §13 file list (Task 7 adds `battle-plan.md` to it).

**Deviation from spec §13:** the spec's file list omits `battle-plan.md`. §7 defines a substantial literal artifact format, which by this repo's convention belongs in its own reference file — forge keeps the same kind of content in `references/proposal-template.md`. Task 7 creates the file and amends the spec's list to match.

---

## Task 1: Docs-consistency test harness

**Files:**
- Create: `tests/docs_test.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: shell functions every later task's red step calls — `assert_eq(actual, expected, msg)`, `assert_file(path, msg)`, `assert_contains(file, pattern, msg)`, `broken_links(file)` (prints `file -> target` per unresolvable link), `flag_names(file, section_heading_regex)` (prints normalized flag names, one per line, sorted, deduped). `ROOT` holds the repo root.

- [ ] **Step 1: Write the harness**

Create `tests/docs_test.sh`:

```sh
#!/usr/bin/env sh
# Consistency tests for the skill prose this repo ships.
# The deliverable is prose, so these assert structural invariants:
# links resolve, flag tables do not drift, no placeholder text ships.
set -u
FAILS=0
pass() { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; FAILS=$((FAILS+1)); }
assert_eq() { # actual expected msg
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (expected [$2] got [$1])"; fi
}
assert_file() { # path msg
  if [ -f "$1" ]; then pass "$2"; else fail "$2 (missing $1)"; fi
}
assert_contains() { # file pattern msg
  if [ -f "$1" ] && grep -qE "$2" "$1"; then pass "$3"; else fail "$3 (no /$2/ in $1)"; fi
}

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# Every relative .md link in a markdown file must resolve.
broken_links() { # $1=markdown file
  _dir=$(dirname -- "$1")
  grep -o ']([^)#]*\.md' "$1" | sed 's/^](//' | while read -r _t; do
    case "$_t" in http*|/*) continue ;; esac
    [ -f "$_dir/$_t" ] || printf '%s -> %s\n' "$1" "$_t"
  done
}

# Normalized flag names from the first column of the tables under one heading.
flag_names() { # $1=file $2=heading regex
  awk -v h="$2" '$0 ~ h {f=1; next} /^## /{f=0} f' "$1" \
    | awk -F'|' 'NF>2 {print $2}' \
    | tr '/' '\n' \
    | sed -n 's/.*`\([^`]*\)`.*/\1/p' \
    | sed 's/^ *//; s/ *$//' \
    | sort -u
}

# --- every skill has frontmatter with a name and a description ---
for _s in "$ROOT"/skills/*/SKILL.md; do
  [ -f "$_s" ] || continue
  assert_eq "$(head -n1 "$_s")" "---" "frontmatter opens $_s"
  assert_contains "$_s" '^name: ' "frontmatter has name: $_s"
  assert_contains "$_s" '^description: ' "frontmatter has description: $_s"
done

# --- every relative markdown link resolves ---
_broken=$(find "$ROOT/skills" -name '*.md' -type f | sort | while read -r _f; do
  broken_links "$_f"
done)
assert_eq "$_broken" "" "all relative markdown links in skills/ resolve"

# --- no placeholder text ships ---
_ph=$(grep -rnE '\bTBD\b|\bTODO\b|\bFIXME\b' "$ROOT/skills" || true)
assert_eq "$_ph" "" "no TBD/TODO/FIXME in skills/"

# --- every mode file carries a manual verification recipe ---
_norecipe=$(find "$ROOT/skills" -path '*/references/modes/*.md' -type f | sort | while read -r _f; do
  grep -q 'Manual verification recipe' "$_f" || printf '%s\n' "$_f"
done)
assert_eq "$_norecipe" "" "every references/modes/*.md has a Manual verification recipe"

# --- forge: flags.md and the README flag table agree ---
assert_eq "$(flag_names "$ROOT/skills/forge/references/flags.md" '^## Flags')" \
          "$(flag_names "$ROOT/README.md" '^## Modifier flags')" \
          "forge: flags.md and README flag tables agree"

printf '\n%s\n' "FAILS=$FAILS"
[ "$FAILS" -eq 0 ]
```

- [ ] **Step 2: Run it against the current repo**

Run: `sh tests/docs_test.sh`
Expected: `FAILS=0`.

If any assertion is red, the harness has found **genuine existing drift**. Fix the drift in the source files — do not weaken the assertion. Finding real drift on first run is a success, not a harness bug.

- [ ] **Step 3: Prove the harness actually catches breakage**

Run:
```sh
printf '\nSee [nope](references/does-not-exist.md).\n' >> skills/forge/SKILL.md
sh tests/docs_test.sh
```
Expected: FAIL on "all relative markdown links in skills/ resolve", exit non-zero.

Then restore and re-confirm:
```sh
git checkout -- skills/forge/SKILL.md
sh tests/docs_test.sh
```
Expected: `FAILS=0`.

- [ ] **Step 4: Commit**

```bash
chmod +x tests/docs_test.sh
git add tests/docs_test.sh
git commit -m "test: add docs consistency harness for shipped skill prose"
```

---

## Task 2: `/forge plan <path>` entry verb

**Files:**
- Create: `skills/forge/references/modes/plan-entry.md`
- Modify: `skills/forge/SKILL.md` (Parameters line, Target grammar table), `skills/forge/references/flags.md` (Entry verbs table), `README.md` (Examples block), `tests/docs_test.sh`

**Interfaces:**
- Consumes: Task 1's `assert_file` / `assert_contains` / `flag_names`.
- Produces: the invocation `/forge plan <path>[#<task-heading-slug>]`, entering forge at Step 7. Task 4 and Task 9 dispatch through it.

- [ ] **Step 1: Write the failing assertions**

Append to `tests/docs_test.sh`, immediately before the final `printf '\n%s\n' "FAILS=$FAILS"` line:

```sh
# --- forge: the plan entry verb is documented in all three places ---
assert_file "$ROOT/skills/forge/references/modes/plan-entry.md" \
  "forge: plan-entry.md exists"
assert_contains "$ROOT/skills/forge/SKILL.md" 'after .`?plan.`? keyword' \
  "forge SKILL.md: target grammar has a plan row"
assert_contains "$ROOT/skills/forge/references/flags.md" '/forge plan <path>' \
  "forge flags.md: entry-verbs table has the plan verb"
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/docs_test.sh`
Expected: 3 FAIL lines for the assertions above, exit non-zero.

- [ ] **Step 3: Create `skills/forge/references/modes/plan-entry.md`**

Required content, in this order:

1. Title `# Forge — plan-entry mode` and a one-line statement that it is loaded on demand when the invocation is `/forge plan <path>`.
2. A `## Manual verification recipe` block (repo convention — `tests/docs_test.sh` enforces it):

```
/forge plan docs/superpowers/plans/2026-08-21-auth.md#task-3
```

Expected: Steps 1, 2, 4, 5 and 6 collapse into a single Step P validation pass; Step 3 still resolves the branch; implementation begins at Step 7 with `/goal` derived from the plan slice's testable deliverable.

3. A `## Step P — plan validation` section stating these four actions in order:
   - resolve the plan slice and confirm its stamp matches this invocation;
   - confirm every path the slice names exists;
   - derive `/goal` from the slice's testable deliverable;
   - treat the slice as the approved Step 5 proposal — the plan's own approval satisfies the gate.
4. A sentence stating that **Step 3 still runs**: branch naming, base selection and the clean-tree check are not optional because a plan exists.
5. A sentence stating that where the slice links an issue and lacks pass criteria, Step 2's fetch is permitted to fill that gap.
6. A `## Slice addressing` section: `<path>#<task-heading-slug>`, or the whole file when the plan describes a single task.
7. A `## Behavior change vs default` table with rows for Steps 1–2, Step 3, Steps 4–6, Step 7 and Step 12, matching the shape of the table in `worktree.md`.
8. A `## Composition with other flags` table stating: `docs` is redundant (the plan *is* the sourced plan) and is accepted with a one-line note; `tdd` still writes and observes the red test before Step 7; `automode` is unaffected because the gate is already satisfied; `codex impl` delegates the slice exactly as it would a chat proposal.

- [ ] **Step 4: Add the grammar row to `skills/forge/SKILL.md`**

In the **Target grammar — `<ref>`** table, add after the `pr` keyword row:

```markdown
| after `plan` keyword | **plan-entry mode** (skips Steps 4–6; enters at Step 7 against the plan slice) | `forge plan docs/superpowers/plans/x.md#task-3` |
```

In the **Parameters** paragraph, extend the invocation grammar to read `..., or `/forge pr <N> [...]`, or `/forge plan <path>[#<slug>] [...]``.

Below the grammar table, add one sentence: "Read **[references/modes/plan-entry.md](references/modes/plan-entry.md)** for the plan-entry step modifications and slice addressing."

- [ ] **Step 5: Add the entry-verb row to `skills/forge/references/flags.md`**

In the `## Entry verbs` table, after the `/forge pr <N>` row:

```markdown
| `/forge plan <path>` | Skip Steps 4–6; enter at Step 7 with the plan slice as the approved proposal. Step 3 still runs | [modes/plan-entry.md](modes/plan-entry.md) |
```

- [ ] **Step 6: Add the README example**

In `README.md`'s Examples block, after the `/forge pr 47` line:

```sh
/forge plan docs/superpowers/plans/x.md#task-3   # implement one plan task directly
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `sh tests/docs_test.sh`
Expected: `FAILS=0` — including the link-resolution assertion, which now covers the two new links to `plan-entry.md`.

- [ ] **Step 8: Commit**

```bash
git add skills/forge/references/modes/plan-entry.md skills/forge/SKILL.md \
        skills/forge/references/flags.md README.md tests/docs_test.sh
git commit -m "feat(forge): add /forge plan <path> entry verb"
```

---

## Task 3: blacksmith skeleton — SKILL.md, entry routes, flags

**Files:**
- Create: `skills/blacksmith-orchestrate/SKILL.md`, `skills/blacksmith-orchestrate/references/entry-routes.md`, `skills/blacksmith-orchestrate/references/flags.md`
- Modify: `tests/docs_test.sh`

**Interfaces:**
- Consumes: Task 1's helpers.
- Produces: `SKILL.md` with an H2 `## Parameters` holding the flag table, and H2 headings `## Step 1` … `## Step 9`. `references/flags.md` with an H2 `## Flags` whose first column carries the eleven orchestrator flag names — `afk`, `resume`, `budget <n>`, `strict`, `stack`, `rescout`, `max <n>`, `dry`, `unified`, `split`, `plan <path>` — and an H2 `## Composition rules`. Every later task appends its own `## Step N` section to this `SKILL.md` and links to its own reference file.

- [ ] **Step 1: Write the failing assertions**

Append to `tests/docs_test.sh` before the `FAILS=` printf:

```sh
# --- blacksmith: skeleton exists and its flag tables agree ---
BS="$ROOT/skills/blacksmith-orchestrate"
assert_file "$BS/SKILL.md"                      "blacksmith: SKILL.md exists"
assert_file "$BS/references/entry-routes.md"    "blacksmith: entry-routes.md exists"
assert_file "$BS/references/flags.md"           "blacksmith: flags.md exists"
assert_eq "$(flag_names "$BS/references/flags.md" '^## Flags')" \
          "$(flag_names "$BS/SKILL.md" '^## Parameters')" \
          "blacksmith: SKILL.md and flags.md flag tables agree"
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/docs_test.sh`
Expected: FAIL on all four, exit non-zero.

- [ ] **Step 3: Create `skills/blacksmith-orchestrate/SKILL.md`**

Frontmatter, verbatim:

```markdown
---
name: blacksmith-orchestrate
description: "Orchestrate many forge runs at once: analyze which tasks collide on the same files, schedule the colliding ones sequentially, and run the rest in parallel worktrees at the right model tier and review depth. Use when the user runs /blacksmith-orchestrate or asks to ship several issues, a milestone, or a written implementation plan in one go."
---
```

Then, in order:

- `# Blacksmith Orchestrate` and the one-line summary: it decides **which tasks run, in what order, at what depth, by which model, in which worktree**, then dispatches one forge run per task.
- `## Overview` — state that it is a wrapper and never reimplements a forge step, and include the Part 1 / Part 2 diagram from spec §2 verbatim:

```
Part 1 — Plan (1–5):     normalize → materialize → analyze → schedule → [GATE] battle plan
Part 2 — Execute (6–9):  provision → dispatch waves → relay → close-out

  gate held: no worktree is created and no forge Part 2 runs until "yes, forge them"
```

- The nine-row step table from spec §2.
- `## Parameters` — the invocation grammar `/blacksmith-orchestrate <work-source> [orchestrator-flags] [forge-flags]`, a link to `references/flags.md` for the full matrix, and the flag table whose first column holds exactly the eleven names listed in this task's Interfaces block, each with a one-line effect and a link to its owning reference file. Also state the two forge pass-through overrides: `worktree` is always implied and orchestrator-managed; `automode` lifts the battle-plan gate and passes through.

  **Write those two overrides as prose sentences, not as a table.** `tests/docs_test.sh` extracts flag names from *every* table under `## Parameters` and compares the set against `references/flags.md`'s `## Flags` table. A second table here would inject `worktree` and `automode` into that set and fail the parity assertion — which lives in a different section of `flags.md` by design.
- `## When to Use` — `/blacksmith-orchestrate <refs>`, "ship this milestone", "implement this plan", "fix these five issues". **Don't use** when: a single issue is in scope (use `/forge`), or no work source is given.
- A `## Step 1` and `## Step 2` section covering parse/normalize and ref materialization, each three or four sentences, delegating detail to `references/entry-routes.md`.
- A `## Scouts never interview` subsection under Step 2 stating: a scout that hits a forge Step 4 gap returns the open question rather than asking it; the orchestrator batches every task's questions into one consolidated interview attached to the Step 5 gate, in forge's proposed-answer format; under `automode` the `(Recommended)` answer is taken and the assumption recorded.

Later tasks append `## Step 3` through `## Step 9`.

- [ ] **Step 4: Create `references/entry-routes.md`**

Required content: a `## Manual verification recipe` block, then the five-row work-source table from spec §1 verbatim (refs, container, `plan`, free-form goal, `resume`), then a `## Normalization` section stating that routes may combine, that every task carries its own route, and that Step 3's routing is decided per task rather than per run. Then a `## Materializing refs` section: spec-file and free-form routes get real issue refs via `/to-issues`, or synthetic `T1..Tn` IDs when the user declines filing; a synthetic ID never reaches a tracker. Then a `## Container expansion` section naming the four trackers forge already supports and stating that expansion reuses forge's own tracker references rather than adding new fetch logic.

- [ ] **Step 5: Create `references/flags.md`**

A `## Flags` table with one row per orchestrator flag — first column the backticked name, second the effect, third a link to the owning reference file — copying the effects from spec §1 verbatim. Then a `## Forge flag pass-through` section listing the forge flags and the two overrides. Then a `## Composition rules` table with the five rules from spec §1: `strict` beats `budget`; `dry` makes `afk` and `budget` inert; `stack` reduces but does not replace `afk`; `rescout` supersedes plan-sourced dispatch for the tasks it re-scouts; `unified` and `split` are mutually exclusive and passing both is an error.

- [ ] **Step 6: Run tests to verify they pass**

Run: `sh tests/docs_test.sh`
Expected: `FAILS=0`. If the flag-table parity assertion fails, the two tables disagree — reconcile them rather than relaxing the assertion.

- [ ] **Step 7: Commit**

```bash
git add skills/blacksmith-orchestrate tests/docs_test.sh
git commit -m "feat(blacksmith): add skill skeleton, entry routes and flag matrix"
```

---

## Task 4: Step 3 — analysis routing, plan-sourced route, scout script

**Files:**
- Create: `skills/blacksmith-orchestrate/references/plan-sourced.md`, `skills/blacksmith-orchestrate/scripts/scout-fanout.mjs`
- Modify: `skills/blacksmith-orchestrate/SKILL.md` (add `## Step 3`), `tests/docs_test.sh`

**Interfaces:**
- Consumes: Task 2's `/forge plan <path>` verb; Task 3's `SKILL.md`.
- Produces: the scout return object, whose exact field names every later task depends on — `ref`, `title`, `kind`, `filesToTouch[]`, `symbols[]`, `plan`, `passCriteria`, `difficulty` (`high|medium|low`), `blastRadius` (`high|medium|low`), `declaredBlockers[]`, `openQuestions[]`, `risks[]`. Also `scripts/scout-fanout.mjs`, exporting `meta` with `name: 'blacksmith-scout-fanout'`.

- [ ] **Step 1: Write the failing assertions**

Append to `tests/docs_test.sh` before the `FAILS=` printf:

```sh
# --- blacksmith: analysis route and scout script ---
assert_file "$BS/references/plan-sourced.md" "blacksmith: plan-sourced.md exists"
assert_file "$BS/scripts/scout-fanout.mjs"   "blacksmith: scout-fanout.mjs exists"
assert_contains "$BS/references/plan-sourced.md" 'dispatch-ready' \
  "plan-sourced.md: defines the dispatch-ready check"
assert_contains "$BS/references/plan-sourced.md" 'stale' \
  "plan-sourced.md: defines the freshness guard"
if node --check "$BS/scripts/scout-fanout.mjs" 2>/dev/null; then
  pass "scout-fanout.mjs parses"
else
  fail "scout-fanout.mjs parses"
fi
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/docs_test.sh`
Expected: FAIL on all five, exit non-zero.

- [ ] **Step 3: Create `references/plan-sourced.md`**

Required content, in order:

1. `## Manual verification recipe` — two invocations and their expected outcomes: one against a fresh plan (expect zero scout agents spawned and dispatch via `/forge plan`), one against a plan naming a path that no longer exists (expect the task flagged stale on the battle plan and routed to a scout instead).
2. `## Detection order` — explicit `plan <path|glob>` argument → `docs/superpowers/plans/*.md` → `docs/superpowers/specs/*-design.md` → a plan location named by the repo's own `CLAUDE.md` / `AGENTS.md`.
3. `## Task boundaries come from the plan` — quote `writing-plans`' definition ("the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate") and state that the orchestrator does not re-decompose. Slice addressing is `<path>#<task-heading-slug>`, or the whole file for a single-task plan.
4. `## Dispatch-ready check` — the three numbered conditions from spec §3a verbatim, then the three-row degradation table (missing file list → cheap hydration grep pass for that task alone; missing pass criteria → orchestrator derives them and confirms at the gate, **never skipped** because `/goal` is a hard floor; missing scope boundary → full scout).
5. `## Plan task order is a declared dependency edge` — a plan's task list is assumed to be a blocker chain; the assumption lifts only when the plan explicitly marks tasks independent, **or** their file sets are disjoint *and* the plan's File Structure section shows no shared interface.
6. `## Freshness guard` — the three bullets from spec §3a (paths must exist; stamped base SHA or the plan file's last commit compared against current `HEAD` for those paths; any changed path flags the task **stale**, and stale tasks fall back to scouting). Close with the sentence that this is forge's `docs` stamp check applied to a set.

- [ ] **Step 4: Create `scripts/scout-fanout.mjs`**

```js
export const meta = {
  name: 'blacksmith-scout-fanout',
  description: 'Run forge Part 1 for each task in parallel and return structured proposals',
  phases: [{ title: 'Scout', detail: 'one forge Part 1 per task, stops at the gate' }],
}

const SCOUT_SCHEMA = {
  type: 'object',
  required: ['ref', 'title', 'kind', 'filesToTouch', 'symbols', 'plan',
             'passCriteria', 'difficulty', 'blastRadius', 'declaredBlockers',
             'openQuestions', 'risks'],
  properties: {
    ref: { type: 'string' },
    title: { type: 'string' },
    kind: { type: 'string', enum: ['bug', 'feature', 'chore', 'docs'] },
    filesToTouch: { type: 'array', items: { type: 'string' } },
    symbols: { type: 'array', items: { type: 'string' } },
    plan: { type: 'string' },
    passCriteria: { type: 'string' },
    difficulty: { type: 'string', enum: ['high', 'medium', 'low'] },
    blastRadius: { type: 'string', enum: ['high', 'medium', 'low'] },
    declaredBlockers: { type: 'array', items: { type: 'string' } },
    openQuestions: { type: 'array', items: { type: 'string' } },
    risks: { type: 'array', items: { type: 'string' } },
  },
}

const tasks = Array.isArray(args) ? args : []

phase('Scout')
const proposals = await parallel(
  tasks.map((t) => () =>
    agent(
      [
        `Load the forge skill and run Part 1 only (Steps 1 through 6) for ref ${t.ref}.`,
        'Stop at the Step 6 gate. Do NOT edit any file and do NOT ask the user anything.',
        'If a Step 4 required field is missing, do not interview: record the question in',
        'openQuestions and continue with your best assumption noted in risks.',
        'Return the structured proposal only.',
        t.hint ? `Context from the caller: ${t.hint}` : '',
      ].filter(Boolean).join('\n'),
      { label: `scout:${t.ref}`, phase: 'Scout', schema: SCOUT_SCHEMA },
    ),
  ),
)

const ok = proposals.filter(Boolean)
log(`scouted ${ok.length}/${tasks.length} tasks`)
return { proposals: ok, failed: tasks.length - ok.length }
```

- [ ] **Step 5: Add `## Step 3 — Analyze` to `SKILL.md`**

Content: the two-row routing table from spec §3 (3a plan-sourced, zero agent spawns; 3b scout fan-out, one forge Part 1 per task), the sentence that routing is per task and a plan covering three of five tasks scouts only the other two, a link to `references/plan-sourced.md`, and a `### Step 3b` subsection stating that the fan-out runs as one Workflow invocation using `scripts/scout-fanout.mjs`, that schema validation is enforced at the tool layer so malformed returns are retried by the runtime rather than parsed defensively, and that on a runtime without a Workflow surface the analysis runs inline and sequentially with a one-line warning.

- [ ] **Step 6: Run tests to verify they pass**

Run: `sh tests/docs_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 7: Commit**

```bash
git add skills/blacksmith-orchestrate tests/docs_test.sh
git commit -m "feat(blacksmith): add analysis routing, plan-sourced route and scout script"
```

---

## Task 5: Step 4 — collision graph

**Files:**
- Create: `skills/blacksmith-orchestrate/references/collision-graph.md`
- Modify: `skills/blacksmith-orchestrate/SKILL.md` (add `## Step 4`), `tests/docs_test.sh`

**Interfaces:**
- Consumes: Task 4's scout fields `filesToTouch`, `symbols`, `declaredBlockers`, `blastRadius`.
- Produces: the terms `hard overlap` and `soft overlap`, and the four-step orientation priority, both referenced by Tasks 6, 7 and 8.

- [ ] **Step 1: Write the failing assertions**

```sh
assert_file "$BS/references/collision-graph.md" "blacksmith: collision-graph.md exists"
assert_contains "$BS/references/collision-graph.md" 'acyclic by construction' \
  "collision-graph.md: states the acyclicity property"
assert_contains "$BS/references/collision-graph.md" 'do not prove independence' \
  "collision-graph.md: states the semantic-conflict caveat"
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/docs_test.sh`
Expected: 3 FAIL lines, exit non-zero.

- [ ] **Step 3: Create `references/collision-graph.md`**

Required content, in order:

1. `## Manual verification recipe` — two tasks whose proposals both name `src/parser.ts` and both name the symbol `parseHeader`; expect one edge, graded hard, and the dependent parked. Same two tasks with disjoint symbols; expect the edge graded soft and still serialized by default. The same soft pair re-run with `stack`; expect both dispatched in wave 1, the dependent based on the blocker's branch.
2. `## Edges` — two tasks collide when their `filesToTouch` sets intersect.
3. `## Orientation` — the four-step priority, numbered, verbatim from spec §4: declared blocker (from `declaredBlockers` or plan task order) wins; else larger blast radius first; else more files touched first; else lower ref number. Then the sentence: because orientation follows one total order, **the graph is acyclic by construction** — there is no cycle-breaking case and no deadlock detection.
4. `## Overlap grades` — the two-row table (hard: same file **and** overlapping symbols or regions → serialize, dependent parks; soft: same file, disjoint symbols → serialize by default, parallel under `stack`), then the sentence that the battle plan always states which grade produced each edge so over-serialization is visible and correctable at the gate.
5. `## Semantic conflicts` — disjoint file sets **do not prove independence**; task A can change an interface that task B's untouched file calls; no file-level graph sees this. State the defense: every worktree rebases onto the current base and re-runs its `/goal` before its PR is treated as ready — a PR is verified against the base it will land on, never the base it forked from.

- [ ] **Step 4: Add `## Step 4 — Schedule` to `SKILL.md`**

Three or four sentences: build the collision graph, apply the triage matrix, group into worktrees, emit waves. Link to `references/collision-graph.md`, `references/triage.md` and `references/scheduling.md`. The last two links will 404 until Tasks 6 and 7 land, so **write this step's prose now but add the `triage.md` and `scheduling.md` links in Task 6 and Task 7 respectively** — the link-resolution assertion would otherwise fail this task.

- [ ] **Step 5: Run tests to verify they pass**

Run: `sh tests/docs_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 6: Commit**

```bash
git add skills/blacksmith-orchestrate tests/docs_test.sh
git commit -m "feat(blacksmith): add collision graph with oriented edges and overlap grades"
```

---

## Task 6: Step 4 — triage

**Files:**
- Create: `skills/blacksmith-orchestrate/references/triage.md`
- Modify: `skills/blacksmith-orchestrate/SKILL.md` (link from Step 4), `tests/docs_test.sh`

**Interfaces:**
- Consumes: Task 4's `difficulty` and `blastRadius` fields.
- Produces: tier values `opus`, `sonnet`, `haiku` and depth values `full`, `lite`, `patch` — the exact strings Task 9's dispatch and Task 10's ledger schema use.

- [ ] **Step 1: Write the failing assertions**

```sh
assert_file "$BS/references/triage.md" "blacksmith: triage.md exists"
assert_contains "$BS/references/triage.md" 'never be assigned .`?lite' \
  "triage.md: states the blast-radius depth floor"
assert_contains "$BS/references/triage.md" 'never the only reviewer' \
  "triage.md: states the cross-model review floor"
assert_eq "$(awk '/^## Axis 1/{f=1;next} /^## /{f=0} f' "$BS/references/triage.md" \
  | grep -c '^| high\|^| medium\|^| low')" "3" \
  "triage.md: tier table has exactly three difficulty rows"
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/docs_test.sh`
Expected: 4 FAIL lines, exit non-zero.

- [ ] **Step 3: Create `references/triage.md`**

Required content, in order:

1. `## Manual verification recipe` — a one-line change to an auth check: expect `haiku × full`, never `lite` or `patch`. A multi-file parser rewrite: expect `opus × full`. A docs typo: expect `haiku × patch`.
2. An opening sentence: two independent axes that correlate but are not the same — a one-line change to an auth check is trivial to implement and catastrophic to get wrong.
3. `## Axis 1 — difficulty → model tier`, with the signals (file count, new interface vs existing pattern, algorithmic content, number of open risks) and this table verbatim:

```markdown
| Difficulty | Agent model | Under `codex impl` pass-through |
|---|---|---|
| high | Opus 5 | `gpt-5.6-sol`, effort `high` |
| medium | Sonnet 5 | `gpt-5.6-terra`, effort `xhigh` |
| low | Haiku 4.5 | `gpt-5.6-luna`, effort `xhigh` |
```

4. `## Axis 2 — blast radius → forge depth`, with the signals (user-facing surface, auth/payment/security adjacency, public API or migration, caller count of touched symbols, existing test coverage) and this table verbatim:

```markdown
| Depth | Forge steps run | Review |
|---|---|---|
| `full` | 1–12, or P + 7–12 plan-sourced | loop to convergence, normal pass cap |
| `lite` | 7, 8, 12 | one review pass, project reviewers only; skips 9, 10, 11 |
| `patch` | 7, 12 | orchestrator reads the diff itself; no reviewer subagent |
```

5. `## The four floors`, numbered 1–4, verbatim from spec §5: `/goal` verification runs at every depth (`patch` means "verified without a review loop," never "unverified"); high blast radius can never be assigned `lite` or `patch`; `secure` and `tdd` survive a depth downgrade; the implementer is **never the only reviewer** (a Haiku-implemented task is reviewed at Sonnet or above; a same-family review is at minimum a distinct agent instance; a different family is preferred where a reviewer flag makes one available).
6. `## Runtime promotion` — if a `patch` or `lite` task fails its `/goal`, or its diff escapes the file list its plan declared, promote it one depth and re-dispatch **once**, bumping the tier if the failure looks like a capability limit; a task that fails after promotion parks for the user rather than looping.

- [ ] **Step 4: Link it from `SKILL.md` Step 4**

Add the `[references/triage.md](references/triage.md)` link to the Step 4 prose written in Task 5.

- [ ] **Step 5: Run tests to verify they pass**

Run: `sh tests/docs_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 6: Commit**

```bash
git add skills/blacksmith-orchestrate tests/docs_test.sh
git commit -m "feat(blacksmith): add two-axis triage with four non-negotiable floors"
```

---

## Task 7: Step 4/6 — scheduling, and Step 5 — the battle plan

**Files:**
- Create: `skills/blacksmith-orchestrate/references/scheduling.md`, `skills/blacksmith-orchestrate/references/battle-plan.md`
- Modify: `skills/blacksmith-orchestrate/SKILL.md` (link from Step 4; add `## Step 5`), `docs/superpowers/specs/2026-08-21-blacksmith-orchestrate-design.md` (§13 file list), `tests/docs_test.sh`

**Interfaces:**
- Consumes: Task 5's overlap grades, Task 6's tier and depth values.
- Produces: the topology terms `unified` and `split`, the wave model, and the gate phrase **"yes, forge them"** — the only phrase that provisions worktrees, which Task 9 depends on.

- [ ] **Step 1: Write the failing assertions**

```sh
assert_file "$BS/references/scheduling.md"  "blacksmith: scheduling.md exists"
assert_file "$BS/references/battle-plan.md" "blacksmith: battle-plan.md exists"
assert_contains "$BS/references/scheduling.md" 'connected components' \
  "scheduling.md: components are the grouping unit"
assert_contains "$BS/references/battle-plan.md" 'yes, forge them' \
  "battle-plan.md: states the approval phrase"
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/docs_test.sh`
Expected: 4 FAIL lines, exit non-zero.

- [ ] **Step 3: Create `references/scheduling.md`**

Required content: a `## Manual verification recipe` block (four tasks, one hard edge; expect two waves and three worktrees in wave 1). Then `## Grouping` opening with "the connected components of the collision graph are the unit — tasks in different components share no files by construction", followed by the three-row topology table from spec §6 (one task → own worktree/branch/PR; two tightly-coupled same-kind tasks → unified, one worktree, sequential commits, one PR; larger → split, one worktree per task with the relay). Add the rationale sentences: unification converts an entire park → notify → merge → rebase cycle into two sequential commits; splitting is the default past two tasks because six colliding tasks in one PR is a bad review artifact. State that `unified` / `split` force the choice globally. Then `## Waves` — tasks with no unsatisfied blockers form wave 1 and dispatch in parallel up to `max` (default `4`); a task enters a later wave when every blocker it depends on has released its relay. Then `## Budget degradation ladder`, numbered 1–4 verbatim from spec §6, closing with: silent truncation is forbidden — anything deferred or downgraded is named in the close-out report.

- [ ] **Step 4: Create `references/battle-plan.md`**

Required content: a `## Manual verification recipe` block — run any multi-task invocation with `dry` and expect the battle plan emitted with no worktree created, no ledger written and no agent dispatched — then a `## Format` section containing the literal artifact block from spec §7 verbatim (the fenced `BATTLE PLAN — 4 tasks, 2 waves, split topology` example), then `## Required elements` listing: every task's ref, title, tier, depth, worktree and analysis route; every edge with its overlap grade and the exact file or symbol that produced it; the topology decision; any plan slice flagged stale; the merge-authority mode in force; anything `budget` will defer; and the consolidated interview. Then `## Approval semantics`: **"yes, forge them"** is the only phrase that provisions worktrees; an amendment (re-tier, re-depth, re-group, drop a task, or force an edge the graph missed) revises the plan and re-asks; under `automode` the gate is skipped, `(Recommended)` answers are taken and the plan is emitted as a record rather than a question; `dry` emits it and stops regardless of any other flag.

- [ ] **Step 5: Add `## Step 5 — The gate` to `SKILL.md`**

Mirror forge's Step 6 tone. State plainly: **do not create any worktree and do not dispatch any forge run until the user approves.** Link to `references/battle-plan.md`. State that `automode` is the only sanctioned bypass and that it lifts this gate exactly as it lifts forge's Step 6. Add the `scheduling.md` link to Step 4's prose.

- [ ] **Step 6: Amend the spec's file list**

In `docs/superpowers/specs/2026-08-21-blacksmith-orchestrate-design.md` §13, add to the file tree, after `scheduling.md`:

```
    battle-plan.md              # literal gate artifact format (analogue of forge's proposal-template.md)
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `sh tests/docs_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 8: Commit**

```bash
git add skills/blacksmith-orchestrate tests/docs_test.sh docs/superpowers/specs
git commit -m "feat(blacksmith): add scheduling, worktree topology and the battle-plan gate"
```

---

## Task 8: Step 8 — relay, and the `afk` floor exception

**Files:**
- Create: `skills/blacksmith-orchestrate/references/relay.md`, `skills/blacksmith-orchestrate/references/afk.md`
- Modify: `skills/blacksmith-orchestrate/SKILL.md` (add `## Step 8`), `tests/docs_test.sh`

**Interfaces:**
- Consumes: Task 7's topology decision.
- Produces: the ancestor-proof command sequence and the seven-item `afk` verify checklist, both cited by Task 11's close-out and Task 12's anti-patterns.

- [ ] **Step 1: Write the failing assertions**

```sh
assert_file "$BS/references/relay.md" "blacksmith: relay.md exists"
assert_file "$BS/references/afk.md"   "blacksmith: afk.md exists"
assert_contains "$BS/references/relay.md" 'merge-base --is-ancestor' \
  "relay.md: uses the ancestor proof"
assert_contains "$BS/references/afk.md" 'single sanctioned exception' \
  "afk.md: labels itself the sanctioned floor exception"
assert_eq "$(awk '/^## The verify checklist/{f=1;next} /^## /{f=0} f' \
  "$BS/references/afk.md" | grep -c '^[0-9]\+\.')" "7" \
  "afk.md: verify checklist has exactly seven items"
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/docs_test.sh`
Expected: 5 FAIL lines, exit non-zero.

- [ ] **Step 3: Create `references/relay.md`**

Required content: a `## Manual verification recipe` block (a blocking PR merged by squash; expect the SHA ancestor check to fail, the `git log --grep` fallback to succeed, and the relay to release). Then `## The relay` stating that the dependent is not released on the PR page's say-so, followed by this block verbatim:

```sh
git -C <dependent-worktree> fetch origin
git -C <dependent-worktree> merge-base --is-ancestor <blocker-head-sha> origin/<base>
git -C <dependent-worktree> rebase origin/<base>
```

Then: a non-ancestor result does **not** release the relay; squash-merges and rebase-merges rewrite SHAs, so the fallback proof is a `git log --grep` for the PR number on the base plus a content assertion drawn from the blocker's proposal (a symbol or line the blocker was specified to introduce); only a positive proof releases the relay. Then `## Parking` — parked is not blocked-forever; every unblocked wave keeps running while a task parks. Then `## Without a host CLI` — if `gh`/`glab` is absent or unauthenticated, no PRs are opened, components produce local branches, the ancestor proof runs against the local base branch instead of `origin/<base>`, close-out reports the branches for the user to publish, and `afk` is inert and says so.

- [ ] **Step 4: Create `references/afk.md`**

Required content, in order:

1. `## Manual verification recipe` — a blocking PR with a red CI check under `afk`; expect no merge, a notification, and the task still parked.
2. `## Default — merge authority is human` — the orchestrator notifies that a blocking PR is ready and parks; it never merges; this preserves forge's stated hard floor unchanged.
3. `## With `afk`` — notify → 5-minute quiet timeout (no user message in the session and the notification unacknowledged) → self-verify.
4. `## The verify checklist` — exactly seven numbered items, verbatim from spec §8: PR mergeable with no conflicts; CI green for the PR head SHA across all required checks; that task's forge review loop converged to zero actionable findings, read from the ledger; zero unresolved human review comments or change requests; the diff's file list is a subset of the approved proposal's file list; `/goal` verifies green in the worktree at the PR head; the base branch permits the merge.
5. A sentence: any single failure keeps the PR parked and notifies; there is no merge retry loop — the checks are re-evaluated on the next poll.
6. `## Scope limits` — `afk` merges **only PRs that block another task**; terminal PRs are always left for the user, even under `afk automode`.
7. `## Why this exception exists` — state explicitly that this is the **single sanctioned exception** to forge's no-auto-push floor, that it is opt-in and never a default, and that it is written down here so the exception is auditable rather than a quiet contradiction of the README.

- [ ] **Step 5: Add `## Step 8 — Relay` to `SKILL.md`**

Three or four sentences plus links to `references/relay.md` and `references/afk.md`. State the default (notify and park, never merge) inline, because a reader who never opens the reference must still get the floor right.

- [ ] **Step 6: Run tests to verify they pass**

Run: `sh tests/docs_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 7: Commit**

```bash
git add skills/blacksmith-orchestrate tests/docs_test.sh
git commit -m "feat(blacksmith): add relay proof and the opt-in afk merge exception"
```

---

## Task 9: Steps 6–7 — provisioning, dispatch, and the ledger

**Files:**
- Create: `skills/blacksmith-orchestrate/references/ledger.md`
- Modify: `skills/blacksmith-orchestrate/SKILL.md` (add `## Step 6`, `## Step 7`), `tests/docs_test.sh`

**Interfaces:**
- Consumes: Task 6's tier/depth strings, Task 7's `max` default and topology, Task 2's `/forge plan` verb.
- Produces: the ledger path `$(git rev-parse --git-common-dir)/blacksmith/run-<id>.json`, the task-state vocabulary `planned|provisioned|running|review|pr-open|parked|merged|done|failed`, and the ledger field names Task 11's close-out reads.

- [ ] **Step 1: Write the failing assertions**

```sh
assert_file "$BS/references/ledger.md" "blacksmith: ledger.md exists"
assert_contains "$BS/references/ledger.md" 'git rev-parse --git-common-dir' \
  "ledger.md: ledger lives under the common git dir"
for _st in planned provisioned running review pr-open parked merged done failed; do
  assert_contains "$BS/references/ledger.md" "$_st" "ledger.md: defines state $_st"
done
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/docs_test.sh`
Expected: 10 FAIL lines, exit non-zero.

- [ ] **Step 3: Create `references/ledger.md`**

Required content: a `## Manual verification recipe` block (interrupt a run after wave 1, then `resume`; expect wave-1 PRs untouched and wave 2 re-planned). Then `## Location` — `$(git rev-parse --git-common-dir)/blacksmith/run-<id>.json`, with the reason: inside `.git`, so it is shared by every linked worktree, never committed, and survives branch switches and `/compact`. Then `## Schema` containing the annotated JSON example from spec §10 verbatim. Then `## Task states` — the nine states with the transition line `planned → provisioned → running → review → pr-open → parked → merged → done`, and `failed` reachable from any running state. Then `## Resume contract` — `resume` rebuilds wave state, worktree paths and PR numbers from the ledger, but **re-verifies before continuing rather than trusting the file**: each worktree must still exist and sit on its recorded branch, and each `pr-open` task's PR state is re-fetched; a worktree that has vanished puts its task back to `planned`; resume never re-dispatches a task in `merged` or `done`.

- [ ] **Step 4: Add `## Step 6 — Provision` to `SKILL.md`**

State: create one worktree per group per the Step 4 topology, composing `superpowers:using-git-worktrees` exactly as forge's `worktree` flag does; write the ledger before dispatching anything so an interrupted run is always resumable. Link to `references/ledger.md`.

- [ ] **Step 5: Add `## Step 7 — Dispatch` to `SKILL.md`**

State: one agent per task, at the tier and depth Step 4 assigned, running in that task's worktree. A plan-sourced task is dispatched as `/forge plan <slice> <pass-through-flags>`; a scouted task is dispatched as `/forge <ref> <pass-through-flags>` with the scout's proposal supplied as the approved plan. Concurrency is capped at `max` (default `4`). Update the ledger row on every state change. Include the runtime-degradation sentence: on a runtime without a parallel agent surface, dispatch sequentially in dependency order with a one-line warning.

- [ ] **Step 6: Add `## Runtime` to `SKILL.md`**

Placed after `## Overview`. State that the skill is Claude-Code-first, degrading elsewhere in the same way forge's `codex` and `coderabbit` flags do, then this table verbatim:

```markdown
| Surface | Used for | Why |
|---|---|---|
| Workflow tool | Step 3b scout fan-out | bounded parallel fan-out, schema-validated returns, keeps N proposals out of the orchestrator's context |
| Agent tool | Step 7 implementation dispatch | per-agent model selection, and the human gates and multi-hour parks live in the main loop |
| Ledger file | Steps 6–9 state | survives `/compact`, crash and resume |
```

Close with the degradation sentence: on a non-Claude-Code runtime the skill degrades with a one-line warning to sequential forge runs in dependency order, one worktree per component, no `afk`, and inline analysis instead of a scout fan-out.

- [ ] **Step 7: Run tests to verify they pass**

Run: `sh tests/docs_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 8: Commit**

```bash
git add skills/blacksmith-orchestrate tests/docs_test.sh
git commit -m "feat(blacksmith): add worktree provisioning, dispatch, runtime table and ledger"
```

---

## Task 10: Step 9 — close-out and the hoisted forge steps

**Files:**
- Modify: `skills/blacksmith-orchestrate/SKILL.md` (add `## Step 9`), `tests/docs_test.sh`

**Interfaces:**
- Consumes: Task 9's ledger fields, Task 7's budget ladder, Task 8's park semantics.
- Produces: the hoisting rule that Task 11's anti-patterns cites.

- [ ] **Step 1: Write the failing assertions**

```sh
assert_contains "$BS/SKILL.md" '^## Step 9' "SKILL.md: has a Step 9 close-out"
assert_contains "$BS/SKILL.md" 'hoisted to the orchestrator' \
  "SKILL.md: states that forge Steps 10 and 11 are hoisted"
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/docs_test.sh`
Expected: 2 FAIL lines, exit non-zero.

- [ ] **Step 3: Write `## Step 9 — Close-out` in `SKILL.md`**

Required content: one aggregate report giving, per task, its PR or branch, final state, depth, tier and `/goal` result; every task deferred or downgraded by `budget`, named explicitly; every parked task and precisely what it waits on; and a worktree cleanup reminder per worktree. State that cleanup is **never auto-run**, inheriting forge's `worktree` rule that losing in-progress state on inferred completion is the wrong default.

Then this table verbatim, under the sentence "Two forge steps are **hoisted to the orchestrator**, because running them per task would produce N conflicting writes to the same targets:"

```markdown
| Forge step | Dispatched run does | Orchestrator does |
|---|---|---|
| Step 10 — spin-off issues via `/to-issues` | collects candidates and reports them; files nothing | dedupes across all tasks, then files once under forge's normal rules |
| Step 11 — self-evolution | reports candidate lessons; writes nothing | dedupes, and proposes a single skill, rule, guide or memory edit |
```

Then: orchestrator-level self-evolution has its own subject matter — triage misses that required runtime promotion, edges the graph over- or under-serialized, and plan slices that proved stale — and those lessons belong in `references/anti-patterns.md`. Close with: the ledger is written to its final state before the report, so a run that is reported is always a run that can be resumed or audited.

- [ ] **Step 4: Run tests to verify they pass**

Run: `sh tests/docs_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 5: Commit**

```bash
git add skills/blacksmith-orchestrate tests/docs_test.sh
git commit -m "feat(blacksmith): add close-out and hoist forge steps 10 and 11"
```

---

## Task 11: Anti-patterns

**Files:**
- Create: `skills/blacksmith-orchestrate/references/anti-patterns.md`
- Modify: `skills/blacksmith-orchestrate/SKILL.md` (trailing link), `tests/docs_test.sh`

**Interfaces:**
- Consumes: every prior task's floors.
- Produces: the canonical home for orchestration lessons, matching forge's `references/anti-patterns.md`.

- [ ] **Step 1: Write the failing assertions**

```sh
assert_file "$BS/references/anti-patterns.md" "blacksmith: anti-patterns.md exists"
assert_eq "$(grep -c '^| ' "$BS/references/anti-patterns.md")" "10" \
  "anti-patterns.md: 9 red-flag rows plus the header row"
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/docs_test.sh`
Expected: 2 FAIL lines, exit non-zero.

- [ ] **Step 3: Create `references/anti-patterns.md`**

A title, a sentence stating this file is the canonical home for lessons learned during an orchestration run, and one table with a `| Red flag | Why it is wrong |` header and exactly these nine rows, verbatim from spec §15:

| Red flag | Why it is wrong |
|---|---|
| Dispatching before battle-plan approval | The gate is the wrapper's contract, exactly as Step 6 is forge's. |
| Treating any file overlap as hard | Over-serializes; the two grades exist precisely to avoid this. |
| Merging because the PR page says green | The ancestor proof, not the PR UI, releases a relay. |
| Downgrading depth on high blast radius | Floor 2. The auth-one-liner case is the reason the axes are separate. |
| Letting the implementing model be the only reviewer | Floor 4, generalized from `codex impl`. |
| Dispatching a plan-sourced task without the freshness check | Nothing else re-validated that plan against the repo. |
| Treating disjoint file sets as proof of independence | Semantic conflicts exist; the rebase-then-`/goal` rule is the defense. |
| Auto-removing worktrees | Inherited from forge's `worktree` flag: losing in-progress state on inferred completion is the wrong default. |
| Silent truncation under `budget` | Anything deferred or downgraded must be named in the close-out. |

- [ ] **Step 4: Link it from the end of `SKILL.md`**

Add a closing `## Anti-patterns & Red Flags` section with one sentence and the link, mirroring forge's `SKILL.md` ending.

- [ ] **Step 5: Run tests to verify they pass**

Run: `sh tests/docs_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 6: Commit**

```bash
git add skills/blacksmith-orchestrate tests/docs_test.sh
git commit -m "docs(blacksmith): add orchestration anti-patterns and red flags"
```

---

## Task 12: Installer

**Files:**
- Modify: `install.sh` (`deps_table`), `tests/install_test.sh`

**Interfaces:**
- Consumes: the skill name `blacksmith-orchestrate` from Task 3.
- Produces: an install command batching both skills from one source: `npx -y skills@latest add radimsem/forge-skills -s forge -s blacksmith-orchestrate -g -y`.

Both skills ship from `$FORGE_SOURCE`, so the source-level "installed last" invariant at `tests/install_test.sh:168` and `:180` is unaffected. Only `deps_table` and its row assertions change.

- [ ] **Step 1: Write the failing assertions**

In `tests/install_test.sh`, update the inventory block (currently lines 83–92) to:

```sh
# --- inventory data (table has exactly 17 rows: 10 tier-1, 1 tier-2, 2 tier-3, 2 tier-4, 2 tier-6) ---
assert_eq "$(deps_table | grep -c '^[1-6]|')" "17" "deps_table: 17 dependency rows"
assert_eq "$(deps_table | awk -F'|' '$1==6{printf "%s ", $4}')" "forge blacksmith-orchestrate " \
  "deps_table: tier 6 is forge then blacksmith-orchestrate"
assert_eq "$(deps_table | awk -F'|' '$1==1 && $2=="skill"{c++} END{print c}')" "10" \
  "deps_table: 10 tier-1 skills (8 mattpocock incl. zoom-out + bootstrap + karpathy)"
assert_eq "$(deps_table | grep -c '^1|skill|mattpocock/skills|zoom-out$')" "1" \
  "deps_table: zoom-out present in mattpocock group"
# blacksmith-orchestrate wraps forge, so forge must precede it and be installed with it
assert_eq "$(deps_table | awk -F'|' '$2=="skill"{last=$4} END{print last}')" "blacksmith-orchestrate" \
  "deps_table: blacksmith-orchestrate is the final skill row"
assert_eq "$(skills_for_source "$FORGE_SOURCE" | tr '\n' ' ')" "forge blacksmith-orchestrate " \
  "skills_for_source: forge precedes blacksmith-orchestrate"
parse_args   # pin OPT_YES empty so the expected command is deterministic
assert_eq "$(build_skill_group_cmd "$FORGE_SOURCE" "forge blacksmith-orchestrate")" \
  "npx -y skills@latest add radimsem/forge-skills -s forge -s blacksmith-orchestrate -g" \
  "build_skill_group_cmd: batches both local skills from one source"
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/install_test.sh`
Expected: FAIL on the row count (got 16, expected 17), on tier 6, on the final skill row, and on both new assertions. Exit non-zero.

- [ ] **Step 3: Add the row to `deps_table` in `install.sh`**

In the `deps_table()` heredoc, immediately after the `6|skill|radimsem/forge-skills|forge` line:

```
6|skill|radimsem/forge-skills|blacksmith-orchestrate
```

Order matters: `skills_for_source` preserves table order, so forge is passed to `npx` first.

- [ ] **Step 4: Run tests to verify they pass**

Run: `sh tests/install_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 5: Confirm the ordering invariant still holds**

Run: `sh tests/install_test.sh | grep 'installed last'`
Expected: both `run_installs: forge source installed last` and `run_installs: forge source still last under --skills-only` report `ok`.

- [ ] **Step 6: Commit**

```bash
git add install.sh tests/install_test.sh
git commit -m "feat(install): install blacksmith-orchestrate alongside forge"
```

---

## Task 13: README and CLAUDE.md sync

**Files:**
- Modify: `README.md`, `CLAUDE.md`, `tests/docs_test.sh`

**Interfaces:**
- Consumes: Task 3's flag names, Task 12's install command.
- Produces: nothing downstream — this is the final task.

- [ ] **Step 1: Write the failing assertion**

Append to `tests/docs_test.sh` before the `FAILS=` printf:

```sh
# --- blacksmith: flags.md and the README flag table agree ---
assert_eq "$(flag_names "$BS/references/flags.md" '^## Flags')" \
          "$(flag_names "$ROOT/README.md" '^## Orchestrator flags')" \
          "blacksmith: flags.md and README flag tables agree"
```

- [ ] **Step 2: Run to verify it fails**

Run: `sh tests/docs_test.sh`
Expected: FAIL — the README has no `## Orchestrator flags` heading yet, so the second operand is empty.

- [ ] **Step 3: Add the blacksmith section to `README.md`**

After the forge **Examples** section, add `## Orchestrating many issues at once` containing: two sentences on what the skill does; the Part 1 / Part 2 diagram; an examples block:

```sh
/blacksmith-orchestrate 42 43 51 60          # four issues, scheduled by file collisions
/blacksmith-orchestrate milestone 3 automode # a whole milestone, unattended
/blacksmith-orchestrate plan docs/superpowers/plans/x.md   # straight from a written plan
```

Then a `## Orchestrator flags` heading with a table whose first column holds exactly the same eleven flag names as `references/flags.md` — the assertion in Step 1 enforces this — each with a one-line description. Add one sentence noting that every forge flag also passes through.

- [ ] **Step 4: Update `CLAUDE.md`**

Three edits:

1. In **What this repo is**, change "ships a skill, not an application" to state that the repo ships **two** skills — `forge` and its orchestration wrapper `blacksmith-orchestrate` — and that edits to `skills/**` are changes to behavior.
2. In **Commands**, add `sh tests/docs_test.sh` beside the installer suite, with one line explaining that it asserts structural invariants across the shipped prose (links resolve, flag tables agree, no placeholders, every mode file carries a verification recipe).
3. In **Architecture**, add a `skills/blacksmith-orchestrate/` subtree to the layout block mirroring the File Structure table at the top of this plan, and add a sentence to the **Conventions** section: the three-way flag sync rule now applies to both skills and is enforced by `tests/docs_test.sh`.

- [ ] **Step 5: Run the full suite**

Run: `sh tests/docs_test.sh && sh tests/install_test.sh`
Expected: `FAILS=0` from both, exit 0 overall.

- [ ] **Step 6: Commit**

```bash
git add README.md CLAUDE.md tests/docs_test.sh
git commit -m "docs: document blacksmith-orchestrate in README and CLAUDE.md"
```

---

## Verification

After Task 13, the whole deliverable is verified by:

```sh
sh tests/docs_test.sh    # structural invariants across both skills
sh tests/install_test.sh # installer inventory, ordering and command construction
```

Both must print `FAILS=0` and exit 0. A command that exits 0 without running assertions does not count as verified — confirm the `ok -` lines are present.
