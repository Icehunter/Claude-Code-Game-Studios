## Design gate (binding)

These rules override any other routing rule. Follow them in order. Do not skip one.

1. First, load the `output-style` skill. Apply it from your first reply.
   Then run `$ROOT/.opencode/scripts/gate.sh`. If it prints `STAGE: unset`
   (no `docs/design/STATUS.md`), dispatch the architect to create
   `docs/design/STATUS.md` with `stage: Concept` and `rigor: minimal` before
   any other dispatch. Rigor changes only on the owner's explicit instruction:
   relay the owner's words to the architect, quoted. Otherwise the architect
   copies `rigor:` unchanged.
2. Work in this order, and only in this order:
   requirements-owner, premise check (rule 3), architect design record, gate,
   planner, builders, design-reviewer plus `code-reviewer`.
3. Premise check, in these steps:
   a. Dispatch the architect to write `## Sample` and the success criteria in
      `docs/design/premise-check.md`.
   b. Dispatch `reader` to check the sample against the real files: does it
      contain what the approach needs? Pass the reader's report on.
   c. If the criteria need code to run, dispatch the planner for one spike brief (`spike-<name>.md` in the briefs folder), then one builder to run it through `check.sh`.
      The spike is exempt from the gate in rules 4, 5, 7 and 12, because the
      gate cannot pass before the premise check exists. The spike is deleted
      afterwards and touches no product files beyond what its brief names.
   d. Dispatch the architect to record the reader's report as `## Sample fit`
      and the spike or reader output as `## Result`.
   e. If `## Sample fit` is no, or `## Result` misses the criteria, stop and
      report to the owner. Do not go on to the design record.
   f. At any stage, even after a PASS: if a `reader` report contradicts
      `premise-check.md` (a sample file missing, or lacking what the approach
      needs), treat it as `## Sample fit` no and stop as in 3e. Never have the
      premise check rewritten to fit, and never have a builder create the sample.
4. Run `$ROOT/.opencode/scripts/gate.sh` before you dispatch the planner.
5. Run `$ROOT/.opencode/scripts/gate.sh` before you dispatch any builder
   (except the spike in rule 3c).
6. Run `$ROOT/.opencode/scripts/gate.sh` again after every stage change.
7. If any `required=true` row shows `status=ABSENT` or `status=PATTERN_MISS`,
   dispatch the role that owns that file.
   Do not dispatch the planner, except for the spike brief in rule 3c.
   - `constraints.md`: requirements-owner.
   - `premise-check.md`: go back to rule 3.
   - `design-record.md`, `adr/*.md`: architect.
   - `api-contract.md`, `failure-modes.md`, `state-flow.md`, `ux-flow.md`, `STATUS.md`: architect.
   - `output-style.md`: optional, installed by ai-init.
8. Dispatch the design-reviewer to write `docs/design/gate-verdict.md` only
   when all three hold in the latest `gate.sh` output:
   a. `STAGE:` is `Concept` or `Design`.
   b. Every `required=true` row is PRESENT.
   c. `VERDICT_STAGE:` is not `STAGE:` (no verdict for this stage yet), or the
      verdict for this stage is FAIL or a CONCERNS the owner did not accept,
      and the owning role has since repaired the findings.
   Never write the verdict yourself.
9. On `verdict: CONCERNS`: show the findings to the owner and ask whether
   they accept them. Only on an explicit yes, dispatch the requirements-owner
   to append `## Owner acceptance` with the lines `owner-accepted: CONCERNS`
   and `quote: "<the owner's words>"`. Never write that section yourself.
   On anything but an explicit yes, send the findings to the owning role.
10. On `verdict: FAIL`: send the findings to the owning role and go back to rule 7.
11. On a design-gate `VERDICT: PASS` (or `VERDICT: CONCERNS` with
    `OWNER_ACCEPTED: yes`) whose `VERDICT_STAGE:` equals `STAGE:` in the
    `gate.sh` output, and `STAGE:` is `Concept` or `Design`, dispatch the
    architect to advance `docs/design/STATUS.md` one step by this table. Then
    go back to rule 6.

    | Stage | New `stage:` | Advanced on |
    |---|---|---|
    | Concept | Design | a PASS for Concept |
    | Design | Technical Setup | a PASS for Design |
    | Technical Setup | Build | the owner's explicit instruction |
    | Build | Harden | the owner's explicit instruction |
    | Harden | Release | the owner's explicit instruction |

    From `Technical Setup` on, the pack defines no gate rows and no verdict is written: report the stage to the owner and stop advancing.
    Advance only on the owner's explicit instruction: relay the owner's words to the architect, quoted.

12. Never dispatch the planner unless all three hold in the latest `gate.sh`
    output:
    a. `STAGE:` is `Technical Setup`, `Build`, `Harden` or `Release`.
    b. `VERDICT:` is `PASS`, or `VERDICT:` is `CONCERNS` and
       `OWNER_ACCEPTED:` is `yes`.
    c. `VERDICT_STAGE:` is `Design` or a later stage, and not later than
       `STAGE:`.
    A Concept PASS only moves the stage to Design. It never unlocks the planner.
    The spike brief in rule 3c is the only exception.
13. If the owner states a constraint, dispatch the requirements-owner to record
    it as the next `C<n>` before any other work.
14. If any plan, brief or result conflicts with a `C<n>` in
    `docs/design/constraints.md`, stop. Report the conflict to the owner,
    quoting the `C<n>`. Do not argue it. Do not build around it.
15. After each slice, dispatch the design-reviewer and `code-reviewer`. Slice
    findings go to `docs/design/slice-review.md`, never `gate-verdict.md`. A
    slice result never advances the stage. The model that wrote a document
    never reviews it.
