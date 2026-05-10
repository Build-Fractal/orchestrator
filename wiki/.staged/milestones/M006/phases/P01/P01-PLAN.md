---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M006"
goal: "Create references/architecture.md and update references/file-formats.md with missing schemas, verified against the actual codebase"
demo_sentence: "A developer reading references/architecture.md understands the engine pipeline (7 stages), data flow (recipes → build → compress → dispatch → verify → record → advance), state machine, file layout, and how M001-M005 subsystems relate — every diagram and path reference verified against actual codebase."
risk: "medium"
depends_on: []
---

<!--
  P01 — Architecture Overview and File Layout
  ============================================

  Context: M006 (Documentation & Quality) Phase 01 creates the first
  two reference documents — architecture.md (new) and file-formats.md
  (update with missing schemas). Every claim in these documents is
  verified by running actual scripts/inspecting actual files. Any
  discrepancies found between documentation and code produce inline
  bug fixes per DC-5.

  Design constraints from M006-CONTEXT.md:
    DC-1: Progressive disclosure format (## Overview after title, ASCII diagrams)
    DC-2: Audience label on every doc
    DC-3: Cross-links use relative paths
    DC-4: Verify-as-you-write is mechanical — run the command, confirm output
    DC-5: Bug fix commits reference the doc that surfaced them
    DC-6: Bash 3.2 / POSIX compatibility for all code fixes
-->

## Must-Haves

### Truths

- `references/architecture.md` exists with progressive disclosure header and audience label.
  - Check: `bash scripts/verify/m006-p01-arch-header.sh`
- `references/architecture.md` contains an ASCII engine pipeline diagram showing the 7 stages.
  - Check: `bash scripts/verify/m006-p01-arch-pipeline.sh`
- `references/architecture.md` documents the data flow: recipe → build → compress → dispatch → verify → record → advance.
  - Check: `bash scripts/verify/m006-p01-arch-dataflow.sh`
- `references/architecture.md` includes a file layout tree of the project directory structure.
  - Check: `bash scripts/verify/m006-p01-arch-layout.sh`
- `references/architecture.md` includes a subsystem relationship map covering M001-[M005](../../../../milestones/M005/index.md) subsystems.
  - Check: `bash scripts/verify/m006-p01-arch-subsystems.sh`
- `references/architecture.md` cross-links to other references/ docs using relative paths (DC-3).
  - Check: `bash scripts/verify/m006-p01-arch-crosslinks.sh`
- `references/file-formats.md` documents the context-recipe.yaml format.
  - Check: `bash scripts/verify/m006-p01-formats-recipe.sh`
- `references/file-formats.md` documents the hooks.yaml format.
  - Check: `bash scripts/verify/m006-p01-formats-hooks.sh`
- `references/file-formats.md` documents the routing.yaml format.
  - Check: `bash scripts/verify/m006-p01-formats-routing.sh`
- `references/file-formats.md` documents the checkpoint.json format.
  - Check: `bash scripts/verify/m006-p01-formats-checkpoint.sh`
- `references/file-formats.md` documents the doctor-history.jsonl format.
  - Check: `bash scripts/verify/m006-p01-formats-doctor.sh`
- Every file path mentioned in `references/architecture.md` exists on disk.
  - Check: `bash scripts/verify/m006-p01-paths-exist.sh`

### Artifacts

- `references/architecture.md` (min 200 lines, contains "## Overview", "Audience:", "engine pipeline", "data flow", "file layout", "subsystem")
- `references/file-formats.md` (min 850 lines, contains "context-recipe.yaml", "hooks.yaml", "routing.yaml", "checkpoint.json", "doctor-history.jsonl")

### Key Links

- `references/architecture.md` → `references/state-machine.md` (state machine cross-ref)
- `references/architecture.md` → `references/file-formats.md` (format cross-ref)
- `references/architecture.md` → `references/verification-ladder.md` (verification cross-ref)
- `references/architecture.md` → `references/tier-definitions.md` (tier cross-ref)
- `references/file-formats.md` → `templates/context-recipe.yaml` (recipe source)
- `references/file-formats.md` → `templates/hooks.yaml` (hooks source)
- `references/file-formats.md` → `templates/routing.yaml` (routing source)

## Tasks

### T01: Create `references/architecture.md` — engine pipeline, data flow, subsystem map

Reads `scripts/engine/run.sh`, `scripts/dispatch/build-context.sh`,
`scripts/dispatch/compress-payload.sh`, `scripts/state/derive-phase.sh`,
`scripts/lifecycle/phase-transition.sh`, `scripts/lifecycle/auto-loop.sh`,
and `extension.yml` to produce a verified architecture document. Includes:
engine pipeline diagram (7 stages), data flow walkthrough, state machine
overview (cross-links to `state-machine.md`), file layout tree, subsystem
map covering M001-M005, and cross-links to all existing reference docs.

Full plan: `tasks/T01-PLAN.md`

### T02: Update `references/file-formats.md` — add missing format schemas

Reads `templates/context-recipe.yaml`, `templates/hooks.yaml`,
`templates/routing.yaml`, `scripts/engine/checkpoint.sh`, and
`scripts/diagnostics/run-doctor.sh` to add five missing format
schemas to the existing file-formats reference document: context-recipe.yaml,
hooks.yaml, routing.yaml, checkpoint.json, and doctor-history.jsonl.
Verifies each schema by cross-checking against the actual template/script.

Full plan: `tasks/T02-PLAN.md`

### T03: Verification scripts for P01 must-haves

Creates the verification scripts referenced in the Truths section above.
Each script is a standalone single-file invocation (AD-19 compliant) that
checks one specific property of the documentation artifacts. Also runs the
full verification to confirm all checks pass after T01 and T02 are complete.

Full plan: `tasks/T03-PLAN.md`

## Task Dependencies

```
T01 (architecture.md) ─────────────┐
                                   ├─→ T03 (verification scripts)
T02 (file-formats.md update) ──────┘
```

T01 and T02 are independent of each other — they produce different files
and read different source scripts. T03 depends on both because it validates
the artifacts T01 and T02 produce.

## Files Likely Touched

- `references/architecture.md` (create)
- `references/file-formats.md` (modify — add 5 missing format schemas)
- `scripts/verify/m006-p01-arch-header.sh` (create)
- `scripts/verify/m006-p01-arch-pipeline.sh` (create)
- `scripts/verify/m006-p01-arch-dataflow.sh` (create)
- `scripts/verify/m006-p01-arch-layout.sh` (create)
- `scripts/verify/m006-p01-arch-subsystems.sh` (create)
- `scripts/verify/m006-p01-arch-crosslinks.sh` (create)
- `scripts/verify/m006-p01-formats-recipe.sh` (create)
- `scripts/verify/m006-p01-formats-hooks.sh` (create)
- `scripts/verify/m006-p01-formats-routing.sh` (create)
- `scripts/verify/m006-p01-formats-checkpoint.sh` (create)
- `scripts/verify/m006-p01-formats-doctor.sh` (create)
- `scripts/verify/m006-p01-paths-exist.sh` (create)
- Bug fix commits for any discrepancies found (files TBD)
