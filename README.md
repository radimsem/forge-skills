# forge-skills

> Forge an issue into a shipped fix: heat it (implement), hammer it (review), then temper it (refactor).

One skill, [`forge`](skills/forge/SKILL.md), that takes an issue, a Jira/Linear ticket, or a pull request and walks it all the way to a committed fix.

## Why this exists

Most "agent does the whole task" tools have the same problem: they start editing your code before you've agreed on what they're going to do. By the time you see the plan, it's already half-built, and unwinding a wrong assumption costs more than writing the fix yourself would have.

Forge splits the work in half with a single gate in the middle. The first half reads the issue, picks the branch, gathers just enough context, and writes you a plan. Then it stops. Nothing touches the codebase until you say "yes, implement." The second half, which runs only after you approve, does the actual work: implement, review until the reviewers stop complaining, propose refactors, file any spin-off issues, and help you commit or open a PR.

If you want it to run unattended, `automode` drops the gates. Even then it will never commit, push, or write back to your tracker on its own. That floor doesn't move.

## Install

Clone the repo and run the installer. It is detect-first and idempotent, so running it twice is safe.

```sh
git clone https://github.com/radimsem/forge-skills.git
cd forge-skills
./install.sh
```

Useful flags:

```sh
./install.sh -y              # non-interactive (auto-accept everything)
./install.sh --skills-only   # bare skills only, skip the Claude Code plugins
./install.sh --force         # reinstall even when a dependency looks present
./install.sh --help          # full option list
```

The installer pulls in everything forge composes (see [What forge uses](#what-forge-uses)) and installs forge last. It uses two mechanisms under the hood: Vercel's `npx skills` for the bare skills, and `claude plugin` for the reviewer plugins that ship agents and hooks. On a non-Claude-Code host, pass `--skills-only` and the plugin step is skipped.

Once it's installed, forge wakes up on `/forge <ref>` or any phrasing that matches the trigger in [`SKILL.md`](skills/forge/SKILL.md).

## How it works

Twelve numbered steps, split by one gate.

```
Part 1 — Gate (1–6):        classify → fetch → branch → context → propose → [GATE] approve
Part 2 — Lifecycle (7–12):  implement → review loop → refactor → spin-off → self-evolve → close
```

Part 1 is the contract. It reads the issue or ticket, works out the right branch from your repo's own conventions, reads only the files the issue actually points at (no full-tree sweep), and hands you one proposal: the problem restated, the root cause, the files it will touch, the plan, the pass criteria, and the risks. If a required detail is missing, it interviews you for it instead of guessing.

Part 2 runs on its own once you approve, and only pauses at decisions that are genuinely yours to make: whether to apply a refactor, whether to file a spin-off issue, and the final commit. The review loop repeats until there are zero actionable findings, re-loading clean-code discipline between passes. Step 12 refuses to assemble a commit until the goal you set in Step 7 actually verifies green, because shipping an unproven "done" is the one failure forge is built to prevent.

The full step-by-step contract lives in [`skills/forge/SKILL.md`](skills/forge/SKILL.md).

## Modifier flags

Flags are orthogonal and compose freely. You can stack as many as you want in one invocation. The full matrix, with conflicts and composition rules, is in [`references/flags.md`](skills/forge/references/flags.md).

| Flag | What it does |
|---|---|
| `automode` | Drops the user gates and lets the agent decide the in-between calls. Never auto-commits, auto-pushes, or writes to Jira. |
| `docs` | Works from documentation. The plan goes to `CONTEXT.md`, and grilling runs through `/grill-with-docs`. |
| `tdd` | Writes the failing test first, watches it fail, then implements. |
| `worktree` | Creates a sibling git worktree instead of switching branch in place. |
| `lookup` | Fetches current docs for every library the issue names before proposing. |
| `secure` | Adds a `security-review` pass once the normal review converges. |
| `changelog` | Drafts a changelog entry at close time, in your repo's existing format. |
| `ci-watch` | Polls CI after a push; a red result reopens the review loop. |
| `codex` / `codex challenge` | Adds Codex as a reviewer (`challenge` runs an adversarial pass). Claude Code only. |
| `coderabbit` | Adds CodeRabbit as a reviewer, with rework via `coderabbit:autofix`. Claude Code only. |

The reviewer flags add to the project's own reviewer agents rather than replacing them, and `codex` and `coderabbit` can both run in the same pass.

## Examples

```sh
/forge 42                          # GitHub/GitLab issue 42
/forge fix #123                    # same, different phrasing
/forge PROJ-123                    # Jira ticket (or Linear issue)
/forge linear ENG-42               # force Linear routing
/forge pr 47                       # review-entry mode against an existing PR diff
```

Stack flags as needed:

```sh
/forge 88 tdd secure               # test-first, with a security pass before close
/forge ticket PROJ-7 docs lookup   # plan from CONTEXT.md, fetch library docs first
/forge 15 automode codex challenge # unattended, adversarial Codex review, stops at the commit
```

The reference token can sit anywhere in the request. "solve issue 42 with tests" works as well as `/forge 42 tdd`.

## What forge uses

Forge leans on a handful of other skills and plugins, all installed for you by `./install.sh`:

| Dependency | From | Used for |
|---|---|---|
| `tdd`, `grill-me`, `grill-with-docs`, `to-issues`, `diagnose`, `write-a-skill`, `improve-codebase-architecture`, `zoom-out` | `mattpocock/skills` | the lifecycle steps and the `tdd`/grilling flags |
| `karpathy-guidelines` | `andrej-karpathy-skills` | re-loading clean-code discipline before each implement/refactor pass |
| `superpowers:requesting-code-review`, `superpowers:using-git-worktrees` | superpowers | the default reviewer and the `worktree` flag |
| `codex` plugin | `openai/codex-plugin-cc` | the `codex` flag (Claude Code only) |
| `coderabbit` plugin | claude-plugins-official | the `coderabbit` flag (Claude Code only) |
| `greploop`, `check-pr` | `greptileai/skills` | the review-loop fallback |

A few things are not installed because your host already provides them: `/goal` and `/compact`, the built-in `security-review`, and the context7 MCP that the `lookup` flag reads from. Set up context7 and your tracker's MCP (Atlassian, Linear) only if you use the flags that need them. Full detail in [`references/dependencies.md`](skills/forge/references/dependencies.md).

## Roadmap

Forge shipped through a five-phase redesign. The plan is in [`docs/specs/2026-05-28-forge-redesign.md`](docs/specs/2026-05-28-forge-redesign.md).

| Phase | Theme | Version |
|---|---|---|
| 1 | Structural split, no behavior change | 0.2.0 ✓ |
| 2 | Pre-implementation safety (`tdd`, `worktree`, `lookup`) | 0.3.0 ✓ |
| 3 | Post-implementation gates (`secure`, `changelog`, `ci-watch`) | 0.4.0 ✓ |
| 4 | Entry variants (`pr`, Linear, backport, stacked) | 0.5.0 ✓ |
| 5 | Reviewer ecosystem (`codex`, `coderabbit`) | 0.6.0 ✓ |

1.0.0 shipped after Phase 5 and a polish pass.

## Layout

```
skills/forge/
  SKILL.md          the skill contract (Steps 1–12)
  references/       the detail files each step defers to
  scripts/          helpers the skill calls
docs/
  specs/            design docs
  adr/              decision records
install.sh          the installer
```

## Contributing

One atomic PR per roadmap unit. No edits to `SKILL.md` without an ADR or a spec excerpt to back them. Current design docs are in [`docs/specs/`](docs/specs/).

## License

[MIT](LICENSE) © radimsem
