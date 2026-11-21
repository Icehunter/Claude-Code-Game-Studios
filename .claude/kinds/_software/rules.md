# _software pack rules

Shared base for the `service`, `application` and `generic` kinds.

## Write scope

| Role | Writes (`writes:` in its agent file) | Never writes |
|---|---|---|
| requirements-owner | `docs/design/constraints.md`; `docs/design/gate-verdict.md`, only to append `## Owner acceptance` | product code, any other file |
| architect | `docs/design/STATUS.md`, `docs/design/premise-check.md`, `docs/design/design-record.md`, `docs/design/adr/*`, the kind extras (`api-contract.md`, `failure-modes.md`, `state-flow.md`, `ux-flow.md`) | product code, `constraints.md`, `gate-verdict.md`, `slice-review.md` |
| design-reviewer | `docs/design/gate-verdict.md` (design gate), `docs/design/slice-review.md` (slices) | product code, any document it reviews |

Each pack agent lists its files in a `writes:` frontmatter line. `ai-init`
turns that list into the agent's only edit permissions, so a role cannot edit
another role's file. Product code is written by builders, from planner briefs,
after the gate. Builders cannot edit or `rm` anything under `docs/design/`.

## Reviewer independence

1. The design-reviewer never reviews a document it wrote.
2. The design-reviewer runs on a different model from the architect.
3. The verdict is written only by the design-reviewer. `gate.sh` reports
   observations, never a verdict. The orchestrator never writes one.

## Constraint binding

1. Every owner-stated constraint is a numbered `C<n>` in
   `docs/design/constraints.md`, quoted exactly.
2. A `C<n>` is binding on every role. On conflict: stop, report to the owner
   quoting the `C<n>`, wait. Never argue it, never build around it.
3. Only the owner withdraws a constraint.

## Repo conventions (all under `docs/design/`)

- `STATUS.md`: lines `stage: <Stage>` and `rigor: minimal|standard|full`.
  Stages: Concept, Design, Technical Setup, Build, Harden, Release. Default
  rigor is `minimal`; the tier name is read case-insensitively. The architect
  creates the file (`stage: Concept`, `rigor: minimal`) when `gate.sh` prints
  `STAGE: unset`, copies `rigor:` unchanged afterwards, and only the owner
  changes it.
- `constraints.md`: goals, non-goals, `C1`, `C2`, ...
- `premise-check.md`: `## Sample`, `## Sample fit`, `## Result`.
- `design-record.md`: `## Approach`, `## Constraint check`, `## Decision log`.
- `adr/*.md`: critical decisions at `standard`, all decisions at `full`.
- `gate-verdict.md`: `verdict: PASS|CONCERNS|FAIL`, `stage: <Stage>`, one line
  per finding; optional `## Owner acceptance` (written only by the
  requirements-owner, only after the owner's explicit yes; never by the
  orchestrator). Design gate only; only this file advances the stage, and only
  when its `stage:` line names the current stage.
- `slice-review.md`: one `## Slice: <name>` block per slice with
  `slice-result: PASS|FAIL` and findings. Never advances the stage.
- Premise check runs before the gate. Its code spike, if any, is a throwaway
  builder run through `check.sh`, exempt from the gate, deleted afterwards,
  touching no product files beyond what its brief names.
- `output-style.md`: the owner's output rules, read before the first reply.
