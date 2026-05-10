---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M005"
goal: "A template at templates/instruction-schema.md defines required sections (Context, Task, Constraints, Verification, Output Format) and optional sections (Prior Art, Related Knowledge); a conformance check in run-doctor.sh verifies instruction files match the schema."
demo_sentence: "A developer runs bash scripts/diagnostics/check-instructions.sh --root . and the script scans all commands/*.md files, reports which required sections (Context, Task, Constraints, Verification, Output Format) are missing from each file, and exits 0 when all files conform; bash scripts/diagnostics/run-doctor.sh includes Instruction Conformance in its diagnostic output."
risk: "medium"
depends_on: []
---

<!--
  P04 -- Agent Instruction Schema
  ================================

  Context: command instruction files in commands/ have evolved organically
  and follow no declared schema. The section headings vary across files
  (some have "## Prerequisites", others "## Context", etc.). This phase
  introduces a declared schema template and a conformance check so that
  all instruction files can be mechanically validated for structural
  consistency. The schema does not change file content at runtime — it is
  a development-time convention enforced by run-doctor.sh.

  Architectural decision:
    AD-4  The instruction schema is a markdown template with required
          sections and optional sections. Enforcement is via conformance
          check (static grep for section headings), not runtime parsing.
          Bash 3.2 compatible.

  Cross-milestone dependencies: none. This phase is standalone.
-->

## Must-Haves

### Truths

- Instruction schema template exists at `templates/instruction-schema.md` and declares at least 5 required section headings and at least 2 optional section headings.
  - Check: `bash scripts/verify/p04-schema-template.sh`
- Conformance check script exists at `scripts/diagnostics/check-instructions.sh` and scans files for required section headings, reporting missing sections per file.
  - Check: `bash scripts/verify/p04-check-instructions.sh`
- `scripts/diagnostics/run-doctor.sh` includes a call to `check-instructions.sh` in its diagnostic sequence.
  - Check: `bash scripts/verify/p04-doctor-integration.sh`
- At least 2 existing templates in `templates/` are updated to include conforming section headings as documented in the schema.
  - Check: `bash scripts/verify/p04-template-migration.sh`

### Artifacts

- templates/instruction-schema.md (create, min 60 lines, contains "## Required Sections")
- scripts/diagnostics/check-instructions.sh (create, min 40 lines, contains "DOCTOR:INSTRUCTIONS")
- scripts/diagnostics/run-doctor.sh (modify, contains "check-instructions.sh")
- scripts/verify/p04-schema-template.sh (create, min 10 lines)
- scripts/verify/p04-check-instructions.sh (create, min 10 lines)
- scripts/verify/p04-doctor-integration.sh (create, min 10 lines)
- scripts/verify/p04-template-migration.sh (create, min 10 lines)
- templates/dispatch-prompt.md (modify, progressive migration)
- templates/task-plan.md (modify, progressive migration)

### Key Links

- templates/instruction-schema.md -> scripts/diagnostics/check-instructions.sh (schema defines what the check enforces)
- scripts/diagnostics/check-instructions.sh -> scripts/diagnostics/run-doctor.sh (check wired into doctor)
- templates/instruction-schema.md -> templates/dispatch-prompt.md (migration target)
- templates/instruction-schema.md -> templates/task-plan.md (migration target)

## Tasks

### T01: Create instruction-schema.md and verification scripts

Creates `templates/instruction-schema.md` declaring the required and optional
section headings for agent instruction files. Also creates all four
verification scripts for this phase under `scripts/verify/p04-*.sh`. The
schema template documents each section's purpose, expected content, and
provides a skeleton example. Also creates
`scripts/diagnostics/check-instructions.sh` which performs the static
conformance check by grepping instruction files for required section headings.

Full plan: `tasks/T01-PLAN.md`

### T02: Wire check-instructions.sh into run-doctor.sh

Updates `scripts/diagnostics/run-doctor.sh` to include the instruction
conformance check in its diagnostic sequence, following the existing
`run_check` pattern used for other diagnostics. Depends on T01 (the
check script must exist).

Full plan: `tasks/T02-PLAN.md`

### T03: Update at least 2 existing templates to conform to schema

Updates `templates/dispatch-prompt.md` and `templates/task-plan.md` to
include the required section headings from the instruction schema as
comments or structural sections, demonstrating progressive migration.
Depends on T01 (schema must define the headings).

Full plan: `tasks/T03-PLAN.md`

## Task Dependencies

```
T01 (instruction-schema.md + check-instructions.sh + verify scripts)
  |
  +---> T02 (wire check-instructions.sh into run-doctor.sh)
  |
  +---> T03 (update 2 templates to conform)
```

T01 is the critical-path gate. T02 and T03 depend on T01 but are
independent of each other and can execute in parallel.

## Files Likely Touched

- templates/instruction-schema.md (create)
- scripts/diagnostics/check-instructions.sh (create)
- scripts/diagnostics/run-doctor.sh (modify)
- scripts/verify/p04-schema-template.sh (create)
- scripts/verify/p04-check-instructions.sh (create)
- scripts/verify/p04-doctor-integration.sh (create)
- scripts/verify/p04-template-migration.sh (create)
- templates/dispatch-prompt.md (modify)
- templates/task-plan.md (modify)
