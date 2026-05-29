# Forge — GitHub issue reference

Loaded on demand by SKILL.md **only when `git remote get-url origin` (fallback `upstream`) host is `github.com` or a GitHub Enterprise hostname**. Other git hosts and Atlassian Jira / Linear never touch this file.

## Step 1b — Fetch source (resolve)

`gh` is the primary CLI.

## Step 2 — Pull the issue

```bash
gh issue view <N> --json number,title,body,state,labels,comments,author,url
```

Read **body + every comment** — latest comments often carry the missing repro / decision.

If `<N>` is a pull request, `gh issue view` says so — stop and ask whether they meant `/forge pr <N>`.

### GitHub-absent fallback

`gh` missing or unauthenticated → host REST API:

```bash
curl -sH "Accept: application/vnd.github+json" \
     ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
     "https://api.github.com/repos/owner/repo/issues/<N>"   # comments: same URL + "/comments"
```

Unauth REST is rate-limited — say so if you fall back.
