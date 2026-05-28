# forge-skills

Packaged Claude Code plugin holding the **forge** skill and its planned evolution.

Forge turns an issue or Jira/Linear ticket reference into a verified, gated proposal and then runs the full implement → review → refactor → close lifecycle, autonomously between substantive gates. See [`0.6.0/skills/forge/SKILL.md`](0.6.0/skills/forge/SKILL.md) for the current skill contract.

## Layout

Mirrors the [`andrej-karpathy-skills`](https://github.com/multica-ai/andrej-karpathy-skills) packaging pattern: each release lives in its own version directory so multiple versions can coexist in a marketplace cache and old versions remain rollback-able as directory renames.

```
0.6.0/
  .claude-plugin/
    plugin.json          ← marketplace manifest
  skills/
    forge/
      SKILL.md           ← the skill entry point
      references/        ← progressive-disclosure detail files
      scripts/           ← helper scripts called by the skill
  README.md              ← per-version notes
  CLAUDE.md              ← contributor guidance for agents in this version
docs/
  specs/                 ← design docs for upcoming changes
  adr/                   ← architecture decision records
```

The version in the directory name (`0.6.0/`) MUST match the `version` field in `0.6.0/.claude-plugin/plugin.json`. Bumping the version is a directory rename plus a manifest edit — kept atomic in a single PR.

## Roadmap

The forge skill is undergoing a five-phase redesign. The full plan is in [`docs/specs/2026-05-28-forge-redesign.md`](docs/specs/2026-05-28-forge-redesign.md):

| Phase | Theme | Target version | Atomic PRs |
|---|---|---|---|
| 1 | Structural split (no behavior change) + small fixes | 0.2.0 ✓ | 6 |
| 2 | Pre-implementation safety (`tdd`, `worktree`, `lookup`) | 0.3.0 ✓ | 5 |
| 3 | Post-implementation gates (`secure`, `changelog`, `ci-watch`) | 0.4.0 ✓ | 5 |
| 4 | Lifecycle entry variants (`/forge pr <N>`, Linear, `backport`, `stacked`) | 0.5.0 ✓ | 5 |
| 5 | Reviewer ecosystem (`coderabbit`, `coderabbit:autofix`) | 0.6.0 ✓ | 3 |

1.0.0 cuts after Phase 5 soaks.

## Install

```sh
# from a local clone
/plugin install /path/to/forge-skills/0.6.0
```

Or via a marketplace once published. Once installed the skill activates on `/forge <ref>` or any phrasing that matches the trigger described in [`0.6.0/skills/forge/SKILL.md`](0.6.0/skills/forge/SKILL.md).

## Contributing

Read [`0.6.0/CLAUDE.md`](0.6.0/CLAUDE.md) first — it codifies the contributor rules an agent working in this repo must follow (one atomic PR per roadmap unit, no SKILL.md edits without an ADR or spec excerpt, etc.).

## License

MIT.
