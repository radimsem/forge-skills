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
assert_eq "$OPT_AGENTS" "" "parse_args: default agents empty (npx auto-detects host agents)"

# --- strip_ansi ---
ESC=$(printf '\033')
colored="${ESC}[36mtdd${ESC}[0m ${ESC}[38;5;102m~/x${ESC}[0m"
assert_eq "$(printf '%s' "$colored" | strip_ansi)" "tdd ~/x" "strip_ansi removes color codes"

# --- skill present-anywhere detection (filesystem stat over $SKILL_DIRS) ---
_SKILL_TMP=$(mktemp -d)
mkdir -p "$_SKILL_TMP/claude/tdd"        # present in the first store (like ~/.claude/skills)
mkdir -p "$_SKILL_TMP/agents/zoom-out"   # present in the second store (like ~/.agents/skills)
ln -s "$_SKILL_TMP/agents/zoom-out" "$_SKILL_TMP/claude/linked"  # symlink whose target exists
ln -s "$_SKILL_TMP/gone"            "$_SKILL_TMP/claude/broken"  # symlink whose target is missing
SKILL_DIRS="$_SKILL_TMP/claude $_SKILL_TMP/agents"
assert_true  skill_installed_anywhere tdd           "skill_installed_anywhere: present in first store"
assert_true  skill_installed_anywhere zoom-out      "skill_installed_anywhere: present in second store"
assert_true  skill_installed_anywhere linked        "skill_installed_anywhere: resolving symlink counts"
assert_false skill_installed_anywhere broken        "skill_installed_anywhere: broken symlink does not count"
assert_false skill_installed_anywhere not-installed "skill_installed_anywhere: absent skill"
rm -rf "$_SKILL_TMP"

# --- plugin detection ---
PLUGINS_LIST_RAW=$(cat "$ROOT/tests/fixtures/plugin-list.txt")
assert_true  plugin_installed "superpowers@claude-plugins-official" "plugin_installed: superpowers"
assert_true  plugin_installed "coderabbit@claude-plugins-official"  "plugin_installed: coderabbit"
assert_false plugin_installed "codex@openai-codex"                   "plugin_installed: codex absent"
assert_false plugin_installed "super@claude-plugins-official"        "plugin_installed: no prefix match"

# --- command builders (batched: many -s skills in one pass) ---
# With --agents set: emit -a flags for each.
OPT_YES=""; OPT_AGENTS="claude-code,codex"
assert_eq "$(build_skill_group_cmd mattpocock/skills 'tdd grill-me')" \
  "npx -y skills@latest add mattpocock/skills -s tdd -s grill-me -a claude-code -a codex -g" \
  "build_skill_group_cmd: --agents set -> -a flags"

# Default (no --agents): NO -a flags, so npx skills auto-detects the host's agents.
OPT_AGENTS=""
assert_eq "$(build_skill_group_cmd mattpocock/skills 'tdd grill-me')" \
  "npx -y skills@latest add mattpocock/skills -s tdd -s grill-me -g" \
  "build_skill_group_cmd: no --agents -> no -a (auto-detect)"

OPT_YES="1"
assert_eq "$(build_skill_group_cmd . forge)" \
  "npx -y skills@latest add . -s forge -g -y" \
  "build_skill_group_cmd: --yes appends -y after -g (no -a)"
OPT_YES=""

assert_eq "$(build_plugin_marketplace_cmd anthropics/claude-plugins-official)" \
  "claude plugin marketplace add anthropics/claude-plugins-official" \
  "build_plugin_marketplace_cmd"
assert_eq "$(build_plugin_install_cmd superpowers@claude-plugins-official)" \
  "claude plugin install superpowers@claude-plugins-official -s user" \
  "build_plugin_install_cmd"

# --- inventory data (table has exactly 17 rows: 10 tier-1, 1 tier-2, 2 tier-3, 2 tier-4, 2 tier-6) ---
assert_eq "$(deps_table | grep -c '^[1-6]|')" "17" "deps_table: 17 dependency rows"
assert_eq "$(deps_table | awk -F'|' '$1==6{printf "%s ", $4}')" "forge blacksmith-orchestrate " \
  "deps_table: tier 6 is forge then blacksmith-orchestrate"
assert_eq "$(deps_table | awk -F'|' '$1==1 && $2=="skill"{c++} END{print c}')" "10" \
  "deps_table: 10 tier-1 skills (8 mattpocock incl. zoom-out + bootstrap + karpathy)"
assert_eq "$(deps_table | grep -c '^1|skill|mattpocock/skills|zoom-out$')" "1" \
  "deps_table: zoom-out present in mattpocock group"
# blacksmith-orchestrate wraps forge, so forge must precede it and be installed with it
assert_eq "$(deps_table | awk -F'|' '$2=="skill"{last=$4} END{print last}')" "blacksmith-orchestrate" \
  "deps_table: blacksmith-orchestrate is the final skill row"
assert_eq "$(skills_for_source "$FORGE_SOURCE" | tr '\n' ' ')" "forge blacksmith-orchestrate " \
  "skills_for_source: forge precedes blacksmith-orchestrate"
parse_args   # pin OPT_YES empty so the expected command is deterministic
assert_eq "$(build_skill_group_cmd "$FORGE_SOURCE" "forge blacksmith-orchestrate")" \
  "npx -y skills@latest add radimsem/forge-skills -s forge -s blacksmith-orchestrate -g" \
  "build_skill_group_cmd: batches both local skills from one source"

# --- status row rendering (skills: filesystem present-anywhere; plugins: present in list) ---
# Skills checked against a temp store; plugins against the plugin-list fixture loaded above.
_SKILL_TMP=$(mktemp -d); mkdir -p "$_SKILL_TMP/s/tdd"
SKILL_DIRS="$_SKILL_TMP/s"
OPT_FORCE=""
assert_eq "$(status_row 1 skill mattpocock/skills tdd)" \
  "= [skill] tdd (present)" "status_row: skill present"
assert_eq "$(status_row 1 skill mattpocock/skills not-installed)" \
  "+ [skill] not-installed (will install)" "status_row: skill absent"
assert_eq "$(status_row 2 plugin anthropics/claude-plugins-official superpowers@claude-plugins-official)" \
  "= [plugin] superpowers@claude-plugins-official (present)" "status_row: plugin present"
assert_eq "$(status_row 3 plugin openai/codex-plugin-cc codex@openai-codex)" \
  "+ [plugin] codex@openai-codex (will install)" "status_row: plugin absent"
rm -rf "$_SKILL_TMP"

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

# source fully installed (every declared skill present in a store) -> skip, no npx call.
_SKILL_TMP=$(mktemp -d); mkdir -p "$_SKILL_TMP/s/greploop" "$_SKILL_TMP/s/check-pr"
SKILL_DIRS="$_SKILL_TMP/s"
: > "$RUN_LOG"; OPT_AGENTS=""; OPT_FORCE=""
install_skill_group greptileai/skills >/dev/null
assert_eq "$(wc -l < "$RUN_LOG" | tr -d ' ')" "0" "install_skill_group: all present -> no-op"
rm -rf "$_SKILL_TMP"

# only the absent skill is batched; no --agents -> no -a flags (npx auto-detects host agents).
# (greploop present in the store; check-pr absent)
_SKILL_TMP=$(mktemp -d); mkdir -p "$_SKILL_TMP/s/greploop"
SKILL_DIRS="$_SKILL_TMP/s"
: > "$RUN_LOG"; OPT_AGENTS=""; OPT_FORCE=""
install_skill_group greptileai/skills >/dev/null
assert_eq "$(cat "$RUN_LOG")" "npx -y skills@latest add greptileai/skills -s check-pr -g" \
  "install_skill_group: installs only the absent skill, auto-detect agents"
rm -rf "$_SKILL_TMP"

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

# --- main orchestration order (batched per source; forge's own repo installed last) ---
ORDER_LOG=$(mktemp)
# Stub the batched actions to record what gets installed, in order.
install_skill_group() { printf 'skillsrc:%s\n' "$1" >> "$ORDER_LOG"; }
install_plugin()      { printf 'plugin:%s\n' "$2" >> "$ORDER_LOG"; }
capture_state()       { :; }   # no network in test
preflight()           { return 0; }
print_status_table()  { :; }

OPT_SKILLS_ONLY=""
run_installs   # the orchestration core called by main()
# forge's own repo ($FORGE_SOURCE) must be the final install
assert_eq "$(tail -n1 "$ORDER_LOG")" "skillsrc:$FORGE_SOURCE" "run_installs: forge source installed last"
assert_eq "$(head -n1 "$ORDER_LOG")" "skillsrc:mattpocock/skills" "run_installs: first source is mattpocock"
# each source is installed in exactly ONE batched pass (not once per skill)
assert_eq "$(grep -c '^skillsrc:mattpocock/skills$' "$ORDER_LOG")" "1" \
  "run_installs: mattpocock batched into ONE pass"
assert_true grep -q '^plugin:superpowers@claude-plugins-official$' "$ORDER_LOG" \
  "run_installs: superpowers plugin installed"

# --skills-only skips plugins
: > "$ORDER_LOG"; OPT_SKILLS_ONLY="1"
run_installs
# helper ignores its trailing message arg, unlike grep, which would otherwise treat the
# message string as a second file operand and print a spurious "No such file" to stderr
plugin_line_present() { grep -q '^plugin:' "$1"; }
assert_false plugin_line_present "$ORDER_LOG" "run_installs: --skills-only skips plugins"
assert_eq "$(tail -n1 "$ORDER_LOG")" "skillsrc:$FORGE_SOURCE" "run_installs: forge source still last under --skills-only"

# run_installs propagates a nonzero exit when a source fails (continues, but returns 1)
install_skill_group() { [ "$1" = "mattpocock/skills" ] && return 1; return 0; }
install_plugin()      { return 0; }
OPT_SKILLS_ONLY=""
run_installs >/dev/null 2>&1
assert_eq "$?" "1" "run_installs: returns 1 when a source fails"
install_skill_group() { return 0; }
run_installs >/dev/null 2>&1
assert_eq "$?" "0" "run_installs: returns 0 when all installs succeed"
rm -f "$ORDER_LOG"

printf '\n%s\n' "FAILS=$FAILS"
[ "$FAILS" -eq 0 ]
