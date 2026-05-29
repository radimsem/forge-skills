# Forge — Dependencies

Forge composes external skills and plugins. Install all of them, then forge itself, with the
repo-root installer:

```sh
./install.sh            # detect-first, idempotent; -y for non-interactive, --help for options
```

Two mechanisms are involved (the installer handles both): bare skills via Vercel's `npx skills`,
and Claude Code plugins via `claude plugin`. `npx skills` cannot install the plugin agents/hooks
the reviewer engines need, which is why the plugins go through `claude plugin`.

## What forge composes

| Dependency | Provider | Mechanism | Needed for |
|---|---|---|---|
| `tdd` `grill-me` `grill-with-docs` `to-issues` `diagnose` `write-a-skill` `improve-codebase-architecture` `zoom-out` | `mattpocock/skills` | `npx skills` | Steps 7/9/10, `tdd` flag, grilling, high-level walkthrough |
| `setup-matt-pocock-skills` | `mattpocock/skills` | `npx skills` + run once per repo | bootstraps the above |
| `karpathy-guidelines` | `forrestchang/andrej-karpathy-skills` | `npx skills` | Step 7 clean-code re-source |
| `superpowers:requesting-code-review` `superpowers:using-git-worktrees` | superpowers (`anthropics/claude-plugins-official`) | `claude plugin` | default reviewer; `worktree` flag |
| `codex` plugin | `openai/codex-plugin-cc` | `claude plugin` (CC-only) | `codex` flag |
| `coderabbit` plugin | `claude-plugins-official` | `claude plugin` (CC-only) | `coderabbit` flag |
| `greploop` `check-pr` | `greptileai/skills` | `npx skills` | Step 8 PR-review fallback |

## No install needed (host/runtime built-ins)

- `/goal`, `/compact` — built-in agent commands.
- `security-review` — Claude Code built-in (`secure` flag).
- **context7 MCP** — the `lookup` flag's documentation source. Optional; set it up (MCP, or the `ctx7` resources your runtime exposes) only if you use `lookup`. The installer does not provision it — MCP setup/auth is per-user.
- Atlassian / Linear MCP, `gh`, `glab` — optional, set up per tracker you use.
