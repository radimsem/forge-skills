# GitHub & GitLab tracker references — design spec

- **Date:** 2026-05-28
- **Status:** Draft (awaiting user review)
- **Target version:** 1.0.1 (doc-only patch per the post-1.0 SemVer policy)
- **Related:** [`2026-05-28-forge-redesign.md`](2026-05-28-forge-redesign.md) §3 (target reference tree); [`../adr/0002-1.0.0-cut.md`](../adr/0002-1.0.0-cut.md) (1.0.0 stability promise)
- **Originating session:** brainstorming session pivot from "broad ideation menu" → focused two-file extract (see this conversation's transcript).

## 1. Goal

Extract the existing per-host (GitHub, GitLab) issue-fetch prose out of `skills/forge/SKILL.md` §Step 1b/§Step 2 into two on-demand-loaded reference files, parallel to the existing `references/trackers/jira.md` and `references/trackers/linear.md`.

Pure extraction — **no behavior changes, no new flags, no new helper scripts.** The new files mirror what is already inlined in SKILL.md; SKILL.md shrinks to a routing table that points at them.

## 2. Why now

Three pull factors:

1. **Symmetry with the tracker subdir.** `references/trackers/` already holds `jira.md` and `linear.md` — Jira-only and Linear-only behavior is delegated out of SKILL.md. The git-host equivalents (GitHub, GitLab) are still inlined, which makes the spine inconsistent.
2. **Headroom for later extension.** A later PR may add genuinely-new GitHub or GitLab behavior (linked-PR discovery, PR/MR template handling, sub-issues, issue-type field, work-item routing). Doing that into already-inlined prose forces a re-shuffle of SKILL.md every time. Pre-establishing the file lets future PRs append, not refactor.
3. **SKILL.md weight.** SKILL.md is 25.7 KB; every kilobyte the spine carries is loaded on every `/forge` invocation. Even the small extraction shaves ~12 lines off the always-loaded surface.

The factor that is **explicitly not driving this** is "new users will need it" — there is no inbound user demand. This is a pre-emptive structural fix.

## 3. Non-goals

This spec ships none of the following. Each is a plausible later PR; conflating them with the extract would balloon scope.

- New flags of any kind (no `github`, no `gitlab`, no host-specific modes).
- New helper scripts (no `repo-host.py`, no `gh-issue-fetch.py`).
- Linked-PR discovery (`Closes #N` mining at Step 4 to surface duplicate work).
- PR / MR template handling at Step 12.
- GitHub sub-issues, Discussions ref-refusal, Projects v2 board context, issue-type field.
- GitLab work-items vs issues vs incidents routing, confidential-issue handling, multi-account hostname resolution.
- REST rate-limit pacing logic.
- A `references/trackers/_generic.md` for hosts beyond GitHub/GitLab — Gitea / Bitbucket / Forgejo / Azure DevOps stay covered by the catch-all row in SKILL.md §Step 1b.
- Any change to `references/trackers/jira.md` or `references/trackers/linear.md`.
- An ADR — doc-only refactor, no architectural decision to record.

## 4. Repo-as-project context

The redesign spec ([§3](2026-05-28-forge-redesign.md#3-file--directory-architecture-target-state-after-phase-5)) already lists `references/trackers/jira.md` and `references/trackers/linear.md` as the target shape. This spec adds two more files to the same subdir; the rest of the target tree is unchanged.

Affected paths:

```
skills/forge/
  SKILL.md                          ← edited (§Step 1b, §Step 2 git-host slimmed)
  references/
    trackers/
      jira.md                       ← unchanged
      linear.md                     ← unchanged
      github.md                     ← NEW
      gitlab.md                     ← NEW
```

No other directories or files touched.

## 5. File 1 — `references/trackers/github.md`

### 5.1 Shape

Mirrors `jira.md`/`linear.md` preamble + per-Step section convention. Sections present only when there is extracted SKILL.md content to host; sections with no inlined content today (e.g. §Step 3, §Step 12) are omitted entirely — a one-line stub would be ceremony, not information.

### 5.2 Section inventory

| Section | Source in current SKILL.md | Verbatim or condensed |
|---|---|---|
| Preamble | new (mirrors jira.md preamble) | new, minimal |
| §Step 1b — Fetch source (resolve) | row 1 of §Step 1b table (`gh` CLI mapping) | extracted |
| §Step 2 — Pull the issue | §Step 2 git-host first paragraph (`gh issue view --json …` command) | extracted verbatim |
| §GitHub-absent fallback | §Step 2 git-host curl block | extracted verbatim |

### 5.3 Content (concrete draft)

```markdown
# Forge — GitHub issue reference

Loaded on demand by SKILL.md **only when `git remote get-url origin` (fallback `upstream`) host is `github.com` or a GitHub Enterprise hostname**. Other git hosts and Atlassian Jira / Linear never touch this file.

## Step 1b — Fetch source (resolve)

`gh` is the primary CLI. GitHub Enterprise hosts are reached by `gh` via its standard host resolution (`GH_HOST` env or `--hostname` flag — `gh` handles this itself; the skill does not configure it).

## Step 2 — Pull the issue

```bash
gh issue view <N> --json number,title,body,state,labels,comments,author,url
```

Comments are included in the JSON above. Read **body + every comment** — latest comments often carry the missing repro / decision.

### GitHub-absent fallback ★

`gh` missing or unauthenticated → host REST API:

```bash
curl -sH "Accept: application/vnd.github+json" \
     ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
     "https://api.github.com/repos/owner/repo/issues/<N>"   # comments: same URL + "/comments"
```

Unauth REST is rate-limited — say so if you fall back.
```

Estimated final length: ~30 lines.

### 5.4 Notes on borderline items

- The "GitHub Enterprise hosts are reached by `gh` via its standard host resolution" sentence is not strict extraction (SKILL.md does not name GHE behavior). It is canonical `gh` behavior, not invented behavior — included because the preamble already names "GH Enterprise" and a reader otherwise has no answer to "how does `gh` know which host?". If strict purity is preferred, drop the sentence; the preamble's host-match rule is sufficient.
- The "Comments are included in the JSON above" sentence is also not strict extraction. SKILL.md only says "Read body + every comment" without telling the reader where the comments come from. The added sentence answers that. Drop it for strict purity; the `--json …,comments,…` field name in the command already encodes the same answer for an attentive reader.

## 6. File 2 — `references/trackers/gitlab.md`

### 6.1 Shape

Same shape as `github.md`.

### 6.2 Section inventory

| Section | Source in current SKILL.md | Verbatim or condensed |
|---|---|---|
| Preamble | new (mirrors jira.md preamble) | new, minimal |
| §Step 1b — Fetch source (resolve) | row 2 of §Step 1b table (`glab` CLI mapping) | extracted, preserves the `--help` hint |
| §Step 2 — Pull the issue | §Step 2 git-host CLI line for `glab` | extracted |
| §GitLab-absent fallback | §Step 2 git-host parenthetical REST hint | extracted + a synthesized curl block in github.md's shape |

### 6.3 Content (concrete draft)

```markdown
# Forge — GitLab issue reference

Loaded on demand by SKILL.md **only when `git remote get-url origin` (fallback `upstream`) host matches `gitlab.*` (including self-hosted)**. Other git hosts and Atlassian Jira / Linear never touch this file.

## Step 1b — Fetch source (resolve)

`glab` is the primary CLI. Self-hosted GitLab instances are reached by `glab` via `GITLAB_HOST` env (`glab` handles this itself; the skill does not configure it).

## Step 2 — Pull the issue

```bash
glab issue view <N> -F json   # confirm flag via `glab issue view --help` — the JSON output flag changed across `glab` versions
```

Comments are included in the JSON above. Read **body + every comment** — latest comments often carry the missing repro / decision.

### GitLab-absent fallback ★

`glab` missing or unauthenticated → host REST API:

```bash
curl -sH "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
     "https://gitlab.com/api/v4/projects/:id/issues/:iid"   # comments: same URL + "/notes"
```

`:id` is the URL-encoded project path (`owner%2Frepo`) or the numeric project ID. Unauth REST is rate-limited — say so if you fall back.
```

Estimated final length: ~30 lines.

### 6.4 Notes on borderline items

- The "self-hosted GitLab instances are reached by `glab` via `GITLAB_HOST`" sentence parallels the github.md GHE sentence. Same drop-for-strict-purity offer.
- The "Comments are included in the JSON above" sentence parallels the github.md one. Same drop-for-strict-purity offer.
- The curl block is synthesized in github.md's shape; the original SKILL.md parenthetical (`GET /projects/:id/issues/:iid` + `/notes`, token in `PRIVATE-TOKEN`) carries the same information in prose. The shape change is purely a presentation choice for symmetry. If strict purity is preferred, replace the code block with a one-line prose description in SKILL.md's original wording.
- The `:id` encoding sentence is canonical GitLab REST behavior, not invented. Same borderline call as the GHE sentence — drop for strict purity if desired.

## 7. SKILL.md changes

### 7.1 §Step 1b table

Before (current):

```markdown
### Step 1b — git-host issue

Map host → CLI:

| Host in remote URL | CLI | Issue fetch |
|---|---|---|
| `github.com` / GH Enterprise | `gh` | `gh issue view <N> --json number,title,body,state,labels,comments,author,url` |
| `gitlab.*` | `glab` | `glab issue view <N> -F json` (confirm flag via `glab issue view --help`) |
| other (Gitea, Bitbucket, …) | that host's CLI if present | its issue-view JSON command |
| any, no CLI / auth error | — | host REST API (see Step 2) |

If neither `origin` nor `upstream` resolves to a known issue host: stop, tell the user, do nothing else.
```

After:

```markdown
### Step 1b — git-host issue

Route by host in `origin` (fallback `upstream`):

| Host in remote URL | Reference |
|---|---|
| `github.com` / GH Enterprise | → [references/trackers/github.md](references/trackers/github.md) |
| `gitlab.*` (incl. self-hosted) | → [references/trackers/gitlab.md](references/trackers/gitlab.md) |
| other (Gitea, Bitbucket, …) | that host's CLI's issue-view JSON command if present; else host REST API |
| any, no CLI / auth error | host REST API per the loaded tracker ref (else generic curl) |

If neither `origin` nor `upstream` resolves to a known issue host: stop, tell the user, do nothing else.
```

### 7.2 §Step 2 git-host paragraph

Before (current):

```markdown
### git-host issue

Prefer the Step 1b CLI. Missing / auth error → host REST API, e.g. GitHub:

```bash
curl -sH "Accept: application/vnd.github+json" \
     ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
     "https://api.github.com/repos/owner/repo/issues/<N>"   # comments: same URL + "/comments"
```

(GitLab: `GET /projects/:id/issues/:iid` + `/notes`, token in `PRIVATE-TOKEN`.) Unauth REST is rate-limited — say so if you fall back.

Read **body + every comment** — latest comments often carry the missing repro / decision.
```

After:

```markdown
### git-host issue

→ The loaded tracker ref ([references/trackers/github.md](references/trackers/github.md) §Step 2 or [references/trackers/gitlab.md](references/trackers/gitlab.md) §Step 2) for the fetch command and the REST fallback. For hosts without a dedicated ref: that host's CLI's issue-view JSON command if present, else curl the host's REST API. Read **body + every comment** regardless.
```

### 7.3 Anchor preservation

- `§Step 1b` and `§Step 2` headings stay; only their content shrinks. No anchor a peer reference might link to is removed or renamed.
- New links from SKILL.md → `references/trackers/github.md`, `references/trackers/gitlab.md` are added.
- No other SKILL.md section is touched.

### 7.4 Net line delta

| File | Before | After | Δ |
|---|---|---|---|
| `skills/forge/SKILL.md` | 308 lines | ~294 lines | −14 |
| `skills/forge/references/trackers/github.md` | absent | ~30 lines | +30 |
| `skills/forge/references/trackers/gitlab.md` | absent | ~30 lines | +30 |
| **Total** | | | **+46** |

Always-loaded surface (SKILL.md) shrinks by ~14 lines; on-demand surface grows by 60. Net total grows because of new preambles + the GHE/self-hosted clarifier sentences.

## 8. Versioning & rollback

- **Bump (target):** 1.0.0 → 1.0.1. Doc-only refactor with no behavior change qualifies as a patch under the post-1.0 SemVer policy.
- **plugin.json status:** **no `plugin.json` exists anywhere in the repo as of 2026-05-28** (verified via `find . -name plugin.json -not -path '*/.git/*'` → empty). The README and the redesign spec both reference `1.0.0/.claude-plugin/plugin.json`, but the recent `chore: move v1.0.0 into root skills folder` commit (13d52fb) flattened the version directory without re-creating the manifest at a new location. This is a pre-existing repo issue, not caused by this spec.
- **Implication for this PR:** the version-bump step in §10 cannot land until the manifest situation is resolved. Three resolutions, each a separate decision the user must make before writing-plans runs:
  - **(R1)** Recreate `.claude-plugin/plugin.json` at the repo root with `"version": "1.0.1"`, ship the bump in this PR.
  - **(R2)** Ship this PR without a version bump; defer the bump until the manifest is recreated as its own PR. SemVer promise resumes once the manifest is back.
  - **(R3)** Decide the repo no longer ships as a single-version plugin (rooted vs versioned dirs is in flux) and remove all manifest-bump steps from forge-skills' shipping process.
- **Rollback:** revert the single PR. SKILL.md anchors are preserved, so no downstream link rot regardless of which resolution is chosen.

## 9. Verification

- **Manual:** open SKILL.md, follow the §Step 1b table's github.md and gitlab.md links — both resolve, both files exist, both contain the extracted prose.
- **Behavior parity:** a default-mode `/forge <N>` invocation on a GitHub repo and on a GitLab repo produces the same fetch commands as before. No test harness exists for the skill itself; "behavior" here means the on-disk prose the agent reads is semantically equivalent.
- **Reviewer engines** (`codex`, `coderabbit`): expected to flag the change as a low-risk doc refactor. Project subagents, if configured in the runtime, may want to verify the link targets resolve.

## 10. Plan shape (for writing-plans to expand)

Single atomic PR, sequenced as:

1. Create `skills/forge/references/trackers/github.md` (~30 lines, content per §5.3).
2. Create `skills/forge/references/trackers/gitlab.md` (~30 lines, content per §6.3).
3. Edit `skills/forge/SKILL.md` §Step 1b table per §7.1.
4. Edit `skills/forge/SKILL.md` §Step 2 git-host paragraph per §7.2.
5. **Conditional on §8 resolution:** if (R1), recreate `plugin.json` and bump to `1.0.1`. If (R2) or (R3), skip — no manifest change in this PR.
6. Verify §9 (manual link-walk + content read).
7. Commit per Conventional Commits convention: `refactor(forge): extract github/gitlab tracker refs from SKILL.md spine`.

writing-plans owns the per-step ordering, commit decomposition (if more than one), and verification command list.

## 11. Open questions for the user before writing-plans

- **Manifest resolution (§8 R1/R2/R3).** Pick one before writing-plans; the plan's step 5 depends on which.
- **Strict purity.** The borderline-extension sentences (§5.4, §6.4) are kept in the draft. If you'd rather strict purity, say so before writing-plans and the spec gets a one-line amendment.
- **README update.** The repo `README.md` still references `1.0.0/skills/forge/SKILL.md` and `1.0.0/CLAUDE.md` (paths that no longer exist post-flatten). Adjacent to this PR or out of scope? Recommendation: out of scope — fix in its own PR, but flag here so it's not lost.
