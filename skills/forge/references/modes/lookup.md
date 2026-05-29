# Forge — `lookup` flag

Composes the `find-docs` skill (and the `context7` MCP if available) at Step 4 so the proposal is grounded in current, fetched library facts instead of training-data recall.

## Manual verification recipe

```
/forge issue 42 lookup
```

Expected: Step 4 (context check) detects the flag. For any library, framework, SDK, CLI tool, or cloud service the issue mentions, forge invokes `find-docs` (and `context7` via MCP if connected) before writing the Step 5 proposal. Cited facts in the proposal carry "(per <library> docs, fetched <date>)" attribution.

## When it fires

Step 4, after the existing-context inventory and the issue-named-file reads. Library lookups happen before the gap interview, so the proposal can use fresh facts when answering the user's interview gaps.

## What it composes

| Tool | Used for | Required? |
|---|---|---|
| `find-docs` skill | Resolves library names → docs; fetches API references, configuration syntax, migration notes | Always for `lookup` |
| `context7` MCP | Same coverage, often more current, when the MCP server is connected | Used opportunistically if available; no error if missing |

## Behavior change vs default

| Stage | Default | With `lookup` |
|---|---|---|
| Step 4 library mentions | Use training-data recall for library facts | Fetch current docs for every mentioned library/framework/SDK/CLI/cloud service |
| Step 5 proposal | API references stated from memory | Each library-specific claim attributed: "(per <library> docs, fetched <date>)" |
| Interview gaps about library behavior | Agent guesses or asks user | Agent fetches docs first, then proposes informed answers in the gap interview |

## When the lookup is the wrong tool

Per `find-docs` skill: not for refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts. The `lookup` flag inherits the same exclusions. If the issue is "refactor the parser to use the visitor pattern", `lookup` adds no value — skip it.

## Composition with other flags

| Combination | Effect |
|---|---|
| `lookup` + `automode` | Fetches happen without prompts. If a fetch fails (rate limit, network), the agent records the failure as a Risk in the proposal and continues — does not block under `automode`. |
| `lookup` + `docs` | `CONTEXT.md` includes fetched-doc attributions. The plan in `CONTEXT.md` cites versions, not just library names. |
| `lookup` + `tdd` | Tests are written against the current API surface fetched by `lookup`, not the training-data API (which may be a release behind). |
| `lookup` + `worktree` | Compose freely. |

## Cost reminder

Doc fetches consume tokens. Use `lookup` when the proposal accuracy depends on library-version-specific behavior. Skip when the issue is about your own code. Per-fetch token cost is small; the value compounds when the lookup catches an API change that would otherwise produce a broken proposal.
