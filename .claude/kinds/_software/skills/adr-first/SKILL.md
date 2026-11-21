---
name: adr-first
description: One short design record exists before the first slice; the planner may not slice without it. Use before planning or briefing any slice.
---

# Design record first

The failure this prevents: multi-hour slices planned with no design and no
premise check behind them.

## Rules

1. Before the first slice, `docs/design/design-record.md` exists and has
   `## Approach`, `## Constraint check` and `## Decision log`.
2. The planner runs `gate.sh` and reads `design-record.md` first. It writes no
   briefs unless `gate.sh` shows `STAGE:` at Technical Setup or later,
   `VERDICT: PASS` (or `VERDICT: CONCERNS` with `OWNER_ACCEPTED: yes`), and a
   `VERDICT_STAGE:` of Design or later. A heading in `gate-verdict.md` alone
   is not acceptance.
3. Keep the record short: one page. It names boundaries, data flow, contracts,
   and how each `C<n>` is honoured.
4. Add to `## Decision log` each time a decision is made or changed, with the
   reason and the rejected alternative.
5. ADRs in `docs/design/adr/` by rigor: none required at `minimal`, critical
   decisions at `standard`, all decisions at `full`.
6. Every slice must cite the design-record section it implements. A slice that
   needs a decision the record does not hold goes back to the architect.
