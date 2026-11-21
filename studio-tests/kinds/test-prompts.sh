#!/usr/bin/env bash
# test-prompts.sh — the pack prompts and agents state the stage, review-scope and spike rules in the exact words
# below. Observations of the text only, not of model behaviour (see replay-scenarios.md for the manual replays).
# Usage: bash studio-tests/kinds/test-prompts.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
K="$HERE/../../.claude/kinds/_software"
ORCH="$K/prompts/orchestrator.md"; PLAN="$K/prompts/planner.md"; BUILD="$K/prompts/builder.md"
ARCH="$K/agents/architect.md"; REV="$K/agents/design-reviewer.md"
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "PASS $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; [ -n "${2:-}" ] && echo "  $2"; }
has()  { if grep -qF -- "$3" "$2"; then ok "$1"; else bad "$1" "$(basename "$2") lacks: $3"; fi; }
hasnt() { if grep -qF -- "$3" "$2"; then bad "$1" "$(basename "$2") still has: $3"; else ok "$1"; fi; }
# rule <file> <n>: the text of numbered rule n (from "n. " to the next top-level "m. ")
rule() { awk -v n="$2" '$0 ~ "^" n "\\. " { on = 1 } on && $0 ~ "^[0-9]+\\. " && $0 !~ "^" n "\\. " { exit } on' "$1"; }
inrule() { # label file n text
  if rule "$2" "$3" | grep -qF -- "$4"; then ok "$1"; else bad "$1" "rule $3 of $(basename "$2") lacks: $4"; fi
}

# R1: the verdict is written only at Concept and Design, once per stage; later stages advance on the owner's word
inrule "R1 rule 8 fires only at Concept or Design" "$ORCH" 8 '`STAGE:` is `Concept` or `Design`.'
inrule "R1 rule 8 needs no verdict for this stage yet" "$ORCH" 8 '`VERDICT_STAGE:` is not `STAGE:` (no verdict for this stage yet)'
inrule "R1 rule 8 re-review only after a repair" "$ORCH" 8 'and the owning role has since repaired the findings'
inrule "R1 rule 11 advances on a verdict only at Concept or Design" "$ORCH" 11 'and `STAGE:` is `Concept` or `Design`'
inrule "R1 rule 11 table: Concept on a Concept PASS" "$ORCH" 11 '| Concept | Design | a PASS for Concept |'
inrule "R1 rule 11 table: Design on a Design PASS" "$ORCH" 11 '| Design | Technical Setup | a PASS for Design |'
for r in "| Technical Setup | Build |" "| Build | Harden |" "| Harden | Release |"; do
  inrule "R1 rule 11 table: $r on the owner's word" "$ORCH" 11 "$r the owner's explicit instruction |"
done
inrule "R1 rule 11 stops at Technical Setup" "$ORCH" 11 'From `Technical Setup` on, the pack defines no gate rows and no verdict is written: report the stage to the owner and stop advancing.'
inrule "R1 rule 11 relays the owner" "$ORCH" 11 "Advance only on the owner's explicit instruction: relay the owner's words to the architect, quoted."
has "R1 architect: verdict advance only at Concept or Design" "$ARCH" '`STAGE:` must be `Concept` or `Design`'
has "R1 architect: owner advance from Technical Setup" "$ARCH" "From \`Technical Setup\` on, advance only when the orchestrator relays the owner's explicit instruction, quoted."
has "R1 architect: owner quote recorded" "$ARCH" "advanced-on: \"owner: <the owner's words, quoted>\""
for f in "$ORCH" "$ARCH"; do   # the old two-column row, advanced on a verdict, is gone
  if grep -qE '\| Technical Setup \| Build \|[[:space:]]*$' "$f"; then bad "R1 $(basename "$f"): old Technical Setup row"
  else ok "R1 $(basename "$f"): no verdict-driven Technical Setup to Build row"; fi
done

# R2: the design-reviewer judges only required=true rows of the current stage
has "R2 reviewer scope" "$REV" 'Judge only the rows `gate.sh` prints with `required=true` for the current `STAGE:`'
has "R2 never a FAIL reason" "$REV" 'A `required=false` row, or an artifact for a later stage, is never a FAIL reason.'
has "R2 FAIL rules scoped" "$REV" 'Each rule below applies only to an artifact whose row is `required=true`.'

# R3: rule 7 owner map covers every gate row's file
for f in api-contract.md failure-modes.md state-flow.md ux-flow.md STATUS.md; do
  inrule "R3 rule 7 maps $f" "$ORCH" 7 "\`$f\`"
done
inrule "R3 rule 7 kind extras and STATUS.md go to the architect" "$ORCH" 7 '`api-contract.md`, `failure-modes.md`, `state-flow.md`, `ux-flow.md`, `STATUS.md`: architect.'
inrule "R3 rule 7 output-style.md" "$ORCH" 7 '`output-style.md`: optional, installed by ai-init.'
# every glob in the gate tables has an owner in rule 7
for t in "$K/gate.tsv" "$K/../service/gate.tsv" "$K/../application/gate.tsv"; do
  for g in $(grep -v '^#' "$t" | cut -f3 | sed 's#^docs/design/##; s#\*\.md$#*.md#' | sort -u); do
    inrule "R3 rule 7 owns $g ($(basename "$(dirname "$t")"))" "$ORCH" 7 "\`$g\`"
  done
done

# R4: the planner writes the premise-check spike brief; the builder runs it without the design record
inrule "R4 rule 3c dispatches the planner for the spike brief" "$ORCH" 3 'dispatch the planner for one spike brief (`spike-<name>.md` in the briefs folder), then one builder to run it through `check.sh`.'
inrule "R4 rule 12 spike exception" "$ORCH" 12 'The spike brief in rule 3c is the only exception.'
has "R4 planner exception to its lock" "$PLAN" 'Exception, before the design PASS: when the orchestrator asks for the premise-check spike, write exactly one brief named `spike-<name>.md` in the briefs folder.'
has "R4 planner spike: one task" "$PLAN" 'One throwaway task, no slicing, no other briefs.'
has "R4 planner spike: first line" "$PLAN" 'Its first line is `SPIKE: delete when done`.'
has "R4 planner spike: no docs/design paths" "$PLAN" 'It names only paths outside `docs/design/`.'
has "R4 builder: SPIKE skips the design record" "$BUILD" 'If the brief starts with `SPIKE:`, do NOT read `docs/design/design-record.md`; it does not exist yet.'
has "R4 builder: spike deletes its files" "$BUILD" 'Delete the files the spike created when it is done, as the brief says.'
has "R4 builder: otherwise read the design record" "$BUILD" 'Otherwise read `docs/design/design-record.md` and `docs/design/constraints.md` before editing; if the brief conflicts with a `C<n>`, stop and report.'
hasnt "R4 builder: no unconditional design-record read" "$BUILD" 'Read `docs/design/design-record.md` and `docs/design/constraints.md` before editing'
# I2: rules 3c, 7 and 12 agree on exactly one planner exception, the spike brief
inrule "I2 rule 7 exempts the spike brief" "$ORCH" 7 'Do not dispatch the planner, except for the spike brief in rule 3c.'
inrule "I2 rule 3c exempts rules 4, 5, 7 and 12" "$ORCH" 3 'The spike is exempt from the gate in rules 4, 5, 7 and 12'
inrule "I2 rule 12 one exception" "$ORCH" 12 'The spike brief in rule 3c is the only exception.'
n=$(grep -c 'spike brief in rule 3c' "$ORCH")
[ "$n" = 2 ] && ok "I2 exactly two references to the one exception (rules 7, 12)" || bad "I2 spike-exception references" "got $n"
n=$(grep -ciE 'except|exempt' "$ORCH")
[ "$n" = 4 ] && ok "I2 no other planner or gate exception" || bad "I2 exceptions in orchestrator.md" "got $n (want 4: rules 3c, 5, 7, 12)"
# M1: slice reviews run at any stage and never write the gate verdict
has "M1 reviewer: gate verdict only at Concept or Design" "$REV" 'The orchestrator dispatches you for a gate verdict only at `Concept` or `Design`.'
has "M1 reviewer: slice reviews at any stage" "$REV" 'It dispatches you for a slice review at any stage, including `Technical Setup` and later: judge the slice against `design-record.md` and `constraints.md`, and never write or change `gate-verdict.md` for it.'
hasnt "M1 reviewer: old only-at wording" "$REV" 'The orchestrator dispatches you only at `Concept` or `Design`.'

# the planner lock itself is unchanged
inrule "lock: planner rule 2 unchanged" "$PLAN" 2 '`STAGE:` is `Technical Setup`, `Build`, `Harden` or `Release`.'
has "lock: planner blocked reply unchanged" "$PLAN" 'Blocked: no docs/design/design-record.md.'

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
