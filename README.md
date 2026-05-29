# forge-skills

Packaged Claude Code plugin holding the **forge** skill and its planned evolution.

Forge turns an issue or Jira/Linear ticket reference into a verified, gated proposal and then runs the full implement → review → refactor → close lifecycle, autonomously between substantive gates. See [`skills/forge/SKILL.md`](skills/forge/SKILL.md) for the current skill contract.

## Layout

```
skills/
  forge/
    SKILL.md           ← the skill entry point
    references/        ← progressive-disclosure detail files
    scripts/           ← helper scripts called by the skill
docs/
  specs/               ← design docs for upcoming changes
  adr/                 ← architecture decision records
install.sh             ← unified installer
```

## Roadmap

The forge skill is undergoing a five-phase redesign. The full plan is in [`docs/specs/2026-05-28-forge-redesign.md`](docs/specs/2026-05-28-forge-redesign.md):

| Phase | Theme | Target version | Atomic PRs |
|---|---|---|---|
| 1 | Structural split (no behavior change) + small fixes | 0.2.0 ✓ | 6 |
| 2 | Pre-implementation safety (`tdd`, `worktree`, `lookup`) | 0.3.0 ✓ | 5 |
| 3 | Post-implementation gates (`secure`, `changelog`, `ci-watch`) | 0.4.0 ✓ | 5 |
| 4 | Lifecycle entry variants (`/forge pr <N>`, Linear, `backport`, `stacked`) | 0.5.0 ✓ | 5 |
| 5 | Reviewer ecosystem (`coderabbit`, `coderabbit:autofix`) | 0.6.0 ✓ | 3 |

**1.0.0 shipped** after Phase 5 + a polish PR.

## Install

Install forge and every skill/plugin it composes with the unified installer:

```sh
git clone https://github.com/radimsem/forge-skills.git
cd forge-skills
./install.sh            # detect-first & idempotent; -y non-interactive, --skills-only for non-Claude-Code hosts
```

The installer uses two mechanisms: Vercel's `npx skills` for bare skills and `claude plugin` for
the Claude Code reviewer plugins (superpowers/codex/coderabbit). It installs forge **last**. See
[`skills/forge/references/dependencies.md`](skills/forge/references/dependencies.md) for the full
dependency list and [`docs/specs/2026-05-29-unified-dependency-install.md`](docs/specs/2026-05-29-unified-dependency-install.md)
for the design.

Once installed, the skill activates on `/forge <ref>` or any phrasing matching the trigger in
[`skills/forge/SKILL.md`](skills/forge/SKILL.md).

## Contributing

One atomic PR per roadmap unit; no SKILL.md edits without an ADR or spec excerpt. See [`docs/specs/`](docs/specs/) for current design docs.

## License

MIT.
