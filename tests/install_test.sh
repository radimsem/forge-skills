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

# --- strip_ansi ---
ESC=$(printf '\033')
colored="${ESC}[36mtdd${ESC}[0m ${ESC}[38;5;102m~/x${ESC}[0m"
assert_eq "$(printf '%s' "$colored" | strip_ansi)" "tdd ~/x" "strip_ansi removes color codes"

# --- agent_slug_to_name ---
assert_eq "$(agent_slug_to_name claude-code)" "Claude Code" "slug claude-code -> Claude Code"
assert_eq "$(agent_slug_to_name codex)" "Codex" "slug codex -> Codex"
assert_eq "$(agent_slug_to_name opencode)" "OpenCode" "slug opencode -> OpenCode"
assert_eq "$(agent_slug_to_name cursor)" "Cursor" "slug cursor -> Cursor"

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

printf '\n%s\n' "FAILS=$FAILS"
[ "$FAILS" -eq 0 ]
