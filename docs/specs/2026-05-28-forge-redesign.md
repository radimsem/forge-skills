# Forge skill redesign — design spec

- **Date:** 2026-05-28
- **Status:** Draft (awaiting user review)
- **Originating handoff:** `/tmp/forge-redesign-handoff-2026-05-28.md`
- **Target layout ADR:** [`../adr/0001-packaged-plugin-layout.md`](../adr/0001-packaged-plugin-layout.md)
- **Phase 0 baseline:** the initial scaffold lived under `0.1.0/` (commit `c5bf9fc`). Phase 1 → `0.2.0/`, Phase 2 → `0.3.0/`, Phase 3 → `0.4.0/`, Phase 4 → `0.5.0/`, Phase 5 → `0.6.0/`. Current spine: [`../../0.6.0/skills/forge/SKILL.md`](../../0.6.0/skills/forge/SKILL.md).

## 1. Context and decisions locked from prior session

The previous brainstorming session (in `/home/radimsem/personal/projects/mempathy/`) reached the following decisions, which this spec **inherits without re-litigating**:

| Decision | Locked value |
|---|---|
| Scope | All four feature categories: pre-implementation safety, post-implementation gates, lifecycle entry variants, reviewer ecosystem expansion |
| Approach | **Phased rollout (Approach B)** — not monolithic (A), not flag-additive-only (C) |
| Phase count | 5 (see §6) |
| Spec ownership | This document supersedes the abandoned `mempathy/docs/superpowers/specs/2026-05-28-forge-redesign-design.md` draft (which never landed); the canonical home is now this repo |

What this spec adds on top of the handoff:
- Concrete **repo-as-project** model (this repo, karpathy-style packaging — see §2).
- A complete **atomic roadmap** breaking each phase into individually-shippable PRs (§8) — the handoff sketched ~6 atomic units for Phase 1; this spec extends that across all 5 phases (~24 units total).
- Explicit **versioning policy** mapping phases to minor version bumps (§9).

## 2. Repo-as-project model

This repository (`forge-skills`) is the source of truth for the forge skill. It mirrors the [`andrej-karpathy-skills`](https://github.com/multica-ai/andrej-karpathy-skills) packaging convention: each shipped version lives in its own top-level directory.

```
forge-skills/
  <version>/                   ← currently 0.6.0 (Phase 5 complete; pre-1.0); originally 0.1.0
    .claude-plugin/plugin.json
    README.md
    CLAUDE.md
    skills/forge/
      SKILL.md
      references/
        anti-patterns.md
        autonomy.md
        proposal-template.md
        review-loop.md
        trackers/jira.md
        reviewers/codex.md
      scripts/resolve-codex.py
  docs/
    specs/2026-05-28-forge-redesign.md     ← this file
    adr/0001-packaged-plugin-layout.md
```

Each phase merges into a new sibling version directory (`0.2.0/`, `0.3.0/`, …). The old version directory stays in place for the lifetime of the cache / for rollback. Cleanup of older versions is a separate housekeeping concern.

## 3. File & directory architecture (target state after Phase 5)

```
0.6.0/skills/forge/
  SKILL.md                          ← slim spine, ~150 lines (see §4)
  references/
    flags.md                        ← all 13 flags, composition rules, conflicts (Phase 2 creates; later phases extend)
    autonomy.md                     ← unified `automode` suppression matrix (Phase 1)
    anti-patterns.md                ← Common Mistakes + Red Flags + encoded learnings (Phase 1)
    proposal-template.md            ← Step 5 proposal layout + Step 4 interview Q format (Phase 1)
    review-loop.md                  ← Step 8 engine selection, 3-pass cap, reviewer matrix (Phase 1; reviewer matrix grows through Phase 5)
    trackers/
      jira.md                       ← (existing, moved into subdir in Phase 1)
      linear.md                     ← Phase 4
    reviewers/
      codex.md                      ← (existing, moved into subdir in Phase 1)
      coderabbit.md                 ← Phase 5
    modes/
      tdd.md                        ← Phase 2
      worktree.md                   ← Phase 2
      lookup.md                     ← Phase 2
      secure.md                     ← Phase 3
      changelog.md                  ← Phase 3
      ci-watch.md                   ← Phase 3
      backport.md                   ← Phase 4
      stacked.md                    ← Phase 4
      pr-entry.md                   ← Phase 4 (entry-mode variant)
  scripts/
    resolve-codex.py                ← (existing)
```

**Grouping rationale.** Sub-directories under `references/` are organized by *concern* (`trackers/`, `reviewers/`, `modes/`) rather than kept flat. The handoff's Section 1 sub-question 1 asked whether to group or flatten; this spec picks grouping because (a) the count of reference files grows from 2 to ~16, past the threshold where a flat list becomes hard to scan; (b) the conceptual buckets are stable — trackers are *where issues live*, reviewers are *who critiques the diff*, modes are *what the flag changes about lifecycle behavior* — so the grouping is unlikely to need refactoring later.

**Granularity rationale.** The handoff's sub-question 3 asked whether to fold some reference files into one (e.g. `post-review-stages.md` collapsing refactor/spinoff/self-evolution). This spec keeps them separate: each Step in SKILL.md should be cited to a single file so the reader of any step has one obvious place to deepen. Folding hides the contract.

## 4. Slim SKILL.md skeleton (Section 2 from handoff)

Target for the post-Phase-1 `SKILL.md` (~150 lines):

```
---
name: forge
description: ...  (updated to mention new flags as they ship)
---

# Forge
> Tagline.

## Overview
  - Two-part structure (gate / lifecycle), one numbered workflow 1–12.

## Parameters
  - One-line summary per flag pointing at references/flags.md.
  - Target grammar table (bare-number / key-shape / `ticket` keyword / new `pr` keyword).

## When to use / Don't use

## Steps 1–12
  - One paragraph each, pointing at the relevant reference.
  - Step 6 (the Gate) stays full-length verbatim — it is the hard contract.

## Autonomy
  - Three-line summary pointing at references/autonomy.md for the full matrix.
```

What **migrates out of SKILL.md**:
- Full `Common Mistakes` table → `references/anti-patterns.md`
- Full `Red Flags` list → `references/anti-patterns.md`
- Scattered `automode` suppression notes (currently in §Autonomy, §6, §12, §4a) → `references/autonomy.md`
- Full Step 5 proposal template → `references/proposal-template.md`
- Full Step 8 engine matrix + 3-pass cap discussion → `references/review-loop.md`
- Step 1b host-CLI table → stays in SKILL.md (small enough; high signal at routing time)
- Step 12 closing menu → stays in SKILL.md (six lines, decision-critical)

What **stays in SKILL.md verbatim**:
- §6 The Gate (the hard contract; must be locatable without a pointer)
- Step 7 opening (the `/goal` set + karpathy re-source ordering; hard ordering)
- The `Re-hydrate block ⟲` definition (referenced from multiple steps)

## 5. Extended flag matrix (Section 3 from handoff)

Post-Phase-5 the parameter line becomes:

```
/forge <ref> [automode] [docs] [codex | codex challenge | coderabbit]
             [tdd] [worktree] [lookup] [secure] [changelog]
             [ci-watch] [backport] [stacked]
```

Plus the new entry verb `/forge pr <N>` (Phase 4).

| Flag | Phase introduced | Effect |
|---|---|---|
| `automode` | 0 (existing) | No user gates; auto-decide 9/11; never auto-commits/pushes/Jira-writes |
| `docs` (was `with docs`) | 1 (rename + alias) | Source plan from `CONTEXT.md`; Step 12 proposal → `/tmp/forge-<ref>.md` |
| `codex` | 0 (existing) | Generic reviewer → Codex (`scripts/resolve-codex.py`); CC-only |
| `codex challenge` | 0 (existing) | Codex `review` → `adversarial-review`; implies `codex` |
| `tdd` | 2 | Compose `superpowers:test-driven-development` before Step 7; observe failing test before implementation |
| `worktree` | 2 | Compose `superpowers:using-git-worktrees` at Step 3 instead of a switch-in-place branch |
| `lookup` | 2 | Compose `find-docs` (and `context7` MCP if available) at Step 4 for library-specific facts |
| `secure` | 3 | Compose `security-review` skill after Step 8 convergence; findings re-enter Step 8 as must-fix |
| `changelog` | 3 | At Step 12, draft a changelog entry per repo convention; ship in the same proposed commit list |
| `ci-watch` | 3 | After Step 12 push, poll CI; report green/red; on red, re-enter Step 8 with the failure as a finding |
| `backport` | 4 | At Step 12, cherry-pick the merged commits onto additional base branches the user specifies |
| `stacked` | 4 | Step 3 branches off another in-flight PR's HEAD; Step 12 push targets the stacked-PR convention |
| `coderabbit` | 5 | Generic reviewer → CodeRabbit (`coderabbit:code-review`); CC-only; **XOR with `codex`** |

### Composition rules

| Rule | Why |
|---|---|
| `codex` and `coderabbit` are mutually exclusive | Both replace the generic reviewer slot — picking both is ambiguous; fail fast with a one-line error |
| `codex challenge` implies `codex` | Already the case; preserved |
| `ci-watch` requires Step 12 push option | Polling without a published target is pointless; silently skip if user picked the non-push Step 12 option |
| `backport` requires Step 12 push option | Same reasoning |
| `stacked` + `worktree` compose freely | Worktree is the recommended scaffold for stacked PR work |
| `automode` does NOT lift `tdd`'s "observe failing test" rule | TDD discipline is the point of the flag; under `automode` the agent itself runs the test and confirms red before writing the fix |
| `/forge pr <N>` ignores all lifecycle flags except `automode` and reviewer flags | PR-review mode skips Step 7 implementation; only Step 8 reviewer engines and the automode "no gates" property apply |

### Conflicting-flag handling

On invocation parse, if two mutually exclusive flags are present, abort before Step 1 with:
```
Error: flags `<a>` and `<b>` cannot be combined. <reason>.
```
No silent precedence — the user must re-invoke. This is the safest behavior because the consequences of guessing wrong (running the wrong reviewer) are non-trivial.

## 6. Per-phase content overview (Section 4 from handoff)

### Phase 1 — Structural split (target 0.2.0, no behavior change)
- Extracts six reference files from SKILL.md (`anti-patterns.md`, `autonomy.md`, `proposal-template.md`, `review-loop.md`, plus subdir moves for `trackers/jira.md` and `reviewers/codex.md`).
- Renames the `with docs` flag → `docs`. Keeps `with docs` as an alias for one release (0.2.0); removes the alias in 0.3.0 with a note in `anti-patterns.md`.
- Encodes the trim-only-fix learning from the prior session's auto-memory: *after a clean Codex pass, a fix that only trims (deletes/condenses) does not require a Step 8 rerun*. Lands as an entry in `references/anti-patterns.md`.
- SKILL.md drops from ~350 lines to ~150.

### Phase 2 — Pre-implementation safety (target 0.3.0)
- Adds three flags: `tdd`, `worktree`, `lookup`. Each composes an existing user-installed skill at a different Step.
- Creates `references/flags.md` (initialized with all 13 future flags as table; modes section populated as flags land).
- Adds the per-flag anti-patterns: implementing before observing failure (tdd), forgetting worktree cleanup at Step 12 (worktree), relying on training data over current docs (lookup).

### Phase 3 — Post-implementation gates (target 0.4.0)
- Adds three flags: `secure`, `changelog`, `ci-watch`. All operate at or after Step 8/12.
- Updates `references/autonomy.md` with the gate-suppression rules: `secure` findings are must-fix (no automode auto-acceptance); `changelog` runs auto under automode (boilerplate); `ci-watch` polls without user gates by definition.

### Phase 4 — Lifecycle entry variants (target 0.5.0)
- New entry verb `/forge pr <N>` for review-existing-PR mode. Skips Steps 4–7; enters Step 8 directly against the PR's diff.
- New tracker: Linear. Same key-shape regex as Jira (`[A-Z]+-\d+`) — on overlap, ask which tracker. Both can be installed simultaneously.
- New flags `backport` and `stacked`. Both modify Step 12 only.

### Phase 5 — Reviewer ecosystem (target 0.6.0)
- Adds `coderabbit` flag (generic-reviewer swap) and the `coderabbit:autofix` rework path (parallel to §8b's `codex:codex-rescue`).
- Final pass on `references/review-loop.md`: full reviewer matrix (built-in `superpowers:requesting-code-review` / `codex` / `coderabbit`), rework-path table, when-to-use heuristics.

## 7. Anti-patterns + encoded learnings (Section 5 from handoff)

`references/anti-patterns.md` consolidates and extends what is today scattered between SKILL.md's "Common Mistakes" + "Red Flags" sections and external memory.

**Inherited from current SKILL.md:** 22 Common Mistakes rows + 12 Red Flags lines.

**New entries (introduced in their respective phase PRs):**

| Rule | Introduced in | Trigger |
|---|---|---|
| Trim-only-fix after a clean Codex pass skips Step 8 rerun | Phase 1 (PR 1b) | From mempathy `feedback_forge_review_loop.md` |
| TDD: implementing before observing the test fail | Phase 2 | New flag `tdd` |
| Worktree: leaving the worktree behind at Step 12 | Phase 2 | New flag `worktree` |
| Lookup: relying on training data instead of fetching | Phase 2 | New flag `lookup` |
| Secure: running security-review as last check rather than during the loop | Phase 3 | New flag `secure` |
| Changelog: writing the entry before `/goal` verifies green | Phase 3 | New flag `changelog` |
| CI-watch: polling without a published PR | Phase 3 | New flag `ci-watch` |
| Backport: cherry-picking before main branch is green | Phase 4 | New flag `backport` |
| Stacked: re-baseing wrong and clobbering the base PR's commits | Phase 4 | New flag `stacked` |
| CodeRabbit + Codex in the same loop | Phase 5 | New flag `coderabbit` (XOR with `codex`) |

## 8. Atomic implementation roadmap (Section 6 — the meat)

Each unit ships as one PR. Target ≤ ~400 LOC delta per PR. Acceptance criteria for every PR include: (a) installs cleanly, (b) one named `/forge` invocation exercises the new path or proves the old path is unchanged, (c) the two §11 content-style passes (humanizer on all changed Markdown, caveman on any file that crossed the heavy-file threshold) have been run and recorded in the PR description.

### Phase 0 — Repo scaffold (single PR)

| PR | Title | Deliverables |
|---|---|---|
| 0a | Plugin scaffold + Phase 0 baseline | `0.1.0/.claude-plugin/plugin.json`, READMEs, CLAUDE.md, verbatim copy of pre-redesign forge skill, this spec, ADR 0001 |

### Phase 1 — Structural split (target 0.2.0, no behavior change)

| PR | Title | Touches | Notes |
|---|---|---|---|
| 1a | Extract Common Mistakes + Red Flags | New `references/anti-patterns.md`; SKILL.md sheds ~60 lines | Pure extraction; identical text relocated |
| 1b | Encode trim-only-fix rule | `references/anti-patterns.md` (+1 row) | The MEMORY learning becomes durable |
| 1c | Centralize automode matrix | New `references/autonomy.md`; SKILL.md scattered notes → one section + a pointer | Source the four scattered locations into one table; SKILL.md keeps only the 3-line summary |
| 1d | Extract proposal + interview templates | New `references/proposal-template.md`; SKILL.md Step 4/5 condensed | Step 4 keeps the proposed-answer-format reminder; full Q1/Q2 example moves out |
| 1e | Extract Step 8 review-loop spec | New `references/review-loop.md`; SKILL.md Step 8 → short orchestration paragraph + pointer | §8a/§8b text already in `references/codex.md`; only the matrix moves |
| 1f | Regroup references + rename `with docs` → `docs` | Move `references/jira.md` → `references/trackers/jira.md`; `references/codex.md` → `references/reviewers/codex.md`; update SKILL.md pointers; accept both flag spellings; bump version 0.1.0 → 0.2.0 (directory rename) | Final PR of Phase 1; the only PR that bumps the version dir |

### Phase 2 — Pre-implementation safety (target 0.3.0)

| PR | Title | Touches |
|---|---|---|
| 2a | Add `tdd` flag | New `references/modes/tdd.md`; new `references/flags.md` with flag matrix; SKILL.md Step 7 honors flag |
| 2b | Add `worktree` flag | New `references/modes/worktree.md`; SKILL.md Step 3 + Step 12 cleanup |
| 2c | Add `lookup` flag | New `references/modes/lookup.md`; SKILL.md Step 4 |
| 2d | Extend anti-patterns for Phase 2 flags | `references/anti-patterns.md` (+3 rows) |
| 2e | Extend autonomy matrix + bump version 0.2.0 → 0.3.0 | `references/autonomy.md`; directory rename |

### Phase 3 — Post-implementation gates (target 0.4.0)

| PR | Title | Touches |
|---|---|---|
| 3a | Add `secure` flag | New `references/modes/secure.md`; SKILL.md Step 8 |
| 3b | Add `changelog` flag | New `references/modes/changelog.md`; SKILL.md Step 12 |
| 3c | Add `ci-watch` flag | New `references/modes/ci-watch.md`; SKILL.md Step 12 |
| 3d | Extend anti-patterns for Phase 3 flags | `references/anti-patterns.md` (+3 rows) |
| 3e | Extend autonomy + flags + bump 0.3.0 → 0.4.0 | `references/autonomy.md`, `references/flags.md`; directory rename |

### Phase 4 — Lifecycle entry variants (target 0.5.0)

| PR | Title | Touches |
|---|---|---|
| 4a | Add `/forge pr <N>` entry mode | New `references/modes/pr-entry.md`; SKILL.md Parameters + Step 1 routing |
| 4b | Add Linear tracker | New `references/trackers/linear.md`; SKILL.md Step 1 grammar (Jira/Linear disambiguation) |
| 4c | Add `backport` flag | New `references/modes/backport.md`; SKILL.md Step 12 |
| 4d | Add `stacked` flag | New `references/modes/stacked.md`; SKILL.md Step 3 + Step 12 |
| 4e | Extend anti-patterns + autonomy + flags + bump 0.4.0 → 0.5.0 | All three references; directory rename |

### Phase 5 — Reviewer ecosystem (target 0.6.0)

| PR | Title | Touches |
|---|---|---|
| 5a | Add `coderabbit` flag | New `references/reviewers/coderabbit.md`; SKILL.md Step 8 + XOR validation with `codex` |
| 5b | Add `coderabbit:autofix` rework path | `references/reviewers/coderabbit.md` (§autofix); SKILL.md §8b parallel branch |
| 5c | Final reviewer matrix + bump 0.5.0 → 0.6.0 | `references/review-loop.md` (full matrix); `references/anti-patterns.md` (+1); directory rename |

**Totals:** 1 (Phase 0) + 6 (Phase 1) + 5 (Phase 2) + 5 (Phase 3) + 5 (Phase 4) + 3 (Phase 5) = **25 atomic PRs**.

## 9. Versioning policy

| Event | Version action |
|---|---|
| First scaffold | `0.1.0` (this commit) |
| Final PR of each phase | Minor bump (e.g. `0.1.0` → `0.2.0`) via directory rename + `plugin.json` edit |
| Bug fix mid-phase | Patch bump optional; default is no bump until phase ends |
| Phase 5 final + post-soak | Cut `1.0.0` |
| Breaking flag rename or removal after 1.0 | Major bump |

The version field in `plugin.json` is the source of truth; the directory name MUST match. Mismatch is a release-blocker the CI (when we add it) will check.

## 10. Open questions / risks

- **No automated tests.** The forge skill is observed-behavior, not unit-tested. Each new flag's reference file includes a one-line manual verification recipe (`/forge <ref> <flag>` + expected behavior). Investing in a synthetic-invocation test harness is deferred to post-1.0; not blocking.
- **Cross-flag combinatorics.** 13 flags = 78 pairs. We do not validate the full matrix; we only enumerate *blocked* pairs in `references/flags.md`. Risk: a silently-broken pair ships. Mitigation: each phase PR adds the new flag's pair-interactions with already-shipped flags as anti-patterns table rows.
- **MEMORY.md sync.** The trim-only-fix rule lives in `mempathy`'s auto-memory today. After PR 1b lands it in `references/anti-patterns.md`, the memory entry stays (it's per-project context); the reference is canonical for the skill itself.
- **`docs` flag rename.** Two-release alias window (0.2.0 ships both; 0.3.0 removes `with docs`). Users who scripted `with docs` get one minor cycle to migrate. If real users complain, extend the alias by one more minor.
- **`/forge pr <N>` overlap with `/check-pr` and `/review`.** Document the boundary in `references/modes/pr-entry.md` (Phase 4): `pr-entry` runs the full forge reviewer pipeline against an existing PR, while `/check-pr` and `/review` are lighter-weight single-pass reviewers. If users find the boundary fuzzy, consider deprecating one of the lighter commands in favor of `/forge pr`.

## 11. Content style and token-budget guardrails

Every PR that creates or substantially edits a Markdown file under the current version directory's `skills/forge/`, `docs/specs/`, `docs/adr/`, or the repo READMEs follows two standing post-write passes, applied in this order:

1. **Humanize the prose.** Load `humanizer` and apply it to the changed Markdown. The skill removes the patterns enumerated in the Wikipedia "Signs of AI writing" guide: inflated symbolism, promotional adjectives, em-dash overuse, rule-of-three list padding, vague attribution, passive-voice filler, negative parallelism, AI vocabulary tells. Code (`scripts/*.py`, JSON manifests) is exempt. Apply judgement on the design spec itself and ADRs — they describe technical intent and tolerate a denser register than user-facing READMEs do.

2. **Compress if heavy.** If a file's body (excluding YAML frontmatter and fenced code blocks) crosses **~150 lines** OR **~6 KB**, load `caveman` and use its compression principles to refactor the prose in-place: drop filler, articles, pleasantries; keep all technical substance; preserve link targets, file paths, command names, and code identifiers **verbatim**. The threshold is a soft trigger — apply judgement when a file is right at the border. Reference files for a single flag should rarely cross it; the spine `SKILL.md` MUST stay under it (§4 target ~150 lines).

Both passes are *idempotent* and *content-preserving*. If a humanize or caveman pass would change technical meaning (drop a clause that carries a constraint, condense a list that hides a step), do not commit that change — refine the source instead.

The PR description for each unit named in §8 records which files crossed which threshold, along with the post-pass `git diff --stat HEAD~1` line so reviewers can confirm the compression actually happened.

Caveman is normally a *communication mode* for chat. Here it is repurposed as a *refactor lens* applied to file contents — load the skill, follow its compression rules, write the result back to the file. This is a slight deviation from the skill's default usage; flag it once in the PR description rather than embedding the explanation in every commit message.

## 12. Transition

On user approval of this spec, the next step is `superpowers:writing-plans` against this document. `writing-plans` produces the executable plan that `superpowers:executing-plans` will then drive PR-by-PR. **No other skill** is invoked between brainstorming and writing-plans — the brainstorming terminal-state rule binds.
