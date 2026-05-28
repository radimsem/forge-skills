# GitHub & GitLab tracker reference extraction — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract per-host (GitHub, GitLab) issue-fetch prose out of `skills/forge/SKILL.md` §Step 1b/§Step 2 into two new on-demand-loaded reference files, parallel to the existing `references/trackers/jira.md` and `references/trackers/linear.md`. Pure extraction — no behavior change, no new flags, no helper scripts, no plugin-manifest bump.

**Architecture:** Add two leaf files under `skills/forge/references/trackers/` (`github.md`, `gitlab.md`). Slim SKILL.md §Step 1b table to point at them; slim §Step 2 git-host paragraph to delegate to them. SKILL.md anchor headings (`§Step 1b`, `§Step 2`) are preserved so no peer reference's link rots. Strict-purity discipline: new files contain only prose already inlined in SKILL.md today; no GHE/self-hosted clarifiers, no explanation of JSON fields, no synthesized prose.

**Tech Stack:** Markdown only. No code, no tests, no build system. Verification is manual link-walk + file-read.

**Spec:** [`../specs/2026-05-28-github-gitlab-tracker-refs.md`](../specs/2026-05-28-github-gitlab-tracker-refs.md) — read once for context; the plan below embeds all content the spec resolves to.

---

## Task 1: Create `references/trackers/github.md`

**Files:**
- Create: `skills/forge/references/trackers/github.md`

- [ ] **Step 1: Write the new file**

Create `skills/forge/references/trackers/github.md` with exactly this content:

````markdown
# Forge — GitHub issue reference

Loaded on demand by SKILL.md **only when `git remote get-url origin` (fallback `upstream`) host is `github.com` or a GitHub Enterprise hostname**. Other git hosts and Atlassian Jira / Linear never touch this file.

## Step 1b — Fetch source (resolve)

`gh` is the primary CLI.

## Step 2 — Pull the issue

```bash
gh issue view <N> --json number,title,body,state,labels,comments,author,url
```

Read **body + every comment** — latest comments often carry the missing repro / decision.

### GitHub-absent fallback ★

`gh` missing or unauthenticated → host REST API:

```bash
curl -sH "Accept: application/vnd.github+json" \
     ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
     "https://api.github.com/repos/owner/repo/issues/<N>"   # comments: same URL + "/comments"
```

Unauth REST is rate-limited — say so if you fall back.
````

- [ ] **Step 2: Verify file exists and content matches**

Run: `wc -l skills/forge/references/trackers/github.md && head -1 skills/forge/references/trackers/github.md`

Expected output:
```
22 skills/forge/references/trackers/github.md
# Forge — GitHub issue reference
```

(Line count may be ±1 depending on trailing newline handling — anywhere in 20–24 is acceptable. The headline must match exactly.)

---

## Task 2: Create `references/trackers/gitlab.md`

**Files:**
- Create: `skills/forge/references/trackers/gitlab.md`

- [ ] **Step 1: Write the new file**

Create `skills/forge/references/trackers/gitlab.md` with exactly this content:

````markdown
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
````

- [ ] **Step 2: Verify file exists and content matches**

Run: `wc -l skills/forge/references/trackers/gitlab.md && head -1 skills/forge/references/trackers/gitlab.md`

Expected output:
```
18 skills/forge/references/trackers/gitlab.md
# Forge — GitLab issue reference
```

(Line count may be ±1 depending on trailing newline handling — anywhere in 16–20 is acceptable. The headline must match exactly.)

---

## Task 3: Slim SKILL.md §Step 1b table

**Files:**
- Modify: `skills/forge/SKILL.md` (the §Step 1b table)

- [ ] **Step 1: Replace the §Step 1b table**

Open `skills/forge/SKILL.md`. Find this block (currently lines 85–96):

````markdown
### Step 1b — git-host issue

Map host → CLI:

| Host in remote URL | CLI | Issue fetch |
|---|---|---|
| `github.com` / GH Enterprise | `gh` | `gh issue view <N> --json number,title,body,state,labels,comments,author,url` |
| `gitlab.*` | `glab` | `glab issue view <N> -F json` (confirm flag via `glab issue view --help`) |
| other (Gitea, Bitbucket, …) | that host's CLI if present | its issue-view JSON command |
| any, no CLI / auth error | — | host REST API (see Step 2) |

If neither `origin` nor `upstream` resolves to a known issue host: stop, tell the user, do nothing else.
````

Replace it with:

````markdown
### Step 1b — git-host issue

Route by host in `origin` (fallback `upstream`):

| Host in remote URL | Reference |
|---|---|
| `github.com` / GH Enterprise | → [references/trackers/github.md](references/trackers/github.md) |
| `gitlab.*` (incl. self-hosted) | → [references/trackers/gitlab.md](references/trackers/gitlab.md) |
| other (Gitea, Bitbucket, …) | that host's CLI's issue-view JSON command if present; else host REST API |
| any, no CLI / auth error | host REST API per the loaded tracker ref (else generic curl) |

If neither `origin` nor `upstream` resolves to a known issue host: stop, tell the user, do nothing else.
````

- [ ] **Step 2: Verify the edit**

Run: `grep -n "github.com" skills/forge/SKILL.md | head -5`

Expected: the line containing `→ [references/trackers/github.md]` appears. The original "Map host → CLI:" heading is gone; the new "Route by host in `origin` (fallback `upstream`):" heading is present.

Run: `grep -c "gh issue view <N>" skills/forge/SKILL.md`

Expected: `0` — the inline `gh issue view` command is now gone from SKILL.md (it lives in github.md).

---

## Task 4: Slim SKILL.md §Step 2 git-host paragraph

**Files:**
- Modify: `skills/forge/SKILL.md` (the `### git-host issue` subsection under §Step 2)

- [ ] **Step 1: Replace the §Step 2 git-host paragraph**

Open `skills/forge/SKILL.md`. Find this block (currently lines 104–116):

````markdown
### git-host issue

Prefer the Step 1b CLI. Missing / auth error → host REST API, e.g. GitHub:

```bash
curl -sH "Accept: application/vnd.github+json" \
     ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
     "https://api.github.com/repos/owner/repo/issues/<N>"   # comments: same URL + "/comments"
```

(GitLab: `GET /projects/:id/issues/:iid` + `/notes`, token in `PRIVATE-TOKEN`.) Unauth REST is rate-limited — say so if you fall back.

Read **body + every comment** — latest comments often carry the missing repro / decision.
````

Replace it with:

````markdown
### git-host issue

→ The loaded tracker ref ([references/trackers/github.md](references/trackers/github.md) §Step 2 or [references/trackers/gitlab.md](references/trackers/gitlab.md) §Step 2) for the fetch command and the REST fallback. For hosts without a dedicated ref: that host's CLI's issue-view JSON command if present, else curl the host's REST API. Read **body + every comment** regardless.
````

- [ ] **Step 2: Verify the edit**

Run: `grep -c "curl -sH" skills/forge/SKILL.md`

Expected: `0` — the inline curl block is now gone from SKILL.md (it lives in github.md).

Run: `grep -n "loaded tracker ref" skills/forge/SKILL.md`

Expected: one line, containing the new delegation prose.

---

## Task 5: Cross-file verification pass

**Files:**
- Inspect only (no edits): `skills/forge/SKILL.md`, both new tracker files.

- [ ] **Step 1: Verify SKILL.md anchor headings survived**

Run: `grep -nE '^(### Step 1b|### git-host issue|## Step 2)' skills/forge/SKILL.md`

Expected: all three lines present and unchanged (only their *content* shrank, not their *headings*). Numbering is the structural promise other reference files link to.

- [ ] **Step 2: Verify the new file links resolve**

Run:
```bash
test -f skills/forge/references/trackers/github.md && echo "github.md exists" || echo "MISSING github.md"
test -f skills/forge/references/trackers/gitlab.md && echo "gitlab.md exists" || echo "MISSING gitlab.md"
```

Expected:
```
github.md exists
gitlab.md exists
```

- [ ] **Step 3: Verify the four `references/trackers/` files are siblings**

Run: `ls skills/forge/references/trackers/`

Expected output (alphabetical):
```
github.md
gitlab.md
jira.md
linear.md
```

- [ ] **Step 4: Verify no unintended SKILL.md changes**

Run: `wc -l skills/forge/SKILL.md`

Expected: ~294 lines (down from 308 — a ~14-line drop). A delta of −10 to −18 is acceptable; anything outside that range indicates an unintended edit and should be investigated before commit.

- [ ] **Step 5: Verify no orphan curl/gh/glab content in SKILL.md**

Run: `grep -nE '(gh issue view|glab issue view|curl -sH)' skills/forge/SKILL.md`

Expected: empty output. All three patterns now live only in the tracker files.

- [ ] **Step 6: Verify jira.md, linear.md, and other refs untouched**

Run: `git diff --stat skills/forge/references/trackers/jira.md skills/forge/references/trackers/linear.md`

Expected: empty output (no modifications). The PR adds two siblings; it must not touch the existing two.

---

## Task 6: Commit

**Files:**
- All four touched paths.

- [ ] **Step 1: Stage exactly the four affected files**

Run:
```bash
git add skills/forge/SKILL.md \
        skills/forge/references/trackers/github.md \
        skills/forge/references/trackers/gitlab.md \
        docs/plans/2026-05-28-github-gitlab-tracker-refs.md \
        docs/specs/2026-05-28-github-gitlab-tracker-refs.md
```

(The spec is included because the writing-plans handoff amended it with §11 resolutions after the initial commit; the plan file is included because it didn't exist when the spec was first committed.)

- [ ] **Step 2: Verify staging is correct**

Run: `git status`

Expected: exactly five files staged for commit (the four listed above), nothing else, no untracked files.

- [ ] **Step 3: Create the commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
refactor(forge): extract github/gitlab tracker refs from SKILL.md spine

Pure extraction. Moves the per-host issue-fetch prose out of
SKILL.md §Step 1b/§Step 2 into references/trackers/github.md and
references/trackers/gitlab.md, parallel to the existing jira.md and
linear.md. SKILL.md routing table now points at the new files;
§Step 1b and §Step 2 anchor headings are preserved.

No behavior change. No new flags or helper scripts. Strict-purity
discipline: the new files contain only prose already inlined in
SKILL.md today (no env-var clarifiers, no JSON-field explanations,
no synthesized curl blocks).

Also amends the spec with the user-resolved §11 open questions
(strict purity adopted, distribution model pivoted to skill-first
repo) and adds the implementation plan.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Verify the commit landed**

Run: `git log --oneline -1`

Expected: one new commit on top of the previous `docs(forge): spec for github/gitlab tracker ref extraction` commit, with subject `refactor(forge): extract github/gitlab tracker refs from SKILL.md spine`.

Run: `git status`

Expected: `nothing to commit, working tree clean`.

---

## Done criteria

All checkboxes above are checked. The repo:

- Has `skills/forge/references/trackers/{github,gitlab}.md` as new files (strict-purity content).
- Has a slimmer SKILL.md §Step 1b table and §Step 2 git-host paragraph that delegate to the new files.
- Has the amended spec and this plan committed.
- Has no plugin.json bump (intentional — see spec §8).
- Has no README changes (intentional — user handles separately via `/humanizer`).

If any verification step fails, **do not commit**: surface the failure and investigate before proceeding.
