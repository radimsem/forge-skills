# Contributor guidance for agents working in `0.4.0/`

If you are an agent editing files in this directory, read this before touching anything.

## Ground rules

1. **SKILL.md is not a scratchpad.** Every edit to `skills/forge/SKILL.md` MUST be justified by either:
   - an excerpt from `../docs/specs/2026-05-28-forge-redesign.md` whose roadmap unit you are implementing, **or**
   - a new ADR in `../docs/adr/` that motivates the change.

   No "small improvement" edits without one of those two artifacts. The skill is in active redesign and unanchored edits drift the spec.

2. **One atomic roadmap unit per PR.** The design doc breaks the redesign into ~24 atomic units (e.g. PR 1a, 1b, …). Each PR implements exactly one unit. Keep PRs ≤ ~400 LOC delta where you can.

3. **No version bumps mid-phase.** A phase merges across N PRs. Bump `.claude-plugin/plugin.json` `version` and rename the parent directory only when the *final* PR of a phase lands. Until then, all PRs target the in-flight version directory.

4. **No silent behavior change.** Phase 1 is structural-only — extractions must produce identical observable forge behavior on the same invocation. Phase 2+ adds flags; each new flag is opt-in and defaults off.

5. **No `.gitignore`-bypassed files.** Anything the skill references at runtime must be checked in under this version directory; otherwise installs break.

6. **Run `humanizer` on every Markdown edit.** After writing or substantially editing any `*.md` file in this version directory or `../docs/`, load the `humanizer` skill and apply it to the changed file. It strips AI-tell patterns (em-dash overuse, inflated adjectives, rule-of-three padding, passive-voice filler) without touching technical content. Code, JSON manifests, and scripts are exempt. The spec's §11 details the rule.

7. **Run `caveman` on heavy files.** When a file's body (excluding YAML frontmatter and code fences) crosses **~150 lines** OR **~6 KB**, load the `caveman` skill and use its compression principles to refactor the file in-place. Preserve link targets, file paths, command names, and code identifiers verbatim — caveman drops articles and filler, not technical tokens. The spine `SKILL.md` MUST stay under the threshold; reference files should as well. Record the pre/post `git diff --stat HEAD~1` line in the PR description.

8. **Humanizer before caveman, always.** Reversed order can re-inflate compressed prose. If both passes apply to the same file in the same PR, run humanizer first, then caveman.

## Where things live

| Need to change… | Edit… |
|---|---|
| The forge skill's spine | `skills/forge/SKILL.md` |
| Tracker-specific behavior (Jira, Linear, …) | `skills/forge/references/trackers/<name>.md` (post-Phase-1 grouping) |
| Reviewer-specific behavior (Codex, CodeRabbit) | `skills/forge/references/reviewers/<name>.md` |
| Flag/mode behavior (`tdd`, `worktree`, …) | `skills/forge/references/modes/<flag>.md` |
| Common mistakes / red-flag rules | `skills/forge/references/anti-patterns.md` |
| `automode` suppression matrix | `skills/forge/references/autonomy.md` |
| The roadmap itself | `../docs/specs/2026-05-28-forge-redesign.md` |

Files in the second column are introduced gradually by the phase that creates them; before that phase ships they don't exist yet.

## Tests

The forge skill has no automated tests today (see design doc §10). When you add a new flag, add a manual verification recipe at the top of its reference file: an exact `/forge <invocation>` and the expected observable behavior. The recipe is the acceptance test.

## When in doubt

Read the spec. The spec wins over CLAUDE.md, CLAUDE.md wins over personal preference.
