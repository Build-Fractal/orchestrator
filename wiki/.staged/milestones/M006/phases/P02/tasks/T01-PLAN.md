---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M006"
name: "Create references/engine.md — engine run.sh documentation"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- No prior tasks required — T01 is independent.

## Description

Create a new reference document at `references/engine.md` that documents
the engine pipeline coordinator (`scripts/engine/run.sh`) comprehensively
enough that a developer can understand arguments, environment variables,
lifecycle stages, checkpointing, dry-run mode, and crash recovery without
reading the source code.

The document must follow existing `references/` conventions (DC-1):
progressive disclosure statement, `## Overview` immediately after title,
`##`/`###` structure, ASCII diagrams where helpful, no inline HTML. It
must declare an audience label (DC-2) of `extenders, contributors`. All
cross-links must use relative paths (DC-3).

## Steps

### Step 1 — Read source scripts to map engine behavior

Read the following scripts to understand the engine pipeline:

- `scripts/engine/run.sh` — the full pipeline. Note:
  - `_engine_usage()` (lines 22-43): CLI args and env vars
  - Argument parsing (lines 62-97): `--dry-run`, `--force`, milestone, phase
  - Run context init (line 104): `init_run_context`
  - Pending task discovery (lines 126-148): plan/summary file presence
  - SESSION_START event (lines 151-154): fields emitted
  - Crash recovery (lines 159-164): checkpoint_detect, checkpoint_read
  - Task loop (lines 197-400): PRE_DISPATCH hook, build, compress, guards,
    dispatch, output guard, verify, POST_VERIFY, record, POST_DISPATCH,
    checkpoint_write, TASK_COMPLETE
  - Post-loop (lines 402-441): PRE_ADVANCE hook, guard_phase_complete,
    PHASE_COMPLETE, checkpoint_clear, SESSION_END, final RESULT
  - Exit codes: 0 (success), 2 (usage/config), 3 (state), 4 (blocked tasks), 5 (verify), 6 (hook)

- `scripts/engine/checkpoint.sh` — checkpoint functions:
  - `checkpoint_path` — returns checkpoint file path
  - `checkpoint_write` — atomic write (temp + mv)
  - `checkpoint_read` — reads a field from the JSON
  - `checkpoint_detect` — checks existence
  - `checkpoint_clear` — removes on success
  - Checkpoint JSON fields: run_id, milestone, phase, last_task, outcome, timestamp

- `scripts/lib/run-context.sh` — run context initialization:
  - `init_run_context [milestone] [phase]` — exports ORCH_RUN_ID, ORCH_STARTED_AT, etc.
  - `orch_now` — frozen timestamp accessor
  - `orch_is_forced` — checks ORCH_FORCE
  - `orch_is_dry_run` — checks ORCH_DRY_RUN
  - Deterministic seeding via ORCH_RUN_SEED

### Step 2 — Write `references/engine.md`

Create the file with the following structure:

```markdown
# Engine Reference

> Progressive disclosure reference for the speckit-orchestrator engine.
> Self-contained — read this document to understand how to invoke the
> engine, what it does at each lifecycle stage, and how crash recovery
> works without reading source code.

> Audience: extenders, contributors

## Overview

[2-3 paragraph summary of what the engine is and how it works]

---

## Usage

[CLI syntax, positional args, flags, environment variables]

### Arguments
[--dry-run, --force, -h, milestone, phase]

### Environment Variables
[ORCH_RUN_SEED, ORCH_DRY_RUN, ORCH_FORCE, ORCH_ENGINE_STOP_AFTER_TASK]

---

## Run Context

[ORCH_RUN_ID, ORCH_STARTED_AT, deterministic seeding, orch_now]

---

## Lifecycle Stages

[7-stage pipeline with brief description of each stage]

### Stage 1 — Init
### Stage 2 — Hook (PRE_DISPATCH)
### Stage 3 — Build
### Stage 4 — Compress
### Stage 5 — Dispatch
### Stage 6 — Verify
### Stage 7 — Record

---

## Dry-Run Mode

[How --dry-run changes behavior: guards skipped, dispatch stubbed, etc.]

---

## Checkpointing and Crash Recovery

[checkpoint_write, checkpoint_detect, checkpoint_read, resume logic]

---

## Exit Codes

[0, 2, 3, 4, 5, 6 with descriptions]

---

## Cross-References

[Links to events.md, errors.md, hooks.md, architecture.md]
```

### Step 3 — Verify-as-you-write (DC-4)

For each claim in the document:
- If it states the engine accepts flag X, confirm by reading the argument
  parsing block in `scripts/engine/run.sh` lines 62-97.
- If it states an environment variable is used, grep for it in run.sh.
- If it states a specific exit code, confirm by grepping `exit N` in run.sh.
- Fix any code discrepancy with a commit referencing `references/engine.md` (DC-5).

### Step 4 — Add cross-links

Insert relative-path links to:
- `events.md` — for event types emitted by the engine
- `errors.md` — for the error taxonomy and emit_result calls
- `hooks.md` — for hook lifecycle integration
- `architecture.md` — for the high-level pipeline overview

## Must-Haves

- [ ] `references/engine.md` exists and is >= 150 lines
- [ ] Opens with progressive disclosure statement and audience label
- [ ] Documents CLI arguments: `--dry-run`, `--force`, milestone, phase
- [ ] Documents environment variables: ORCH_RUN_SEED, ORCH_DRY_RUN, ORCH_FORCE, ORCH_ENGINE_STOP_AFTER_TASK
- [ ] Documents 7 lifecycle stages
- [ ] Documents checkpointing and crash recovery
- [ ] Documents dry-run mode behavior
- [ ] Documents exit codes (0, 2, 3, 4, 5, 6)
- [ ] Cross-links to events.md, errors.md, hooks.md, architecture.md using relative paths

## Verification

After writing the file, confirm:

```
test -f references/engine.md
test "$(wc -l < references/engine.md | tr -d ' ')" -ge 150
grep -q "## Overview" references/engine.md
grep -qi "Audience:" references/engine.md
grep -q "\-\-dry-run" references/engine.md
grep -q "\-\-force" references/engine.md
grep -q "ORCH_RUN_SEED" references/engine.md
grep -q "checkpoint" references/engine.md
grep -q "crash recovery" references/engine.md
grep -q "events.md" references/engine.md
grep -q "errors.md" references/engine.md
grep -q "hooks.md" references/engine.md
```

All must pass. If verification scripts from T05 are not yet available,
these manual checks confirm the core must-haves.

## Inputs

### From Previous Tasks

None — T01 is independent.

### From Disk (Pre-existing)

- `scripts/engine/run.sh` — engine pipeline coordinator
- `scripts/engine/checkpoint.sh` — checkpoint read/write/detect/clear
- `scripts/lib/run-context.sh` — deterministic run context
- `scripts/lib/errors.sh` — error emission (for exit code context)
- `scripts/lib/events.sh` — event emission (for emitted event context)
- `scripts/lib/guards.sh` — guard functions (for guard stage context)
- `scripts/lib/hooks.sh` — hook lifecycle (for hook stage context)
- `references/architecture.md` — cross-link target
- `references/events.md` — cross-link target (may not exist yet)
- `references/errors.md` — cross-link target (may not exist yet)
- `references/hooks.md` — cross-link target (may not exist yet)

## Constraints

- **DC-1**: Progressive disclosure format, `## Overview`, `##`/`###`, ASCII diagrams, no HTML.
- **DC-2**: Audience label: `extenders, contributors`.
- **DC-3**: All cross-links use relative paths from `references/` directory.
- **DC-4**: Verify-as-you-write — every documented behavior confirmed by reading the source.
- **DC-5**: Any bug fix commit references `references/engine.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `references/engine.md` exists with 150+ lines.
2. The document covers usage, run context, lifecycle stages, dry-run mode,
   checkpointing/crash recovery, and exit codes.
3. Cross-links to events.md, errors.md, hooks.md, and architecture.md are present.
4. If any code bugs were found, each fix is committed referencing this doc.
