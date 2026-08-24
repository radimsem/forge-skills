#!/usr/bin/env sh
# install.sh — unified dependency installer for the forge skill.
# Installs forge's external skills (npx skills) and plugins (claude plugin), then forge itself last.
set -u

# Empty by default: let `npx skills` auto-detect the host's installed agents
# (passing a hardcoded list installs onto agents you may not have). --agents overrides.
DEFAULT_AGENTS=""

# forge ships from its own public repo and is always installed LAST, after the skills
# and plugins it composes. This is the source `npx skills add` clones forge from.
FORGE_SOURCE="radimsem/forge-skills"

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
      --agents "a,b"   Install onto specific agents (default: npx skills auto-detects your installed agents)
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

# Directories where an installed bare skill shows up. `~/.agents/skills` is the canonical
# global store `npx skills add -g` writes to (other agents symlink into it); `~/.claude/skills`
# also holds Claude-Code-local skills. Overridable (env or test) for non-default layouts.
: "${SKILL_DIRS:=$HOME/.claude/skills $HOME/.agents/skills}"

# True if the skill directory exists in any of $SKILL_DIRS — i.e. it is installed somewhere.
# Detection is agent-agnostic (present anywhere counts as installed), so a re-run does not
# reinstall skills you already have. A filesystem stat, not an `npx skills list` round-trip.
# `-e` follows symlinks, so a Claude Code symlink into ~/.agents/skills counts only when its
# target still exists. (Trade-off: a skill present in one store is not backfilled to others.)
skill_installed_anywhere() { # $1=skill name
  for _d in $SKILL_DIRS; do
    [ -e "$_d/$1" ] && return 0
  done
  return 1
}

# Reads $PLUGINS_LIST_RAW (captured `claude plugin list`). True if plugin@marketplace present.
# Anchored so "super@m" does not match "superpowers@m".
plugin_installed() { # $1=plugin@marketplace
  printf '%s\n' "${PLUGINS_LIST_RAW:-}" | strip_ansi \
    | grep -qE "(^|[[:space:]])$(printf '%s' "$1" | sed 's/[.[\*^$/]/\\&/g')([[:space:]]|$)"
}

# Build ONE batched `npx skills add` command: all given skills from one source in a single
# pass (one clone). $2 is a space-separated skill list. `-a` is added only when --agents is
# set; otherwise npx skills auto-detects the host's installed agents (no phantom targets).
build_skill_group_cmd() { # $1=source $2=space-separated skills ; uses OPT_AGENTS, OPT_YES
  _cmd="npx -y skills@latest add $1"
  for _sk in $2; do _cmd="$_cmd -s $_sk"; done
  if [ -n "$OPT_AGENTS" ]; then
    _oldifs=$IFS; IFS=','
    for _a in $OPT_AGENTS; do _cmd="$_cmd -a $_a"; done
    IFS=$_oldifs
  fi
  _cmd="$_cmd -g"   # global scope: matches `npx skills list -g` detection; avoids the Project-scope prompt
  [ -n "$OPT_YES" ] && _cmd="$_cmd -y"   # with -g, suppresses the scope + "Proceed?" prompts
  printf '%s' "$_cmd"
}

# Unique skill sources in table order, EXCLUDING forge's own repo, which is deferred to last.
skill_sources_before_forge() {
  deps_table | awk -F'|' -v forge="$FORGE_SOURCE" '$2=="skill" && $3!=forge && !seen[$3]++ {print $3}'
}

# All skills declared for a given source, in table order (space-separated when captured).
skills_for_source() { # $1=source
  deps_table | awk -F'|' -v s="$1" '$2=="skill" && $3==s {print $4}'
}

# True if forge's repo appears as a skill source (it should — forge installs last).
has_forge_skill() {
  deps_table | awk -F'|' -v forge="$FORGE_SOURCE" '$2=="skill" && $3==forge{f=1} END{exit !f}'
}

build_plugin_marketplace_cmd() { # $1=marketplace source (owner/repo)
  printf 'claude plugin marketplace add %s' "$1"
}

build_plugin_install_cmd() { # $1=plugin@marketplace
  printf 'claude plugin install %s -s user' "$1"
}

# Single source of truth for forge's external dependencies.
# Columns: tier|kind|source|name
#   kind=skill  -> source is an npx skills add source (owner/repo, e.g. forge's own repo); name = -s skill
#   kind=plugin -> source is the marketplace owner/repo; name = plugin@marketplace
deps_table() {
  cat <<'EOF'
1|skill|mattpocock/skills|tdd
1|skill|mattpocock/skills|grill-me
1|skill|mattpocock/skills|grill-with-docs
1|skill|mattpocock/skills|to-tickets
1|skill|mattpocock/skills|diagnosing-bugs
1|skill|mattpocock/skills|writing-for-agents
1|skill|mattpocock/skills|improve-codebase-architecture
1|skill|mattpocock/skills|wait-what
1|skill|mattpocock/skills|code-review
1|skill|mattpocock/skills|resolving-merge-conflicts
1|skill|mattpocock/skills|wayfinder
1|skill|mattpocock/skills|implement
1|skill|mattpocock/skills|setup-matt-pocock-skills
1|skill|forrestchang/andrej-karpathy-skills|karpathy-guidelines
2|plugin|anthropics/claude-plugins-official|superpowers@claude-plugins-official
3|plugin|openai/codex-plugin-cc|codex@openai-codex
3|plugin|anthropics/claude-plugins-official|coderabbit@claude-plugins-official
4|skill|greptileai/skills|greploop
4|skill|greptileai/skills|check-pr
6|skill|radimsem/forge-skills|forge
6|skill|radimsem/forge-skills|blacksmith-orchestrate
EOF
}

# Render one detection status line. "=" present (skip), "+" will install.
status_row() { # $1=tier $2=kind $3=source $4=name
  case "$2" in
    skill)
      if skill_installed_anywhere "$4" && [ -z "$OPT_FORCE" ]; then
        printf '= [skill] %s (present)' "$4"
      else
        printf '+ [skill] %s (will install)' "$4"
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
  printf '\nDependency status (agents: %s):\n' "${OPT_AGENTS:-auto-detected}"
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
  have_cmd gh     || printf 'warn: `gh` (GitHub CLI) not found — needed for GitHub trackers / greploop on GitHub.\n' >&2
  have_cmd glab   || printf 'warn: `glab` (GitLab CLI) not found — needed for GitLab trackers.\n' >&2
  return 0
}

# Capture plugin state once (skills are detected straight off the filesystem, no capture needed).
capture_state() {
  if have_cmd claude; then
    PLUGINS_LIST_RAW=$(claude plugin list 2>/dev/null || printf '')
  else
    PLUGINS_LIST_RAW=""
  fi
}

# Of a source's declared skills, the ones not installed on any agent (space-separated).
# Under --force, every declared skill is "needed".
needed_skills_for_source() { # $1=source ; uses OPT_FORCE
  _need=""
  for _sk in $(skills_for_source "$1"); do
    if [ -n "$OPT_FORCE" ] || ! skill_installed_anywhere "$_sk"; then
      _need="$_need $_sk"
    fi
  done
  printf '%s' "${_need# }"
}

# Install all needed skills from one source in a SINGLE npx pass (one clone). Skips the
# source entirely when every declared skill is already installed (on any agent).
install_skill_group() { # $1=source
  _need=$(needed_skills_for_source "$1")
  if [ -z "$_need" ]; then
    printf '  = all skills from %s already installed\n' "$1"
    return 0
  fi
  _cmd=$(build_skill_group_cmd "$1" "$_need")
  printf '  + installing from %s: %s\n' "$1" "$_need"
  # shellcheck disable=SC2086
  $_cmd || { printf '  ! failed to install from %s (continuing)\n' "$1" >&2; return 1; }
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

# Install order: bare-skill sources (each batched into one npx pass) → plugins → forge's
# own repo LAST, so forge is the final thing installed and never resolves before its
# dependencies. Continues past failures but returns nonzero if any failed.
run_installs() {
  _rc=0
  # 1) Bare-skill sources other than forge's — one batched npx pass per source.
  #    Sources have no spaces, so word-splitting the command substitution is safe.
  for _src in $(skill_sources_before_forge); do
    install_skill_group "$_src" || _rc=1
  done
  # 2) Plugins (unless --skills-only). Read on FD 3 so an interactive `claude plugin`
  #    keeps the real terminal on stdin instead of consuming this here-doc.
  if [ -z "$OPT_SKILLS_ONLY" ]; then
    while IFS='|' read -r _psrc _pname <&3; do
      [ -n "$_psrc" ] || continue
      install_plugin "$_psrc" "$_pname" || _rc=1
    done 3<<EOF
$(deps_table | awk -F'|' '$2=="plugin"{print $3"|"$4}')
EOF
  fi
  # 3) forge's own repo LAST — forge installed after everything it depends on.
  if has_forge_skill; then
    install_skill_group "$FORGE_SOURCE" || _rc=1
  fi
  return $_rc
}

post_install_notes() {
  cat <<'EOF'

Done. Next steps / runtime notes:
  - Run `/setup-matt-pocock-skills` once in each repo where you use forge
    (bootstraps tracker + triage labels consumed by tdd/to-tickets/diagnosing-bugs/implement/code-review/improve-codebase-architecture).
  - Built-in, no install needed: /goal, /compact, and security-review (Claude Code built-ins).
  - Optional, set up if you use the matching flag/tracker:
      * context7 MCP — the `lookup` flag's doc source; Atlassian MCP (Jira); Linear MCP (Linear)
      * gh / glab CLIs for GitHub / GitLab trackers
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
