# Forge — `lookup` flag

Composes the **context7 MCP** at Step 4 so the proposal is grounded in current, fetched library facts instead of training-data recall. When the context7 MCP is not connected, fall back to whatever context7 resources the runtime exposes (e.g. the `ctx7` CLI); if none is available, note the gap as a Risk rather than guessing.

## Manual verification recipe

```
/forge issue 42 lookup
```

Expected: Step 4 (context check) detects the flag. For any library, framework, SDK, CLI tool, or cloud service the issue mentions, forge queries context7 — resolve the library id, then fetch its docs — before writing the Step 5 proposal. Cited facts in the proposal carry "(per <library> docs, fetched <date>)" attribution.

## When it fires

Step 4, after the existing-context inventory and the issue-named-file reads. Library lookups happen before the gap interview, so the proposal can use fresh facts when answering the user's interview gaps.

## What it composes

| Source | Used for | Required? |
|---|---|---|
| context7 MCP | Resolve library names → ids, fetch API references, configuration syntax, migration notes. The canonical doc source for `lookup`. | Preferred when the MCP server is connected |
| context7 resources / `ctx7` CLI | Same coverage when the MCP is not connected | Fallback only; no error if missing — record a Risk instead |

No skill is bundled for this flag: `lookup` rides on the context7 MCP/resources the runtime already provides.

## Behavior change vs default

| Stage | Default | With `lookup` |
|---|---|---|
| Step 4 library mentions | Use training-data recall for library facts | Fetch current docs via context7 for every mentioned library/framework/SDK/CLI/cloud service |
| Step 5 proposal | API references stated from memory | Each library-specific claim attributed: "(per <library> docs, fetched <date>)" |
| Interview gaps about library behavior | Agent guesses or asks user | Agent fetches docs first, then proposes informed answers in the gap interview |

## When the lookup is the wrong tool

Not for refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts. The `lookup` flag adds value only when a proposal hinges on library-version-specific facts. If the issue is "refactor the parser to use the visitor pattern", `lookup` adds nothing — skip it.

## Composition with other flags

| Combination | Effect |
|---|---|
| `lookup` + `automode` | Fetches happen without prompts. If a fetch fails (rate limit, network, MCP absent), the agent records the failure as a Risk in the proposal and continues — does not block under `automode`. |
| `lookup` + `docs` | `CONTEXT.md` includes fetched-doc attributions. The plan in `CONTEXT.md` cites versions, not just library names. |
| `lookup` + `tdd` | Tests are written against the current API surface fetched by `lookup`, not the training-data API (which may be a release behind). |
| `lookup` + `worktree` | Compose freely. |

## Cost reminder

Doc fetches consume tokens. Use `lookup` when the proposal accuracy depends on library-version-specific behavior. Skip when the issue is about your own code. Per-fetch token cost is small; the value compounds when the lookup catches an API change that would otherwise produce a broken proposal.
