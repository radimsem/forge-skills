# Forge — `changelog` flag

At Step 12, drafts a changelog entry per the repo's existing convention and includes it in the proposed commit list. The entry covers what the implementation diff actually shipped — not the original issue text — so the changelog reflects the merged code.

## Manual verification recipe

```
/forge issue 42 changelog
```

Expected: Steps 1–11 run unchanged. Step 12 (after `/goal` verifies green) inspects the repo for an existing changelog file. If found, forge drafts a new entry matching the file's existing format and adds it to the proposed commit list. If no changelog file exists, forge surfaces this once with a one-line note ("No changelog file detected; skipping `changelog`.") and proceeds.

## When it fires

Step 12, after the `/goal` verification gate passes and before the closing menu is offered. The draft entry is part of the proposed commit list, not a separate commit.

## What it composes

No external skill. Internal logic only: locate the changelog file, parse its format, draft the entry. Read the file's last 3–5 entries to mirror tone, granularity, and section headers (Keep-a-Changelog, project-specific, conventional commits, etc.).

## Locating the changelog file

Check in order, stop at the first hit:

| Path / pattern | Notes |
|---|---|
| `CHANGELOG.md`, `CHANGELOG`, `HISTORY.md` | The conventional top-level locations |
| `docs/CHANGELOG.md`, `docs/changelog/` | Docs-prefixed variants |
| `.changeset/` directory | Changesets convention (one file per change) |
| `changie.yaml` + `.changes/` | Changie tool |
| Any file the repo guide names | Repo-specific config wins |

Repo guide (`CONTRIBUTING.md` / agent guide / etc.) wins over this list.

## Behavior change vs default

| Stage | Default | With `changelog` |
|---|---|---|
| Step 12 commit-list assembly | Code changes only | Code changes **+** one new changelog entry matching repo format |
| Entry placement | (n/a) | Top of the changelog file (Keep-a-Changelog convention) OR a new file in the changesets directory if applicable |
| Entry wording | (n/a) | Imperative summary of what the diff did, not what the issue asked. Length matches the file's existing entries. |
| Closing menu | Six options as usual | Same six options; option 2 (push + PR) includes the changelog entry in the PR body summary |

## Composition with other flags

| Combination | Effect |
|---|---|
| `changelog` + `automode` | Entry is drafted without prompt. The commit list at Step 12 emits the proposed history as a plan (per `automode` Step 12 behavior); the changelog entry is included in that plan. |
| `changelog` + `docs` | Entry is included in the `/tmp/forge-<ref>.md` Step 12 plan output. |
| `changelog` + `secure` | Security-fix entries should follow the repo's security-disclosure convention if one exists (look for SECURITY.md). If unclear, surface the security finding's nature in the entry and let the user adjust. |
| `changelog` + `ci-watch` | Entry lands in the proposed commits regardless of CI outcome. If CI goes red post-push, the user can pull the entry from the commit. |

## Anti-pattern (encoded in [anti-patterns.md](../anti-patterns.md))

Drafting the changelog entry before `/goal` verifies green. The entry must reflect what actually shipped. If the verify gate fails and Step 8 reopens, the previous draft entry is stale; redraft after re-convergence. Never include a changelog entry in a commit list whose verify failed.

## `automode` behavior

See [autonomy.md](../autonomy.md). `changelog` runs unprompted at Step 12; the entry rides along in the emitted plan.
