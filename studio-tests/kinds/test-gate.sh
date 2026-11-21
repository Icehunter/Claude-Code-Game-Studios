#!/usr/bin/env bash
# test-gate.sh — .claude/kinds/_software/scripts/gate.sh against fixture repos.
# Usage: bash studio-tests/kinds/test-gate.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../.claude/kinds/_software/scripts/gate.sh"
FIX="$HERE/fixtures/gate"
TMPS=""
trap 'for d in $TMPS; do rm -rf "$d"; done' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "PASS $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "  $2"; }

# has <name> <root> <exact line>
has() {
  out=$(bash "$SCRIPT" "$2" 2>&1); rc=$?
  if [ "$rc" = 0 ] && printf '%s\n' "$out" | grep -Fxq -- "$3"; then ok "$1"
  else bad "$1 (rc=$rc)" "missing: $3"; printf '%s\n' "$out" | sed 's/^/    /'; fi
}

E=$(mktemp -d); TMPS="$TMPS $E"
has "a empty: stage"   "$E" "STAGE: unset"
has "a empty: rigor"   "$E" "RIGOR: minimal"
has "a empty: rows"    "$E" "ROWS: 6"
has "a empty: verdict" "$E" "VERDICT: none"
has "a empty: verdict stage" "$E" "VERDICT_STAGE: none"
has "a empty: owner"   "$E" "OWNER_ACCEPTED: no"
n=$(bash "$SCRIPT" "$E" | grep -c '^ARTIFACT: .* status=ABSENT ')
[ "$n" = 6 ] && ok "a empty: all rows ABSENT" || bad "a empty: all rows ABSENT" "got $n"
has "a empty: Concept row required" "$E" \
 "ARTIFACT: constraints recorded stage=Concept min_rigor=minimal required=true status=ABSENT glob=docs/design/constraints.md"
n=$(bash "$SCRIPT" "$E" | grep -c 'required=true')
[ "$n" = 1 ] && ok "a empty: only Concept row required" || bad "a empty: only Concept row required" "got $n"
bash "$SCRIPT" "$TMPS/does-not-exist" >/dev/null 2>&1 && ok "missing dir exits 0" || bad "missing dir exits 0"

SP=$(mktemp -d); TMPS="$TMPS $SP"; mkdir -p "$SP/a b/docs/design" "$SP/c d"
printf '# c\n' > "$SP/a b/docs/design/constraints.md"
has "space root: PRESENT" "$SP/a b" \
 "ARTIFACT: constraints recorded stage=Concept min_rigor=minimal required=true status=PRESENT glob=docs/design/constraints.md"
has "space root: ABSENT" "$SP/c d" \
 "ARTIFACT: constraints recorded stage=Concept min_rigor=minimal required=true status=ABSENT glob=docs/design/constraints.md"

has "b design-record PATTERN_MISS" "$FIX/design-miss" \
 "ARTIFACT: design-record has Constraint check stage=Design min_rigor=minimal required=true status=PATTERN_MISS glob=docs/design/design-record.md"
has "b stage" "$FIX/design-miss" "STAGE: Design"
has "b Decision log required at Design minimal" "$FIX/design-miss" \
 "ARTIFACT: design-record has Decision log stage=Design min_rigor=minimal required=true status=PATTERN_MISS glob=docs/design/design-record.md"

has "c standard: adr required" "$FIX/std" \
 "ARTIFACT: ADRs recorded (at full: one per decision, reviewer judges) stage=Design min_rigor=standard required=true status=ABSENT glob=docs/design/adr/*.md"
has "c standard: rigor" "$FIX/std" "RIGOR: standard"
has "c minimal: adr not required" "$FIX/min" \
 "ARTIFACT: ADRs recorded (at full: one per decision, reviewer judges) stage=Design min_rigor=standard required=false status=ABSENT glob=docs/design/adr/*.md"

has "d bogus stage" "$FIX/bogus" "STAGE: unknown(Bogus)"
has "d bogus: Concept row required" "$FIX/bogus" \
 "ARTIFACT: constraints recorded stage=Concept min_rigor=minimal required=true status=ABSENT glob=docs/design/constraints.md"
has "d bogus: Design row not required" "$FIX/bogus" \
 "ARTIFACT: design-record has Constraint check stage=Design min_rigor=minimal required=false status=ABSENT glob=docs/design/design-record.md"
has "d bogus rigor" "$FIX/bogus" "RIGOR: minimal"

has "e verdict echoed uppercase" "$FIX/concerns" "VERDICT: CONCERNS"
has "e quoted stage with comment" "$FIX/concerns" "STAGE: Technical Setup"
has "e verdict stage echoed" "$FIX/concerns" "VERDICT_STAGE: Design"
o=$(bash "$SCRIPT" "$FIX/concerns" | grep -A1 '^VERDICT: ' | tail -1)
[ "$o" = "VERDICT_STAGE: Design" ] && ok "e VERDICT_STAGE right after VERDICT" || bad "e VERDICT_STAGE right after VERDICT" "got: $o"
has "owner-yes verdict stage" "$FIX/owner-yes" "VERDICT_STAGE: Design"

RC=$(mktemp -d); TMPS="$TMPS $RC"; mkdir -p "$RC/docs/design"
printf 'stage: Design\nrigor: Standard\n' > "$RC/docs/design/STATUS.md"
has "g rigor case-insensitive" "$RC" "RIGOR: standard"
printf 'stage: Design\nrigor: FULL # loud\n' > "$RC/docs/design/STATUS.md"
has "g rigor upper FULL" "$RC" "RIGOR: full"
printf 'stage: Design\nrigor: Strict\n' > "$RC/docs/design/STATUS.md"
has "g invalid rigor -> minimal" "$RC" "RIGOR: minimal"

has "full-ok: adr PRESENT" "$FIX/full-ok" \
 "ARTIFACT: ADRs recorded (at full: one per decision, reviewer judges) stage=Design min_rigor=standard required=true status=PRESENT glob=docs/design/adr/*.md"
has "full-ok: decision log PRESENT" "$FIX/full-ok" \
 "ARTIFACT: design-record has Decision log stage=Design min_rigor=minimal required=true status=PRESENT glob=docs/design/design-record.md"
has "full-ok: Result misses" "$FIX/full-ok" \
 "ARTIFACT: premise-check has Result stage=Design min_rigor=minimal required=true status=PATTERN_MISS glob=docs/design/premise-check.md"

has "owner yes"   "$FIX/owner-yes"   "OWNER_ACCEPTED: yes"
has "owner no"    "$FIX/owner-no"    "OWNER_ACCEPTED: no"
has "owner quote-empty" "$FIX/owner-empty" "OWNER_ACCEPTED: no"

# f: no verdict of its own
bad_n=0
for r in "$E" "$FIX/design-miss" "$FIX/std" "$FIX/bogus" "$FIX/concerns" "$FIX/owner-yes" "$FIX/full-ok"; do
  o=$(bash "$SCRIPT" "$r" 2>&1)
  printf '%s\n' "$o" | grep -Eq '^(PASS|FAIL)' && bad_n=$((bad_n + 1))
  printf '%s\n' "$o" | grep -v '^VERDICT:' | grep -q 'verdict:' && bad_n=$((bad_n + 1))
done
[ "$bad_n" = 0 ] && ok "f no verdict of its own" || bad "f no verdict of its own" "$bad_n offending"

echo "---"; echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
