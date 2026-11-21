---
name: premise-check
description: Before any slice is planned, run the proposed approach on a small sample that can actually exercise it, and record the evidence in docs/design/premise-check.md. Use when an approach is chosen and before the planner slices.
---

# Premise check

The failure this prevents: an idea planned into hours of slices without ever
being run on a representative sample, or tested on a sample already known to
lack what the approach needs.

## Rules

1. Do this before the planner writes any slice. No premise check, no slices.
2. Pick the sample to exercise the approach. Name what the approach needs
   (a format, a dialect, a size, a feature) and pick real files that contain it.
3. If the obvious sample cannot exercise the approach, say so in `## Sample fit`
   and pick another before anything is built. Never test on a sample you know
   lacks what the approach needs, and never mention that only afterwards.
4. Keep it small: minutes, not hours.

## Who does what

1. The architect writes `## Sample` (which files, and what in them the approach
   needs) and the success criteria.
2. The `reader` checks the sample against the real files and reports whether
   they contain what the approach needs.
3. Anything that needs running code is a throwaway builder spike, run through
   `check.sh`. The spike is exempt from the gate (the gate cannot pass before
   the premise check exists), is deleted afterwards, and touches no product
   files beyond what its brief names.
4. The architect records the reader's report as `## Sample fit` and the spike
   or reader output as `## Result`.

## Output

`docs/design/premise-check.md`, one short paragraph per section:

```markdown
# Premise check

## Sample
<files or inputs, and what in them the approach needs>
Success criteria: <what result means the premise holds>

## Sample fit
<reader's finding: does the sample contain what the approach needs? yes/no, with evidence>

## Result
<what happened when the approach ran on the sample, against the criteria>
```

Stop, report to the owner and re-plan, and do not slice, when any of these is
true. The design-reviewer fails the gate on each of them:

1. `## Sample fit` is "no".
2. `## Result` misses the success criteria.
3. `## Result` contradicts `## Sample fit`.
4. `## Sample fit` calls the sample representative while the approach needs
   something the sample lacks.
