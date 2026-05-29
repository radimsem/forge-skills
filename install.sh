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

# Reads $PLUGINS_LIST_RAW (captured `claude plugin list`). True if plugin@marketplace present.
# Anchored so "super@m" does not match "superpowers@m".
plugin_installed() { # $1=plugin@marketplace
  printf '%s\n' "${PLUGINS_LIST_RAW:-}" | strip_ansi \
    | grep -qE "(^|[[:space:]])$(printf '%s' "$1" | sed 's/[.[\*^$/]/\\&/g')([[:space:]]|$)"
}

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

# Render one detection status line. "=" present (skip), "+" will install.
status_row() { # $1=tier $2=kind $3=source $4=name
  case "$2" in
    skill)
      _missing=$(agents_missing_skill "$4" "$OPT_AGENTS")
      if [ -z "$_missing" ] && [ -z "$OPT_FORCE" ]; then
        printf '= [skill] %s (present)' "$4"
      else
        [ -n "$OPT_FORCE" ] && _missing="$(printf '%s' "$OPT_AGENTS" | tr ',' ' ') (forced)"
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

# Walk the inventory in table order; forge (tier 6) is last by construction.
# Continues past individual failures but returns nonzero if any install failed.
run_installs() {
  _rc=0
  while IFS='|' read -r _tier _kind _src _name; do
    [ -n "$_tier" ] || continue
    case "$_kind" in
      skill) install_skill "$_tier" "$_src" "$_name" || _rc=1 ;;
      plugin)
        [ -n "$OPT_SKILLS_ONLY" ] && continue
        install_plugin "$_src" "$_name" || _rc=1
        ;;
    esac
  done <<EOF
$(deps_table)
EOF
  return $_rc
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
  run_installs; _rc=$?
  post_install_notes
  return $_rc
}

# --- entrypoint guard: skip main() when sourced by tests ---
if [ "${INSTALL_SH_SOURCED:-0}" != "1" ]; then
  main "$@"
fi
