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

# --- plugin detection ---
PLUGINS_LIST_RAW=$(cat "$ROOT/tests/fixtures/plugin-list.txt")
assert_true  plugin_installed "superpowers@claude-plugins-official" "plugin_installed: superpowers"
assert_true  plugin_installed "coderabbit@claude-plugins-official"  "plugin_installed: coderabbit"
assert_false plugin_installed "codex@openai-codex"                   "plugin_installed: codex absent"
assert_false plugin_installed "super@claude-plugins-official"        "plugin_installed: no prefix match"

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

# --- inventory data (table has exactly 16 rows: 9 tier-1, 1 tier-2, 2 tier-3, 3 tier-4, 1 tier-6) ---
assert_eq "$(deps_table | grep -c '^[1-6]|')" "16" "deps_table: 16 dependency rows"
assert_eq "$(deps_table | awk -F'|' '$1==6{print $4}')" "forge" "deps_table: tier 6 is forge"
assert_eq "$(deps_table | awk -F'|' '$1==1 && $2=="skill"{c++} END{print c}')" "9" \
  "deps_table: 9 tier-1 skills (7 mattpocock + bootstrap + karpathy)"
# forge must be the last skill row encountered (installed last)
assert_eq "$(deps_table | awk -F'|' '$2=="skill"{last=$4} END{print last}')" "forge" \
  "deps_table: forge is the final skill row"

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

# --- preflight guards (have_cmd / require_cmd) ---
assert_true  have_cmd sh   "have_cmd: sh exists"
assert_false have_cmd this-command-does-not-exist-xyz "have_cmd: missing command"

# require_cmd returns non-zero and prints to stderr when missing
( require_cmd this-command-does-not-exist-xyz "test hint" ) 2>/dev/null
assert_eq "$?" "1" "require_cmd: missing command returns 1"
( require_cmd sh "test hint" ) 2>/dev/null
assert_eq "$?" "0" "require_cmd: present command returns 0"

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

# run_installs propagates a nonzero exit when an install fails (continues, but returns 1)
install_skill()  { [ "$3" = "tdd" ] && return 1; return 0; }
install_plugin() { return 0; }
OPT_SKILLS_ONLY=""
run_installs >/dev/null 2>&1
assert_eq "$?" "1" "run_installs: returns 1 when a skill install fails"
install_skill()  { return 0; }
run_installs >/dev/null 2>&1
assert_eq "$?" "0" "run_installs: returns 0 when all installs succeed"
rm -f "$ORDER_LOG"

printf '\n%s\n' "FAILS=$FAILS"
[ "$FAILS" -eq 0 ]
