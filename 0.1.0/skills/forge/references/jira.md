# Forge — Jira ticket reference

Loaded on demand by SKILL.md **only when `<ref>` resolves to a Jira ticket** (key-shape `[A-Z][A-Z0-9]+-\d+` or the `ticket` keyword — see Parameters → Target grammar). Git-host issues never touch this file.

"The runtime's Jira tool" = whatever Atlassian/Jira MCP read/write tools the runtime advertises. Never hardcode a tool name.

## Step 1c — Fetch source (resolve)

Fetch via the **connected Atlassian/Jira MCP tools** the runtime exposes (issue-fetch + comments; usually a Jira "get issue" tool, often needs a cloud-id from an "accessible resources" tool first). No Jira MCP connected, or auth/permission error → **§Jira-absent fallback** below.

## Step 2 — Pull the ticket

Pull via the runtime's Jira read tool: summary, description, issue type, status, priority, labels/components, acceptance-criteria field if present, **and every comment**. Issue type = bug-vs-feature signal for Step 4 table + Step 3 prefix.

Read **body + every comment**. Latest comments often carry the missing repro / decision.

### Jira-absent fallback ★

No Jira MCP connected, or auth/permission error: **warn explicitly that Jira sourcing is unavailable**, then offer exactly three choices (proposed-answer; `automode` still stops here — it suppresses *gates*, not a missing data source):

```
⚠ Atlassian/Jira MCP not connected (or unauthorized) — can't fetch <ref>.
  - Paste the ticket title + description (+ acceptance criteria) here (Recommended)
  - I'll authenticate the Atlassian MCP, then retry the fetch
  - Abort
```

*Paste* → treat text as issue body, → Step 3. *Authenticate* → run the runtime's Atlassian auth/connect tool, retry Step 1c once. *Abort* → stop, do nothing.

## Step 3 — Key in branch & commits

Repo guide still wins (documented Jira convention / smart-commit / subject-line rule overrides everything). Guide silent → branch `<prefix>/<KEY>-<slug>` (e.g. `fix/PROJ-123-parser-utf16-bom`); commit subjects keep repo style — do **not** force `PROJ-123` into the subject unless the guide asks (breaks e.g. subject-only ≤72-char repos). Key always in the Step 5 proposal text regardless.

## Step 12 — Write-back ★

The Step 12 closing menu shows a Jira write-back option **only when the target was a Jira ticket**:

```
  - Lay down that history, push, open the PR, and comment + transition <KEY> on Jira
```

Jira write-back — **opt-in, never automatic**. On selection: comment on `<KEY>` (branch/PR link + one-line summary), then transition — but first read the ticket's *available* transitions via the runtime's Jira tool and confirm the target state (names are project-specific; ambiguous → ask, proposed-answer). Never invent a transition id. **Never** Jira-write-back on any other menu option, without an explicit pick here, or under `automode`.
