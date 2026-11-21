# Project kinds

`project.kind` in `project.yaml` says what the project is. Absent means `game`.
`service`, `application` and `generic` each have a pack in `.claude/kinds/`:
the shared base `_software/` plus the kind's extras. `game` has no pack: it
uses the studio as it stands.

## Install

```bash
ai-init --kind service --studio-dir <this repo>
```

`ai-init` copies the pack into the target repo. Check a pack here first with
`bash .claude/scripts/pack-check.sh <kind>`.

## Stages

Concept, Design, Technical Setup, Build, Harden, Release. On a fresh repo
(`gate.sh` prints `STAGE: unset`) the orchestrator first has the architect
create `docs/design/STATUS.md` at `stage: Concept`. The design-reviewer writes a
verdict only at Concept and Design, once per stage (again only after a FAIL or
an unaccepted CONCERNS has been repaired). After a `verdict: PASS` (or an
owner-accepted CONCERNS) whose `stage:` names the current stage, the
orchestrator dispatches the architect to advance `STATUS.md` one step: Concept
to Design, Design to Technical Setup. The pack defines no gate rows for
Technical Setup or later, so no verdict is written there: the orchestrator
reports the stage and stops, and Technical Setup to Build, Build to Harden and
Harden to Release happen only on the owner's explicit instruction, relayed
quoted to the architect. Software kinds never advance through `/gate-check`,
which is game-staged. The planner runs only at Technical Setup or later, after
a PASS whose `stage:` is Design or later: a Concept PASS never unlocks it. The
one exception is the premise-check spike: before the design PASS the planner
may write a single `spike-<name>.md` brief (first line `SPIKE: delete when
done`, no `docs/design/` paths), which one builder runs without the design
record, outside the gate.

## Rigor tiers

| Tier | Needs |
|---|---|
| `minimal` (default) | premise-check evidence and a decision log |
| `standard` | adds ADRs for critical decisions |
| `full` | adds ADRs for all decisions and the kind's contract or flow checklist |

The tiers are the studio's `modes.rigor` tiers: the same three names with the
same meaning. One thing differs, on purpose: a software kind keeps its tier in
the target repo's `docs/design/STATUS.md` (`rigor:`), not in `project.yaml`,
because a target repo has no `project.yaml` and no `resolve_config`. The owner
sets it; the architect copies it unchanged. `gate.sh` reads it
case-insensitively and treats an unknown value as `minimal`.

## docs/design/ files

| File | Written by | Holds |
|---|---|---|
| `constraints.md` | requirements-owner | the `C<n>` constraints |
| `premise-check.md` | architect | `## Sample`, `## Sample fit`, `## Result` |
| `design-record.md` | architect | `## Approach`, `## Constraint check`, `## Decision log` |
| `adr/*.md` | architect | one decision each |
| `gate-verdict.md` | design-reviewer; requirements-owner appends `## Owner acceptance` | PASS, CONCERNS or FAIL, `stage:`, plus `## Owner acceptance` if accepted |
| `slice-review.md` | design-reviewer | one block per finished slice |
| `STATUS.md` | architect | `stage`, `rigor`, `advanced-on` |
| `api-contract.md`, `failure-modes.md` | architect | service extras at `full` |
| `state-flow.md`, `ux-flow.md` | architect | application extras at `full` |

## Write scopes

Each pack agent file lists the files it may write in a `writes:` frontmatter
line (space-separated paths or globs, each under `docs/design/`). `ai-init`
turns the list into the agent's edit permissions; an agent with
`access: design-write` and no `writes:` falls back to `docs/design/*`.
`pack-check.sh` reports a `writes:` entry outside `docs/design/` or with `..`.

## Shell permission limits

`ai-init` writes OpenCode permission rules, and OpenCode matches a shell
command with a wildcard that knows only `*` and `?`, both of which also match a
literal `*` or `?`. It turns a backslash into `/`, compares case-sensitively,
and does not resolve the path an `rm` names. Every shell user gets denies for
chaining and substitution (`;`, `&`, `|`, newline, CR, tab, `$`, backticks,
`<(`, `>`, `..`, `--output`) and for `git difftool`, `--ext-diff` and
`--no-index`. Builders' `rm` also denies options after an operand, absolute and
`~` operands, quotes, `[` and `{`, and the lower, UPPER and Capitalized forms of
the protected names (and of `docs/design` when a kind is installed).

What a deny cannot express, and so stays open to a builder's `rm`:

- a `*` or `?` glob (`rm *.md`, `rm d?cs/design/x.md`, `rm docs/d*/x.md`)
- a backslash inside a name (`rm d\ocs/design/x.md`, `rm .\./x`)
- mixed case inside a word on a case-insensitive volume such as macOS APFS
  (`rm dOcs/design/x.md`, `rm .oPencode/agents/x.md`)

The edit tool is not affected: OpenCode resolves an edited path to its on-disk
case and real path before the check. The committer's `git add` takes plain
paths and its `git commit` takes `-m` only; it can still stage more than it was
named with a glob pathspec (`git add *`, `git add src/*`), and
`git commit -m x <path>` commits that path's working-tree state without
staging it. A builder can change the code `check.sh` runs, and a commit
runs the repo's hooks: both are by design. Accepted as limits of the wildcard
syntax; a delete script that checks its real arguments would close the `rm`
ones.
