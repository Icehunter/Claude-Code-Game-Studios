#!/usr/bin/env bash
# test-pack-check.sh — .claude/scripts/pack-check.sh on the real packs and on broken copies.
# Usage: bash studio-tests/kinds/test-pack-check.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
SCRIPT="$ROOT/.claude/scripts/pack-check.sh"
TMPS=""
trap 'for d in $TMPS; do rm -rf "$d"; done' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "PASS $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "  $2"; }

for k in service application generic; do
  out=$(bash "$SCRIPT" "$k" 2>&1); rc=$?
  if [ "$rc" = 0 ] && ! printf '%s\n' "$out" | grep -q PROBLEM && printf '%s\n' "$out" | grep -q "^PACK: $k OK"; then ok "real $k passes"
  else bad "real $k passes (rc=$rc)" "$out"; fi
done

# broken <name> <mutator> <expected text>; the mutator runs inside a temp copy of .claude/kinds
broken() {
  d=$(mktemp -d); TMPS="$TMPS $d"
  cp -R "$ROOT/.claude/kinds" "$d/kinds"
  (cd "$d/kinds" && eval "$2")
  out=$(PACK_KINDS_DIR="$d/kinds" bash "$SCRIPT" service 2>&1); rc=$?
  if [ "$rc" != 0 ] && printf '%s\n' "$out" | grep -q "PROBLEM.*$3"; then ok "$1"
  else bad "$1 (rc=$rc)" "$out"; fi
}

broken "skill name differs from directory" \
  "sed -i.bak 's/^name: .*/name: other-name/' service/skills/api-failure-checklist/SKILL.md" "other-name"
broken "listed file missing" \
  "rm _software/prompts/planner.md" "planner.md"
broken "model-role opus" \
  "sed -i.bak 's/^model-role: .*/model-role: opus/' _software/agents/architect.md" "model-role"
broken "game word in SKILL.md" \
  "printf 'See the GDD.\n' >> _software/skills/adr-first/SKILL.md" "game vocabulary"
broken "gate row with four fields" \
  "printf 'Design\tfull\tdocs/x.md\t-\n' >> service/gate.tsv" "fields"
broken "gate row unknown stage" \
  "printf 'Nope\tfull\tdocs/x.md\t-\tlbl\n' >> service/gate.tsv" "stage"
broken "extras duplicate base label" \
  "printf 'Concept\tfull\tdocs/x.md\t-\tconstraints recorded\n' >> service/gate.tsv" "duplicate"

broken "writes outside docs/design" \
  "sed -i.bak 's#^writes: .*#writes: docs/design/STATUS.md src/main.ts#' _software/agents/architect.md" "writes"
broken "writes with .." \
  "sed -i.bak 's#^writes: .*#writes: docs/design/../../x.md#' _software/agents/architect.md" "writes"
broken "writes on a read agent" \
  "sed -i.bak 's/^access: .*/access: read/' _software/agents/architect.md" "writes"
broken "writes key present but empty" \
  "sed -i.bak 's#^writes: .*#writes:#' _software/agents/architect.md" "writes"
for a in architect requirements-owner design-reviewer; do
  w=$(awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1&&/^writes:/{sub(/^writes:[ \t]*/,""); print}' "$ROOT/.claude/kinds/_software/agents/$a.md")
  [ -n "$w" ] && ok "real $a declares writes" || bad "real $a declares writes"
done

echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
