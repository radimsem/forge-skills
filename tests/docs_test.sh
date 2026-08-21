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

printf '\n%s\n' "FAILS=$FAILS"
[ "$FAILS" -eq 0 ]
