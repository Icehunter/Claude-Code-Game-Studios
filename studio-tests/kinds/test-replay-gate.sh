#!/usr/bin/env bash
# test-replay-gate.sh — real gate.sh (base gate.tsv) against the replay scenario fixtures.
# Covers only gate.sh observations, not model or reviewer behaviour. See replay-scenarios.md.
# Usage: bash studio-tests/kinds/test-replay-gate.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../.claude/kinds/_software/scripts/gate.sh"
FIX="$HERE/fixtures/replay"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "PASS $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "  $2"; }
has() {
  out=$(bash "$SCRIPT" "$2" 2>&1); rc=$?
  if [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -Fxq -- "$3"; then ok "$1"
  else bad "$1 (rc=$rc)" "missing: $3"; printf '%s\n' "$out" | sed 's/^/    /'; fi
}
row() { # row <label> <status> <glob>
  echo "ARTIFACT: $1 stage=Design min_rigor=minimal required=true status=$2 glob=$3"
}
PM=docs/design/premise-check.md
DR=docs/design/design-record.md

S="$FIX/constraint-ignored"
has "1 stage" "$S" "STAGE: Design"
has "1 constraints present" "$S" \
 "ARTIFACT: constraints recorded stage=Concept min_rigor=minimal required=true status=PRESENT glob=docs/design/constraints.md"
has "1 constraint-check row PRESENT (gate cannot see C1 omitted)" "$S" "$(row 'design-record has Constraint check' PRESENT $DR)"
has "1 verdict none" "$S" "VERDICT: none"
grep -q 'C1: Feature X will not work, do not build it' "$S/docs/design/constraints.md" && ok "1 C1 text" || bad "1 C1 text"
grep -q '^## Constraint check' "$S/$DR" && ! sed -n '/^## Constraint check/,$p' "$S/$DR" | grep -q 'C1:' && ok "1 check omits C1" || bad "1 check omits C1"

S="$FIX/fixture-mismatch"
has "2 stage" "$S" "STAGE: Design"
has "2 Sample fit PRESENT" "$S" "$(row 'premise-check has Sample fit' PRESENT $PM)"
has "2 Result PATTERN_MISS" "$S" "$(row 'premise-check has Result' PATTERN_MISS $PM)"
grep -q '^## Sample$' "$S/$PM" && grep -qi postgres "$S/$PM" && grep -qi redshift "$S/fixtures/NOTE.md" && ok "2 fixture contradiction" || bad "2 fixture contradiction"

S="$FIX/unrepresentative-sample"
has "3 Sample fit PRESENT" "$S" "$(row 'premise-check has Sample fit' PRESENT $PM)"
has "3 Result PRESENT" "$S" "$(row 'premise-check has Result' PRESENT $PM)"
grep -qi 'representative' "$S/$PM" && ! grep -qi 'DDL' <(sed -n '/^## Sample fit/,/^## Result/p' "$S/$PM") && ok "3 fit claims representative, silent on DDL" || bad "3 fit claims representative"

# 4. fresh repo: no STATUS.md, only constraints.md. Only the Concept row is required, so a PASS here
# gates Concept, never Design. The orchestrator prompt (not gate.sh) creates STATUS.md and keeps the
# planner locked until a Design-or-later verdict; see replay-scenarios.md, scenario 4.
S="$FIX/fresh-repo"
[ ! -e "$S/docs/design/STATUS.md" ] && ok "4 no STATUS.md" || bad "4 no STATUS.md"
has "4 stage unset" "$S" "STAGE: unset"
has "4 rigor minimal" "$S" "RIGOR: minimal"
has "4 verdict stage none" "$S" "VERDICT_STAGE: none"
req=$(bash "$SCRIPT" "$S" | grep 'required=true' | sed 's/^ARTIFACT: \(.*\) stage=.*/\1/')
[ "$req" = "constraints recorded" ] && ok "4 required rows exactly [constraints]" || bad "4 required rows exactly [constraints]" "got: $req"
has "4 constraints PRESENT" "$S" \
 "ARTIFACT: constraints recorded stage=Concept min_rigor=minimal required=true status=PRESENT glob=docs/design/constraints.md"

# 5. Concept PASS: STATUS.md stage Concept, constraints present, verdict PASS for Concept. No Design row is
# required, and VERDICT_STAGE says Concept, so this PASS cannot be read as the design gate.
S="$FIX/concept-pass"
has "5 stage Concept" "$S" "STAGE: Concept"
has "5 verdict PASS" "$S" "VERDICT: PASS"
has "5 verdict stage Concept" "$S" "VERDICT_STAGE: Concept"
n=$(bash "$SCRIPT" "$S" | grep -c '^ARTIFACT: .* stage=Design .*required=true')
[ "$n" = 0 ] && ok "5 no Design row required" || bad "5 no Design row required" "got $n"
n=$(bash "$SCRIPT" "$S" | grep -c '^ARTIFACT: .* stage=Design .*required=false')
[ "$n" = 5 ] && ok "5 all five Design rows required=false" || bad "5 all five Design rows required=false" "got $n"
req=$(bash "$SCRIPT" "$S" | grep 'required=true' | sed 's/^ARTIFACT: \(.*\) stage=.*/\1/')
[ "$req" = "constraints recorded" ] && ok "5 required rows exactly [constraints]" || bad "5 required rows exactly [constraints]" "got: $req"

# 6. Technical Setup: the Design PASS moved the stage on. The pack defines no row for Technical Setup or later, so
# gate.sh shows no row of this stage to require and the orchestrator writes no new verdict (rule 8 fires only at
# Concept or Design); the stage moves on only on the owner's word (rule 11). Earlier rows stay required.
S="$FIX/tech-setup"
has "6 stage Technical Setup" "$S" "STAGE: Technical Setup"
has "6 verdict PASS" "$S" "VERDICT: PASS"
has "6 verdict stage Design" "$S" "VERDICT_STAGE: Design"
n=$(bash "$SCRIPT" "$S" | grep -cE '^ARTIFACT: .* stage=(Technical Setup|Build|Harden|Release) ')
[ "$n" = 0 ] && ok "6 no Technical Setup or later row" || bad "6 no Technical Setup or later row" "got $n"
n=$(bash "$SCRIPT" "$S" | grep 'required=true' | grep -vcE ' stage=(Concept|Design) ')
[ "$n" = 0 ] && ok "6 every required row is Concept or Design" || bad "6 every required row is Concept or Design" "got $n"
n=$(bash "$SCRIPT" "$S" | grep 'required=true' | grep -vc 'status=PRESENT')
[ "$n" = 0 ] && ok "6 every required row PRESENT" || bad "6 every required row PRESENT" "got $n"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
