<p align="center">
  <img src="assets/logo.png" alt="forge-skills logo: Claude Code as a blacksmith at an anvil" width="400">
</p>

<h1 align="center">Forge</h1>

<p align="center">Plan, implement, and review issues with an agent</p>

<p align="center"><em>See the plan before the agent changes your code.</em></p>

## Why this exists

An agent can start editing before you have agreed on the approach. If its first assumption is wrong, reviewing a half-finished fix takes more work than correcting a plan.

Forge reads the issue, checks the branch and relevant code, and shows you a plan. It waits for "yes, implement" before changing implementation files. After approval, it implements the fix, runs reviews, proposes refactors and related issues, and prepares a commit or PR for your decision. With the `docs` flag, it saves the proposal to `CONTEXT.md` before approval.

Use `automode` to skip the approval pauses. It still stops before committing, pushing, or writing back to the source ticket.

## Features

- **Approval before implementation.** Forge shows one proposal and waits for your decision unless you use `automode`.
- **Review until findings are resolved.** Forge reloads its coding guidelines between review and refactor passes, and keeps the issue's acceptance criteria in one `/goal`. It verifies that goal before preparing a commit.
- **A place for lessons learned.** Forge can propose a skill, agent-guide rule, or project-memory note after a run. The default run asks before saving it; `automode` makes that decision itself.
- **Optional worktree isolation.** The `worktree` flag puts the fix in a sibling git worktree and leaves your current checkout on its branch.
- **Flexible scope.** Add test-first work, current library docs, a security pass, CI watching, or extra reviewers with modifier flags.
- **Tracker and runtime support.** Forge handles GitHub, GitLab, Jira, Linear, and existing PRs. It follows your repository's branch and commit conventions and adapts to the agent runtime.

## Install

Run the installer. It skips dependencies already present, so you can run it again.

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/radimsem/forge-skills/main/install.sh)"
```

Pass flags after a `--`. A fully non-interactive run, for example:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/radimsem/forge-skills/main/install.sh)" -- -y
```

The full set:

```
-y, --yes        non-interactive (auto-accept everything)
--skills-only    bare skills only, skip the Claude Code plugins
--force          reinstall even when a dependency looks present
--agents "a,b"   install onto specific agents (default: auto-detect your installed agents)
-h, --help       full option list
```

The installer pulls in everything forge composes (see [What forge uses](#what-forge-uses)) and installs forge last, using `npx skills` for the bare skills and `claude plugin` for the reviewer plugins. On a non-Claude-Code host, pass `--skills-only` to skip the plugin step.

Once installed, run `/forge <ref>` or ask the agent to resolve a specific issue. The full trigger is in [`SKILL.md`](skills/forge/SKILL.md).

## How it works

Forge has twelve steps and one approval gate.

1. **Plan (steps 1–6).** Read the issue, choose a branch using repository conventions, inspect the relevant files, and present the problem, approach, affected files, pass criteria, and risks. Forge asks about missing requirements before proceeding.
2. **Implement (steps 7–12).** After approval, implement and review until no actionable findings remain. The default run asks before optional refactors, related issues, or a commit. It checks the `/goal` and repository checks before preparing a commit.

The full step-by-step contract lives in [`skills/forge/SKILL.md`](skills/forge/SKILL.md).

## Modifier flags

You can combine flags in one invocation. See [`references/flags.md`](skills/forge/references/flags.md) for conflicts and detailed rules.

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
| `compress` | Sources a token-saving output skill (`ponytail`, else `caveman`) for the whole session before Step 1. Ignored if neither is installed. |
| `codex` / `codex challenge` | Adds Codex as a reviewer (`challenge` runs an adversarial pass). Claude Code only. |
| `codex impl` | Delegates implementation to Codex (GPT-5.6 Sol/Terra/Luna, auto-tiered by task); Claude reviews the result. Claude Code only. |
| `coderabbit` | Adds CodeRabbit as a reviewer, with rework via `coderabbit:autofix`. Claude Code only. |
| `code-review` | Adds `/code-review` (two-axis: Standards + Spec) as a reviewer. A plain skill — works on any runtime. |
| `implement` | Delegates implementation to `/implement`, scoped to the approved plan; forge keeps the review loop. Conflicts with `codex impl`. |

The reviewer flags add to the project's own reviewer agents rather than replacing them, and `codex`, `coderabbit`, and `code-review` can all run in the same pass.

## Examples

```sh
/forge 42                          # GitHub/GitLab issue 42
/forge fix #123                    # same, different phrasing
/forge PROJ-123                    # Jira ticket (or Linear issue)
/forge linear ENG-42               # force Linear routing
/forge pr 47                       # review-entry mode against an existing PR diff
/forge plan docs/superpowers/plans/x.md#task-3   # implement one plan task directly
```

Stack flags as needed:

```sh
/forge 88 tdd secure               # test-first, with a security pass before close
/forge ticket PROJ-7 docs lookup   # plan from CONTEXT.md, fetch library docs first
/forge 15 automode codex challenge # unattended, adversarial Codex review, stops at the commit
```

The reference token can sit anywhere in the request. "solve issue 42 with tests" works as well as `/forge 42 tdd`.

## Orchestrating many issues at once

`blacksmith-orchestrate` handles several forge tasks together. It checks which tasks touch the same files or depend on each other, schedules those in order, and runs independent tasks in parallel worktrees. Each task still follows forge's twelve steps.

It first shows you one battle plan. After approval, it creates the worktrees, dispatches the tasks, and tracks their progress. Run `/blacksmith-orchestrate <work-source>` or ask the agent to ship several issues, a milestone, or a written plan. The full contract is in [`skills/blacksmith-orchestrate/SKILL.md`](skills/blacksmith-orchestrate/SKILL.md).

```sh
/blacksmith-orchestrate 42 43 51 60          # four issues, scheduled by file collisions
/blacksmith-orchestrate milestone 3 automode # a whole milestone, unattended
/blacksmith-orchestrate plan docs/superpowers/plans/x.md   # straight from a written plan
```

## Orchestrator flags

Orchestrator flags are consumed by `blacksmith-orchestrate` itself and are never forwarded to a dispatched forge run. The full matrix, with composition and conflict rules, is in [`references/flags.md`](skills/blacksmith-orchestrate/references/flags.md).

| Flag | What it does |
|---|---|
| `afk` | After a 5-minute quiet timeout, self-verify and merge blocking PRs only; combined with `automode`, also authorizes each dispatched run's own Step 12 commit-and-PR — the single sanctioned exception to forge's never-auto-push floor. |
| `resume` | Resume a run from its ledger instead of starting a new one. |
| `budget <n>` | Token ceiling for the run, with a deterministic degradation ladder. |
| `strict` | No depth downgrade; every task runs full forge. |
| `stack` | Blocked tasks on a soft edge base off the blocker's branch and open stacked PRs; hard-edge blocks still park. |
| `rescout` | Force scout analysis even where dispatch-ready plans exist. |
| `max <n>` | Concurrent implementation agents; default `4`. |
| `dry` | Emit the battle plan and stop; dispatch nothing. |
| `unified` / `split` | Override worktree grouping: `unified` puts a coupled cluster in one worktree behind one PR, `split` gives every task its own. |
| `plan <path>` | Source tasks from a written implementation plan; each plan task becomes one orchestration task. |

Every flag forge understands also passes through unchanged to every dispatched run.

## blueprint

Use `/blueprint` to explore UI changes in the browser before implementation.
It builds proposal screens from the project's design guide, tokens, and
components. Choose options and add notes on a screen, then paste the copied
response into the agent session. After you approve a design, blueprint writes
a spec and offers a handoff to a plan, `/to-tickets`, or
`/blacksmith-orchestrate`.

## Blueprint flags

| Flag | Effect |
|---|---|
| `fresh` | Force a full design re-harvest, ignoring the `.brainstorm/` cache |
| `terminal` | Skip the browser; run every round in the terminal fallback |
| `resume` | Continue from an existing ledger: restart the server, re-push the last unresolved screen |

## What forge uses

`./install.sh` installs the skills and plugins Forge uses:

| Dependency | From | Used for |
|---|---|---|
| `tdd`, `grill-me`, `grill-with-docs`, `to-tickets`, `diagnosing-bugs`, `writing-for-agents`, `improve-codebase-architecture`, `wait-what`, `code-review`, `resolving-merge-conflicts`, `wayfinder`, `implement` | [`mattpocock/skills`](https://github.com/mattpocock/skills) | the lifecycle steps, the `tdd`/grilling/`code-review`/`implement` flags, conflict resolution, and pre-orchestration mapping |
| `karpathy-guidelines` | [`forrestchang/andrej-karpathy-skills`](https://github.com/forrestchang/andrej-karpathy-skills) | re-loading clean-code discipline before each implement/refactor pass |
| `superpowers:requesting-code-review`, `superpowers:using-git-worktrees` | [`obra/superpowers`](https://github.com/obra/superpowers) | the default reviewer and the `worktree` flag |
| `codex` plugin | [`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc) | the `codex` flag (Claude Code only) |
| `coderabbit` plugin | [`coderabbitai/skills`](https://github.com/coderabbitai/skills) | the `coderabbit` flag (Claude Code only) |
| `greploop`, `check-pr` | [`greptileai/skills`](https://github.com/greptileai/skills) | the review-loop fallback |

Some features need tools from your runtime. `/goal` and `/compact` come from the agent runtime. The `secure` flag uses Claude Code's `security-review`; `lookup` uses the context7 MCP. Jira and Linear routing need their respective tracker MCPs. Set up these tools if you use the corresponding feature.

## License

[MIT](LICENSE)
