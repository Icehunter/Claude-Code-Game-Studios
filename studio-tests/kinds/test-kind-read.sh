#!/usr/bin/env bash
# test-kind-read.sh — .claude/scripts/kind-read.sh against fixture project roots.
# Usage: bash studio-tests/kinds/test-kind-read.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../../.claude/scripts/kind-read.sh"
TMPS=""
trap 'for d in $TMPS; do rm -rf "$d"; done' EXIT
pass=0; fail=0

# run_case <name> <project.yaml text or -> <project.local.yaml text or -> <expected output>
run_case() {
  name="$1"; yaml="$2"; local_yaml="$3"; want="$4"
  d=$(mktemp -d); TMPS="$TMPS $d"
  [ "$yaml" = "-" ] || printf '%s\n' "$yaml" > "$d/project.yaml"
  [ "$local_yaml" = "-" ] || printf '%s\n' "$local_yaml" > "$d/project.local.yaml"
  got=$(bash "$SCRIPT" "$d" 2>&1); rc=$?
  if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then
    pass=$((pass + 1)); echo "PASS $name"
  else
    fail=$((fail + 1)); echo "FAIL $name (rc=$rc)"; echo "  want: $(printf '%s' "$want" | tr '\n' '|')"; echo "  got:  $(printf '%s' "$got" | tr '\n' '|')"
  fi
}

nl='
'
run_case "no project.yaml -> game/default" - - "KIND: game${nl}SOURCE: default${nl}PACK: no"
run_case "no kind key -> game/default" "project:
  name: x" - "KIND: game${nl}SOURCE: default${nl}PACK: no"
run_case "kind: service" "project:
  kind: service" - "KIND: service${nl}SOURCE: project.yaml${nl}PACK: yes"
run_case "kind: application" "project:
  kind: application" - "KIND: application${nl}SOURCE: project.yaml${nl}PACK: yes"
run_case "kind: generic" "project:
  kind: generic" - "KIND: generic${nl}SOURCE: project.yaml${nl}PACK: yes"
run_case "kind: tool has no pack" "project:
  kind: tool" - "KIND: tool${nl}SOURCE: project.yaml${nl}PACK: no"
run_case "kind: game explicit" "project:
  kind: game" - "KIND: game${nl}SOURCE: project.yaml${nl}PACK: no"
run_case "kind: bogus" "project:
  kind: bogus" - "KIND: invalid(bogus)${nl}SOURCE: project.yaml${nl}PACK: no"
run_case "project.local.yaml kind ignored" "project:
  name: x" "project:
  kind: service" "KIND: game${nl}SOURCE: default${nl}PACK: no"
run_case "project.local.yaml does not override project.yaml" "project:
  kind: tool" "project:
  kind: service" "KIND: tool${nl}SOURCE: project.yaml${nl}PACK: no"

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
