# Unified dependency installer — design spec

- **Date:** 2026-05-29
- **Status:** Approved (all §10 open questions resolved inline; ready for writing-plans)
- **Target version:** *deferred* — installer is a repo-root tooling artifact, not part of the `skills/forge` surface. No plugin-manifest bump.
- **Related:** [`2026-05-28-github-gitlab-tracker-refs.md`](2026-05-28-github-gitlab-tracker-refs.md) §"Install path" (establishes `npx skills` as the primary install path); root [`README.md`](../../README.md) (stale `/plugin install` instructions — superseded here).
- **Originating session:** brainstorming session — "trace down every external skill reference in forge and propose a unified dependency install, forge installed last, leaning on Vercel's `npx skills`."

## 1. Goal

Ship a single repo-root `install.sh` that, in one run, makes a fresh host able to run the forge skill end-to-end: install every external skill and plugin forge composes, then install forge itself **last**. The script is detection-first (skip what is already present), idempotent (safe to re-run), and honest about the two install mechanisms forge actually spans.

The user's stated lean — Vercel's `npx skills` "package manager" — is the primary mechanism. It is *not* sufficient on its own (see §5), so the script also orchestrates the Claude Code `/plugin` path for the dependencies that ship as plugins rather than bare skills.

## 2. Why now

- Forge composes **~15 external skills/plugins across five provider repos** (§4). There is no single command that installs them; a new contributor or a fresh machine currently reverse-engineers the set by reading every reference file. This spec turns that tacit knowledge into one script.
- The repo already committed to `npx skills` as the primary install path (`2026-05-28-github-gitlab-tracker-refs.md`), but never shipped the tooling. The root README still says `/plugin install /path/to/forge-skills/1.0.0`, which is both stale (the `1.0.0/` dir moved to `skills/` in `13d52fb`) and incomplete (says nothing about the dependencies).
- `npx skills` gained `list` (installed-skill introspection) and per-agent targeting, which makes a clean detection-first script feasible today.

## 3. Non-goals

- **No dependency resolution baked into SKILL.md.** `npx skills` has no transitive-dep mechanism and no lockfile-restore (open FR vercel-labs/skills#549). We do not invent one; the script is an explicit, ordered sequence.
- **No version pinning / lockfile** in this pass. Skills install from each provider's default branch. A `skills-lock.json`-style pin is a plausible later PR once `npx skills` ships restore support.
- **No behavior change to forge.** The only `skills/forge` touch is documentation (a Dependencies section + README fix); the workflow is untouched.
- **No MCP server provisioning.** Atlassian / Linear / context7 MCP setup stays a documented runtime prerequisite, not a script step (auth is interactive and per-user).
- **No CI integration** (no GitHub Action running the installer). The script is `-y`-friendly so a later PR can add one.

## 4. Verified dependency inventory

Traced from the `skills/forge` tree (grep of every ``/cmd`` and ``plugin:skill`` reference) and confirmed against the host's plugin cache, `known_marketplaces.json`, and each provider's README. Sources cited so a reviewer can re-verify.

| Forge reference | Provider (repo / marketplace) | Mechanism | Tier |
|---|---|---|---|
| `/tdd` `/grill-me` `/grill-with-docs` `/to-issues` `/diagnose` `/write-a-skill` `/improve-codebase-architecture` | `mattpocock/skills` | `npx skills add` | 1 |
| `setup-matt-pocock-skills` (per-repo bootstrap the above consume) | `mattpocock/skills` | `npx skills add` + **run once per repo** | 1 |
| `/karpathy-guidelines` | `forrestchang/andrej-karpathy-skills` | `npx skills add` | 1 |
| `superpowers:requesting-code-review` (default reviewer — always runs) | superpowers plugin (`anthropics/claude-plugins-official`) | `/plugin` | 2 |
| `superpowers:using-git-worktrees` (`worktree` flag) | superpowers plugin | `/plugin` | 2 |
| `codex:codex-rescue` `codex review` `codex adversarial-review` (`codex` flag) | codex plugin (`openai/codex-plugin-cc`) | `/plugin` (CC-only) | 3 |
| `coderabbit:code-review` `coderabbit:autofix` (`coderabbit` flag) | coderabbit plugin (`claude-plugins-official`) | `/plugin` (CC-only) | 3 |
| `/greploop` `/check-pr` (Step 8 PR-review fallback) | `greptileai/skills` | `npx skills add` | 4 |
| `find-docs` (`lookup` flag) | bundled into this repo (§7.2); Context7-CLI-backed | `npx skills add` (local) + `npm i -g ctx7` | 4 |
| `/goal` `/compact` | **built-in agent commands** (Claude Code / Codex / others) | none | 5 |
| `security-review` (`secure` flag) | `builtin:security-review` (Claude Code) | none | 5 |
| context7 MCP, Atlassian MCP, Linear MCP | various | MCP (interactive auth) | 5 |
| `gh` / `glab` (tracker CLIs) | GitHub CLI / GitLab CLI | OS package manager | 5 |
| **forge** | this repo (`radimsem/forge-skills`, skill at `skills/forge`) | `npx skills add` — **installed last** | 6 |

### Resolved during brainstorming

- **`/goal` is not a skill.** It is a built-in agent command (confirmed by the user; absent from every marketplace, mattpocock's set, and all local skill dirs). Forge's Step 7 "set `/goal`" and Step 12 "`/goal` verifies green" rely on the host agent, not on an installable artifact. → Tier 5, no install.
- **`/notes` is a false positive.** It is a GitLab REST path fragment (`GET /projects/:id/issues/:iid` + `/notes`) in `references/trackers/gitlab.md`, not a skill.
- **`find-docs` is not shipped by the context7 plugin.** The installed context7 plugin cache contains no `find-docs` skill. The host's `~/.claude/skills/find-docs` is a standalone skill that wraps the **Context7 CLI** (`ctx7`). It has no public source repo we could pin, so we bundle it (§7.2).
- **`/caveman` is not a forge dependency.** It appears in this repo's tooling/process but is never referenced by the `skills/forge` tree. Excluded from the installer.

## 5. Why two mechanisms (the core constraint)

`npx skills` installs bare `SKILL.md` directories. Three of forge's dependencies are **plugins**, not bare skills:

- **superpowers** ships many interdependent skills; `requesting-code-review` composes other superpowers skills.
- **codex** ships an agent (`codex-rescue`), commands, hooks, and `codex-companion.mjs` — the script that `skills/forge/scripts/resolve-codex.py` drives over Bash.
- **coderabbit** ships the `code-review`/`autofix` skills plus plugin wiring.

`npx skills add` cannot install plugin agents/hooks/companion-scripts. These must go through the Claude Code plugin system (`/plugin marketplace add` + `/plugin install`). The installer therefore has two install bodies: an `npx skills` loop (Tiers 1, 4, 6) and a `/plugin` block (Tiers 2, 3). This split is the reason a wrapper script exists at all rather than a one-line `npx skills add`.

## 6. Architecture

```
install.sh  (POSIX sh; repo root)
  ├─ 0. Preflight     require node+npx+git (fatal if absent); warn non-fatally on missing gh/glab/ctx7
  ├─ 1. Detect        npx skills list -g  → set of {skill × agent} already present
  │                   parse ~/.claude/plugins/installed_plugins.json .plugins → set of plugin@marketplace
  │                   → print STATUS TABLE (present ✓ / will-install +) before mutating anything
  ├─ 2. npx skills    Tier 1 + Tier 4: per skill, install only onto the targeted agents missing it
  ├─ 3. plugins       Tier 2 + Tier 3: skip if present (claude plugin list); else
  │                     - if `claude` CLI present → `claude plugin marketplace add` + `claude plugin install <p>@<m> -s user`
  │                     - else PRINT the equivalent `/plugin …` paste-in lines (degraded fallback only)
  ├─ 4. forge         Tier 6: detect-then-add forge LAST (npx skills add . -s forge  OR  radimsem/forge-skills -s forge)
  └─ 5. Post-install  remind to run `/setup-matt-pocock-skills` once per repo;
                      note built-ins (/goal, /compact, security-review) need nothing;
                      list optional MCP/CLI prerequisites with one-line install pointers
```

### Flags

| Flag | Effect |
|---|---|
| `--yes` / `-y` | Non-interactive; pass `-y` to every `npx skills add`; assume "print" for `/plugin` if no CLI |
| `--force` | Reinstall even when detection says present (re-link / repair) |
| `--agents "a,b,…"` | Override the multi-agent target set (default: `claude-code,codex,cursor,opencode`) |
| `--skills-only` | Run Tiers 1/4/6 only; skip the `/plugin` block (for non-CC hosts) |
| `--help` | Usage |

### Default agent target

Tiers 1/4/6 install onto **`claude-code,codex,cursor,opencode`** (the user's choice — forge's "runtime-generic" design). Tiers 2/3 are **Claude Code only** because codex/coderabbit are CC-exclusive and superpowers is a CC plugin; the script notes this asymmetry rather than failing on non-CC agents.

## 7. Detailed decisions

### 7.1 Detection

- **Bare skills:** parse `npx skills list -g` output (alias `ls`; "like `npm ls`"). "Installed" is per-agent, not binary — for each skill, install only onto the agents where it is missing (`npx skills add <src> -s <name> -a <missing-agent>… -y`). Without `--force`, a skill present on all targeted agents is skipped.
- **Plugins:** detect via `claude plugin list` (the CLI's own ledger). Fallback when `claude` is absent: a plugin is present iff `<plugin>@<marketplace>` is a key under `.plugins` in `~/.claude/plugins/installed_plugins.json` (observed format: `superpowers@claude-plugins-official`, `greptile@claude-plugins-official`, …), read with `python3 -c` or grep on the literal key.
- **Idempotency does not depend on detection.** `npx skills add` is already safe to re-run; detection exists for clean reporting and to avoid redundant work, and to make `--force` meaningful.

### 7.2 `find-docs` — vendored (decided)

Bundle a copy at `skills/find-docs/SKILL.md` (+ any resources) sourced from the host's working copy, so the installer is self-contained — no dangling reference to an unsourceable skill. The skill wraps the Context7 CLI, so the script's preflight warns (non-fatal) if `ctx7` is absent and prints `npm i -g ctx7@latest`. Because `find-docs` is only reached behind the `lookup` flag, its absence never blocks core forge.

### 7.3 Plugin install — run headlessly (decided)

The `claude` CLI exposes a fully headless plugin interface, so the script runs it directly (no TUI, no paste-in for the common case):

```sh
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install superpowers@claude-plugins-official -s user
# optional reviewers (flag-gated, CC-only):
claude plugin marketplace add openai/codex-plugin-cc && claude plugin install codex@openai-codex -s user
claude plugin install coderabbit@claude-plugins-official -s user
```

Detection uses `claude plugin list`. `marketplace add` is idempotent (re-adding an existing marketplace is a no-op/refresh). Only when `claude` is not on PATH does the script fall back to printing the equivalent `/plugin marketplace add` + `/plugin install` lines for the user to paste. (Marketplace/plugin identifiers verified against the host's `known_marketplaces.json` and `installed_plugins.json`; `-s user` matches the install `--scope` default.)

### 7.4 Ordering

Strict tier order 1 → 6, forge last, because forge is the consumer: installing it first would leave a window where `/forge` resolves but its dependencies do not. The post-install `/setup-matt-pocock-skills` reminder is last of all (it is a per-repo runtime step, not an install).

## 8. Files

| File | Change |
|---|---|
| `install.sh` (repo root) | **New.** The orchestrator described above. Executable, POSIX `sh`. |
| `skills/find-docs/SKILL.md` (+ any resources) | **New (vendored).** Copied from the host working copy (§7.2). |
| `README.md` (root) | **Edit.** Replace the stale `/plugin install …/1.0.0` block with `./install.sh` + a one-line description of the two mechanisms. Fix the `1.0.0/` → `skills/` path drift while here. |
| `skills/forge/references/dependencies.md` | **New.** A concise Dependencies section: the §4 inventory + a pointer to `install.sh`. SKILL.md gains one short line linking to it (keeps the always-loaded spine light). |

No change to forge's workflow, flags, or any existing reference file's behavior.

## 9. Verification

1. **Dry host simulation:** on a host with none of the deps, `./install.sh --yes` exits 0; `npx skills list -g` afterwards shows all Tier 1/4/6 skills on the targeted agents; `installed_plugins.json` (or printed instructions) covers Tier 2/3.
2. **Idempotency:** a second `./install.sh --yes` run installs nothing and the status table reports all-present.
3. **Partial host:** with some deps already present (the current dev machine), the status table correctly marks present vs missing and only installs the gaps.
4. **`--skills-only`:** skips the `/plugin` block cleanly; useful for non-CC agents.
5. **Forge-last invariant:** forge's `npx skills add` is the last install action before post-install notes.
6. **No-network failure mode:** a failed `npx skills add` for one skill reports the failure and continues to the next (no half-abort), exiting non-zero overall so CI can catch it.

## 10. Open questions — all resolved

1. **`find-docs` provenance (§7.2)** — ✅ vendor the local skill into `skills/find-docs/`.
2. **Dependencies doc placement (§8)** — ✅ new `skills/forge/references/dependencies.md`, linked from SKILL.md.
3. **`claude plugin` CLI (§7.3)** — ✅ confirmed headless (`marketplace add` / `install -s user` / `list`). Script runs it directly; printing is the no-`claude`-on-PATH fallback only.

## 11. Next step

On user approval of this spec, the next step is `superpowers:writing-plans` against this document to produce the PR-by-PR executable plan. No other skill is invoked between brainstorming and writing-plans.
