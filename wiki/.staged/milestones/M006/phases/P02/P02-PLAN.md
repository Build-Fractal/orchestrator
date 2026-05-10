---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M006"
goal: "Create four reference docs (engine.md, events.md, errors.md, hooks.md) verified against actual source scripts"
demo_sentence: "A developer reading references/engine.md can understand run context initialization, event types, error taxonomy, result protocol, guard checks, and hook lifecycle without reading source code — every function signature and event type verified by running the engine against a test fixture."
risk: "medium"
depends_on: []
---

<!--
  P02 — Engine and Library Reference Docs
  ========================================

  Context: M006 (Documentation & Quality) Phase 02 creates four new
  reference documents covering the engine pipeline and its supporting
  libraries. Each document is verified against the actual source scripts
  to ensure accuracy. Any discrepancies found between documentation and
  code produce bug fix commits per DC-5.

  Design constraints from M006-CONTEXT.md:
    DC-1: Progressive disclosure format (## Overview after title, ASCII diagrams)
    DC-2: Audience label on every doc
    DC-3: Cross-links use relative paths
    DC-4: Verify-as-you-write — run the command, confirm output matches
    DC-5: Bug fix commits reference the doc that surfaced them
    DC-6: Bash 3.2 / POSIX compatibility for all code fixes
-->

## Must-Haves

### Truths

- `references/engine.md` exists with progressive disclosure header and audience label.
  - Check: `bash scripts/verify/m006-p02-engine-header.sh`
- `references/engine.md` documents CLI arguments (--dry-run, --force, milestone, phase) and environment variables (ORCH_RUN_SEED, ORCH_DRY_RUN, ORCH_FORCE, ORCH_ENGINE_STOP_AFTER_TASK).
  - Check: `bash scripts/verify/m006-p02-engine-args.sh`
- `references/engine.md` documents the 7 lifecycle stages and crash recovery via checkpointing.
  - Check: `bash scripts/verify/m006-p02-engine-lifecycle.sh`
- `references/events.md` exists with progressive disclosure header and audience label.
  - Check: `bash scripts/verify/m006-p02-events-header.sh`
- `references/events.md` documents all 18 canonical event types from ORCH_EVENT_TYPES.
  - Check: `bash scripts/verify/m006-p02-events-types.sh`
- `references/events.md` documents the EVENT: line format with field schemas.
  - Check: `bash scripts/verify/m006-p02-events-format.sh`
- `references/errors.md` exists with progressive disclosure header and audience label.
  - Check: `bash scripts/verify/m006-p02-errors-header.sh`
- `references/errors.md` documents all 6 error kinds (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO) with examples.
  - Check: `bash scripts/verify/m006-p02-errors-kinds.sh`
- `references/errors.md` documents the RESULT: JSON line format and emit_result protocol.
  - Check: `bash scripts/verify/m006-p02-errors-protocol.sh`
- `references/hooks.md` exists with progressive disclosure header and audience label.
  - Check: `bash scripts/verify/m006-p02-hooks-header.sh`
- `references/hooks.md` documents all 4 lifecycle points (PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE).
  - Check: `bash scripts/verify/m006-p02-hooks-lifecycle.sh`
- `references/hooks.md` documents the verdict protocol (PASS, BLOCK, WARN, NEEDS_REVIEW) and snapshot isolation.
  - Check: `bash scripts/verify/m006-p02-hooks-verdicts.sh`
- All four P02 docs cross-link to each other and to existing reference docs using relative paths (DC-3).
  - Check: `bash scripts/verify/m006-p02-crosslinks.sh`

### Artifacts

- `references/engine.md` (min 150 lines, contains "## Overview", "Audience:", "--dry-run", "--force", "checkpoint", "crash recovery")
- `references/events.md` (min 120 lines, contains "## Overview", "Audience:", "SESSION_START", "TASK_COMPLETE", "GUARD_BLOCKED", "HOOK_BLOCKED", "EVENT:")
- `references/errors.md` (min 100 lines, contains "## Overview", "Audience:", "CONFIG", "STATE", "DISPATCH", "VERIFY", "BUDGET", "IO", "RESULT:")
- `references/hooks.md` (min 150 lines, contains "## Overview", "Audience:", "PRE_DISPATCH", "POST_DISPATCH", "POST_VERIFY", "PRE_ADVANCE", "VERDICT:", "snapshot")

### Key Links

- `references/engine.md` -> `references/events.md` (event emission cross-ref)
- `references/engine.md` -> `references/errors.md` (error taxonomy cross-ref)
- `references/engine.md` -> `references/hooks.md` (hook lifecycle cross-ref)
- `references/engine.md` -> `references/architecture.md` (pipeline overview cross-ref)
- `references/events.md` -> `references/engine.md` (engine context cross-ref)
- `references/events.md` -> `references/errors.md` (error/event relationship)
- `references/errors.md` -> `references/events.md` (event/error relationship)
- `references/hooks.md` -> `references/engine.md` (engine integration cross-ref)
- `references/hooks.md` -> `references/events.md` (hook event emission cross-ref)
- `references/hooks.md` -> `references/file-formats.md` (hooks.yaml format cross-ref)

## Tasks

### T01: Create `references/engine.md` — engine run.sh documentation

Reads `scripts/engine/run.sh`, `scripts/engine/checkpoint.sh`, and
`scripts/lib/run-context.sh` to produce a verified reference document
covering: CLI arguments and flags, environment variables, run context
initialization, lifecycle stages (init, hook, build, compress, dispatch,
verify, record), checkpointing and crash recovery, dry-run mode behavior,
and exit codes. Includes cross-links to events.md, errors.md, hooks.md,
and architecture.md.

Full plan: `tasks/T01-PLAN.md`

### T02: Create `references/events.md` — event type registry

Reads `scripts/lib/events.sh` and `scripts/engine/run.sh` to produce a
verified reference document covering: the canonical event type registry
(all 18 types), EVENT: line format specification, field schemas for each
event type (which key=value pairs each type emits), timestamp handling
(ORCH_STARTED_AT frozen timestamps), unknown event type behavior, and
practical examples of each event type.

Full plan: `tasks/T02-PLAN.md`

### T03: Create `references/errors.md` — error taxonomy and result protocol

Reads `scripts/lib/errors.sh` and usage sites across `scripts/engine/run.sh`,
`scripts/lib/guards.sh`, and `scripts/lib/hooks.sh` to produce a verified
reference document covering: the closed error taxonomy (6 kinds), the
RESULT: JSON line format, the emit_result protocol (status, error_kind,
detail), error_kind validation behavior, escaping rules, and concrete
examples from every script that emits errors.

Full plan: `tasks/T03-PLAN.md`

### T04: Create `references/hooks.md` — hook lifecycle and verdict protocol

Reads `scripts/lib/hooks.sh`, `scripts/lib/verdicts.sh`, and
`templates/hooks.yaml` to produce a verified reference document covering:
the 4 lifecycle points, run_hooks function signature and behavior,
hooks.yaml format (with cross-link to file-formats.md), frozen snapshot
mechanism (chmod 444, tampering detection), verdict protocol (4 verdicts,
emit_verdict/parse_verdict), timeout behavior, force-override semantics,
graceful degradation, and a walkthrough for writing a custom hook.

Full plan: `tasks/T04-PLAN.md`

### T05: Verification scripts and cross-link validation

Creates all 13 verification scripts referenced in the Truths section
above. Each script is a standalone single-file invocation (AD-19 compliant)
that checks one specific property of the documentation artifacts.
Runs the full verification to confirm all checks pass after T01-T04.

Full plan: `tasks/T05-PLAN.md`

## Task Dependencies

```
T01 (engine.md) ──────────┐
T02 (events.md) ──────────┤
T03 (errors.md) ──────────┼──→ T05 (verification scripts + cross-links)
T04 (hooks.md)  ──────────┘
```

T01-T04 are independent of each other — they produce different files
and their source scripts do not overlap in ways that create ordering
constraints. T05 depends on all four because it validates the artifacts
T01-T04 produce and checks cross-links between them.

## Files Likely Touched

- `references/engine.md` (create)
- `references/events.md` (create)
- `references/errors.md` (create)
- `references/hooks.md` (create)
- `scripts/verify/m006-p02-engine-header.sh` (create)
- `scripts/verify/m006-p02-engine-args.sh` (create)
- `scripts/verify/m006-p02-engine-lifecycle.sh` (create)
- `scripts/verify/m006-p02-events-header.sh` (create)
- `scripts/verify/m006-p02-events-types.sh` (create)
- `scripts/verify/m006-p02-events-format.sh` (create)
- `scripts/verify/m006-p02-errors-header.sh` (create)
- `scripts/verify/m006-p02-errors-kinds.sh` (create)
- `scripts/verify/m006-p02-errors-protocol.sh` (create)
- `scripts/verify/m006-p02-hooks-header.sh` (create)
- `scripts/verify/m006-p02-hooks-lifecycle.sh` (create)
- `scripts/verify/m006-p02-hooks-verdicts.sh` (create)
- `scripts/verify/m006-p02-crosslinks.sh` (create)
- Bug fix commits for any discrepancies found (files TBD)
