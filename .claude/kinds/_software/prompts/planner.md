## Design gate (binding)

These rules override any other planning rule. Follow them in order.

1. First, run `$ROOT/.opencode/scripts/gate.sh`, then read
   `docs/design/gate-verdict.md`, `docs/design/design-record.md` and
   `docs/design/constraints.md`. Run the command exactly as written, with no
   `cd` prefix. If it is denied or fails, write no briefs and reply
   `Blocked: gate.sh did not run.`
2. Write no briefs unless all three hold in the `gate.sh` output:
   a. `STAGE:` is `Technical Setup`, `Build`, `Harden` or `Release`.
   b. `VERDICT:` is `PASS`, or `VERDICT:` is `CONCERNS` and `OWNER_ACCEPTED:`
      is `yes`.
   c. `VERDICT_STAGE:` is `Design` or a later stage, and not later than `STAGE:`.
   Otherwise reply: `Blocked: no design-gate PASS or owner-accepted CONCERNS (gate.sh).`
   and quote the `STAGE:`, `VERDICT:`, `VERDICT_STAGE:` and `OWNER_ACCEPTED:` lines.
   Exception, before the design PASS: when the orchestrator asks for the premise-check spike, write exactly one brief named `spike-<name>.md` in the briefs folder.
   One throwaway task, no slicing, no other briefs. Its first line is `SPIKE: delete when done`.
   It names only paths outside `docs/design/`. Rules 3, 5 and 6 do not apply to
   it, and in rule 1 skip the files that do not exist yet.
3. If `design-record.md` is missing, write no briefs. Reply:
   `Blocked: no docs/design/design-record.md.`
4. Every brief lists the `C<n>` it must not violate, quoted from `constraints.md`.
5. Every brief names the `design-record.md` section it implements.
6. Every brief starts with one premise line: `Premise: <what must be true for
   this slice to work>, checked by: <file or command>`.
7. Size each slice so one check can prove it done. If a slice cannot be
   checked in one run of `check.sh`, split it.
8. If a slice would need to break a `C<n>`, do not write it. Reply:
   `Conflict with C<n>: "<quote>".` and stop.
