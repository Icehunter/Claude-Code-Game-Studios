#!/usr/bin/env bash
# gate.sh — report which gate artifacts exist for a repo's current stage.
#
# EMITS OBSERVATIONS, NOT A VERDICT. It never says PASS or FAIL of its own;
# the VERDICT line only echoes what docs/design/gate-verdict.md says. The
# caller (the gate reviewer) applies judgement. Always exits 0.
#
# Usage: bash gate.sh [repo-root]     (default: current directory)
# Reads gate.tsv beside this script (rows: stage, min_rigor, glob, pattern, label).
#
# Output:
#   STAGE: <Stage>|unset|unknown(<v>)
#   RIGOR: minimal|standard|full
#   ROWS: <n>
#   ARTIFACT: <label> stage=<S> min_rigor=<r> required=<bool> status=<PRESENT|ABSENT|PATTERN_MISS> glob=<g>
#   VERDICT: <PASS|CONCERNS|FAIL|none>
#   VERDICT_STAGE: <the stage: line of gate-verdict.md, as written>|none
#   OWNER_ACCEPTED: yes|no
HERE="$(cd "$(dirname "$0")" && pwd)"
TSV="$HERE/../gate.tsv"   # pack root; falls back to beside the script
[ -f "$TSV" ] || TSV="$HERE/gate.tsv"
ROOT="${1:-.}"
D="$ROOT/docs/design"

# value <file> <key>: first "key: value" line, trimmed, unquoted, comment stripped.
value() {
  [ -f "$1" ] || return 0
  sed -n "s/^$2:[[:space:]]*//p" "$1" 2>/dev/null | head -n 1 \
    | sed -e 's/[[:space:]]*#.*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/" -e 's/[[:space:]]*$//'
}

stage_idx() {
  case "$1" in
    Concept) echo 0;; Design) echo 1;; "Technical Setup") echo 2;;
    Build) echo 3;; Harden) echo 4;; Release) echo 5;; *) echo -1;;
  esac
}
rigor_idx() { case "$1" in minimal) echo 0;; standard) echo 1;; full) echo 2;; *) echo -1;; esac; }

stage=$(value "$D/STATUS.md" stage)
rigor=$(value "$D/STATUS.md" rigor | tr '[:upper:]' '[:lower:]')
cur=-1
if [ -z "$stage" ]; then echo "STAGE: unset"
else
  cur=$(stage_idx "$stage")
  if [ "$cur" -lt 0 ]; then echo "STAGE: unknown($stage)"; else echo "STAGE: $stage"; fi
fi
# unset or unknown stage: compute required as if the stage were Concept
[ "$cur" -ge 0 ] || cur=0
[ "$(rigor_idx "$rigor")" -ge 0 ] || rigor=minimal
echo "RIGOR: $rigor"
rcur=$(rigor_idx "$rigor")

rows=$(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$TSV" 2>/dev/null | wc -l | tr -d ' ')
echo "ROWS: ${rows:-0}"

grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$TSV" 2>/dev/null | {
  while IFS="$(printf '\t')" read -r rstage rrigor glob pat label; do
    req=false
    ri=$(stage_idx "$rstage"); mi=$(rigor_idx "$rrigor")
    [ "$cur" -ge 0 ] && [ "$ri" -le "$cur" ] && [ "$mi" -le "$rcur" ] && req=true
    status=ABSENT; found=0
    for f in "$ROOT"/$glob; do
      [ -f "$f" ] || continue
      found=1
      if [ "$pat" = "-" ] || grep -Eq -- "$pat" "$f" 2>/dev/null; then status=PRESENT; break; fi
    done
    [ "$found" = 1 ] && [ "$status" = ABSENT ] && status=PATTERN_MISS
    echo "ARTIFACT: $label stage=$rstage min_rigor=$rrigor required=$req status=$status glob=$glob"
  done
}

v=$(sed -n 's/^verdict:[[:space:]]*//p' "$D/gate-verdict.md" 2>/dev/null | head -n 1 \
    | sed -e 's/[[:space:]]*$//' | tr '[:lower:]' '[:upper:]')
echo "VERDICT: ${v:-none}"
vs=$(value "$D/gate-verdict.md" stage)
echo "VERDICT_STAGE: ${vs:-none}"

owner=no
if [ -f "$D/gate-verdict.md" ]; then
  owner=$(awk '
    /^owner-accepted: CONCERNS/ { seen=1; next }
    seen && /^quote:/ { q=$0; sub(/^quote:[[:space:]]*/, "", q); gsub(/^"+|"+$/, "", q); if (q != "") { print "yes"; exit } }
    END { }' "$D/gate-verdict.md")
  [ "$owner" = yes ] || owner=no
fi
echo "OWNER_ACCEPTED: $owner"
exit 0
