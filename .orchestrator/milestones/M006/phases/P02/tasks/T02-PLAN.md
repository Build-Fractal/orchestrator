---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M006"
name: "Create references/events.md — complete event type registry"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- No prior tasks required — T02 is independent.

## Description

Create a new reference document at `references/events.md` that provides a
complete registry of the orchestrator's structured event types, their field
schemas, format specification, and usage examples. A developer reading this
document should understand exactly what events the engine emits, what fields
each event carries, and how to parse event output without reading source code.

The document must follow existing `references/` conventions (DC-1):
progressive disclosure statement, `## Overview` immediately after title,
`##`/`###` structure, no inline HTML. It must declare an audience label
(DC-2) of `extenders, contributors`. All cross-links must use relative
paths (DC-3).

## Steps

### Step 1 — Read source scripts to catalog event types and fields

Read the following scripts:

- `scripts/lib/events.sh` — the event emission library. Note:
  - `ORCH_EVENT_TYPES` (lines 22-40): all 18 canonical event types:
    SESSION_START, SESSION_END, PHASE_START, PHASE_COMPLETE,
    TASK_START, TASK_COMPLETE, DISPATCH_START, DISPATCH_FALLBACK,
    VERIFY_START, VERIFY_COMPLETE, GUARD_BLOCKED, GUARD_WARNING,
    SAFETY_WARNING, HOOK_START, HOOK_COMPLETE, HOOK_BLOCKED,
    HOOK_VIOLATION, CHECKPOINT_WRITE, CHECKPOINT_RESUME
  - `orch_is_event_type` (lines 48-59): validation function
  - `_orch_events_timestamp` (lines 65-71): uses ORCH_STARTED_AT when set
  - `_orch_events_quote` (lines 76-87): shell-safe quoting
  - `emit_event` (lines 98-116): validation + emit, unknown type behavior
  - `_orch_events_print` (lines 119-144): EVENT: line format

- `scripts/engine/run.sh` — to discover which fields each event type carries:
  - SESSION_START: milestone, phase, pending_tasks, dry_run, forced
  - SESSION_END: milestone, phase, completed, blocked, dry_run
  - PHASE_START: milestone, phase, pending_tasks
  - PHASE_COMPLETE: milestone, phase, completed, blocked
  - TASK_START: task, milestone, phase
  - TASK_COMPLETE: task, outcome, reason (when blocked), model, verify,
    tokens_estimated (when successful)
  - DISPATCH_START: task, model, tokens_estimated, payload_bytes, dry_run (opt)
  - VERIFY_START: task, phase
  - VERIFY_COMPLETE: task, result
  - CHECKPOINT_RESUME: milestone, phase, last_task

- `scripts/lib/guards.sh` — to discover guard event fields:
  - GUARD_BLOCKED: guard, reason
  - GUARD_WARNING: guard, reason, forced=1

- `scripts/lib/hooks.sh` — to discover hook event fields:
  - HOOK_START: hook, lifecycle, script
  - HOOK_COMPLETE: hook, lifecycle, exit_code, verdict (opt), reason (opt)
  - HOOK_BLOCKED: hook, lifecycle, exit_code or verdict, reason
  - HOOK_VIOLATION: hook, reason, script
  - HOOK_WARNING: hook, lifecycle, exit_code or verdict, reason, forced (opt)

- `scripts/engine/checkpoint.sh` — to discover checkpoint event fields:
  - CHECKPOINT_WRITE: milestone, phase, last_task, outcome, path

### Step 2 — Write `references/events.md`

Create the file with the following structure:

```markdown
# Event Reference

> Progressive disclosure reference for the speckit-orchestrator event system.
> Self-contained — read this document to understand every event type, its
> fields, and when it fires without reading source code.

> Audience: extenders, contributors

## Overview

[2-3 paragraph summary: what events are, how they are emitted, the
 EVENT: line format, timestamp handling]

---

## Event Line Format

[Format: EVENT:<TYPE> timestamp=<iso8601> run_id=<id> key=value ...]
[Quoting rules: values with whitespace are double-quoted]
[Unknown type behavior: event emitted + companion SAFETY_WARNING]

---

## Event Type Registry

### Session Events
#### SESSION_START
[Fields, when it fires, example line]

#### SESSION_END
[Fields, when it fires, example line]

### Phase Events
#### PHASE_START
#### PHASE_COMPLETE

### Task Events
#### TASK_START
#### TASK_COMPLETE

### Dispatch Events
#### DISPATCH_START
#### DISPATCH_FALLBACK

### Verification Events
#### VERIFY_START
#### VERIFY_COMPLETE

### Guard Events
#### GUARD_BLOCKED
#### GUARD_WARNING

### Safety Events
#### SAFETY_WARNING

### Hook Events
#### HOOK_START
#### HOOK_COMPLETE
#### HOOK_BLOCKED
#### HOOK_VIOLATION

### Checkpoint Events
#### CHECKPOINT_WRITE
#### CHECKPOINT_RESUME

---

## Timestamp Handling

[ORCH_STARTED_AT frozen timestamp, orch_now, deterministic seeding]

---

## Cross-References

[Links to engine.md, errors.md, hooks.md, run-context.sh]
```

### Step 3 — Verify event type completeness

Cross-check the documented event types against the `ORCH_EVENT_TYPES`
variable in `scripts/lib/events.sh`. Ensure all 18 types are documented.
For each type, verify the documented fields by grepping for `emit_event <TYPE>`
across the codebase to find all call sites and their key=value arguments.

### Step 4 — Add examples

For each event type, include at least one example EVENT: line showing
realistic field values. Examples should be derived from actual engine
dry-run output or constructed to match the documented format exactly.

### Step 5 — Add cross-links

Insert relative-path links to:
- `engine.md` — where events fire in the pipeline
- `errors.md` — how errors and events differ (RESULT: vs EVENT:)
- `hooks.md` — hook event emission

## Must-Haves

- [ ] `references/events.md` exists and is >= 120 lines
- [ ] Opens with progressive disclosure statement and audience label
- [ ] Documents EVENT: line format with quoting rules
- [ ] Documents all 18 canonical event types from ORCH_EVENT_TYPES
- [ ] Each event type has field schema documentation (which key=value pairs)
- [ ] Each event type has at least one example EVENT: line
- [ ] Documents timestamp handling (ORCH_STARTED_AT, orch_now)
- [ ] Documents unknown event type behavior (companion SAFETY_WARNING)
- [ ] Cross-links to engine.md, errors.md, hooks.md using relative paths

## Verification

After writing the file, confirm:

```
test -f references/events.md
test "$(wc -l < references/events.md | tr -d ' ')" -ge 120
grep -q "## Overview" references/events.md
grep -qi "Audience:" references/events.md
grep -q "SESSION_START" references/events.md
grep -q "TASK_COMPLETE" references/events.md
grep -q "GUARD_BLOCKED" references/events.md
grep -q "HOOK_BLOCKED" references/events.md
grep -q "CHECKPOINT_WRITE" references/events.md
grep -q "EVENT:" references/events.md
grep -q "engine.md" references/events.md
grep -q "errors.md" references/events.md
```

All must pass.

## Inputs

### From Previous Tasks

None — T02 is independent.

### From Disk (Pre-existing)

- `scripts/lib/events.sh` — event emission library (primary source of truth)
- `scripts/engine/run.sh` — event call sites with field usage
- `scripts/engine/checkpoint.sh` — CHECKPOINT_WRITE event emission
- `scripts/lib/guards.sh` — GUARD_BLOCKED/GUARD_WARNING emission
- `scripts/lib/hooks.sh` — HOOK_START/HOOK_COMPLETE/HOOK_BLOCKED/HOOK_VIOLATION emission
- `scripts/lib/run-context.sh` — ORCH_STARTED_AT frozen timestamp

## Constraints

- **DC-1**: Progressive disclosure format, `## Overview`, `##`/`###`, no HTML.
- **DC-2**: Audience label: `extenders, contributors`.
- **DC-3**: All cross-links use relative paths from `references/` directory.
- **DC-4**: Verify-as-you-write — every event type and field confirmed by reading source.
- **DC-5**: Any bug fix commit references `references/events.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `references/events.md` exists with 120+ lines.
2. All 18 canonical event types are documented with field schemas and examples.
3. EVENT: line format and quoting rules are specified.
4. Cross-links to engine.md, errors.md, hooks.md are present.
5. If any event types are missing from the registry or emit incorrect fields,
   each fix is committed referencing this doc.
