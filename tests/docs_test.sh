#!/usr/bin/env sh
# Consistency tests for the skill prose this repo ships.
# The deliverable is prose, so these assert structural invariants:
# links resolve, flag tables do not drift, no placeholder text ships.
set -u
FAILS=0
pass() { printf 'ok   - %s\n' "$1"; }
fail() { printf 'FAIL - %s\n' "$1"; FAILS=$((FAILS+1)); }
assert_eq() { # actual expected msg
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (expected [$2] got [$1])"; fi
}
assert_file() { # path msg
  if [ -f "$1" ]; then pass "$2"; else fail "$2 (missing $1)"; fi
}
assert_contains() { # file pattern msg
  if [ -f "$1" ] && grep -qE "$2" "$1"; then pass "$3"; else fail "$3 (no /$2/ in $1)"; fi
}
assert_nonempty() { # value msg
  if [ -n "$1" ]; then pass "$2"; else fail "$2 (extracted set is empty)"; fi
}

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# Every relative .md link in a markdown file must resolve.
broken_links() { # $1=markdown file
  _dir=$(dirname -- "$1")
  grep -o ']([^)#]*\.md' "$1" | sed 's/^](//' | while read -r _t; do
    case "$_t" in http*|/*) continue ;; esac
    [ -f "$_dir/$_t" ] || printf '%s -> %s\n' "$1" "$_t"
  done
}

# Normalized flag names from the first column of EVERY markdown table under the
# heading matched by $2, up to the next `## ` heading. Two consequences for any
# section compared for flag parity:
#   * it must contain exactly ONE table. A second one (entry verbs, model tiers,
#     defaults) silently adds its first column to the extracted set, so the parity
#     assertion goes red reading like a drifted flag list when nothing drifted.
#   * content that is not a flag row therefore belongs in prose under that
#     heading, not in a table of its own — this is why forge's pass-through
#     overrides are written as sentences.
# Callers must also assert the extracted set is non-empty before comparing two of
# them: a missing or emptied table extracts to "", and equality alone would report
# green for a repo whose flag tables are gone entirely.
flag_names() { # $1=file $2=heading regex
  awk -v h="$2" '$0 ~ h {f=1; next} /^## /{f=0} f' "$1" \
    | awk -F'|' 'NF>2 {print $2}' \
    | tr '/' '\n' \
    | sed -n 's/.*`\([^`]*\)`.*/\1/p' \
    | sed 's/^ *//; s/ *$//' \
    | sort -u
}

# --- every skill has frontmatter with a name and a description ---
for _s in "$ROOT"/skills/*/SKILL.md; do
  [ -f "$_s" ] || continue
  assert_eq "$(head -n1 "$_s")" "---" "frontmatter opens $_s"
  assert_contains "$_s" '^name: ' "frontmatter has name: $_s"
  assert_contains "$_s" '^description: ' "frontmatter has description: $_s"
done

# --- every relative markdown link resolves ---
_broken=$(find "$ROOT/skills" -name '*.md' -type f | sort | while read -r _f; do
  broken_links "$_f"
done)
assert_eq "$_broken" "" "all relative markdown links in skills/ resolve"

# --- no placeholder text ships ---
_ph=$(grep -rnE '\bTBD\b|\bTODO\b|\bFIXME\b' "$ROOT/skills" || true)
assert_eq "$_ph" "" "no TBD/TODO/FIXME in skills/"

# --- every mode file carries a manual verification recipe ---
_norecipe=$(find "$ROOT/skills" -path '*/references/modes/*.md' -type f | sort | while read -r _f; do
  grep -q 'Manual verification recipe' "$_f" || printf '%s\n' "$_f"
done)
assert_eq "$_norecipe" "" "every references/modes/*.md has a Manual verification recipe"

# --- forge: flags.md and the README flag table agree ---
# Non-emptiness first: equality alone passes when both tables are missing.
_forge_flags=$(flag_names "$ROOT/skills/forge/references/flags.md" '^## Flags')
_forge_readme=$(flag_names "$ROOT/README.md" '^## Modifier flags')
assert_nonempty "$_forge_flags"  "forge: flags.md flag table is non-empty"
assert_nonempty "$_forge_readme" "forge: README flag table is non-empty"
assert_eq "$_forge_flags" "$_forge_readme" \
          "forge: flags.md and README flag tables agree"

# --- forge: the plan entry verb is documented in all three places ---
assert_file "$ROOT/skills/forge/references/modes/plan-entry.md" \
  "forge: plan-entry.md exists"
assert_contains "$ROOT/skills/forge/SKILL.md" 'after .`?plan.`? keyword' \
  "forge SKILL.md: target grammar has a plan row"
assert_contains "$ROOT/skills/forge/references/flags.md" '/forge plan <path>' \
  "forge flags.md: entry-verbs table has the plan verb"

# --- blacksmith: skeleton exists and its flag tables agree ---
BS="$ROOT/skills/blacksmith-orchestrate"
assert_file "$BS/SKILL.md"                      "blacksmith: SKILL.md exists"
assert_file "$BS/references/entry-routes.md"    "blacksmith: entry-routes.md exists"
assert_file "$BS/references/flags.md"           "blacksmith: flags.md exists"
_bs_flags=$(flag_names "$BS/references/flags.md" '^## Flags')
_bs_skill=$(flag_names "$BS/SKILL.md" '^## Parameters')
assert_nonempty "$_bs_flags" "blacksmith: flags.md flag table is non-empty"
assert_nonempty "$_bs_skill" "blacksmith: SKILL.md Parameters flag table is non-empty"
assert_eq "$_bs_flags" "$_bs_skill" \
          "blacksmith: SKILL.md and flags.md flag tables agree"

# --- blacksmith: analysis route and scout script ---
assert_file "$BS/references/plan-sourced.md" "blacksmith: plan-sourced.md exists"
assert_file "$BS/scripts/scout-fanout.mjs"   "blacksmith: scout-fanout.mjs exists"
assert_contains "$BS/references/plan-sourced.md" 'dispatch-ready' \
  "plan-sourced.md: defines the dispatch-ready check"
assert_contains "$BS/references/plan-sourced.md" 'stale' \
  "plan-sourced.md: defines the freshness guard"

# scout-fanout.mjs is deliberately NOT `node --check`-able: it is a Workflow
# script, not a standalone module. The Workflow runtime evaluates its body in
# a wrapper that supplies agent/parallel/pipeline/phase/log/args/budget as
# free variables and permits a top-level `return` as the script's result —
# that is its real contract, documented in the file's own header comment.
# `node --check` would reject that on sight, so a parse check here would
# reward wrapping the body in an exported function, which parses cleanly but
# breaks the script at the runtime that actually calls it. These structural
# checks assert the shape the Workflow runtime and later tasks depend on
# instead of module validity.
_scout="$BS/scripts/scout-fanout.mjs"
assert_contains "$_scout" 'export const meta' \
  "scout-fanout.mjs: exports meta"
assert_contains "$_scout" 'blacksmith-scout-fanout' \
  "scout-fanout.mjs: meta.name is blacksmith-scout-fanout"
if [ -f "$_scout" ] && grep -q 'export default' "$_scout"; then
  fail "scout-fanout.mjs: no export default (Workflow scripts are not standalone modules)"
else
  pass "scout-fanout.mjs: no export default (Workflow scripts are not standalone modules)"
fi
for _field in ref title kind filesToTouch symbols plan passCriteria difficulty \
              blastRadius declaredBlockers openQuestions risks; do
  assert_contains "$_scout" "$_field" "scout-fanout.mjs: schema has field $_field"
done

# --- blacksmith: Step 4 triage ---
assert_file "$BS/references/triage.md" "blacksmith: triage.md exists"
assert_contains "$BS/references/triage.md" 'never be assigned .`?lite' \
  "triage.md: states the blast-radius depth floor"
assert_contains "$BS/references/triage.md" 'never the only reviewer' \
  "triage.md: states the cross-model review floor"
assert_eq "$(awk '/^## Axis 1/{f=1;next} /^## /{f=0} f' "$BS/references/triage.md" \
  | grep -c '^| high\|^| medium\|^| low')" "3" \
  "triage.md: tier table has exactly three difficulty rows"

# --- blacksmith: Step 4 collision graph ---
assert_file "$BS/references/collision-graph.md" "blacksmith: collision-graph.md exists"
assert_contains "$BS/references/collision-graph.md" 'acyclic by construction' \
  "collision-graph.md: states the acyclicity property"
assert_contains "$BS/references/collision-graph.md" 'do not prove independence' \
  "collision-graph.md: states the semantic-conflict caveat"

# --- blacksmith: Step 4/6 scheduling and the Step 5 battle-plan gate ---
assert_file "$BS/references/scheduling.md"  "blacksmith: scheduling.md exists"
assert_file "$BS/references/battle-plan.md" "blacksmith: battle-plan.md exists"
assert_contains "$BS/references/scheduling.md" 'connected components' \
  "scheduling.md: components are the grouping unit"
assert_contains "$BS/references/battle-plan.md" 'yes, forge them' \
  "battle-plan.md: states the approval phrase"

# --- blacksmith: Step 8 relay, and the afk floor exception ---
assert_file "$BS/references/relay.md" "blacksmith: relay.md exists"
assert_file "$BS/references/afk.md"   "blacksmith: afk.md exists"
assert_contains "$BS/references/relay.md" 'merge-base --is-ancestor' \
  "relay.md: uses the ancestor proof"
assert_contains "$BS/references/afk.md" 'single sanctioned exception' \
  "afk.md: labels itself the sanctioned floor exception"
assert_eq "$(awk '/^## The verify checklist/{f=1;next} /^## /{f=0} f' \
  "$BS/references/afk.md" | grep -c '^[0-9]\+\.')" "7" \
  "afk.md: verify checklist has exactly seven items"

# --- blacksmith: every references/*.md carries a manual verification recipe ---
# flags.md and anti-patterns.md are excluded, same as forge's own top-level
# references/ files: a flag matrix and a red-flag/anti-pattern list are not
# behaviors verified by running something, so neither carries a recipe by
# convention.
_bs_norecipe=$(find "$BS/references" -maxdepth 1 -name '*.md' -type f | sort | while read -r _f; do
  case "$_f" in
    */flags.md|*/anti-patterns.md) continue ;;
  esac
  grep -q 'Manual verification recipe' "$_f" || printf '%s\n' "$_f"
done)
assert_eq "$_bs_norecipe" "" \
  "every blacksmith-orchestrate/references/*.md (except flags.md, anti-patterns.md) has a Manual verification recipe"

# --- blacksmith: Steps 6-7 provisioning, dispatch, and the ledger ---
assert_file "$BS/references/ledger.md" "blacksmith: ledger.md exists"
assert_contains "$BS/references/ledger.md" 'git rev-parse --git-common-dir' \
  "ledger.md: ledger lives under the common git dir"
for _st in planned provisioned running review pr-open parked merged done failed; do
  assert_contains "$BS/references/ledger.md" "$_st" "ledger.md: defines state $_st"
done

# --- blacksmith: Step 9 close-out and the hoisted forge steps ---
assert_contains "$BS/SKILL.md" '^## Step 9' "SKILL.md: has a Step 9 close-out"
assert_contains "$BS/SKILL.md" 'hoisted to the orchestrator' \
  "SKILL.md: states that forge Steps 10 and 11 are hoisted"

# --- blacksmith: anti-patterns ---
assert_file "$BS/references/anti-patterns.md" "blacksmith: anti-patterns.md exists"
assert_eq "$(grep -c '^| ' "$BS/references/anti-patterns.md")" "10" \
  "anti-patterns.md: 9 red-flag rows plus the header row"

printf '\n%s\n' "FAILS=$FAILS"
[ "$FAILS" -eq 0 ]
