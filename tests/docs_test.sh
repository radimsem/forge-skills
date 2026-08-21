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

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# Every relative .md link in a markdown file must resolve.
broken_links() { # $1=markdown file
  _dir=$(dirname -- "$1")
  grep -o ']([^)#]*\.md' "$1" | sed 's/^](//' | while read -r _t; do
    case "$_t" in http*|/*) continue ;; esac
    [ -f "$_dir/$_t" ] || printf '%s -> %s\n' "$1" "$_t"
  done
}

# Normalized flag names from the first column of the tables under one heading.
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
assert_eq "$(flag_names "$ROOT/skills/forge/references/flags.md" '^## Flags')" \
          "$(flag_names "$ROOT/README.md" '^## Modifier flags')" \
          "forge: flags.md and README flag tables agree"

# --- forge: the plan entry verb is documented in all three places ---
assert_file "$ROOT/skills/forge/references/modes/plan-entry.md" \
  "forge: plan-entry.md exists"
assert_contains "$ROOT/skills/forge/SKILL.md" 'after .`?plan.`? keyword' \
  "forge SKILL.md: target grammar has a plan row"
assert_contains "$ROOT/skills/forge/references/flags.md" '/forge plan <path>' \
  "forge flags.md: entry-verbs table has the plan verb"

printf '\n%s\n' "FAILS=$FAILS"
[ "$FAILS" -eq 0 ]
