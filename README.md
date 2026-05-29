<p align="center">
  <img src="assets/logo.png" alt="forge-skills logo: Claude Code as a blacksmith at an anvil" width="400">
</p>

<h1 align="center">Forge — a blacksmith for agentic workflows</h1>

<p align="center"><em>Forge an issue into a shipped fix: heat it (implement), hammer it (review), then temper it (refactor).</em></p>

## Why this exists

Most "agent does the whole task" tools have the same problem: they start editing your code before you've agreed on what they're going to do. By the time you see the plan, it's already half-built, and unwinding a wrong assumption costs more than writing the fix yourself would have.

Forge splits the work in half with a single gate in the middle. The first half reads the issue, picks the branch, gathers just enough context, and writes you a plan. Then it stops. Nothing touches the codebase until you say "yes, implement." The second half, which runs only after you approve, does the actual work: implement, review until the reviewers stop complaining, propose refactors, file any spin-off issues, and help you commit or open a PR.

If you want it to run unattended, `automode` drops the gates. Even then it will never commit, push, or write back to your tracker on its own. That floor doesn't move.

## Features

- **A plan you sign off on first.** Part 1 ends with one proposal and waits. Nothing gets edited until you say "yes, implement", so a wrong assumption costs a sentence instead of a rewrite. `automode` lifts the wait, never the no-commit-without-asking floor.
- **Re-hydration that keeps discipline fresh.** Before each implement and refactor turn, forge compacts the conversation to drop stale reviewer transcript, then re-sources the Karpathy guidelines. The clean-code rules stay loaded on every pass instead of fading as the window fills, and the compaction keeps the token bill down.
- **Self-evolution at the end of a run.** When forge hits a caveat it could have sidestepped, it offers to write the lesson back: a new skill, a rule in your agent guide, or a note in project memory. The next session starts ahead of this one. The idea comes from the Hermes agent's self-improving workflow, pointed here at whatever agent runs the skill rather than at one framework.
- **One `/goal`, verified before it ships.** Forge turns the issue's acceptance criteria into a single `/goal` at the start, so the whole run aims at the same target. Step 12 won't assemble a commit until that goal actually runs green; a command that exits 0 without running any tests counts as not done.
- **Isolated worktrees when you want them.** Pass the `worktree` flag and forge builds the fix in a sibling git worktree instead of switching your current branch in place. Your working tree stays where it is, and the run ends with a reminder to remove the worktree once you're done.
- **Flags that stack.** Test-first, a security pass, library-doc lookup, CI watching, extra reviewers. Turn on what a job needs, in any combination, in a single invocation.
- **Trackers and hosts it already speaks.** GitHub, GitLab, Jira, and Linear, plus a mode that enters straight into reviewing an existing PR. Forge follows your repo's own branch and commit conventions instead of imposing its own.
- **Not wired to one assistant.** "The agent" is whatever runtime runs the skill. The config paths, the review engine, and the interview UI all adapt to the host.

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

The installer pulls in everything forge composes (see [What forge uses](#what-forge-uses)) and installs forge last, using `npx skills` for the bare skills and `claude plugin` for the reviewer plugins. On a non-Claude-Code host, pass `--skills-only` to skip the plugin step.

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
| `tdd`, `grill-me`, `grill-with-docs`, `to-issues`, `diagnose`, `write-a-skill`, `improve-codebase-architecture`, `zoom-out` | [`mattpocock/skills`](https://github.com/mattpocock/skills) | the lifecycle steps and the `tdd`/grilling flags |
| `karpathy-guidelines` | [`forrestchang/andrej-karpathy-skills`](https://github.com/forrestchang/andrej-karpathy-skills) | re-loading clean-code discipline before each implement/refactor pass |
| `superpowers:requesting-code-review`, `superpowers:using-git-worktrees` | [`obra/superpowers`](https://github.com/obra/superpowers) | the default reviewer and the `worktree` flag |
| `codex` plugin | [`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc) | the `codex` flag (Claude Code only) |
| `coderabbit` plugin | [`coderabbitai/skills`](https://github.com/coderabbitai/skills) | the `coderabbit` flag (Claude Code only) |
| `greploop`, `check-pr` | [`greptileai/skills`](https://github.com/greptileai/skills) | the review-loop fallback |

The installer leaves a few things alone, because they belong to your environment rather than to forge. They only need to be present when you reach for the feature that depends on them. `/goal` and `/compact` come from the agent runtime. `security-review` is a Claude Code built-in that the `secure` flag calls. The context7 MCP backs the `lookup` flag, and a tracker MCP backs ticket routing: the Atlassian MCP for Jira, the Linear MCP for Linear issues. Set each up yourself, and only if you use the flag or tracker that asks for it.

## License

[MIT](LICENSE)
