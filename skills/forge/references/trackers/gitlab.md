# Forge — GitLab issue reference

Loaded on demand by SKILL.md **only when `git remote get-url origin` (fallback `upstream`) host matches `gitlab.*` (including self-hosted)**. Other git hosts and Atlassian Jira / Linear never touch this file.

## Step 1b — Fetch source (resolve)

`glab` is the primary CLI.

## Step 2 — Pull the issue

```bash
glab issue view <N> -F json   # confirm flag via `glab issue view --help`
```

Read **body + every comment** — latest comments often carry the missing repro / decision.

### GitLab-absent fallback ★

`glab` missing or unauthenticated → host REST API: `GET /projects/:id/issues/:iid` + `/notes`, token in `PRIVATE-TOKEN`. Unauth REST is rate-limited — say so if you fall back.
