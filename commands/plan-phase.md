---
description: "Use when planning one phase — creates task decomposition with must-haves. Produces a phase plan file with truths, artifacts, key links, and zero-context task plans."
---

# orchestrator:plan-phase

Plan one phase of the roadmap by creating a detailed phase plan with must-haves and self-contained task plans. Each task plan is written so a fresh agent context with zero prior knowledge can execute it independently.

## Intensity Behavior

This command is an intensity-aware stage. At entry, call:

```bash
bash scripts/engine/intensity-gate.sh --stage plan-phase --intensity-metadata <path-to-metadata>
```

Parse the `execute_substeps=` and `skip_substeps=` output and branch:

| Intensity | execute_substeps        | Behavior |
|-----------|-------------------------|----------|
| Quick     | single-task             | Create ONE task plan. No boundary map. No full decomposition. Must-haves list is minimal (one truth, one artifact). |
| Standard  | basic-decomp,boundary-map | Create 2-4 task plans. Include a basic Boundary Map showing Produces/Consumes. Must-haves cover core behaviors. |
| Full      | full-decomp,boundary-map  | Full decomposition (1-7 tasks per FR-005). Complete Boundary Map. Full Must-Haves section with Truths, Artifacts, Key Links. Zero-context task plans per FR-011. |

The existing planning workflow below describes the Full behavior. At Quick/Standard, apply the reductions above to the same workflow; do not invent a different workflow.

## Phase Selection

Determine which phase to plan:

1. **Derive current state** by running `bash scripts/state/derive-phase.sh <milestone-dir>`. The state must be `planning`.
2. **Auto-select the next phase**: Use `bash scripts/state/read-roadmap.sh <roadmap-file> active-phase` to identify the next phase that needs planning (first incomplete phase in dependency order).
3. **Manual override**: Accept `--phase P##` to plan a specific phase instead of the auto-selected one. Verify that the specified phase exists in the roadmap and that its dependencies are satisfied (upstream phases have summaries).

### Brand-new milestone bootstrap path (no roadmap yet)

If the milestone directory exists with a finalized `<MID>-CONTEXT.md` but no `<MID>-ROADMAP.md`, the planner MAY author a minimal roadmap inline as the first step of plan-phase, provided:

1. The milestone is operator-scaffolded (CONTEXT.md exists with `status: finalized`).
2. The first phase to be planned is unambiguous from CONTEXT.md (single-phase milestones; or first-phase-of-a-decomposable-milestone where CONTEXT.md or a parent reshape DR identifies the entry phase).
3. The inline roadmap covers at least the phase being planned + a placeholder for follow-on phases (so subsequent plan-phase passes have something to extend).

Author the roadmap before authoring the phase plan; verify state derives to `planning` after the roadmap lands; then proceed with the standard phase-selection flow above.

If conditions 1-3 don't hold, exit with the existing "No roadmap found. Run `/orchestrator-roadmap` first." error.

This bootstrap path is the operator-driven roadmap-light pattern; PBJ Stage 3 dogfood (2026-05-08) exercised it across 3 brand-new milestones (M2a-min, M2b-min, M-Spike-BG001) without an explicit prior `orchestrator:roadmap` invocation.

## Context Gathering

Assemble the information needed to plan the phase:

1. **Read the roadmap** (`M###-ROADMAP.md`) for the target phase's:
   - Goal and demo sentence
   - Risk classification
   - Dependencies (upstream phase IDs)
   - Boundary map: what this phase Produces and Consumes
2. **Read upstream phase summaries** (`P##-SUMMARY.md` for each dependency phase) to understand what has been built and what interfaces are available.
3. **Read the feature spec** (`specs/{NNN}-{name}/spec.md`) for the relevant user story details, acceptance criteria, and requirements that this phase addresses.
4. **Read the context draft** (if it exists) for architectural decisions and constraints that apply to this phase.

## Phase Planning

Create the phase plan using the `templates/phase-plan.md` template format:

### YAML Frontmatter

```yaml
---
schema_version: "1.0"
type: phase-plan
phase: "P##"
milestone: "M###"
goal: "<one-line goal>"
demo_sentence: "<what the developer can observe when complete>"
risk: "<high|medium|low>"
depends_on: [<upstream phase IDs>]
---
```

### Must-Haves

Write must-haves in three categories per FR-010. These are the mechanical verification criteria that `scripts/verify/check-must-haves.sh` will check at phase completion:

#### Truths

Observable behaviors that can be mechanically verified. Each truth should have a `Check:` sub-item with a concrete command:

```markdown
- <behavioral truth statement>
  - Check: `<grep|command that returns exit 0 if truth holds>`
```

Truth `Check:` commands verify observable proxies for behavior, not behavior itself. They are Tier 1 (static) checks — they catch "forgot to implement" but cannot catch "implemented with different names." When writing checks: use broad regex alternation for common naming variants, prefer structural checks over naming checks where possible (e.g., check the logic pattern, not the variable name), and accept that some truths genuinely need Tier 3 (behavioral) verification rather than writing fragile Tier 1 checks.

Truths without `Check:` sub-items are classified as Tier 3 behavioral checks — they require agent judgment rather than mechanical verification. Use sparingly and only for behaviors that genuinely cannot be reduced to a command.

#### Truth `Check:` command shape — mandatory script-file shape (AD-19)

Truth `Check:` commands run through the harness bash permission system,
which has two layers:

1. **The allow list** (`.claude/settings.json`) — P07 generates this from
   project introspection to cover every orchestrator script. Patterns
   that match the allow list execute without prompting.

2. **The safety heuristic layer** — built into the host and **cannot be
   disabled from `settings.json`**. It fires on command *shape*, not
   content, to catch obfuscation patterns. Even a command whose
   individual tokens are fully allow-listed will trigger a prompt if its
   shape matches one of the heuristic classes.

**Forbidden shapes** (observed to trigger the harness heuristic — see
AD-19 in `.orchestrator/milestones/M005/M005-CONTEXT.md` for the
authoritative trigger list):

- Inline compound `bash -c '...' && bash -c '...'` chains.
- Plain `( … )` subshells — even without `&&`/`||` — e.g.
  `( . scripts/lib/errors.sh && fn arg )`.
- `source` / `.` builtin with arguments inside a subshell.
- Command substitution `$(…)` containing pipes — e.g.
  `rc=$(bash cmd | grep -c '^RESULT:')`.
- Process substitution `<(…)` or `>(…)` anywhere.
- `cmd <file` input redirection nested inside `$(…)` — e.g.
  `lines=$(wc -l < path)`.
- Compound `;`-separated statements chaining more than two commands.
- Inline `for`/`while`/`if` blocks embedded in a single command.
- Heredocs feeding commands with pipes or further redirects.
- Brace expansion containing quote characters.
- `bash -c '...'` with embedded quoted regex or character classes.

**Required shape**: **single-script-file invocations**. Instead of
writing a compound command inline, extract the logic into a short
helper script and invoke it as the `Check:` command. Path discipline:
project-owned per-phase verifiers (slug-bearing filenames like
`m036-p01-foundation-bundle.sh`) live under `tools/verify/`; framework-owned
verifiers that ship in the install bundle (`check-*`, `run-*`,
`spec-shape-lint`, `validate-*`, `guards/*`) live under `scripts/verify/`.
Discriminator: any verifier whose filename embeds a phase/task/milestone
slug is project-owned and emits to `tools/verify/`. Why: in any downstream
project, `scripts/` is one of the four bulk-staged framework dirs
(`commands/ references/ scripts/ templates/`), gitignored to avoid
duplicating framework files into the consumer git history; project-owned
files written there are gitignored AND vulnerable to silent clobber on
the next `install-claude-code.sh` run. (M032 Finding A; surfaced
2026-04-29 by pbj-central-mono-repo dogfooding.)

**Naming convention — milestone slug REQUIRED for per-phase verifiers**:
project-owned verifier filenames MUST embed the milestone slug as the
first segment (`m###-p##-<descriptor>.sh`), not phase-only
(`p##-<descriptor>.sh`). Why: every milestone has a P00, every milestone
has a phase-suite aggregator, and the unprefixed slug `p##-phase-suite.sh`
silently clobbered prior milestones' aggregators on every new milestone
P00 close (M030 lost to M031, M031 lost to M036, observed 2026-05-01).
Phase-only slugs are reserved for genuinely cross-milestone framework
verifiers (none today). The lint at `scripts/diagnostics/check-plans.sh`
flags unprefixed `p##-*` plan deliverables as warnings.

```markdown
# FORBIDDEN — triggers harness heuristic (plain subshell + source)
- My truth statement
  - Check: `( . scripts/lib/errors.sh && emit_result ok "" "test" | grep -q RESULT )`

# FORBIDDEN — triggers harness heuristic ($(...) containing pipe)
- My truth statement
  - Check: `test $(grep -c "pattern" file.txt) -gt 0`

# REQUIRED — single-script-file shape, project-owned path, milestone-prefixed
- My truth statement
  - Check: `bash tools/verify/m036-p07-my-check.sh`
```

**Why this matters**: the orchestrator's `/orchestrator-auto`
command runs unattended. Every harness prompt interrupts that
unattended run — even for commands the developer has allow-listed.
Writing `Check:` commands in the script-file shape keeps auto mode
genuinely unattended. This is preventive; P06's
`scripts/diagnostics/check-plans.sh` is the detective counterpart, an
advisory lint that scans task plans and flags violations before they
reach auto mode.

Rationale: the rule exists because the harness heuristic layer is
*above* the allow list, cannot be configured away, and fires on shape
family rather than specific patterns. Future planners encountering an
edge case should read AD-19 in full rather than mechanically following
the bulleted list — the list is indicative, not exhaustive, and will
grow as new triggers are observed.

#### Artifacts

File paths with verifiable properties:

```markdown
- <file-path> (min <N> lines, contains "<pattern>")
```

The verification script checks: file exists, line count ≥ min, and `grep -q "<pattern>" <file-path>` succeeds.

#### Key Links

Cross-file references that must exist:

```markdown
- <source-file> → <target-file>
```

The verification script checks that the source file contains a reference to the target file's basename (e.g., `grep -q "target-file" <source-file>`).

### Task Decomposition

Decompose the phase into 1–7 tasks, each fitting in one context window (FR-005):

1. **Order tasks** by dependency — each task should build on what the previous task created.
2. **Size tasks** so each can be understood and executed by an agent with a single context window of capacity.
3. **Ensure completeness** — all must-haves must be addressed by at least one task.

### Zero-Context Task Plans (FR-011)

Each task plan must be completely self-contained — an agent starting with zero knowledge of the project must be able to execute the task using only the task plan and the codebase. Each task plan includes:

- **Exact file paths**: every file to create, read, or modify — full relative paths from project root
- **Complete code snippets**: not "implement the handler" but the actual code to write, or a precise specification. Use this heuristic for verbosity level:
  - **Include verbatim code** for: configuration files, data definitions, shader source, and any code where exact syntax matters (regex patterns, math formulas).
  - **Include interface specifications** (method signatures, parameter types, return types, behavioral contracts) for: classes and modules where the implementing agent needs flexibility in internal structure but must match a specific API surface.
  - **Include architecture descriptions** (pattern name, key data structures, interaction protocol) for: complex systems where the approach matters more than exact code.
- **Exact commands with expected output**: `bash scripts/verify/check-must-haves.sh <path>` should output `PASS: ...`. **Section discipline**: the `## Verification` section MUST contain ONLY executable check commands (inline backticks or fenced ` ```bash ` blocks). Document expected verifier output as prose in a separate `## Notes` section (or any later `## ` header) — `auto-loop.sh --step=V` eval's every line inside fenced blocks under `## Verification` as a command, so an "Expected output:" example fence will be eval'd as a literal `PASS:` shell command and report a false failure (M028/P01 dogfood finding, 2026-04-29).
- **Inputs**: what files from previous tasks this task reads. The Inputs section must summarize the API surface of upstream outputs — method signatures, key types, behavioral contracts — not just list file paths. An agent reading only this task plan must know what methods to call, what types to use, and what behavior to expect without reading upstream files.
- **Must-haves**: the subset of phase must-haves that this specific task addresses

### Plan-Time Discipline (Verification + Prerequisites)

These five rules turn known plan-time confabulations into mechanical fail-fast checks at plan-authoring time, before any executor is dispatched. The brief that captured them is `.orchestrator/proposals/papercut-sweep-pre-M030.md` (paper-cut sweep, group 8 commit 1); each rule cites the dogfood incident that motivated it.

1. **Prerequisite-existence verification.** When a task plan's `Prerequisites:` block names files via paths, run `[ -f <path> ]` against each path at plan-authoring time. FAIL the plan-authoring step on any miss — surface the gap before the executor inherits a stale assumption. Surfaced 2026-04-29 by M028/P02/T03 (`before-commit.sh` was claimed to exist; only `after-verify-sync.sh` did).

2. **Verifier-availability cross-check.** Every command in a task's `## Verification` section MUST resolve to an existing-on-disk script at plan-authoring time. Cross-task verifier dependencies are rejected: if a verifier script does not yet exist, the plan must either (a) schedule its authorship inside *this* task's `## Steps` (co-authored alongside the deliverable), or (b) use a stub-tolerant inline shape-check (file existence, content-presence grep) that doesn't depend on the unwritten verifier. Surfaced 2026-04-29 by M028/P03/T01 (T01-T04 plans referenced verifier scripts that were T05 deliverables — first-fail-retry/second-fail-pause cannot recover from a missing verifier).

3. **Classifier-shape pre-validation.** When a task introduces lines that will be subject to the active M021/M028 PreToolUse Bash shape-guard, OR when a verifier's contract depends on a specific classifier verdict for a specific input, the planner MUST run the proposed line/input through `scripts/verify/lib/shape-classifier.sh::classify_command` at plan-authoring time and record the verdict in plan prose. Without the classifier trace, the verdict claim is text — not a contract. Surfaced 2026-04-29 by M028/P02/T01 + T05 (planners confabulated classifier verdicts for compound shapes that the classifier actually rejects).

4. **`run-probe.sh` scope discipline.** `scripts/util/run-probe.sh` is the staged-throwaway-probe wrapper — it exits 3 on paths outside `/tmp`, `/var/folders`, and `<repo>/tmp/`. It is **not** a generic invocation harness. For repo-resident verifiers under `scripts/verify/<...>.sh` or `tools/verify/<...>.sh`, invoke directly via `bash scripts/verify/<path>` (or `bash tools/verify/<path>`). Reserve `run-probe.sh` for genuinely staged probes inside the allowed directories. Surfaced 2026-04-29 by M028/P02/T01-T05 self-dogfood: five consecutive task plans wrapped a project-tree verifier path in `run-probe.sh` and uniformly false-FAILed under `auto-loop --step=V`.

5. **Real-DB verification for SQL-bound code.** When a task introduces new SQL reads, schema migrations, or DB-bound integration code, the `## Verification` section MUST include either (a) a real-DB column-existence verifier (a prepared SELECT against a freshly-migrated empty schema, asserting no `no such column` throw), OR (b) an explicit `## Notes` "real-app smoke test pending — confirm before phase close" callout that names the surface to smoke-test and the expected behavior. Mock-only DB integration verification is a known false-pass shape: typed mocks share the planner's vocabulary so they round-trip cleanly even when the runtime schema diverges. Surfaced 2026-04-29 by lakeledger M066/P04 (column-name drift between planner spec vocabulary and persistence-layer schema names; mock tests passed; first app reload threw `no such column` — took two column-name-drift fixes against different tables to clear). Layer-2 fix (boundary-translation decision packet) is queued for M034.

6. **Path-collision check.** Every artifact path the plan declares as `Produces:` (in the Boundary Map) or as a `create` deliverable (in `## Files Likely Touched`) MUST NOT already exist on disk at plan-authoring time. The planner MUST `ls -la` each declared `create` path before authoring. If a path already exists: STOP. Either (a) the convention is wrong (rename the planned artifact to a milestone-prefixed slug — see Naming convention rule above), or (b) the existing file belongs to a closed milestone and the plan is silently overwriting it (escalate to the user; do not proceed). Surfaced 2026-05-01 by M036/P00/T03 (the M031 P00 phase-suite aggregator at `tools/verify/p00-phase-suite.sh` was silently overwritten when M036's T03 plan declared the same path as a `create` deliverable; M030's prior P00 aggregator had been similarly lost weeks earlier without anyone noticing). The planner cannot rely on the executor to catch this — the executor honors the plan literally.

### Planning lenses (non-mechanical)

The six rules above are mechanical fail-fast checks. Planning lenses are non-mechanical disciplines that improve plan quality but don't flag a violator a CI check could detect. They land in `references/`, not as inclusion-criteria-gated principles:

- **Deep Modules** — see [`references/plan-time-discipline.md`](../references/plan-time-discipline.md) § Deep Modules. Vocabulary (module / interface / implementation / depth / seam / adapter / locality) + the deletion test as an optional planning gate, applied in the plan's *Risk* section when proposing new helper scripts or new `references/` docs. Composes with Constitution Principles III (Design Before Code) and XIV (No Speculative Complexity).

## Scope Declaration

Include a "Files Likely Touched" section listing all files the phase will create or modify:

```markdown
## Files Likely Touched

- path/to/new-file.sh (create)
- path/to/existing-file.md (modify)
```

This list is used by `scripts/verify/check-scope.sh` (from T01) for scope enforcement. It should be comprehensive — any file touched by any task in the phase should appear here.

## Output

Write the plan files to the phase directory:

1. **Write the phase plan** to `<milestone-dir>/phases/P##/P##-PLAN.md`.
2. **Create the tasks directory** at `<milestone-dir>/phases/P##/tasks/` if it doesn't exist.
3. **Write individual task plans** to `<milestone-dir>/phases/P##/tasks/T##-<slug>-PLAN.md` for each task (e.g. `T01-conversus-resolver-PLAN.md`), using the `templates/task-plan.md` template format. The `<slug>` is a short kebab-case descriptor derived from the task title; it keeps the filename readable and sibling-symmetric with the `T##-<slug>-PAYLOAD.md` / `T##-<slug>-SUMMARY.md` files that dispatch and phase-transition emit. Back-compat: the no-slug form `T##-PLAN.md` is still accepted by every discovery glob (`T*-PLAN.md`) and by downstream tooling (which canonicalizes the leading `T##` prefix for orchestrator IDs), so historical milestones are not affected.

## Post-Completion

After writing the phase plan and all task plans:

1. **Verify state transition**: Run `bash scripts/state/derive-phase.sh <milestone-dir>`. The state should now be `executing` (task plans exist without summaries).
2. **Report next step**: Inform the developer that the phase is ready for execution via `/orchestrator-dispatch` (one task at a time) or `/orchestrator-auto` (autonomous execution).
3. **Report deliverables accurately**: when listing what the plan delivers, frame the report as "deliverables the plan **schedules**" — regardless of which agent actually authors the artifact at execution time. Do NOT report "authored N verifier scripts" if the scripts are scheduled as executor-task deliverables in plan bodies; planner has *scheduled* their authorship, not *performed* it. Misleading reporting muddies plan/exec accounting and makes verification gaps harder to spot. Surfaced 2026-04-29 by lakeledger M066/P02 dogfooding.

Note: Running `plan-phase` again without `--phase P##` would attempt to re-plan the same phase since it is still the active phase. Use `--phase` to target a different phase.

## Idempotency

If a phase plan already exists at `<milestone-dir>/phases/P##/P##-PLAN.md`:

1. **Display the existing phase plan** to the developer.
2. **Require explicit confirmation** before overwriting: "Phase plan already exists for {P##}. Overwrite? Existing task plans will also be regenerated."
3. If confirmed, regenerate the phase plan and all task plans.
4. If not confirmed, exit without changes.

This satisfies R012 (idempotent commands) — running `plan-phase` twice without confirmation produces identical disk state.

## Error Handling

- If the milestone directory doesn't exist, exit with error: "Milestone directory not found. Run `/orchestrator-evaluate` first."
- If no roadmap exists, exit with error: "No roadmap found. Run `/orchestrator-roadmap` first."
- If state is not `planning`, report: "Cannot plan phases in state '{state}'. Expected planning."
- If the specified phase doesn't exist in the roadmap, exit with error: "Phase {P##} not found in roadmap."
- If upstream dependencies are not satisfied (missing summaries), report: "Phase {P##} depends on {P##} which is not yet complete."

## Gotchas

- **Truths without `Check:` sub-items are Tier 3 (behavioral)**: They require agent judgment and cannot fail mechanically. Use sparingly — prefer concrete `Check:` commands wherever possible.
- **Task plans referencing files from upstream tasks**: If an upstream task has not yet run, the referenced files will not exist and verification will fail. Plan tasks in dependency order and verify upstream completion before dispatching downstream.
- **Phase plan overwrite is all-or-nothing**: Requires confirmation; partial overwrite is not supported. All task plans are regenerated alongside the phase plan.

## Reference Files

- `templates/phase-plan.md` — output template for the phase plan
- `templates/task-plan.md` — output template for individual task plans
- `scripts/state/derive-phase.sh` — derives current orchestrator state from disk
- `scripts/state/read-roadmap.sh` — parses roadmap for phase info and dependencies
- `references/state-machine.md` — state transition rules and conditions
