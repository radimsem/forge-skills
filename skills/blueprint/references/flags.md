# Blueprint — Flag matrix

Flags are orthogonal and parsed from anywhere in the invocation.

## Flags

| Flag | Effect | Owner |
|---|---|---|
| `fresh` | Force a full design re-harvest, ignoring the `.brainstorm/` cache | [harvest.md](harvest.md) |
| `terminal` | Skip the browser; run every round in the terminal fallback | [screens.md](screens.md) |
| `resume` | Continue from an existing ledger: restart the server, re-push the last unresolved screen | [ledger.md](ledger.md) |

## Composition rules

All three compose freely. `terminal` + `resume` resumes without restarting
the server. `fresh` affects only Step 2; it never clears ledgers or screens.
There are no conflicting combinations.
