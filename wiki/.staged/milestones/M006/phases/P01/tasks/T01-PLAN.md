---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M006"
name: "Create references/architecture.md — engine pipeline, data flow, subsystem map"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- No prior tasks required — T01 is the phase entry point.

## Description

Create a new reference document at `references/architecture.md` that gives
a developer a complete mental model of the speckit-orchestrator system. The
document must follow existing `references/` conventions (DC-1): progressive
disclosure statement, `## Overview` immediately after title, ASCII diagrams,
`##`/`###` structure, no inline HTML. It must declare an audience label (DC-2)
of `contributors, extenders`. All cross-links must use relative paths (DC-3).

The document covers five sections:

1. **Engine Pipeline Diagram** — an ASCII diagram showing the 7 stages the
   engine executes per task: Hook (PRE_DISPATCH) → Build Context → Compress →
   Dispatch → Guard (output sanity) → Verify → Record/Advance. Derived from
   `scripts/engine/run.sh` lines 197-400.

2. **Data Flow** — narrative tracing a single task dispatch from context-recipe
   resolution through build-context assembly, compression, model selection,
   dispatch, verification, result recording, and checkpoint write. References
   specific scripts and the order they execute.

3. **State Machine Overview** — brief summary of the 10 states with a
   cross-link to `references/state-machine.md` for the full reference. Mentions
   that state derivation is in `scripts/state/derive-phase.sh` and is
   intentionally not tier-aware.

4. **File Layout Tree** — ASCII tree showing the project directory structure:
   `commands/`, `scripts/` (with subdirectories), `templates/`, `references/`,
   `tests/`, `.specify/orchestrator/`. Every path listed must exist on disk.

5. **Subsystem Relationship Map** — how M001-[M005](../../../../../milestones/M005/index.md) subsystems relate:
   - M001 (Foundation): state machine, verification, knowledge, dispatch scaffolding
   - [M002](../../../../../milestones/M002/index.md) (Knowledge Architecture): knowledge lifecycle, graph relationships, scope filtering
   - [M003](../../../../../milestones/M003/index.md) (Migration): adapter-based migration from GSD/spec-kit
   - [M004](../../../../../milestones/M004/index.md) (Engine): run.sh pipeline, library extraction, recipe-driven context
   - M005 (Hardening): diagnostics, provider conventions, autonomy permissions

## Steps

### Step 1 — Read source scripts to map the engine pipeline

Read the following scripts to understand the pipeline stages:

- `scripts/engine/run.sh` — the main pipeline loop. Note the order:
  1. Session init (init_run_context, pending task discovery)
  2. PRE_DISPATCH hooks (run_hooks PRE_DISPATCH)
  3. Context build (build-context.sh)
  4. Compression (compress-payload.sh)
  5. Guards (guard_payload_sanity, guard_budget)
  6. Dispatch (DISPATCH_START event, agent call or stub)
  7. Output guard (guard_output_sanity)
  8. Verification (check-must-haves.sh)
  9. POST_VERIFY hooks
  10. Result recording (record-result.sh)
  11. POST_DISPATCH hooks
  12. Checkpoint write (checkpoint_write)
  13. TASK_COMPLETE event
  14. (after loop) PRE_ADVANCE hooks, guard_phase_complete, PHASE_COMPLETE

- `scripts/dispatch/build-context.sh` — context assembly from recipe sections
- `scripts/dispatch/compress-payload.sh` — graduated compression steps
- `scripts/dispatch/classify-complexity.sh` — task complexity classification
- `scripts/dispatch/select-model.sh` — model selection from routing.yaml
- `scripts/verify/check-must-haves.sh` — truth/artifact verification
- `scripts/lifecycle/record-result.sh` — execution log entry writing
- `scripts/engine/checkpoint.sh` — crash recovery checkpoint

Group these into 7 logical stages for the pipeline diagram:
1. **Init** — run context, task discovery, model selection
2. **Hook** — PRE_DISPATCH lifecycle hooks
3. **Build** — context recipe resolution, section assembly
4. **Compress** — graduated payload compression
5. **Dispatch** — guard checks, model invocation
6. **Verify** — output sanity, must-have checks, POST_VERIFY hooks
7. **Record** — result logging, checkpoint, POST_DISPATCH hooks, advance

### Step 2 — Read state and lifecycle scripts for the overview sections

- `scripts/state/derive-phase.sh` — 10-state file-presence derivation
- `scripts/state/read-roadmap.sh` — roadmap parsing
- `scripts/lifecycle/phase-transition.sh` — phase completion mechanics
- `scripts/lifecycle/auto-loop.sh` — autonomous execution loop
- `scripts/lifecycle/lock-manager.sh` — session locking
- `scripts/lifecycle/stuck-detector.sh` — stuck task detection

### Step 3 — Verify the project directory structure

Run `ls` / `find` commands to confirm every directory path that will appear
in the file layout tree actually exists. Pay attention to:
- `scripts/diagnostics/` (14 check scripts)
- `scripts/dispatch/lib/` (section-handlers.sh)
- `scripts/migrate/` (adapter-interface.sh, adapters/, lib/, transform/)
- `templates/` (14 templates + 1 config default)

### Step 4 — Write `references/architecture.md`

Create the file with the following structure:

```markdown
# Architecture Reference

> Progressive disclosure reference for the speckit-orchestrator architecture.
> Self-contained — read this document to understand the engine pipeline, data flow,
> state machine, and subsystem relationships without cross-referencing source code.

> Audience: contributors, extenders

## Overview

[2-3 paragraph summary of what the orchestrator is and how it works]

---

## Engine Pipeline

[ASCII diagram of the 7-stage pipeline]

### Stage 1: Init
[Description]

### Stage 2: Hook (PRE_DISPATCH)
[Description]

...etc for all 7 stages...

---

## Data Flow

[Narrative tracing one task dispatch end-to-end]

---

## State Machine

[Brief 10-state overview with cross-link to state-machine.md]

---

## File Layout

[ASCII tree of project directories]

---

## Subsystem Map

### M001 — Foundation
### M002 — Knowledge Architecture
### M003 — Migration
### M004 — Engine
### M005 — Hardening

---

## Cross-References

[Links to all related references/ docs]
```

### Step 5 — Verify-as-you-write (DC-4)

For each claim in the document:
- If it states a script does X, run the script (or read it) and confirm X.
- If it lists a file path, confirm the path exists with `test -f` or `test -d`.
- If the output diverges from what the doc says, either fix the doc or fix the
  code (with a commit message referencing `references/architecture.md` per DC-5).

### Step 6 — Check cross-links

Verify every relative link in the document resolves to an existing file.
For example, `[State Machine](state-machine.md)` should resolve to
`references/state-machine.md`.

## Must-Haves

- [ ] `references/architecture.md` exists and is non-empty
- [ ] File opens with progressive disclosure statement and audience label
- [ ] Contains an ASCII engine pipeline diagram with 7 named stages
- [ ] Documents data flow: recipe → build → compress → dispatch → verify → record → advance
- [ ] Includes file layout tree with accurate paths
- [ ] Includes subsystem relationship map for M001-M005
- [ ] Cross-links to state-machine.md, file-formats.md, verification-ladder.md, tier-definitions.md using relative paths
- [ ] Every file path mentioned in the document exists on disk

## Verification

After writing the file, run:

```
bash scripts/verify/m006-p01-arch-header.sh
bash scripts/verify/m006-p01-arch-pipeline.sh
bash scripts/verify/m006-p01-arch-dataflow.sh
bash scripts/verify/m006-p01-arch-layout.sh
bash scripts/verify/m006-p01-arch-subsystems.sh
bash scripts/verify/m006-p01-arch-crosslinks.sh
bash scripts/verify/m006-p01-paths-exist.sh
```

All must exit 0. If any verification script does not yet exist (because T03
has not run), verify manually by grepping the file for required patterns.

## Inputs

### From Previous Tasks

None — T01 is the phase entry point.

### From Disk (Pre-existing)

- `scripts/engine/run.sh` — pipeline loop (7 stages)
- `scripts/engine/checkpoint.sh` — checkpoint read/write/detect/clear
- `scripts/dispatch/build-context.sh` — context assembly
- `scripts/dispatch/compress-payload.sh` — graduated compression
- `scripts/dispatch/classify-complexity.sh` — complexity classification
- `scripts/dispatch/select-model.sh` — model routing
- `scripts/dispatch/scope-filter.sh` — scope-based knowledge filtering
- `scripts/dispatch/detect-capabilities.sh` — agent host detection
- `scripts/state/derive-phase.sh` — 10-state file-presence derivation
- `scripts/state/read-roadmap.sh` — roadmap parsing
- `scripts/state/read-config.sh` — config resolution
- `scripts/lifecycle/phase-transition.sh` — phase completion
- `scripts/lifecycle/auto-loop.sh` — autonomous loop
- `scripts/lifecycle/lock-manager.sh` — session locking
- `scripts/lifecycle/record-result.sh` — execution log recording
- `scripts/verify/check-must-haves.sh` — truth/artifact verification
- `scripts/lib/errors.sh` — error emission protocol
- `scripts/lib/events.sh` — structured event emission
- `scripts/lib/guards.sh` — safety rail guard checks
- `scripts/lib/hooks.sh` — hook lifecycle execution
- `scripts/lib/run-context.sh` — deterministic run context
- `scripts/lib/recipe-parser.sh` — YAML recipe parsing
- `scripts/lib/verdicts.sh` — verification verdict protocol
- `references/state-machine.md` — state machine reference (cross-link target)
- `references/file-formats.md` — file formats reference (cross-link target)
- `references/verification-ladder.md` — verification ladder (cross-link target)
- `references/tier-definitions.md` — tier definitions (cross-link target)
- `extension.yml` — extension manifest (command/script inventory)

## Constraints

- **DC-1**: Follow existing `references/` doc convention: progressive disclosure
  statement, `## Overview`, `##`/`###` structure, ASCII diagrams, no inline HTML.
- **DC-2**: Audience label: `contributors, extenders`.
- **DC-3**: All cross-links use relative paths from `references/` directory.
- **DC-4**: Verify-as-you-write — every documented behavior confirmed by reading
  or running the actual script.
- **DC-5**: Any bug fix commit messages reference `references/architecture.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `references/architecture.md` exists with 200+ lines.
2. The document contains all five sections: engine pipeline, data flow, state
   machine overview, file layout tree, subsystem map.
3. All cross-links are relative and resolve to existing files.
4. All file paths mentioned in the document exist on disk.
5. If any code bugs were found and fixed, each fix is committed with a message
   referencing `(found via references/architecture.md)`.
