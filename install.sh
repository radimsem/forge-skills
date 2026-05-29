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

main() {
  parse_args "$@" || return $?
  printf 'install.sh scaffold OK (agents: %s)\n' "$OPT_AGENTS"
}

# --- entrypoint guard: skip main() when sourced by tests ---
if [ "${INSTALL_SH_SOURCED:-0}" != "1" ]; then
  main "$@"
fi
