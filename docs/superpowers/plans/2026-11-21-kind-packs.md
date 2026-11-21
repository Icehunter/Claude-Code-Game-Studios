# Kind Packs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `kind` (game | service | application | generic) to dev-studios with installable role/skill/gate packs, and an `ai-init --kind` flag that installs a pack into a target repo.

**Architecture:** Approach A. dev-studios owns pack content in `.claude/kinds/` (`_software` base plus `service/`, `application/`, `generic/` extras). ai-init copies a pack through its existing staged `write_file` path and appends enforcement text to the orchestrator and planner prompts. Gates reuse dev-studios' model: stage list, `modes.rigor` tiers, an observation-only artifact script, and a reviewer that returns PASS / CONCERNS / FAIL.

**Tech Stack:** bash, awk, jq (ai-init and gate scripts); Markdown with YAML frontmatter (packs); OpenCode agent/skill format.

**Spec:** `docs/superpowers/specs/2026-11-21-kind-packs-design.md`

**Workstreams:** WS1 = Tasks 1-5, repo `/Volumes/Engineering/Icehunter/dev-studios`. WS2 = Tasks 6-10, repo `/Volumes/Engineering/Kodeniks/arcane/projects/hindsight/agent-init/` (local arcane clone). WS2 starts only after WS1 Task 5 passes. **No commits unless the owner asks**; the commit step in each task is replaced by "stop, show `git status`".

## Global Constraints

- `project.kind` values (owner decision): the existing reserved list `game | tool | engine | mod | library` is kept unchanged, and `service | application | generic` are added. Absent means `game`. Only `service | application | generic` have packs; the other values are accepted by `kind-read.sh` but `ai-init --kind` rejects them.
- Use the existing `project.kind` slot (`.claude/docs/effects-map.md:1684`). Do not add a second key.
- Do not seed `modes.review_mode`, `modes.workflow`, `docs.density`, `qa.level`, `modes.story_granularity` or `team.size` in `project.yaml`.
- Default rigor is `minimal`; tiers are `minimal < standard < full`.
- Stages for software kinds: Concept, Design, Technical Setup, Build, Harden, Release.
- Pack roles write Markdown under `docs/design/` only, never product code. Reviewer is never the author of what it reviews.
- Scripts in `.claude/scripts/` and `gate.sh` emit observations, never PASS/FAIL.
- Pack content must not reference game vocabulary or game agents/skills (GDD, genre, engine, playtest, art bible, `.claude/agents/*`).
- Skills install to `.opencode/skills/<name>/SKILL.md`; agents to `.opencode/agents/`; gate script to `.opencode/scripts/gate.sh`.
- ai-init: all output goes through `$STAGE` and `write_file`; no `--kind` means byte-identical stdout and staged files to today's script.
- Builders in target repos cannot edit `.opencode/`, `opencode.json`, `AGENTS.md`, `.claude/`, `.codex/`.
- No AI attribution trailer in commits; no commits unless asked.

## Review Focus

Failure modes the spec implies that no spec task names; each has a test in the owning task.

1. `gate.sh` run in a repo with no `docs/design/` or no `STATUS.md`: must print `STAGE: unset`/`RIGOR: minimal` and ABSENT rows, exit 0, not crash. (Task 3)
2. `STATUS.md` with an unknown stage or rigor value: report `STAGE: unknown(<value>)`, treat rigor as `minimal`, exit 0. (Task 3)
3. `--kind` with a name that has no pack, or `--studio-dir` unset and `$DEV_STUDIOS` empty: clear message, exit 1, nothing written (also under `--dry-run`). (Task 7)
4. Re-run with a different `--kind` when the recorded file list includes a file the owner edited or already removed: delete only listed files that still exist; never delete outside `.opencode/` and `docs/design/output-style.md`. (Task 9)
5. `AGENTS.md` that already has a managed block without kind lines (a pre-kind install): first `--kind` run adds them; a later plain re-run keeps no kind. (Task 9)

---

### Task 1: The `kind` key in dev-studios

**Files:**
- Modify: `.claude/docs/effects-map.md:1684-1730` (the `## project.kind` section)
- Modify: `project.yaml` (add commented documentation of `project.kind`, no value)
- Create: `.claude/scripts/kind-read.sh`
- Test: `studio-tests/kinds/test-kind-read.sh`

**Interfaces:**
- Produces: `bash .claude/scripts/kind-read.sh [project-root]` prints one line `KIND: <value>`, then `SOURCE: <project.yaml|default>` and `PACK: <yes|no>` (yes only for service, application, generic); exit 0. A value outside the eight prints `KIND: invalid(<value>)`, exit 0 (observation, not verdict).

- [ ] **Step 1: Check key handling.** Read `.claude/scripts/config-set.sh`, `.claude/scripts/project-coherence.sh` and `.claude/hooks/yaml-helper.sh` for any key allowlist or value validation for `project.*`. Note whether `project.kind` is already accepted. The spec's open item "confirm the exact key path" ends here: the path is `project.kind` (effects-map line 136 and section 1684).
- [ ] **Step 2: Write `test-kind-read.sh`** with cases: no `project.yaml` -> `KIND: game` / `SOURCE: default`; `project:\n  kind: service` -> `KIND: service` / `SOURCE: project.yaml`; `kind: tool` -> `KIND: tool` / `PACK: no`; `kind: service` -> `PACK: yes`; `kind: bogus` -> `KIND: invalid(bogus)`; `project.local.yaml` carrying `kind: service` is ignored (kind is locked to `project.yaml`, effects-map line 136). Each case builds a temp dir. Run it: expect FAIL (script missing).
- [ ] **Step 3: Implement `kind-read.sh`** using `.claude/scripts/yaml-get.awk` (the existing reader) rather than a new parser.
- [ ] **Step 4: Run the test**: `bash studio-tests/kinds/test-kind-read.sh`; expect all cases PASS.
- [ ] **Step 5: Rewrite the `## project.kind` doc section.** Keep the existing value table and its `tool/engine/mod/library` rows as they are. Add rows for `service`, `application`, `generic` (meaning, and "installable pack: `.claude/kinds/<kind>/`"). Replace the RESERVED banner with a partial-implementation note: `kind-read.sh` reads the key; the pack kinds are consumed by `ai-init --kind` (which takes its value from the flag, not this file); the skill-routing behaviour in the "Affected skills" table stays unbuilt and must be marked as such in that table's heading. `game` = unchanged behaviour.
- [ ] **Step 6: Stop.** Show `git status`.

---

### Task 2: `_software` base pack: roles and skills

**Files:**
- Create: `.claude/kinds/_software/pack.yaml`
- Create: `.claude/kinds/_software/agents/{architect,requirements-owner,design-reviewer}.md`
- Create: `.claude/kinds/_software/skills/{premise-check,user-constraints-binding,adr-first,output-style}/SKILL.md`
- Create: `.claude/kinds/_software/rules.md`
- Create: `.claude/kinds/_software/prompts/{orchestrator,planner,builder}.md`
- Test: `studio-tests/kinds/test-pack-check.sh` (written in Task 4; Task 2 is verified by Task 4's checker)

**Interfaces:**
- Produces, pack manifest `pack.yaml` (decided: needed, so ai-init lists files without guessing):
  ```yaml
  name: _software
  extends: null          # service/application/generic: extends: _software
  agents: [architect, requirements-owner, design-reviewer]
  skills: [premise-check, user-constraints-binding, adr-first, output-style]
  prompts: {orchestrator: prompts/orchestrator.md, planner: prompts/planner.md, builder: prompts/builder.md}
  gate: gate.tsv
  scripts: [gate.sh]
  ```
- Produces, agent frontmatter (ai-init generates the final OpenCode frontmatter from these two fields):
  ```yaml
  ---
  description: <one line>
  mode: subagent
  model-role: plan        # plan | review ; ai-init maps to --plan / --review model
  access: design-write    # read | design-write ; design-write = edit only docs/design/*
  ---
  ```
  `architect` and `requirements-owner`: `model-role: plan`, `design-write`. `design-reviewer`: `model-role: review`, `design-write` (it writes `docs/design/gate-verdict.md`).
- Produces, skill frontmatter: `name` (equals directory) and `description` only (OpenCode skill format; verify against `/Volumes/Engineering/Icehunter/opencode/packages/web/src/content/docs/skills.mdx`).
- Produces, repo conventions the prompts and gate rely on, all under `docs/design/`:
  `STATUS.md` (lines `stage: <Stage>`, `rigor: minimal|standard|full`), `constraints.md` (numbered `C1`, `C2`, ...), `premise-check.md`, `design-record.md`, `adr/*.md`, `gate-verdict.md`, `output-style.md`.

- [ ] **Step 1: Write the three agent files.** Bodies, one decision each:
  - `requirements-owner`: writes `constraints.md` (goals, non-goals, owner-stated constraints as `C<n>`); appends owner-accepted CONCERNS to `gate-verdict.md` quoting the owner; never paraphrases a constraint.
  - `architect`: writes `premise-check.md` inputs (sample + success criteria), `design-record.md` (must contain `## Constraint check` mapping every `C<n>` to how the design honours it) and `adr/*.md`; after a design-reviewer PASS, updates `STATUS.md` stage, quoting the verdict.
  - `design-reviewer`: reads `gate.sh` output, `constraints.md`, `premise-check.md`, `design-record.md`; writes `gate-verdict.md` as `verdict: PASS|CONCERNS|FAIL`, `stage:`, one line per finding; FAIL on any violated `C<n>`, a premise-check whose sample cannot exercise the approach, or a missing required artifact. Also reviews each slice against the design record, alongside the existing `code-reviewer`.
- [ ] **Step 2: Write the four skills**, each aimed at one observed failure (spec section 2): `premise-check` (sample picked to exercise the approach; one paragraph of evidence with sections `## Sample`, `## Sample fit`, `## Result`; who runs what exactly as the spec's "my call": architect writes sample and criteria, `reader` checks them against real files, running code is a throwaway builder spike through `check.sh`); `user-constraints-binding` (stop and re-plan on conflict, never argue or build around); `adr-first` (planner may not slice without the design record); `output-style` (read `docs/design/output-style.md` before the first reply, apply from turn one; if absent, say so once).
- [ ] **Step 3: Write `prompts/orchestrator.md`, `prompts/planner.md`, `prompts/builder.md`.** These carry the enforcement, since skills alone are too weak for cheap models:
  - orchestrator: order is requirements-owner, premise-check, architect, gate, planner, builders, design-reviewer plus `code-reviewer`; run `$ROOT/.opencode/scripts/gate.sh` (absolute path) before dispatching planner or any builder, and again after every stage change; if a required row is ABSENT or PATTERN_MISS, dispatch the owning role, not the planner; dispatch design-reviewer to write the verdict; never dispatch planner without `verdict: PASS` or an owner-accepted CONCERNS in `gate-verdict.md`; on a conflict with a `C<n>` stop and report to the owner; load `output-style` first.
  - planner: read `gate-verdict.md` and `design-record.md` first; refuse to write briefs without PASS or owner-accepted CONCERNS; every brief cites the `C<n>` it must not violate; slices are sized to be checkable, with a premise statement per slice.
  - builder: one added line, "Read `docs/design/design-record.md` and `docs/design/constraints.md` before editing; if the brief conflicts with a `C<n>`, stop and report."
  Use ai-init's placeholders `$ROOT` literally in text; ai-init substitutes them (Task 8).
- [ ] **Step 4: Write `rules.md`** (one page: roles' write scope, reviewer independence, constraint binding) and `pack.yaml` per the Interfaces block.
- [ ] **Step 5: Verify no game vocabulary.** `rg -i "gdd|genre|engine|playtest|art bible|\.claude/agents|game" .claude/kinds/_software` -> expected: no matches.
- [ ] **Step 6: Stop.** Show `git status`.

---

### Task 3: Gate artifacts and `gate.sh`

**Files:**
- Create: `.claude/kinds/_software/gate.tsv`
- Create: `.claude/kinds/_software/scripts/gate.sh`
- Test: `studio-tests/kinds/test-gate.sh`, fixtures under `studio-tests/kinds/fixtures/gate/`

**Interfaces:**
- Consumes: `docs/design/STATUS.md` conventions from Task 2.
- Produces, `gate.tsv`, tab-separated, `#` comments allowed: `stage<TAB>min_rigor<TAB>glob<TAB>pattern<TAB>label`. Pattern `-` means none. Kind packs add rows in their own `gate.tsv`; ai-init concatenates base then extras.
- Produces, `gate.sh [repo-root]` stdout, one fact per line, exit 0 always:
  ```
  STAGE: <Stage>|unset|unknown(<v>)
  RIGOR: minimal|standard|full
  ROWS: <n>
  ARTIFACT: <label> stage=<S> min_rigor=<r> required=<true|false> status=<PRESENT|ABSENT|PATTERN_MISS> glob=<g>
  VERDICT: <PASS|CONCERNS|FAIL|none> (from docs/design/gate-verdict.md, as written there)
  ```
  `required=true` when the row's `stage` is the current stage or earlier and `min_rigor <= RIGOR`. Never prints a verdict of its own. `gate.sh` finds `gate.tsv` beside itself.
- Base rows (decided): Concept `minimal` `docs/design/constraints.md`; Design `minimal` `docs/design/premise-check.md` pattern `^## Sample fit` and again `^## Result`; Design `minimal` `docs/design/design-record.md` pattern `^## Constraint check`; Design `standard` `docs/design/adr/*.md` (one row; "all decisions" at `full` is the reviewer's judgement, noted in the label); Technical Setup `minimal` a `docs/design/design-record.md` pattern `^## Decision log`.

- [ ] **Step 1: Write `test-gate.sh`** with fixture repos and exact expected lines: (a) empty repo: `STAGE: unset`, `RIGOR: minimal`, all rows `ABSENT`, `VERDICT: none`; (b) `STATUS.md` `stage: Design` / `rigor: minimal` with `design-record.md` lacking `## Constraint check` -> that row `PATTERN_MISS`, `required=true`; (c) `rigor: standard` makes the `adr/*.md` row `required=true`, at `minimal` it is `required=false`; (d) `stage: Bogus` -> `STAGE: unknown(Bogus)`; `rigor: loud` -> `RIGOR: minimal`; (e) `gate-verdict.md` with `verdict: CONCERNS` -> `VERDICT: CONCERNS`; (f) the output contains no line starting `PASS`/`FAIL` and never the word `verdict:` in lowercase except the `VERDICT:` echo. Expect FAIL (script missing).
- [ ] **Step 2: Write `gate.tsv`** per the base rows above.
- [ ] **Step 3: Implement `gate.sh`** in bash + awk; model it on `.claude/scripts/artifact-check.sh` header conventions (observations only). Stage order array: Concept, Design, "Technical Setup", Build, Harden, Release.
- [ ] **Step 4: Run** `bash studio-tests/kinds/test-gate.sh`; expect all cases PASS.
- [ ] **Step 5: Stop.** Show `git status`.

---

### Task 4: Kind extras, pack checker, stage doc

**Files:**
- Create: `.claude/kinds/service/{pack.yaml,gate.tsv,skills/api-failure-checklist/SKILL.md}`
- Create: `.claude/kinds/application/{pack.yaml,gate.tsv,skills/state-ux-checklist/SKILL.md}`
- Create: `.claude/kinds/generic/pack.yaml`
- Create: `.claude/scripts/pack-check.sh`
- Create: `.claude/docs/kinds.md` (stages, tiers, file conventions, install command)
- Test: `studio-tests/kinds/test-pack-check.sh`

**Interfaces:**
- Produces: `bash .claude/scripts/pack-check.sh <kind>` for `service|application|generic`: resolves `_software` plus the kind, prints `PACK: <name> OK|PROBLEM <reason>` per pack and exits non-zero on any PROBLEM. Checks: every file named in `pack.yaml` exists; `extends` resolves; each SKILL.md `name:` equals its directory; each agent has `description`, `mode`, `model-role` in {plan, review}, `access` in {read, design-write}; no game-vocabulary match (the Task 2 Step 5 regex); each `gate.tsv` row has five tab fields and a known stage.
- Pack extras: `service` gate rows at `full`: `docs/design/api-contract.md` and `docs/design/failure-modes.md` (Design stage). `application` at `full`: `docs/design/state-flow.md` and `docs/design/ux-flow.md`. The two checklist skills are short: each lists the questions the artifact must answer (service: endpoints, error model, timeouts/retries, idempotency, auth; application: state ownership, data flow, loading/empty/error states, navigation). `generic`: `extends: _software` only.

- [ ] **Step 1: Write `test-pack-check.sh`**: the real three packs pass; a temp copy with a skill whose `name:` differs from its directory, a missing listed file, a `model-role: opus`, and a SKILL.md containing the word "GDD" each yield a `PROBLEM` line naming the cause and a non-zero exit. Expect FAIL.
- [ ] **Step 2: Implement `pack-check.sh`.**
- [ ] **Step 3: Write the three kind packs** per Interfaces.
- [ ] **Step 4: Write `.claude/docs/kinds.md`** (what a kind is, the six stages, rigor tiers per spec section 4, the `docs/design/` file table, "game has no pack", and the command `ai-init --kind service --studio-dir <this repo>`). Note under the stages that software kinds advance `STATUS.md` by hand after a PASS, not through `/gate-check` (which is game-staged). Open question left to the owner, do not build: a `/setup-kind` entry point.
- [ ] **Step 5: Run** `bash studio-tests/kinds/test-pack-check.sh` and `for k in service application generic; do bash .claude/scripts/pack-check.sh $k; done`; expect all OK.
- [ ] **Step 6: Stop.** Show `git status`.

---

### Task 5: WS1 gate: game behaviour unchanged

**Files:**
- Modify: none expected.

- [ ] **Step 1: Run every WS1 test**: `for t in studio-tests/kinds/test-*.sh; do bash "$t" || echo "FAILED $t"; done`; expect no FAILED lines.
- [ ] **Step 2: Parity check for game.** `git diff --stat main -- .claude/agents .claude/skills .claude/genres .claude/engines project.yaml` : expected: only `project.yaml` comment lines changed; nothing under agents, skills, genres, engines.
- [ ] **Step 3: Run the repo's own checks**: `bash .claude/scripts/skill-lint.sh` and `bash .claude/scripts/project-coherence.sh`; expected: same output as on `main` (run both on `git stash`ed tree if needed to compare). Anything new is a defect in this workstream.
- [ ] **Step 4: Report to the owner** with the three outputs. WS2 starts only on their go.

---

### Task 6: ai-init baseline and test harness

**Files (all under `agent-init/`):**
- Create: `tests/lib.sh`, `tests/test-parity.sh`, `tests/fixtures/baseline/` (captured output)
- Create: `tests/fixtures/studio/` (small fake studio: `.claude/kinds/_software` and `.claude/kinds/service` with one agent, one skill, one `gate.tsv`, `gate.sh`, three prompts)

**Interfaces:**
- Produces, `tests/lib.sh`: `new_repo` (prints path of a fresh `git init` temp repo with a distinct name), `run_init <repo> args...` (runs `init-agents.sh --dir <repo> --check true`, with `PATH` unchanged), `norm` (sed filter replacing the temp repo path and `/private/tmp/<name>-briefs` with `<ROOT>` and `<BRIEFS>`).

- [ ] **Step 1: Capture the baseline from the UNMODIFIED script.** `git -C agent-init status` must show `init-agents.sh` unchanged. Run `--dry-run` and a real run on a fresh repo; store normalised stdout as `fixtures/baseline/dry-run.txt` and `run.txt`, and copy the written tree (`.opencode/`, `opencode.json`, `AGENTS.md`, `CLAUDE.md`) to `fixtures/baseline/tree/`. Note: the script probes the gateway and `opencode models`, which print `warning:`/`model:` lines; if those vary, pin them by running with `--gateway http://127.0.0.1:9` and an `opencode` shim absent from `PATH`, and record that in `lib.sh`.
- [ ] **Step 2: Write `test-parity.sh`**: run the same two commands, normalise, `diff -r` against the baseline. Expect PASS on the unmodified script (proves the harness is deterministic; run it twice).
- [ ] **Step 3: Build the fake studio fixture** small enough to read in one screen; its pack files satisfy the manifest and frontmatter contract from Task 2.
- [ ] **Step 4: Stop.** Show `git status`.

---

### Task 7: `--kind`, `--studio-dir`, pack resolution

**Files:**
- Modify: `init-agents.sh` (usage block `:25-50`, arg loop `:55-76`, after `:99`)
- Test: `tests/test-kind-args.sh`

**Interfaces:**
- Produces, in the script: variables `KIND` (default empty), `STUDIO` (default `${DEV_STUDIOS:-}`), `PACKS` (array of pack dirs, base first), and function `resolve_packs` that sets `PACKS` or prints an error and exits 1. `KIND=none` means "remove the kind".
- Valid kinds: `service|application|generic|none`. Any other `project.kind` value (`game|tool|engine|mod|library`) is rejected with "<kind> has no pack; omit --kind"; a value outside all eight is `unknown kind: <v>`.

- [ ] **Step 1: Write `test-kind-args.sh`** with: `--kind service --studio-dir tests/fixtures/studio --dry-run` lists the pack files it would write (assert exact `create:` lines for `.opencode/agents/<role>.md`, `.opencode/skills/<name>/SKILL.md`, `.opencode/scripts/gate.sh`, `.opencode/scripts/gate.tsv`); `--kind bogus` -> exit 1 `unknown kind: bogus`; `--kind tool` -> exit 1 `tool has no pack; omit --kind`; `--kind service` with no `--studio-dir` and `DEV_STUDIOS` unset -> exit 1 naming both ways to set it; `--studio-dir` without `.claude/kinds/service` -> exit 1 `pack not found: <path>`; each failure leaves the repo tree empty, also with `--dry-run`. Expect FAIL.
- [ ] **Step 2: Add the two flags to usage and the arg loop**; call `resolve_packs` after the `git` root check and before any staging (fail fast, nothing written).
- [ ] **Step 3: Parse `pack.yaml`** with `awk`/`sed` for the flat keys in the Task 2 manifest (no YAML dependency; `yq` is not a required tool in this script).
- [ ] **Step 4: Run** `tests/test-kind-args.sh` and `tests/test-parity.sh`; expect PASS.
- [ ] **Step 5: Stop.** Show `git status`.

---

### Task 8: Staging agents, skills, scripts, prompts, permissions

**Files:**
- Modify: `init-agents.sh` (permission helpers near `:112-131`; orchestrator and planner `agent` calls `:140-186`; `BUILDER_BODY` `:189`; staging before `:238`; reviewer warning loop `:101`)
- Test: `tests/test-kind-stage.sh`

**Interfaces:**
- Consumes: `PACKS`, pack manifest keys, `$PLAN`, `$REVIEW`.
- Produces: functions `P_DESIGN_EDIT` (`perm edit 'docs/design/*' allow`), `P_GATE` (shell allow for `$ROOT/.opencode/scripts/gate.sh*` and relative), `P_KIND_SKILL` (`perm skill '*' allow`), `P_KIND_ORCH` (P_GATE + P_KIND_SKILL), `P_KIND_PLAN` (P_KIND_SKILL), `P_KIND_SUBAGENTS` (allow lines for each pack agent). **Every one prints nothing when `KIND` is empty**; they are appended to the existing orchestrator/planner perm lists so the no-kind output is unchanged.
- Produces: `stage_pack` writing into `$STAGE`: for each pack agent a file `.opencode/agents/<name>.md` whose frontmatter is generated from `model-role` (`plan`->`$PLAN`, `review`->`$REVIEW`) and `access` (`read` -> `P_READ`; `design-write` -> `P_READ P_DESIGN_EDIT P_GITRO P_GATE`), plus `perm '*' '*' deny` first like `agent()`; skills copied verbatim; `gate.sh` (executable) and `gate.tsv` (base then extras concatenated, comment header stripped of duplicates); `prompts/orchestrator.md` and `planner.md` appended to the staged orchestrator and planner bodies, `prompts/builder.md` appended to every builder body via `BUILDER_BODY`. Literal `$ROOT` in pack prompts is replaced with the real root at staging.
- Skill permission syntax: the script's existing `permissions:` action/resource/effect list is valid OpenCode (owner-confirmed), and `perm skill '*' allow` follows the same shape. Verify it anyway, in three ways, and record each result in the task notes: (1) read how OpenCode turns agent frontmatter into rules and evaluates the `skill` permission: `/Volumes/Engineering/Icehunter/opencode/packages/opencode/src/tool/skill.ts`, `src/skill/index.ts`, `src/agent/`; (2) in a scratch repo run the staged output through the installed binary: `opencode debug agents` must list `architect`, `requirements-owner`, `design-reviewer` with the expected resolved rules (skill allowed, `edit docs/design/*` allowed, `edit .opencode/*` denied), and `opencode debug skill` must list the four base skills plus the kind's extras; (3) negative probe: stage one agent with `perm skill '*' deny` and confirm `debug agents` shows the skill denied, proving the check can fail. Prefer a per-skill allow list (`perm skill '<name>' allow` for each pack skill) over `'*'` if (2) shows `'*'` also exposes unrelated skills.

- [ ] **Step 1: Write `test-kind-stage.sh`** against the fixture studio: after `--kind service` real run assert files exist (agents, skills, `gate.sh` executable, `gate.tsv` containing both packs' rows); `architect.md` frontmatter has `model:` equal to the `--plan` value and `design-reviewer.md` the `--review` value; `design-reviewer.md` allows `edit docs/design/*` and denies `.opencode/*`; `orchestrator.md` contains the pack prompt text, `gate.sh` shell allow, and a `subagent` allow for each pack role; `quick-editor.md` contains the builder line; planner body contains the planner prompt; no pack file contains an unreplaced `$ROOT`. And the **parity test still passes** (`test-parity.sh`). Expect FAIL.
- [ ] **Step 2: Implement the helpers and `stage_pack`**, and call `stage_pack` only when `PACKS` is non-empty.
- [ ] **Step 3: Extend the reviewer warning** (`:101`) with a second loop that runs only when `KIND` is set and warns when `$PLAN` and `$REVIEW` share a model family (the architect writes, the design-reviewer reviews).
- [ ] **Step 4: Run** `tests/test-kind-stage.sh`, `tests/test-kind-args.sh`, `tests/test-parity.sh`; expect PASS.
- [ ] **Step 5: Stop.** Show `git status`.

---

### Task 9: Managed block record, re-runs, `--style-file`, `--kind none`

**Files:**
- Modify: `init-agents.sh` (block heredoc `:286-322`, write phase `:325-356`)
- Test: `tests/test-kind-rerun.sh`

**Interfaces:**
- Produces, inside the managed block, only when a kind is installed:
  ```
  ### Kind pack: <kind>
  | Role/Skill | File |
  ...
  <!-- kind: <kind> -->
  <!-- kind-files: <path> <path> ... -->
  ```
  `read_recorded_kind` and `read_recorded_files` parse those two comment lines from the existing `AGENTS.md`. Parser must treat a block with neither line (pre-kind install) as "no kind".
- Produces, `--style-file FILE`: staged as `docs/design/output-style.md`; recorded in `kind-files`; error if used without a kind; error if FILE missing.
- Re-run rules: no `--kind` -> reuse the recorded kind (needs a studio dir; same errors as Task 7); `--kind <other>` -> stage the new pack, then delete recorded files that are not in the new set, **only if they still exist and lie under `.opencode/` or equal `docs/design/output-style.md`**; `--kind none` -> same deletion, no pack staged, kind lines removed from the block. Deletions are listed as `remove:` and skipped under `--dry-run`.

- [ ] **Step 1: Write `test-kind-rerun.sh`** (fixture studio with a `service` and a second `generic`-style pack that has fewer files): (a) block lists the table, `kind` and `kind-files`; (b) plain re-run keeps the same files, output all `unchanged:`; (c) switch `service` -> `generic` removes exactly the files only `service` installed; (d) a listed file the test deleted by hand does not error; a listed path outside the allowed prefixes (hand-edited into `kind-files`, e.g. `src/app.ts`) is NOT deleted and prints `note: refusing to remove <path>`; (e) `--kind none` removes all and strips the kind lines; (f) an `AGENTS.md` produced by the baseline tree, then `--kind service`, then plain re-run: kind retained; the baseline tree plus plain run: no kind, parity holds; (g) `--style-file` copies the content, and `--dry-run` lists it; (h) `--dry-run` for a switch lists `remove:` lines and removes nothing. Expect FAIL.
- [ ] **Step 2: Implement** the block additions behind `[ -n "$KIND" ]` (when empty, the heredoc output must stay byte-identical), the parsers, and the delete phase.
- [ ] **Step 3: Run** all `tests/test-*.sh`; expect PASS, including parity.
- [ ] **Step 4: Stop.** Show `git status`.

---

### Task 10: End to end against the real studio, and the scenario replay

**Files:**
- Create: `tests/test-e2e-real.sh` (agent-init)
- Create: `studio-tests/kinds/replay-scenarios.md` (dev-studios)
- Modify: `README.md` in `agent-init/` parent or the script's usage text (document `--kind`, `--studio-dir`, `--style-file`, `--kind none`)

- [ ] **Step 1: `test-e2e-real.sh`**: run `--kind service --studio-dir /Volumes/Engineering/Icehunter/dev-studios` on a fresh repo; assert `pack-check.sh service` passes from the studio, every file in the recorded list exists, `.opencode/scripts/gate.sh` runs in the target and prints `STAGE: unset` / `RIGOR: minimal`, and the run is idempotent (second run all `unchanged:`).
- [ ] **Step 2: Scenario fixtures** in `replay-scenarios.md`, one per failure, each with: repo state to create, what the model is told, the exact `gate.sh` lines expected (automated here), and the expected design-reviewer outcome (manual):
  1. Constraint ignored: `constraints.md` has `C1: Feature X will not work, do not build it`; `design-record.md` builds X. gate.sh: constraint-check row `PRESENT`. Expected reviewer: `verdict: FAIL` citing `C1`; planner refuses to brief.
  2. Fixture mismatch found late: `premise-check.md` exists with `## Sample fit` that names Postgres while the real fixtures are Redshift. Expected: reviewer `FAIL`/`CONCERNS` (reader's file check contradicts); gate row for `## Result` `PATTERN_MISS` when the run was never done.
  3. Unrepresentative sample: sample repo has no DDL, approach needs DDL. Expected: `## Sample fit` must state what the sample lacks; reviewer `FAIL` if the section says it is representative.
  Automated: script asserts the gate.sh lines for each fixture (put the fixtures under `studio-tests/kinds/fixtures/replay/`).
- [ ] **Step 3: Manual replay** in a scratch repo initialised with `--kind service` using an OpenCode session: run each scenario, save the transcript excerpt showing the gate stopping it under a `## Result` heading per scenario in `replay-scenarios.md`. If a model-dependent scenario does not stop, tighten the orchestrator/planner prompt in `_software/prompts/`, re-run ai-init, repeat. Do not mark done until all three stop.
- [ ] **Step 4: Final run**: all `studio-tests/kinds/test-*.sh`, all `agent-init/tests/test-*.sh`, parity included. Expect no failures.
- [ ] **Step 5: Stop.** Show both `git status` outputs and the replay results; no commit unless the owner asks.

---

## Self-review

- **Spec coverage:** kind key (T1); `_software` roles/skills/rules/manifest (T2); gate script, rigor tiers, verdict, order (T2 prompts, T3); service/application/generic (T4); `--kind`, `--studio-dir`, missing-pack errors (T7); install paths, AGENTS.md table, permissions (T8); recorded kind, re-run, kind switch, `--style-file`, dry-run listing (T9); parity (T6-9); replay of the three failures (T10). Stages (T3 ordering, T4 doc). Left-to-builder items: wording (T2), skill permission syntax (T8), design record location (`docs/design/`, T2), ai-init tests (T6-10), `pack.yaml` (decided: yes), `/setup-kind` (deferred, noted in T4).
- **My calls beyond the spec, for the owner to veto:** `STATUS.md` holds stage and rigor; pack agent frontmatter uses `model-role` and `access` rather than ai-init permission names; `gate.tsv` has a pattern column so section presence is observable; `design-reviewer` writes `gate-verdict.md`; `--kind none` exists; planner/reviewer same-family warning only with a kind.
- **Known soft spot:** T10 Step 3 depends on cheap-model behaviour and cannot be proven by unit tests; it is a manual replay with recorded results.
