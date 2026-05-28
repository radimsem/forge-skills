# Forge — Linear ticket reference

Loaded on demand by SKILL.md **only when `<ref>` resolves to a Linear issue** (key-shape `[A-Z]+-\d+` after Jira disambiguation, or the `linear` keyword — see Parameters → Target grammar). Git-host issues and Jira tickets never touch this file.

"The runtime's Linear tool" = whatever Linear MCP read/write tools the runtime advertises. Never hardcode a tool name; common surfaces are the Linear MCP server, the `linear` CLI, and the Linear REST/GraphQL API. The skill picks whichever is connected.

## Jira / Linear disambiguation

Both trackers use the same key shape (`[A-Z]+-\d+`). When the user invokes `/forge ENG-42` with both trackers configured, ask which:

```
⚠ Both Jira and Linear are connected, and `ENG-42` matches both key shapes.
  - Linear (issue ENG-42 in <team-name>) (Recommended if Linear is the primary tracker)
  - Jira (project ENG, issue 42)
  - Abort
```

Single-tracker setups skip this prompt — only one match is possible. `automode` cannot answer this question (it interviews the user); under `automode`, attempt Linear first if both are connected, record the assumption in the proposal, abort if Linear lookup 404s.

The `linear` keyword (e.g. `/forge linear ENG-42`) forces Linear routing without the disambiguation prompt. Symmetric to the `ticket` keyword that exists for Jira.

## Step 1 — Fetch source (resolve)

Fetch via the connected Linear MCP tools the runtime exposes (issue-fetch + comments; usually a Linear "get issue" tool, often needs a team-id or workspace-id prefix). No Linear MCP connected, or auth/permission error → **§Linear-absent fallback** below.

## Step 2 — Pull the issue

Pull via the runtime's Linear read tool: title, description, state (Triage / Backlog / Todo / In Progress / In Review / Done / Canceled / Duplicate), priority (Urgent / High / Medium / Low / No priority), labels, assignee, estimate, parent issue (if sub-issue), **and every comment**. State + labels = bug-vs-feature signal for Step 4 table + Step 3 prefix.

Read **body + every comment**. Linear's comment surface is heavily used for inline implementation discussion; comments often carry the actual spec.

### Linear-absent fallback ★

No Linear MCP connected, or auth/permission error: warn explicitly that Linear sourcing is unavailable, then offer the three-choice fallback (proposed-answer; `automode` still stops here — missing data source, not a gate):

```
⚠ Linear MCP not connected (or unauthorized) — can't fetch <ref>.
  - Paste the issue title + description (+ acceptance criteria) here (Recommended)
  - I'll authenticate the Linear MCP, then retry the fetch
  - Abort
```

*Paste* → treat text as issue body, → Step 3. *Authenticate* → run the runtime's Linear auth/connect tool, retry once. *Abort* → stop, do nothing.

## Step 3 — Key in branch & commits

Repo guide still wins (documented Linear convention overrides everything). Guide silent → branch `<prefix>/<KEY>-<slug>` (e.g. `fix/ENG-123-parser-utf16-bom`). Linear has no smart-commit syntax like Jira; the key in the branch name is enough for Linear's GitHub/GitLab integration to auto-link.

Key always in the Step 5 proposal text regardless.

## Step 12 — Write-back ★

The Step 12 closing menu shows a Linear write-back option **only when the target was a Linear issue**:

```
  - Lay down that history, push, open the PR, and comment + transition <KEY> on Linear
```

Linear write-back — **opt-in, never automatic**. On selection: comment on `<KEY>` (branch/PR link + one-line summary), then transition — but first read the issue's *available* states via the runtime's Linear tool and confirm the target state (workflow states are workspace-specific; ambiguous → ask, proposed-answer). Never invent a state id. **Never** Linear-write-back on any other menu option, without an explicit pick here, or under `automode`.

The closing menu in `references/proposal-template.md` §Step 12 keeps a single "comment + transition <KEY>" line; the trailing tracker name (`Jira` or `Linear`) is filled in based on which tracker resolved `<ref>`.
