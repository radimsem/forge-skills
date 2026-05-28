# ADR 0001 — Packaged plugin layout (mirrors `andrej-karpathy-skills`)

- **Status:** Accepted
- **Date:** 2026-05-28
- **Deciders:** radimsem (skill owner)

## Context

The forge skill previously lived as a loose directory at `~/.claude/skills/forge/`. It has reached the size and complexity (350-line SKILL.md, two references, one helper script) where unmanaged editing has started causing drift: scattered `automode` rules, anti-patterns that re-prove themselves across sessions because they aren't checked in anywhere durable, and a planned redesign that needs to land across ~24 atomic units without losing coherence.

A handoff document (`/tmp/forge-redesign-handoff-2026-05-28.md`) from the prior brainstorming session locked five redesign phases. We need a working surface that can hold both the current shipping skill AND the per-phase roadmap, with version coordinates that match what Claude Code's plugin marketplace expects.

## Decision

Adopt the **packaged plugin** layout used by `multica-ai/andrej-karpathy-skills`:

```
<version>/
  .claude-plugin/plugin.json   ← manifest (name, version, skills array)
  skills/<skill-name>/SKILL.md ← skill entry point
  README.md
  CLAUDE.md
docs/specs/
docs/adr/
```

Each release is its own top-level directory whose name equals the `version` field of its `plugin.json`. Bumping the version is a directory rename + manifest edit in the same PR. The first release in this repo is `0.1.0/`.

## Alternatives considered

1. **Flat layout (no version dir).** Simpler, but loses the "old version cached for rollback" property the karpathy layout gets for free, and forces a `git tag`-only versioning story that the marketplace surface can't see.
2. **Monorepo with multiple skills at top level** (e.g. `skills/forge/`, `skills/something-else/` directly under root). Premature — we ship one skill today. The single-skill `plugin.json` already supports multiple skills via the `skills` array, so we can grow into a monorepo by adding entries, no restructure required.
3. **In-place edits to `~/.claude/skills/forge/`** (no repo). Status quo. Rejected: no PR mechanism, no rollback, no spec colocated with the skill.

## Consequences

**Positive:**
- Phased ship plan can land as one PR per atomic unit, with the spec living next to the skill it describes.
- Old versions stay readable in the repo history and the install cache; rollback is a directory rename.
- Mirrors a known-good packaging style that Claude Code's plugin tooling already understands.

**Negative:**
- Bumping versions means duplicating most files into the new version dir (mitigation: use `git mv` + `cp -r` so history follows the new path).
- Contributors must learn to edit the in-flight version directory, not the previously-shipped one. Codified in `<version>/CLAUDE.md`.

## References

- Pattern source: `~/.claude/plugins/cache/karpathy-skills/andrej-karpathy-skills/1.0.0/`
- Handoff document: `/tmp/forge-redesign-handoff-2026-05-28.md`
- First spec: `docs/specs/2026-05-28-forge-redesign.md`
