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
