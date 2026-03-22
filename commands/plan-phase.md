---
description: "Use when planning one phase — creates task decomposition with must-haves. Produces a phase plan file with truths, artifacts, key links, and zero-context task plans."
---

# speckit.orchestrator.plan-phase

Plan one phase of the roadmap by creating a detailed phase plan with must-haves and self-contained task plans. Each task plan is written so a fresh agent context with zero prior knowledge can execute it independently.

## Phase Selection

Determine which phase to plan:

1. **Derive current state** by running `bash scripts/state/derive-phase.sh <milestone-dir>`. The state must be `planning`.
2. **Auto-select the next phase**: Use `bash scripts/state/read-roadmap.sh <roadmap-file> active-phase` to identify the next phase that needs planning (first incomplete phase in dependency order).
3. **Manual override**: Accept `--phase P##` to plan a specific phase instead of the auto-selected one. Verify that the specified phase exists in the roadmap and that its dependencies are satisfied (upstream phases have summaries).

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
- **Exact commands with expected output**: `bash scripts/verify/check-must-haves.sh <path>` should output `PASS: ...`
- **Inputs**: what files from previous tasks this task reads. The Inputs section must summarize the API surface of upstream outputs — method signatures, key types, behavioral contracts — not just list file paths. An agent reading only this task plan must know what methods to call, what types to use, and what behavior to expect without reading upstream files.
- **Must-haves**: the subset of phase must-haves that this specific task addresses

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
3. **Write individual task plans** to `<milestone-dir>/phases/P##/tasks/T##-PLAN.md` for each task, using the `templates/task-plan.md` template format.

## Post-Completion

After writing the phase plan and all task plans:

1. **Verify state transition**: Run `bash scripts/state/derive-phase.sh <milestone-dir>`. The state should now be `executing` (task plans exist without summaries).
2. **Report next step**: Inform the developer that the phase is ready for execution via `speckit.orchestrator.dispatch` (one task at a time) or `speckit.orchestrator.auto` (autonomous execution).

Note: Running `plan-phase` again without `--phase P##` would attempt to re-plan the same phase since it is still the active phase. Use `--phase` to target a different phase.

## Idempotency

If a phase plan already exists at `<milestone-dir>/phases/P##/P##-PLAN.md`:

1. **Display the existing phase plan** to the developer.
2. **Require explicit confirmation** before overwriting: "Phase plan already exists for {P##}. Overwrite? Existing task plans will also be regenerated."
3. If confirmed, regenerate the phase plan and all task plans.
4. If not confirmed, exit without changes.

This satisfies R012 (idempotent commands) — running `plan-phase` twice without confirmation produces identical disk state.

## Error Handling

- If the milestone directory doesn't exist, exit with error: "Milestone directory not found. Run speckit.orchestrator.evaluate first."
- If no roadmap exists, exit with error: "No roadmap found. Run speckit.orchestrator.roadmap first."
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
