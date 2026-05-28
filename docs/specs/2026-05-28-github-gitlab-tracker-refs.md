# GitHub & GitLab tracker references — design spec

- **Date:** 2026-05-28
- **Status:** Approved (user-resolved open questions inline; ready for writing-plans)
- **Target version:** *deferred* — see §8. No plugin-manifest bump in this PR.
- **Related:** [`2026-05-28-forge-redesign.md`](2026-05-28-forge-redesign.md) §3 (target reference tree); [`../adr/0002-1.0.0-cut.md`](../adr/0002-1.0.0-cut.md) (1.0.0 stability promise — context only, not a constraint here)
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

### 5.3 Content (final, strict purity)

```markdown
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
```

Estimated final length: ~22 lines.

### 5.4 Strict-purity discipline

The draft above contains **no prose that is not already in SKILL.md** verbatim or trivially-rearranged. Specifically:

- No "GHE reached via `GH_HOST`" sentence (cut — canonical `gh` behavior, but not in SKILL.md today).
- No "Comments are included in the JSON above" sentence (cut — the `--json …,comments,…` field name encodes the same fact for an attentive reader).
- No prose explaining what fields the JSON contains beyond the command itself.

Headings, code fences, and preamble structure are presentation — not new content. The preamble's "loaded on demand…" sentence pattern is copied from `jira.md`/`linear.md`.

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

### 6.3 Content (final, strict purity)

```markdown
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
```

Estimated final length: ~18 lines.

### 6.4 Strict-purity discipline

Same discipline as §5.4. Specifically:

- No "self-hosted reached via `GITLAB_HOST`" sentence (cut).
- No "Comments are included in the JSON above" sentence (cut).
- No synthesized curl block — the original SKILL.md parenthetical is preserved verbatim as the prose form of the fallback. github.md keeps a curl block because **that block was already in SKILL.md**; gitlab.md gets prose because **the GitLab fallback was already prose**. The two files end up asymmetric in shape, but each is faithful to what existed.
- No `:id` encoding explanation (cut — canonical GitLab REST behavior, but not in SKILL.md).
- The "the JSON output flag changed across `glab` versions" trailing-clause is dropped; only the `--help` hint remains, matching SKILL.md's wording verbatim.

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
| `skills/forge/references/trackers/github.md` | absent | ~22 lines | +22 |
| `skills/forge/references/trackers/gitlab.md` | absent | ~18 lines | +18 |
| **Total** | | | **+26** |

Always-loaded surface (SKILL.md) shrinks by ~14 lines; on-demand surface grows by ~40. Net total grows modestly because of two new preambles. Under strict purity the new files carry no extension content; they exist to host what was already inlined and to give future PRs a place to append host-specific behavior without re-shuffling SKILL.md.

## 8. Distribution model & rollback

**User decision (2026-05-28):** `forge-skills` is a **skill repository**, not a plugin repository. The plugin-manifest model from 1.0.0 is **deprecated for this repo**:

- **Primary install path** is now [`npx skills`](https://github.com/vercel/skills) (Vercel's skill runner). The skill is consumed directly from the source tree; no manifest required.
- **Plugin manifests are optional per-consumer.** A Claude Code `.claude-plugin/plugin.json`, a Cursor manifest, a Codex manifest, etc. may each be added as separate opt-in artifacts in future PRs if the matching consumer wants one. None is the canonical install path.
- **No version bump in this PR.** SemVer-policy language from `1.0.0/README.md` no longer governs how this repo ships. The 1.0.0 cut ADR remains accurate as history; it is not a constraint on doc-only refactors going forward.
- **README rewrite.** The user will recreate `README.md` separately via `/humanizer` to document the `npx skills` install path and the forge skill's capabilities. **Out of scope for this PR.**
- **Rollback:** revert the single PR. SKILL.md anchors are preserved; the two new files are independent; no downstream link rot.

## 9. Verification

- **Manual:** open SKILL.md, follow the §Step 1b table's github.md and gitlab.md links — both resolve, both files exist, both contain the extracted prose.
- **Behavior parity:** a default-mode `/forge <N>` invocation on a GitHub repo and on a GitLab repo produces the same fetch commands as before. No test harness exists for the skill itself; "behavior" here means the on-disk prose the agent reads is semantically equivalent.
- **Reviewer engines** (`codex`, `coderabbit`): expected to flag the change as a low-risk doc refactor. Project subagents, if configured in the runtime, may want to verify the link targets resolve.

## 10. Plan shape (for writing-plans to expand)

Single atomic PR, sequenced as:

1. Create `skills/forge/references/trackers/github.md` (~22 lines, content per §5.3).
2. Create `skills/forge/references/trackers/gitlab.md` (~18 lines, content per §6.3).
3. Edit `skills/forge/SKILL.md` §Step 1b table per §7.1.
4. Edit `skills/forge/SKILL.md` §Step 2 git-host paragraph per §7.2.
5. Verify §9 (manual link-walk + content read).
6. Commit per Conventional Commits convention: `refactor(forge): extract github/gitlab tracker refs from SKILL.md spine`.

No plugin-manifest step (see §8 — distribution-model pivot). writing-plans owns the per-step ordering, commit decomposition (if more than one), and verification command list.

## 11. Resolved questions (audit trail)

All §11 open questions were resolved by the user at the writing-plans handoff:

- **Manifest (was R1/R2/R3).** Resolved by §8 rewrite: skill-first repo, plugin manifest is optional per-consumer, no version bump in this PR, primary install via `npx skills`.
- **Strict purity.** Adopted. Both borderline-extension sentence pairs dropped; gitlab.md fallback returns to SKILL.md's original prose form (no synthesized curl block). See §5.4 / §6.4 for the discipline.
- **README path rot.** Out of scope for this PR. User will recreate `README.md` via `/humanizer` in a separate session — folded into the §8 distribution-model pivot.
