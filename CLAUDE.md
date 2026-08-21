# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This repo **ships two skills, not an application.** The primary deliverable is `forge` — an agent-runtime-agnostic skill that turns an issue/ticket/PR reference into a shipped fix through a gated 12-step workflow. Alongside it, `blacksmith-orchestrate` is forge's orchestration wrapper: it takes several issues, a milestone, or a written plan, decides which of them collide and which can run in parallel, then dispatches one ordinary forge run per task. "The code" is the prose in each skill's markdown; the only executable is the installer.

Because the artifact is instructions an agent reads and follows, edits to `skills/**` are changes to behavior. Treat wording with the same care as code: a sentence in `SKILL.md` is a contract the running agent will obey literally.

## Commands

Everything lives in POSIX `sh`; there is no package manager, build step, or linter config.

```sh
sh tests/install_test.sh          # run the installer unit suite
sh tests/docs_test.sh             # run the structural-invariants suite across both skills' prose
sh tests/install_test.sh | grep FAIL   # quick check for failures; exits non-zero if FAILS>0
sh install.sh -h                  # see installer usage
```

- `tests/install_test.sh` sources `install.sh` with `INSTALL_SH_SOURCED=1`, which is the guard that prevents `main()` from running on source (see the bottom of `install.sh`). This lets the suite unit-test individual functions (`parse_args`, `build_skill_group_cmd`, `run_installs`, …) by stubbing `npx`/`claude`.
- `tests/docs_test.sh` asserts structural invariants across the shipped prose for both skills: relative markdown links resolve, the flag tables agree across `SKILL.md`/`references/flags.md`/`README.md`, no `TBD`/`TODO`/`FIXME` placeholders remain, and every `references/modes/*.md` (forge) or `references/*.md` (blacksmith-orchestrate) file carries a manual verification recipe.
- There is no single-test selector; each suite is one script. To isolate a check, comment out the others or add a temporary `assert_*` near the function under test.
- `shellcheck` is not configured or installed here, but the scripts are written to pass it — keep new shell POSIX-clean (no bashisms).

## Architecture

### Progressive disclosure (the core pattern)

`skills/forge/SKILL.md` is the **single entry point and master workflow**. It stays deliberately terse and **delegates details to `references/` files that the agent loads only when a step or flag needs them.** This mirrors the discipline forge imposes on its own runs (Step 4: never sweep the whole codebase). When editing, preserve this split — put step-level contract in `SKILL.md`, put the expandable detail in the matching reference, and link to it rather than inlining.

```
skills/forge/
  SKILL.md                  # 12-step workflow + Parameters/flag table + When-to-Use
  references/
    flags.md                # canonical flag matrix, composition + conflict rules
    autonomy.md             # per-step gate matrix; automode hard floors
    proposal-template.md    # literal block formats for Steps 4, 5, 12
    review-loop.md          # Step 8 engine selection, /greploop fallback, pass discipline
    anti-patterns.md        # common-mistakes table + red-flag stop list (canonical home for new lessons)
    mistakes.md, red-flags.md
    modes/                  # one file per behavioral flag: tdd, worktree, lookup, secure,
                            #   changelog, ci-watch, pr-entry
    reviewers/              # one file per pluggable Step 8 reviewer: codex, coderabbit
    trackers/               # one file per issue source: github, gitlab, jira, linear
  scripts/resolve-codex.py  # resolves the Codex review invocation for the `codex` flag

skills/blacksmith-orchestrate/
  SKILL.md                  # 9-step workflow + Parameters/orchestrator-flag table + When-to-Use
  references/
    flags.md                # orchestrator flag matrix, composition + conflict rules
    entry-routes.md         # the five work-source routes, normalization, container expansion
    triage.md                # two-axis triage (difficulty tier, blast-radius depth) + the four hard floors
    collision-graph.md      # file/declared/plan-order edges, acyclicity, worktree-grouping input
    scheduling.md            # connected components, wave assignment, budget degradation ladder
    battle-plan.md           # Step 5 gate artifact format and approval phrase
    plan-sourced.md          # Step 3a dispatch-ready check and the freshness guard
    relay.md                 # Step 8 ancestor proof, rebase-then-release sequence
    afk.md                   # the single sanctioned floor exception + its 7-item verify checklist
    ledger.md                # run-state schema, task-state vocabulary, resume contract
    anti-patterns.md         # canonical home for orchestration-level lessons
  scripts/scout-fanout.mjs  # Workflow tool driving the Step 3b scout fan-out
```

### The workflow's shape

One numbered workflow split by a single gate (`SKILL.md` is authoritative):

```
Part 1 — Gate (Steps 1–6):   classify → fetch → branch → context → propose → [GATE] approve
Part 2 — Lifecycle (7–12):   implement → review-loop → refactor → spin-off → self-evolve → close
```

- **The gate (Step 6) is the most important invariant.** Nothing touches the codebase until the user says "yes, implement". `automode` is the *only* sanctioned bypass, and even it never auto-commits, auto-pushes, or writes back to a tracker. If you change anything in Part 1, do not weaken this contract.
- **`/goal` verification (Step 12)** is the other hard floor: forge refuses to assemble a commit until the goal set in Step 7 verifies green. A command exiting 0 without running tests counts as *not done*.
- **Flags are orthogonal and compose.** They are parsed from anywhere in the invocation. Each flag's behavior is owned by exactly one file under `references/modes/` or `references/reviewers/`; `flags.md` holds the matrix. When adding/changing a flag, update both `SKILL.md`'s flag list **and** the owning reference, and keep the README's flag table in sync.

### Runtime-agnostic by design

"The agent" means whatever runtime runs the skill — config paths, the review engine, and the interview UI all adapt to the host. Do **not** hardcode Claude-Code-specific paths or assumptions into the general workflow. The two reviewer flags (`codex`, `coderabbit`) are explicitly Claude-Code-only and degrade with a one-line warning elsewhere; that's the model for any host-specific feature.

### The installer

`install.sh` installs every external skill/plugin forge composes (see the "What forge uses" table in `README.md`), then installs forge **last**. Key invariants the test suite enforces:

- forge is always the final skill installed (`run_installs` orders the `.` source last).
- With no `--agents`, **no `-a` flags are emitted** so `npx skills` auto-detects the host's agents — passing a hardcoded agent list installs onto agents the user may not have.
- Detection is idempotent: present skills/plugins are skipped unless `--force`. A second run is safe.
- `deps_table` is the single source of truth for what gets installed; the suite asserts its exact row count and tiering, so adding a dependency means updating that table **and** the corresponding assertion in `tests/install_test.sh`.

## Conventions

- **Keep `SKILL.md`, `README.md`, and `references/flags.md` consistent.** The flag list and behaviors appear in all three; they must not drift. The same three-way sync rule applies to `blacksmith-orchestrate`'s orchestrator flags, and `tests/docs_test.sh` enforces both skills' flag tables mechanically rather than relying on review alone.
- New lessons learned during a forge session belong in `references/anti-patterns.md` (its stated canonical home), not scattered into `SKILL.md`.
- When listing files an agent should touch, the skill's own rule applies to edits here too: verify paths exist before referencing them, and drop `:line` suffixes for files you haven't opened.
