---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M006"
name: "Create references/errors.md — error taxonomy and result protocol"
depends_on: []
---

## Prerequisites

- Access to the full codebase at the project root.
- No prior tasks required — T03 is independent.

## Description

Create a new reference document at `references/errors.md` that documents
the orchestrator's closed error taxonomy and the structured result emission
protocol. A developer reading this document should understand every error
kind, when each is emitted, the RESULT: JSON line format, and how to use
emit_result correctly without reading source code.

The document must follow existing `references/` conventions (DC-1):
progressive disclosure statement, `## Overview` immediately after title,
`##`/`###` structure, no inline HTML. It must declare an audience label
(DC-2) of `extenders, contributors`. All cross-links must use relative
paths (DC-3).

## Steps

### Step 1 — Read source scripts to catalog error kinds and usage

Read the following scripts:

- `scripts/lib/errors.sh` — the error emission library. Note:
  - Error taxonomy constants (lines 21-27):
    ORCH_ERR_CONFIG="CONFIG", ORCH_ERR_STATE="STATE",
    ORCH_ERR_DISPATCH="DISPATCH", ORCH_ERR_VERIFY="VERIFY",
    ORCH_ERR_BUDGET="BUDGET", ORCH_ERR_IO="IO"
  - `ORCH_ERR_KINDS` (lines 29-34): newline-separated list
  - `orch_is_error_kind` (lines 40-47): validation function
  - `_orch_errors_escape` (lines 49-59): JSON escaping (backslash, quote, control chars)
  - `emit_result` (lines 61-94): status ok/error, kind validation, RESULT: JSON format
  - RESULT: line format: `RESULT:{"status":"ok|error","error_kind":"<KIND>","detail":"<text>"}`
  - Invalid status fallback: status → "error", kind → "CONFIG"
  - Unknown error_kind: wraps original detail, downgrades to CONFIG

- `scripts/engine/run.sh` — emit_result call sites:
  - CONFIG: "unknown flag", "missing required positional args"
  - STATE: "phase directory not found", "tasks directory not found",
    "phase ended with N blocked task(s)", "PRE_ADVANCE hook blocked"
  - VERIFY: "phase_complete guard blocked advance"
  - ok: "engine completed M/P (dry_run=N, completed=N)"

- `scripts/lib/guards.sh` — error kinds from guard failures:
  - Guards emit GUARD_BLOCKED events (not RESULT: lines), but the engine
    converts these to TASK_COMPLETE outcome=blocked and eventually may
    produce a STATE error via the blocked-count check.

- Other scripts that call emit_result (grep across codebase to find all sites):
  - `scripts/lifecycle/record-result.sh`
  - `scripts/knowledge/create-entry.sh`
  - `scripts/verify/check-must-haves.sh`
  - `scripts/state/derive-phase.sh`
  - `scripts/dispatch/build-context.sh`
  - `scripts/dispatch/compress-payload.sh`

### Step 2 — Write `references/errors.md`

Create the file with the following structure:

```markdown
# Error Reference

> Progressive disclosure reference for the speckit-orchestrator error
> taxonomy and result protocol. Self-contained — read this document to
> understand error kinds, the RESULT: line format, and emit_result usage
> without reading source code.

> Audience: extenders, contributors

## Overview

[2-3 paragraph summary: what the error taxonomy is, why it exists,
 how it relates to structured events]

---

## Result Line Format

[RESULT: JSON format specification]
[Fields: status (ok|error), error_kind, detail]
[Escaping rules: backslash, double-quote, control characters → spaces]
[Requirement: every script must emit exactly one RESULT: line at completion]

---

## Error Taxonomy

### CONFIG
[Definition: configuration-related errors]
[When emitted: invalid CLI args, missing config files, bad YAML]
[Examples from actual code]

### STATE
[Definition: state consistency errors]
[When emitted: missing phase/tasks directory, blocked tasks, invalid state]
[Examples from actual code]

### DISPATCH
[Definition: dispatch pipeline errors]
[When emitted: context build failure, model unavailable, dispatch timeout]
[Examples from actual code]

### VERIFY
[Definition: verification failures]
[When emitted: guard_phase_complete blocks, must-have check failure]
[Examples from actual code]

### BUDGET
[Definition: budget constraint violations]
[When emitted: cost or duration exceeds configured caps]
[Examples from actual code]

### IO
[Definition: file system and I/O errors]
[When emitted: file read/write failures, checkpoint write failures]
[Examples from actual code]

---

## emit_result Protocol

### Function Signature
[emit_result <status> [error_kind] [detail]]

### Behavior
[Status validation: ok or error, others downgraded to error+CONFIG]
[Error kind validation: unknown kinds downgraded to CONFIG with wrapped detail]
[One RESULT: line per script invocation]
[Silent failure principle: script without RESULT: is a bug]

---

## Error Kinds in JSONL

[How error_kind appears in execution-log.jsonl entries]
[Cross-ref to file-formats.md for JSONL schema]

---

## Cross-References

[Links to events.md, engine.md, file-formats.md]
```

### Step 3 — Verify emit_result usage across the codebase

Grep for `emit_result` across all scripts to confirm:
- Every call uses a valid error_kind from the taxonomy
- The status is always "ok" or "error"
- No script exits without emitting a RESULT: line (where required)

Fix any issues found with a commit referencing `references/errors.md` (DC-5).

### Step 4 — Add examples

For each error kind, include at least one example RESULT: line from
actual code, showing the JSON format with realistic values.

### Step 5 — Add cross-links

Insert relative-path links to:
- `events.md` — how events (EVENT:) differ from results (RESULT:)
- `engine.md` — where the engine emits results
- `file-formats.md` — JSONL format for execution-log entries

## Must-Haves

- [ ] `references/errors.md` exists and is >= 100 lines
- [ ] Opens with progressive disclosure statement and audience label
- [ ] Documents all 6 error kinds: CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO
- [ ] Each error kind has a definition, when-emitted list, and examples
- [ ] Documents the RESULT: JSON line format with all three fields
- [ ] Documents emit_result function signature and validation behavior
- [ ] Documents escaping rules for the detail field
- [ ] Cross-links to events.md, engine.md using relative paths

## Verification

After writing the file, confirm:

```
test -f references/errors.md
test "$(wc -l < references/errors.md | tr -d ' ')" -ge 100
grep -q "## Overview" references/errors.md
grep -qi "Audience:" references/errors.md
grep -q "CONFIG" references/errors.md
grep -q "STATE" references/errors.md
grep -q "DISPATCH" references/errors.md
grep -q "VERIFY" references/errors.md
grep -q "BUDGET" references/errors.md
grep -q "IO" references/errors.md
grep -q "RESULT:" references/errors.md
grep -q "emit_result" references/errors.md
grep -q "events.md" references/errors.md
grep -q "engine.md" references/errors.md
```

All must pass.

## Inputs

### From Previous Tasks

None — T03 is independent.

### From Disk (Pre-existing)

- `scripts/lib/errors.sh` — error taxonomy and emit_result (primary source)
- `scripts/engine/run.sh` — emit_result call sites in the engine
- `scripts/lib/guards.sh` — guard-related error context
- `scripts/lifecycle/record-result.sh` — execution log recording
- `scripts/verify/check-must-haves.sh` — verification-related errors
- `scripts/state/derive-phase.sh` — state-related errors
- `scripts/dispatch/build-context.sh` — dispatch-related errors
- `references/file-formats.md` — cross-link target for JSONL format

## Constraints

- **DC-1**: Progressive disclosure format, `## Overview`, `##`/`###`, no HTML.
- **DC-2**: Audience label: `extenders, contributors`.
- **DC-3**: All cross-links use relative paths from `references/` directory.
- **DC-4**: Verify-as-you-write — every error kind and example confirmed by reading source.
- **DC-5**: Any bug fix commit references `references/errors.md`.
- **DC-6**: Bash 3.2 / POSIX compatibility for any code fixes.

## Expected Output

After completing this task:

1. `references/errors.md` exists with 100+ lines.
2. All 6 error kinds are documented with definitions, triggers, and examples.
3. RESULT: JSON format and emit_result protocol are fully specified.
4. Cross-links to events.md and engine.md are present.
5. If any emit_result calls use invalid error kinds, each fix is committed.
