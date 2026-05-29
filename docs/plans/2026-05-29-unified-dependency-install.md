# Unified Dependency Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a detection-first, idempotent `install.sh` at the repo root that installs every external skill and plugin the forge skill composes, then installs forge itself last.

**Architecture:** A single POSIX `sh` script split into pure, sourceable functions (capture vs parse, build vs run) so the parsing/diff/arg logic is unit-testable with fixtures and no network. The script spans two install mechanisms — `npx skills add` for bare skills (Tiers 1/4/6) and `claude plugin` for plugins (Tiers 2/3) — because `npx skills` cannot install plugin agents/hooks/companion scripts. A bottom-of-file entrypoint guard lets tests source the script without executing `main`.

**Tech Stack:** POSIX shell (`sh`), `npx skills@latest` (Vercel skills CLI), `claude plugin` (Claude Code CLI), `awk`/`sed`/`grep` for parsing, a hand-rolled `tests/install_test.sh` assertion harness (stubs `npx`/`claude` as shell functions).

**Spec:** [`docs/specs/2026-05-29-unified-dependency-install.md`](../specs/2026-05-29-unified-dependency-install.md)

---

## File structure

| File | Responsibility |
|---|---|
| `install.sh` (repo root) | The orchestrator. All logic in functions; `main "$@"` runs only when executed, not when sourced. |
| `tests/install_test.sh` | Assertion harness. Stubs `npx`/`claude` as functions, sets fixtures, sources `install.sh`, asserts on pure functions. |
| `tests/fixtures/skills-list.txt` | Captured `npx skills list -g` sample (ANSI-stripped) for parser tests. |
| `tests/fixtures/plugin-list.txt` | Captured `claude plugin list` sample for plugin-detection tests. |
| `skills/find-docs/SKILL.md` | Vendored `find-docs` skill (copied from the host working copy). |
| `skills/forge/references/dependencies.md` | The dependency inventory + pointer to `install.sh`. |
| `skills/forge/SKILL.md` | One added line linking to `references/dependencies.md`. |
| `README.md` (root) | Replace stale `/plugin install …/1.0.0` block with `./install.sh`; fix `1.0.0/`→`skills/` path drift. |

The dependency inventory is encoded **once** as a pipe-delimited data table inside `install.sh` (`tier|kind|source|name`). Every loop reads that table — no inventory is restated elsewhere in the script.

---

## Conventions for this plan

- Booleans are strings: `"1"` = true, `""` = false; test with `[ -n "$x" ]`.
- The script never calls `command npx`/`command claude` — always bare `npx`/`claude` so test stubs (shell functions) shadow them.
- ANSI strip helper uses a literal ESC built with `printf` (portable across GNU/BSD sed).
- Agent target default: `claude-code,codex,cursor,opencode`.
- Commit style: conventional commits, `feat(install): …` / `docs(forge): …` / `chore: …`.

---

## Task 1: Scaffold `install.sh` + entrypoint guard + arg parsing

**Files:**
- Create: `install.sh`
- Create: `tests/install_test.sh`

- [ ] **Step 1: Create the test harness with the first failing test (arg parsing)**

Create `tests/install_test.sh`:

```sh
#!/usr/bin/env sh
# Unit tests for install.sh. Sources the script with INSTALL_SH_SOURCED=1 so main() does not run.
set -u
FAILS=0
pass() { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; FAILS=$((FAILS+1)); }
assert_eq() { # actual expected msg
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (expected [$2] got [$1])"; fi
}
assert_true()  { if "$@"; then pass "$*"; else fail "$* (expected success)"; fi; }
assert_false() { if "$@"; then fail "$* (expected failure)"; else pass "$*"; fi; }

# Resolve repo root relative to this test file.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

INSTALL_SH_SOURCED=1
# shellcheck disable=SC1090
. "$ROOT/install.sh"

# --- arg parsing ---
parse_args --yes --force --agents "claude-code,codex" --skills-only
assert_eq "$OPT_YES" "1" "parse_args: --yes sets OPT_YES"
assert_eq "$OPT_FORCE" "1" "parse_args: --force sets OPT_FORCE"
assert_eq "$OPT_SKILLS_ONLY" "1" "parse_args: --skills-only sets OPT_SKILLS_ONLY"
assert_eq "$OPT_AGENTS" "claude-code,codex" "parse_args: --agents override"

parse_args
assert_eq "$OPT_YES" "" "parse_args: defaults OPT_YES empty"
assert_eq "$OPT_AGENTS" "claude-code,codex,cursor,opencode" "parse_args: default agents"

printf '\n%s\n' "FAILS=$FAILS"
[ "$FAILS" -eq 0 ]
```

- [ ] **Step 2: Run the test, verify it fails**

Run: `sh tests/install_test.sh`
Expected: FAIL — `install.sh` does not exist yet (`.: cannot open … install.sh`).

- [ ] **Step 3: Create `install.sh` with the guard + `parse_args`**

Create `install.sh`:

```sh
#!/usr/bin/env sh
# install.sh — unified dependency installer for the forge skill.
# Installs forge's external skills (npx skills) and plugins (claude plugin), then forge itself last.
set -u

DEFAULT_AGENTS="claude-code,codex,cursor,opencode"

OPT_YES=""
OPT_FORCE=""
OPT_SKILLS_ONLY=""
OPT_AGENTS="$DEFAULT_AGENTS"

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Installs every skill and plugin the forge skill composes, then forge itself last.

Options:
  -y, --yes            Non-interactive (pass -y to npx skills; auto-accept plugin installs)
      --force          Reinstall even when detection reports a dependency present
      --agents "a,b"   Override the multi-agent target (default: claude-code,codex,cursor,opencode)
      --skills-only    Install bare skills only; skip the claude plugin block (non-Claude-Code hosts)
  -h, --help           Show this help
EOF
}

parse_args() {
  OPT_YES=""; OPT_FORCE=""; OPT_SKILLS_ONLY=""; OPT_AGENTS="$DEFAULT_AGENTS"
  while [ $# -gt 0 ]; do
    case "$1" in
      -y|--yes) OPT_YES="1" ;;
      --force) OPT_FORCE="1" ;;
      --skills-only) OPT_SKILLS_ONLY="1" ;;
      --agents) shift; OPT_AGENTS="${1:-$DEFAULT_AGENTS}" ;;
      -h|--help) usage; return 2 ;;
      *) printf 'install.sh: unknown option: %s\n' "$1" >&2; usage >&2; return 2 ;;
    esac
    shift
  done
  return 0
}

main() {
  parse_args "$@" || return $?
  printf 'install.sh scaffold OK (agents: %s)\n' "$OPT_AGENTS"
}

# --- entrypoint guard: skip main() when sourced by tests ---
if [ "${INSTALL_SH_SOURCED:-0}" != "1" ]; then
  main "$@"
fi
```

- [ ] **Step 4: Run the test, verify it passes**

Run: `sh tests/install_test.sh`
Expected: all `ok` lines, `FAILS=0`, exit 0.

- [ ] **Step 5: Make scripts executable and smoke-test help**

Run:
```sh
chmod +x install.sh tests/install_test.sh
./install.sh --help
```
Expected: usage text prints; exit code 2 (help is not a successful run).

- [ ] **Step 6: Commit**

```sh
git add install.sh tests/install_test.sh
git commit -m "feat(install): scaffold install.sh with arg parsing and test harness"
```

---

## Task 2: ANSI strip + agent slug↔name mapping

**Files:**
- Modify: `install.sh` (add helpers above `main`)
- Modify: `tests/install_test.sh` (add tests)

- [ ] **Step 1: Add failing tests**

Append to `tests/install_test.sh` before the final `printf '\n%s\n' "FAILS=$FAILS"` line:

```sh
# --- strip_ansi ---
ESC=$(printf '\033')
colored="${ESC}[36mtdd${ESC}[0m ${ESC}[38;5;102m~/x${ESC}[0m"
assert_eq "$(printf '%s' "$colored" | strip_ansi)" "tdd ~/x" "strip_ansi removes color codes"

# --- agent_slug_to_name ---
assert_eq "$(agent_slug_to_name claude-code)" "Claude Code" "slug claude-code -> Claude Code"
assert_eq "$(agent_slug_to_name codex)" "Codex" "slug codex -> Codex"
assert_eq "$(agent_slug_to_name opencode)" "OpenCode" "slug opencode -> OpenCode"
assert_eq "$(agent_slug_to_name cursor)" "Cursor" "slug cursor -> Cursor"
```

- [ ] **Step 2: Run, verify new tests fail**

Run: `sh tests/install_test.sh`
Expected: FAIL — `strip_ansi: not found` / `agent_slug_to_name: not found`.

- [ ] **Step 3: Implement the helpers**

In `install.sh`, add above `main()`:

```sh
# Strip ANSI SGR/escape sequences. ESC built via printf for GNU/BSD sed portability.
strip_ansi() {
  sed "s/$(printf '\033')\[[0-9;]*[A-Za-z]//g"
}

# Map an `npx skills` agent slug to the display name `npx skills list` prints.
agent_slug_to_name() {
  case "$1" in
    claude-code) printf 'Claude Code' ;;
    codex) printf 'Codex' ;;
    cursor) printf 'Cursor' ;;
    opencode) printf 'OpenCode' ;;
    pi) printf 'Pi' ;;
    *) printf '%s' "$1" ;;
  esac
}
```

- [ ] **Step 4: Run, verify pass**

Run: `sh tests/install_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 5: Commit**

```sh
git add install.sh tests/install_test.sh
git commit -m "feat(install): add ansi strip and agent slug-to-name mapping"
```

---

## Task 3: Skill detection parser (capture/parse split)

**Files:**
- Modify: `install.sh`
- Create: `tests/fixtures/skills-list.txt`
- Modify: `tests/install_test.sh`

- [ ] **Step 1: Create the fixture (real `npx skills list` shape, ANSI already stripped)**

Create `tests/fixtures/skills-list.txt`:

```
Global Skills

Mattpocock Skills
  diagnose ~/.agents/skills/diagnose
    Agents: Claude Code
  grill-with-docs ~/.agents/skills/grill-with-docs
    Agents: Claude Code, Pi
  tdd ~/.agents/skills/tdd
    Agents: Claude Code

General
  greploop ~/.agents/skills/greploop
    Agents: Claude Code, Codex
```

- [ ] **Step 2: Add failing tests**

Append to `tests/install_test.sh` (before the final summary lines):

```sh
# --- skill detection parser ---
SKILLS_LIST_RAW=$(cat "$ROOT/tests/fixtures/skills-list.txt")

assert_eq "$(parse_skill_agents tdd)" "Claude Code" "parse_skill_agents: tdd -> Claude Code"
assert_eq "$(parse_skill_agents grill-with-docs)" "Claude Code, Pi" "parse_skill_agents: multi-agent"
assert_eq "$(parse_skill_agents not-installed)" "" "parse_skill_agents: absent skill -> empty"

assert_true  agent_has_skill greploop codex   "agent_has_skill: greploop on codex"
assert_false agent_has_skill tdd codex         "agent_has_skill: tdd NOT on codex"
assert_false agent_has_skill not-installed claude-code "agent_has_skill: absent skill"

assert_eq "$(agents_missing_skill tdd 'claude-code,codex,cursor')" "codex cursor" \
  "agents_missing_skill: tdd missing on codex,cursor"
assert_eq "$(agents_missing_skill grill-with-docs 'claude-code')" "" \
  "agents_missing_skill: nothing missing"
assert_eq "$(agents_missing_skill not-installed 'claude-code,codex')" "claude-code codex" \
  "agents_missing_skill: absent skill -> all targeted"
```

- [ ] **Step 3: Run, verify fail**

Run: `sh tests/install_test.sh`
Expected: FAIL — `parse_skill_agents: not found`.

- [ ] **Step 4: Implement the parser functions**

In `install.sh`, add above `main()`:

```sh
# Reads $SKILLS_LIST_RAW (captured `npx skills list` output). Echoes the comma-separated
# display-name list for the given skill, or empty if the skill is absent.
parse_skill_agents() { # $1=skill name
  printf '%s\n' "${SKILLS_LIST_RAW:-}" | strip_ansi | awk -v want="$1" '
    /^  [^ ]/ { found = ($1 == want) }
    /^    Agents:/ && found {
      sub(/^    Agents:[ ]*/, "")
      print
      found = 0
    }
  '
}

# True if the skill is installed on the given agent slug.
agent_has_skill() { # $1=skill $2=agent-slug
  _display=$(agent_slug_to_name "$2")
  _agents=$(parse_skill_agents "$1")
  [ -n "$_agents" ] || return 1
  case ",$(printf '%s' "$_agents" | sed 's/, /,/g')," in
    *",$_display,"*) return 0 ;;
  esac
  return 1
}

# Echoes the space-separated subset of targeted slugs missing the skill.
agents_missing_skill() { # $1=skill $2=csv-of-slugs
  _miss=""
  _oldifs=$IFS; IFS=','
  for _a in $2; do
    IFS=$_oldifs
    agent_has_skill "$1" "$_a" || _miss="$_miss $_a"
    IFS=','
  done
  IFS=$_oldifs
  printf '%s' "${_miss# }"
}
```

- [ ] **Step 5: Run, verify pass**

Run: `sh tests/install_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 6: Commit**

```sh
git add install.sh tests/install_test.sh tests/fixtures/skills-list.txt
git commit -m "feat(install): add per-agent skill detection parser"
```

---

## Task 4: Plugin detection

**Files:**
- Modify: `install.sh`
- Create: `tests/fixtures/plugin-list.txt`
- Modify: `tests/install_test.sh`

- [ ] **Step 1: Create the fixture (real `claude plugin list` shape)**

Create `tests/fixtures/plugin-list.txt`:

```
Installed plugins:

  ❯ superpowers@claude-plugins-official
    Version: 5.1.0
    Scope: user
    Status: ✔ enabled

  ❯ coderabbit@claude-plugins-official
    Version: 1.1.1
    Scope: user
    Status: ✔ enabled
```

- [ ] **Step 2: Add failing tests**

Append to `tests/install_test.sh`:

```sh
# --- plugin detection ---
PLUGINS_LIST_RAW=$(cat "$ROOT/tests/fixtures/plugin-list.txt")
assert_true  plugin_installed "superpowers@claude-plugins-official" "plugin_installed: superpowers"
assert_true  plugin_installed "coderabbit@claude-plugins-official"  "plugin_installed: coderabbit"
assert_false plugin_installed "codex@openai-codex"                   "plugin_installed: codex absent"
assert_false plugin_installed "super@claude-plugins-official"        "plugin_installed: no prefix match"
```

- [ ] **Step 3: Run, verify fail**

Run: `sh tests/install_test.sh`
Expected: FAIL — `plugin_installed: not found`.

- [ ] **Step 4: Implement**

In `install.sh`, add above `main()`:

```sh
# Reads $PLUGINS_LIST_RAW (captured `claude plugin list`). True if plugin@marketplace present.
# Anchored so "super@m" does not match "superpowers@m".
plugin_installed() { # $1=plugin@marketplace
  printf '%s\n' "${PLUGINS_LIST_RAW:-}" | strip_ansi \
    | grep -qE "(^|[[:space:]])$(printf '%s' "$1" | sed 's/[.[\*^$/]/\\&/g')([[:space:]]|\$)"
}
```

- [ ] **Step 5: Run, verify pass**

Run: `sh tests/install_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 6: Commit**

```sh
git add install.sh tests/install_test.sh tests/fixtures/plugin-list.txt
git commit -m "feat(install): add plugin detection from claude plugin list"
```

---

## Task 5: Command builders (build/run split)

**Files:**
- Modify: `install.sh`
- Modify: `tests/install_test.sh`

- [ ] **Step 1: Add failing tests**

Append to `tests/install_test.sh`:

```sh
# --- command builders ---
OPT_YES=""
assert_eq "$(build_skill_add_cmd mattpocock/skills tdd 'claude-code,codex')" \
  "npx -y skills@latest add mattpocock/skills -s tdd -a claude-code -a codex" \
  "build_skill_add_cmd: basic"

OPT_YES="1"
assert_eq "$(build_skill_add_cmd greptileai/skills greploop 'claude-code')" \
  "npx -y skills@latest add greptileai/skills -s greploop -a claude-code -y" \
  "build_skill_add_cmd: --yes appends -y"
OPT_YES=""

assert_eq "$(build_plugin_marketplace_cmd anthropics/claude-plugins-official)" \
  "claude plugin marketplace add anthropics/claude-plugins-official" \
  "build_plugin_marketplace_cmd"
assert_eq "$(build_plugin_install_cmd superpowers@claude-plugins-official)" \
  "claude plugin install superpowers@claude-plugins-official -s user" \
  "build_plugin_install_cmd"
```

- [ ] **Step 2: Run, verify fail**

Run: `sh tests/install_test.sh`
Expected: FAIL — builders not found.

- [ ] **Step 3: Implement**

In `install.sh`, add above `main()`:

```sh
# Build (do not run) the npx skills add command for a skill onto specific agents.
build_skill_add_cmd() { # $1=source $2=skill $3=csv-of-agent-slugs
  _cmd="npx -y skills@latest add $1 -s $2"
  _oldifs=$IFS; IFS=','
  for _a in $3; do _cmd="$_cmd -a $_a"; done
  IFS=$_oldifs
  [ -n "$OPT_YES" ] && _cmd="$_cmd -y"
  printf '%s' "$_cmd"
}

build_plugin_marketplace_cmd() { # $1=marketplace source (owner/repo)
  printf 'claude plugin marketplace add %s' "$1"
}

build_plugin_install_cmd() { # $1=plugin@marketplace
  printf 'claude plugin install %s -s user' "$1"
}
```

- [ ] **Step 4: Run, verify pass**

Run: `sh tests/install_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 5: Commit**

```sh
git add install.sh tests/install_test.sh
git commit -m "feat(install): add skill/plugin command builders"
```

---

## Task 6: Dependency inventory data table + tier iterator

**Files:**
- Modify: `install.sh`
- Modify: `tests/install_test.sh`

- [ ] **Step 1: Add failing tests**

Append to `tests/install_test.sh`:

```sh
# --- inventory data (table has exactly 16 rows: 9 tier-1, 1 tier-2, 2 tier-3, 3 tier-4, 1 tier-6) ---
assert_eq "$(deps_table | grep -c '^[1-6]|')" "16" "deps_table: 16 dependency rows"
assert_eq "$(deps_table | awk -F'|' '$1==6{print $4}')" "forge" "deps_table: tier 6 is forge"
assert_eq "$(deps_table | awk -F'|' '$1==1 && $2=="skill"{c++} END{print c}')" "9" \
  "deps_table: 9 tier-1 skills (7 mattpocock + bootstrap + karpathy)"
# forge must be the last skill row encountered (installed last)
assert_eq "$(deps_table | awk -F'|' '$2=="skill"{last=$4} END{print last}')" "forge" \
  "deps_table: forge is the final skill row"
```

- [ ] **Step 2: Run, verify fail**

Run: `sh tests/install_test.sh`
Expected: FAIL — `deps_table: not found`.

- [ ] **Step 3: Implement the single-source inventory**

In `install.sh`, add above `main()`. Order matters: rows are processed top-to-bottom and forge is last.

```sh
# Single source of truth for forge's external dependencies.
# Columns: tier|kind|source|name
#   kind=skill  -> source is an npx skills add source (owner/repo or "." for this repo); name = -s skill
#   kind=plugin -> source is the marketplace owner/repo; name = plugin@marketplace
deps_table() {
  cat <<'EOF'
1|skill|mattpocock/skills|tdd
1|skill|mattpocock/skills|grill-me
1|skill|mattpocock/skills|grill-with-docs
1|skill|mattpocock/skills|to-issues
1|skill|mattpocock/skills|diagnose
1|skill|mattpocock/skills|write-a-skill
1|skill|mattpocock/skills|improve-codebase-architecture
1|skill|mattpocock/skills|setup-matt-pocock-skills
1|skill|forrestchang/andrej-karpathy-skills|karpathy-guidelines
2|plugin|anthropics/claude-plugins-official|superpowers@claude-plugins-official
3|plugin|openai/codex-plugin-cc|codex@openai-codex
3|plugin|anthropics/claude-plugins-official|coderabbit@claude-plugins-official
4|skill|greptileai/skills|greploop
4|skill|greptileai/skills|check-pr
4|skill|.|find-docs
6|skill|.|forge
EOF
}
```

- [ ] **Step 4: Run, verify pass**

Run: `sh tests/install_test.sh`
Expected: `FAILS=0`. (If the row count differs, you edited the table — update the `16`/`9` assertions to match what you actually ship.)

- [ ] **Step 5: Commit**

```sh
git add install.sh tests/install_test.sh
git commit -m "feat(install): add dependency inventory data table"
```

---

## Task 7: Status table renderer (detection-first reporting)

**Files:**
- Modify: `install.sh`
- Modify: `tests/install_test.sh`

- [ ] **Step 1: Add failing tests**

Append to `tests/install_test.sh`:

```sh
# --- status row rendering ---
# Uses the skills/plugins fixtures already loaded above.
OPT_AGENTS="claude-code,codex"
assert_eq "$(status_row 1 skill mattpocock/skills tdd)" \
  "+ [skill] tdd (missing: codex)" "status_row: skill partially present"
assert_eq "$(status_row 1 skill mattpocock/skills not-installed)" \
  "+ [skill] not-installed (missing: claude-code codex)" "status_row: skill fully absent"
assert_eq "$(status_row 2 plugin anthropics/claude-plugins-official superpowers@claude-plugins-official)" \
  "= [plugin] superpowers@claude-plugins-official (present)" "status_row: plugin present"
assert_eq "$(status_row 3 plugin openai/codex-plugin-cc codex@openai-codex)" \
  "+ [plugin] codex@openai-codex (will install)" "status_row: plugin absent"
```

(`SKILLS_LIST_RAW` from the Task 3 fixture has `tdd` on Claude Code only; `PLUGINS_LIST_RAW` from Task 4 has superpowers but not codex.)

- [ ] **Step 2: Run, verify fail**

Run: `sh tests/install_test.sh`
Expected: FAIL — `status_row: not found`.

- [ ] **Step 3: Implement**

In `install.sh`, add above `main()`:

```sh
# Render one detection status line. "=" present (skip), "+" will install.
status_row() { # $1=tier $2=kind $3=source $4=name
  case "$2" in
    skill)
      _missing=$(agents_missing_skill "$4" "$OPT_AGENTS")
      if [ -z "$_missing" ] && [ -z "$OPT_FORCE" ]; then
        printf '= [skill] %s (present)' "$4"
      else
        [ -n "$OPT_FORCE" ] && _missing="$OPT_AGENTS (forced)" && _missing=$(printf '%s' "$_missing" | tr ',' ' ')
        printf '+ [skill] %s (missing: %s)' "$4" "$_missing"
      fi
      ;;
    plugin)
      if plugin_installed "$4" && [ -z "$OPT_FORCE" ]; then
        printf '= [plugin] %s (present)' "$4"
      else
        printf '+ [plugin] %s (will install)' "$4"
      fi
      ;;
  esac
}

# Print the full status table by walking the inventory.
print_status_table() {
  printf '\nDependency status (target agents: %s):\n' "$OPT_AGENTS"
  deps_table | while IFS='|' read -r _tier _kind _src _name; do
    [ -n "$_tier" ] || continue
    printf '  %s\n' "$(status_row "$_tier" "$_kind" "$_src" "$_name")"
  done
}
```

- [ ] **Step 4: Run, verify pass**

Run: `sh tests/install_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 5: Commit**

```sh
git add install.sh tests/install_test.sh
git commit -m "feat(install): add detection status table renderer"
```

---

## Task 8: Capture functions + preflight (the network/IO boundary)

**Files:**
- Modify: `install.sh`
- Modify: `tests/install_test.sh`

These functions touch the network/host; tests verify only the pure guard logic (`require_cmd`, `have_cmd`) via stubs.

- [ ] **Step 1: Add failing tests**

Append to `tests/install_test.sh`:

```sh
# --- preflight guards (have_cmd / require_cmd) ---
assert_true  have_cmd sh   "have_cmd: sh exists"
assert_false have_cmd this-command-does-not-exist-xyz "have_cmd: missing command"

# require_cmd returns non-zero and prints to stderr when missing
( require_cmd this-command-does-not-exist-xyz "test hint" ) 2>/dev/null
assert_eq "$?" "1" "require_cmd: missing command returns 1"
( require_cmd sh "test hint" ) 2>/dev/null
assert_eq "$?" "0" "require_cmd: present command returns 0"
```

- [ ] **Step 2: Run, verify fail**

Run: `sh tests/install_test.sh`
Expected: FAIL — `have_cmd: not found`.

- [ ] **Step 3: Implement preflight + capture**

In `install.sh`, add above `main()`:

```sh
have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_cmd() { # $1=cmd $2=install hint
  if have_cmd "$1"; then return 0; fi
  printf 'install.sh: required command not found: %s\n  %s\n' "$1" "$2" >&2
  return 1
}

preflight() {
  _ok=0
  require_cmd node "Install Node.js: https://nodejs.org" || _ok=1
  require_cmd npx  "npx ships with Node.js" || _ok=1
  require_cmd git  "Install git: https://git-scm.com" || _ok=1
  [ "$_ok" -eq 0 ] || return 1
  # Non-fatal warnings:
  have_cmd claude || printf 'warn: `claude` CLI not on PATH — plugin steps will print paste-in commands instead of running.\n' >&2
  have_cmd gh   || printf 'warn: `gh` (GitHub CLI) not found — needed for GitHub trackers / greploop on GitHub.\n' >&2
  have_cmd glab || printf 'warn: `glab` (GitLab CLI) not found — needed for GitLab trackers.\n' >&2
  have_cmd ctx7 || printf 'warn: `ctx7` not found — the find-docs (lookup) skill needs it: npm i -g ctx7@latest\n' >&2
  return 0
}

# Capture detection output ONCE into the globals the parsers read.
capture_state() {
  SKILLS_LIST_RAW=$(npx -y skills@latest list -g 2>/dev/null || printf '')
  if have_cmd claude; then
    PLUGINS_LIST_RAW=$(claude plugin list 2>/dev/null || printf '')
  else
    PLUGINS_LIST_RAW=""
  fi
}
```

- [ ] **Step 4: Run, verify pass**

Run: `sh tests/install_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 5: Commit**

```sh
git add install.sh tests/install_test.sh
git commit -m "feat(install): add preflight checks and one-shot state capture"
```

---

## Task 9: Install actions (skills + plugins) with stub-based tests

**Files:**
- Modify: `install.sh`
- Modify: `tests/install_test.sh`

- [ ] **Step 1: Add failing tests (stub `npx`/`claude`, assert what gets run)**

Append to `tests/install_test.sh`:

```sh
# --- install actions (with stubbed npx/claude that log their args) ---
RUN_LOG=$(mktemp)
npx()    { printf 'npx %s\n' "$*" >> "$RUN_LOG"; }
claude() { printf 'claude %s\n' "$*" >> "$RUN_LOG"; }

# skill present on all targeted agents -> no install
: > "$RUN_LOG"; OPT_AGENTS="claude-code"; OPT_FORCE=""
install_skill 1 mattpocock/skills tdd
assert_eq "$(wc -l < "$RUN_LOG" | tr -d ' ')" "0" "install_skill: present -> no-op"

# skill missing on codex -> installs onto codex only
: > "$RUN_LOG"; OPT_AGENTS="claude-code,codex"; OPT_FORCE=""
install_skill 1 mattpocock/skills tdd
assert_eq "$(cat "$RUN_LOG")" "npx -y skills@latest add mattpocock/skills -s tdd -a codex" \
  "install_skill: installs only the missing agent"

# plugin present -> no install ; absent -> marketplace add + install
: > "$RUN_LOG"; OPT_FORCE=""
install_plugin anthropics/claude-plugins-official superpowers@claude-plugins-official
assert_eq "$(wc -l < "$RUN_LOG" | tr -d ' ')" "0" "install_plugin: present -> no-op"

: > "$RUN_LOG"
install_plugin openai/codex-plugin-cc codex@openai-codex
assert_eq "$(cat "$RUN_LOG")" \
"claude plugin marketplace add openai/codex-plugin-cc
claude plugin install codex@openai-codex -s user" \
  "install_plugin: absent -> marketplace add + install"
rm -f "$RUN_LOG"
unset -f npx claude
```

- [ ] **Step 2: Run, verify fail**

Run: `sh tests/install_test.sh`
Expected: FAIL — `install_skill: not found`.

- [ ] **Step 3: Implement install actions**

In `install.sh`, add above `main()`:

```sh
install_skill() { # $1=tier $2=source $3=name
  _missing=$(agents_missing_skill "$3" "$OPT_AGENTS")
  if [ -n "$OPT_FORCE" ]; then _missing=$(printf '%s' "$OPT_AGENTS" | tr ',' ' '); fi
  if [ -z "$_missing" ]; then
    printf '  = %s already present on all targeted agents\n' "$3"
    return 0
  fi
  _agents_csv=$(printf '%s' "$_missing" | tr ' ' ',')
  _cmd=$(build_skill_add_cmd "$2" "$3" "$_agents_csv")
  printf '  + installing %s -> %s\n' "$3" "$_missing"
  # shellcheck disable=SC2086
  $_cmd || { printf '  ! failed to install %s (continuing)\n' "$3" >&2; return 1; }
}

install_plugin() { # $1=marketplace-source $2=plugin@marketplace
  if plugin_installed "$2" && [ -z "$OPT_FORCE" ]; then
    printf '  = %s already installed\n' "$2"
    return 0
  fi
  if have_cmd claude; then
    printf '  + installing plugin %s\n' "$2"
    claude plugin marketplace add "$1"
    claude plugin install "$2" -s user \
      || { printf '  ! failed to install %s (continuing)\n' "$2" >&2; return 1; }
  else
    printf '  ! claude CLI absent — run these inside Claude Code:\n    /plugin marketplace add %s\n    /plugin install %s\n' "$1" "$2"
  fi
}
```

- [ ] **Step 4: Run, verify pass**

Run: `sh tests/install_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 5: Commit**

```sh
git add install.sh tests/install_test.sh
git commit -m "feat(install): add skill and plugin install actions"
```

---

## Task 10: Wire `main` — orchestrate in tier order, forge last

**Files:**
- Modify: `install.sh`
- Modify: `tests/install_test.sh`

- [ ] **Step 1: Add a failing test for the orchestration order**

Append to `tests/install_test.sh`:

```sh
# --- main orchestration order (forge installed last) ---
ORDER_LOG=$(mktemp)
# Stub the per-row actions to just record name+tier in order.
install_skill()  { printf 'skill:%s\n' "$3" >> "$ORDER_LOG"; }
install_plugin() { printf 'plugin:%s\n' "$2" >> "$ORDER_LOG"; }
capture_state()  { :; }   # no network in test
preflight()      { return 0; }
print_status_table() { :; }

OPT_SKILLS_ONLY=""
run_installs   # the orchestration core called by main()
# forge must be the final line
assert_eq "$(tail -n1 "$ORDER_LOG")" "skill:forge" "run_installs: forge installed last"
# plugins must appear (not skipped) when --skills-only is off
assert_true grep -q '^plugin:superpowers@claude-plugins-official$' "$ORDER_LOG" \
  "run_installs: superpowers plugin installed"

# --skills-only skips plugins
: > "$ORDER_LOG"; OPT_SKILLS_ONLY="1"
run_installs
assert_false grep -q '^plugin:' "$ORDER_LOG" "run_installs: --skills-only skips plugins"
assert_eq "$(tail -n1 "$ORDER_LOG")" "skill:forge" "run_installs: forge still last under --skills-only"
rm -f "$ORDER_LOG"
```

- [ ] **Step 2: Run, verify fail**

Run: `sh tests/install_test.sh`
Expected: FAIL — `run_installs: not found`.

- [ ] **Step 3: Implement `run_installs` + finalize `main`**

In `install.sh`, replace the scaffold `main()` with:

```sh
# Walk the inventory in table order; forge (tier 6) is last by construction.
run_installs() {
  deps_table | while IFS='|' read -r _tier _kind _src _name; do
    [ -n "$_tier" ] || continue
    case "$_kind" in
      skill) install_skill "$_tier" "$_src" "$_name" ;;
      plugin)
        [ -n "$OPT_SKILLS_ONLY" ] && continue
        install_plugin "$_src" "$_name"
        ;;
    esac
  done
}

post_install_notes() {
  cat <<'EOF'

Done. Next steps / runtime notes:
  - Run `/setup-matt-pocock-skills` once in each repo where you use forge
    (bootstraps tracker + triage labels consumed by tdd/to-issues/diagnose/improve-codebase-architecture).
  - Built-in, no install needed: /goal, /compact, and security-review (Claude Code built-ins).
  - Optional, set up if you use the matching flag/tracker:
      * context7 MCP (lookup), Atlassian MCP (Jira), Linear MCP (Linear)
      * gh / glab CLIs for GitHub / GitLab trackers
  - find-docs (lookup flag) needs the Context7 CLI: npm i -g ctx7@latest
EOF
}

main() {
  parse_args "$@" || return $?
  preflight || { printf 'install.sh: preflight failed; resolve the above and re-run.\n' >&2; return 1; }
  capture_state
  print_status_table
  run_installs
  post_install_notes
}
```

- [ ] **Step 4: Run, verify pass**

Run: `sh tests/install_test.sh`
Expected: `FAILS=0`.

- [ ] **Step 5: Lint the script (if shellcheck is available)**

Run: `command -v shellcheck >/dev/null && shellcheck install.sh || echo "shellcheck not installed; skipping"`
Expected: no errors (warnings about intentional word-splitting on `$_cmd` are suppressed with the inline `# shellcheck disable=SC2086`).

- [ ] **Step 6: Commit**

```sh
git add install.sh tests/install_test.sh
git commit -m "feat(install): wire main orchestration (forge installed last)"
```

---

## Task 11: Vendor the `find-docs` skill

**Files:**
- Create: `skills/find-docs/SKILL.md` (+ any sibling resource files)

- [ ] **Step 1: Copy the skill from the host working copy**

Run:
```sh
mkdir -p skills/find-docs
cp -R "$HOME/.claude/skills/find-docs/." skills/find-docs/
ls -la skills/find-docs/
```
Expected: `SKILL.md` present (plus any references the skill bundles).

- [ ] **Step 2: Verify it has valid frontmatter and self-contained content**

Run: `sed -n '1,20p' skills/find-docs/SKILL.md`
Expected: YAML frontmatter with `name: find-docs` and a description; no absolute machine-specific paths in the body. If any `~/.claude`-specific path is hardcoded, edit it to a generic reference.

- [ ] **Step 3: Verify `npx skills add` can see it locally (dry list)**

Run: `npx -y skills@latest add . --list 2>&1 | grep -i find-docs || echo "NOT LISTED — check SKILL.md location"`
Expected: `find-docs` appears in the repo's installable-skill list.

- [ ] **Step 4: Commit**

```sh
git add skills/find-docs
git commit -m "feat(install): vendor find-docs skill for the lookup flag"
```

---

## Task 12: Add `references/dependencies.md` + link from SKILL.md

**Files:**
- Create: `skills/forge/references/dependencies.md`
- Modify: `skills/forge/SKILL.md`

- [ ] **Step 1: Create the dependencies reference**

Create `skills/forge/references/dependencies.md`:

```markdown
# Forge — Dependencies

Forge composes external skills and plugins. Install all of them, then forge itself, with the
repo-root installer:

```sh
./install.sh            # detect-first, idempotent; -y for non-interactive, --help for options
```

Two mechanisms are involved (the installer handles both): bare skills via Vercel's `npx skills`,
and Claude Code plugins via `claude plugin`. `npx skills` cannot install the plugin agents/hooks
the reviewer engines need, which is why the plugins go through `claude plugin`.

## What forge composes

| Dependency | Provider | Mechanism | Needed for |
|---|---|---|---|
| `tdd` `grill-me` `grill-with-docs` `to-issues` `diagnose` `write-a-skill` `improve-codebase-architecture` | `mattpocock/skills` | `npx skills` | Steps 7/9/10, `tdd` flag, grilling |
| `setup-matt-pocock-skills` | `mattpocock/skills` | `npx skills` + run once per repo | bootstraps the above |
| `karpathy-guidelines` | `forrestchang/andrej-karpathy-skills` | `npx skills` | Step 7 clean-code re-source |
| `superpowers:requesting-code-review` `superpowers:using-git-worktrees` | superpowers (`anthropics/claude-plugins-official`) | `claude plugin` | default reviewer; `worktree` flag |
| `codex` plugin | `openai/codex-plugin-cc` | `claude plugin` (CC-only) | `codex` flag |
| `coderabbit` plugin | `claude-plugins-official` | `claude plugin` (CC-only) | `coderabbit` flag |
| `greploop` `check-pr` | `greptileai/skills` | `npx skills` | Step 8 PR-review fallback |
| `find-docs` | vendored (`skills/find-docs`); needs `ctx7` CLI | `npx skills` | `lookup` flag |

## No install needed (host/runtime built-ins)

- `/goal`, `/compact` — built-in agent commands.
- `security-review` — Claude Code built-in (`secure` flag).
- context7 / Atlassian / Linear MCP, `gh`, `glab` — optional, set up per tracker/flag you use.
```

- [ ] **Step 2: Link it from SKILL.md**

Find the references list / pointers section in `skills/forge/SKILL.md`:

Run: `grep -n 'references/' skills/forge/SKILL.md | head`

Add one line near the other reference pointers (match the surrounding format), e.g.:

```markdown
- Dependencies & install: [references/dependencies.md](references/dependencies.md) — what forge composes and how to install it (`./install.sh`).
```

- [ ] **Step 3: Verify the link resolves and frontmatter still parses**

Run:
```sh
test -f skills/forge/references/dependencies.md && echo "ref exists"
python3 -c "import sys,yaml; s=open('skills/forge/SKILL.md').read(); fm=s.split('---',2)[1]; yaml.safe_load(fm); print('frontmatter OK')"
```
Expected: `ref exists` and `frontmatter OK`.

- [ ] **Step 4: Commit**

```sh
git add skills/forge/references/dependencies.md skills/forge/SKILL.md
git commit -m "docs(forge): add dependencies reference and link from SKILL.md"
```

---

## Task 13: Fix the root README install section

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Inspect the current stale install block**

Run: `grep -n '1.0.0\|/plugin install\|## Install' README.md`
Expected: shows the `## Install` heading and the stale `/plugin install /path/to/forge-skills/1.0.0` line and `1.0.0/` path references.

- [ ] **Step 2: Replace the Install section**

In `README.md`, replace the `## Install` section body with:

```markdown
## Install

Install forge and every skill/plugin it composes with the unified installer:

```sh
git clone https://github.com/radimsem/forge-skills.git
cd forge-skills
./install.sh            # detect-first & idempotent; -y non-interactive, --skills-only for non-Claude-Code hosts
```

The installer uses two mechanisms: Vercel's `npx skills` for bare skills and `claude plugin` for
the Claude Code reviewer plugins (superpowers/codex/coderabbit). It installs forge **last**. See
[`skills/forge/references/dependencies.md`](skills/forge/references/dependencies.md) for the full
dependency list and [`docs/specs/2026-05-29-unified-dependency-install.md`](docs/specs/2026-05-29-unified-dependency-install.md)
for the design.

Once installed, the skill activates on `/forge <ref>` or any phrasing matching the trigger in
[`skills/forge/SKILL.md`](skills/forge/SKILL.md).
```

- [ ] **Step 3: Fix the remaining `1.0.0/` path drift**

Run: `grep -n '1.0.0/' README.md`
For each remaining hit that points at a moved file (e.g. `1.0.0/skills/forge/SKILL.md`, `1.0.0/README.md`, `1.0.0/CLAUDE.md`), update the path to its current location under `skills/` (or remove the line if the target no longer exists). Verify each rewritten link:
```sh
grep -oE '\]\([^)]+\)' README.md | sed 's/](//;s/)//' | while read -r p; do
  case "$p" in http*) continue;; esac
  [ -e "$p" ] && echo "OK  $p" || echo "BROKEN $p"
done
```
Expected: every local link prints `OK`.

- [ ] **Step 4: Commit**

```sh
git add README.md
git commit -m "docs: replace stale install instructions with ./install.sh"
```

---

## Task 14: End-to-end dry verification on this host

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `sh tests/install_test.sh`
Expected: all `ok`, `FAILS=0`, exit 0.

- [ ] **Step 2: Status-table-only smoke run (this host already has most deps)**

Run: `./install.sh --help` then read the status table by running the detection path without installs is not separable; instead run with a narrow agent set and observe the table + that present deps are skipped:
```sh
./install.sh --agents claude-code --skills-only --yes 2>&1 | sed -n '1,40p'
```
Expected: a "Dependency status" table prints; mattpocock skills already on claude-code show `=` (present); any genuinely missing skill shows `+` and installs; no plugin lines (`--skills-only`). The run exits 0.

- [ ] **Step 3: Idempotency check**

Run the same command again:
```sh
./install.sh --agents claude-code --skills-only --yes 2>&1 | grep -c '^\s*=.*present'
```
Expected: a non-zero count of `present` rows and zero `+ installing` lines on the second run (everything already satisfied).

- [ ] **Step 4: Confirm forge installs last**

Run:
```sh
./install.sh --agents claude-code --skills-only --yes 2>&1 | grep -E 'installing|present' | tail -n3
```
Expected: forge's line (`+ installing forge …` or `= forge already present …`) is the last skill-related line before the post-install notes.

- [ ] **Step 5: Final commit (if any verification fixups were needed)**

```sh
git add -A
git commit -m "chore(install): verification fixups" || echo "nothing to commit"
```

---

## Self-review notes (author)

- **Spec coverage:** Tier 1/4/6 skills → Tasks 6/9/10/11; Tier 2/3 plugins → Tasks 4/5/9/10; detection-first → Tasks 3/4/7/8; flags (`--yes/--force/--agents/--skills-only`) → Tasks 1/5/7/9/10; `find-docs` vendoring → Task 11; `references/dependencies.md` → Task 12; README fix → Task 13; verification (§9) → Task 14. `/goal`, `/notes`, `security-review`, MCP/CLI built-ins are encoded as the post-install notes (Task 10) + dependencies.md, matching spec Tier 5.
- **Known acceptable behavior:** `karpathy-guidelines` may already be present as the `andrej-karpathy-skills@karpathy-skills` *plugin* rather than an npx skill; the installer's canonical path is npx, so detection may show it `+` and (re)install it as a skill. Harmless overlap — documented, not a bug.
- **Type/name consistency:** globals `OPT_YES/OPT_FORCE/OPT_SKILLS_ONLY/OPT_AGENTS`, capture globals `SKILLS_LIST_RAW/PLUGINS_LIST_RAW`, and function names (`parse_skill_agents`, `agents_missing_skill`, `plugin_installed`, `build_skill_add_cmd`, `build_plugin_marketplace_cmd`, `build_plugin_install_cmd`, `install_skill`, `install_plugin`, `run_installs`) are used identically across all tasks.
- **Inventory count:** `deps_table` ships 16 rows (9 tier-1, 1 tier-2, 2 tier-3, 3 tier-4, 1 tier-6); the Task 6 assertions match.
```
