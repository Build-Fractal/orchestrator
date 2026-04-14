---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M006"
goal: "Update CHANGELOG.md with M001-M006 entries, verify extension.yml inventory, add doc conformance to run-doctor.sh, update CLAUDE.md, and run final verification sweep"
demo_sentence: "CHANGELOG.md has entries for M001-M006; extension.yml is verified to list every command, hook, and script; run-doctor.sh passes all checks including new documentation conformance — any remaining bugs found during this sweep are fixed."
risk: "low"
depends_on: ["P01", "P02", "P03", "P04", "P05"]
---

<!--
  P06 — CHANGELOG, Extension Inventory, and Final Verification Sweep
  ===================================================================

  Context: M006 (Documentation & Quality) Phase 06 is the final sweep phase.
  It brings CHANGELOG.md up to date with entries for all milestones (M001-M006),
  verifies extension.yml lists every command/hook/script that actually exists,
  adds a documentation conformance diagnostic check to run-doctor.sh, updates
  CLAUDE.md to reflect the current project state, and runs all diagnostics to
  catch any remaining bugs.

  Upstream context:
    P01: references/architecture.md (378 lines), references/file-formats.md (1105 lines)
    P02: references/engine.md (242 lines), events.md (614 lines), errors.md (316 lines), hooks.md (361 lines)
    P03: references/recipes.md (530 lines), routing.md (258 lines)
    P04: docs/getting-started.md (386 lines), recipe-authoring.md (599 lines),
         hook-development.md (509 lines), knowledge-management.md (465 lines)
    P05: scripts/AGENTS.md (323 lines), references/constitution-walkthrough.md (459 lines)

  Design constraints from M006-CONTEXT.md:
    DC-4: Verify-as-you-write — cross-check all claims against actual files
    DC-5: Bug fix commits reference the doc that surfaced them
    DC-6: Bash 3.2 / POSIX compatibility for code changes
-->

## Must-Haves

### Truths

- `CHANGELOG.md` contains an entry section for M002 (knowledge architecture) with Added/Changed items.
  - Check: `bash scripts/verify/m006-p06-changelog-m002.sh`
- `CHANGELOG.md` contains an entry section for M003 (migration tool) with Added items.
  - Check: `bash scripts/verify/m006-p06-changelog-m003.sh`
- `CHANGELOG.md` contains an entry section for M004 (engine architecture) with Added/Changed items.
  - Check: `bash scripts/verify/m006-p06-changelog-m004.sh`
- `CHANGELOG.md` contains an entry section for M005 (hardening) with Added/Changed items.
  - Check: `bash scripts/verify/m006-p06-changelog-m005.sh`
- `CHANGELOG.md` contains an entry section for M006 (documentation) with Added items.
  - Check: `bash scripts/verify/m006-p06-changelog-m006.sh`
- Every command file listed in `extension.yml` exists on disk.
  - Check: `bash scripts/verify/m006-p06-extyml-commands.sh`
- Every script file listed in `extension.yml` exists on disk and is executable.
  - Check: `bash scripts/verify/m006-p06-extyml-scripts.sh`
- `scripts/diagnostics/check-docs.sh` exists and checks for required reference and user guide files.
  - Check: `bash scripts/verify/m006-p06-check-docs-exists.sh`
- `run-doctor.sh` invokes `check-docs.sh` as part of its diagnostic suite.
  - Check: `bash scripts/verify/m006-p06-doctor-docs.sh`
- `CLAUDE.md` project status reflects the current command count, script count, template count, and reference doc count.
  - Check: `bash scripts/verify/m006-p06-claude-md-status.sh`

### Artifacts

- `CHANGELOG.md` (contains "## [0.2.0]" or version header for M002-M006, contains "knowledge", "migration", "engine", "hardening", "documentation")
- `scripts/diagnostics/check-docs.sh` (new file, contains "DOCTOR:", checks references/ and docs/ files)
- `CLAUDE.md` (updated project status line, updated key files list)

### Key Links

- `CHANGELOG.md` -> `specs/` (spec references for each milestone)
- `extension.yml` -> `commands/*.md` (every listed command file must exist)
- `extension.yml` -> `scripts/**/*.sh` (every listed script must exist)
- `scripts/diagnostics/run-doctor.sh` -> `scripts/diagnostics/check-docs.sh` (integration)

## Tasks

### T01: Update CHANGELOG.md with M002-M006 entries

Reads milestone summaries (M002, M003, M004, M005) and P01-P05 phase
summaries (M006) to produce CHANGELOG entries for each milestone. Each
entry follows the Keep a Changelog format already established in the
file. The existing M001 entries (v0.1.0, v0.1.1) are preserved. New
entries are added above the existing entries. Entries summarize what
was Added, Changed, and Fixed in each milestone.

Full plan: `tasks/T01-PLAN.md`

### T02: Verify extension.yml, add doc conformance check, update CLAUDE.md

Cross-checks every command, hook, and script listed in `extension.yml`
against actual file existence on disk. Creates
`scripts/diagnostics/check-docs.sh` that verifies required reference
docs and user guide files exist. Adds the new check to
`run-doctor.sh`. Updates `CLAUDE.md` with accurate project status
(command count, script count, template count, reference doc count,
recent changes). Registers `check-docs.sh` in `extension.yml`.

Full plan: `tasks/T02-PLAN.md`

### T03: Verification scripts and final sweep

Creates all 10 verification scripts referenced in the Truths section.
Runs the full verification suite. Runs `run-doctor.sh` to confirm all
checks pass including the new documentation conformance check. Fixes
any bugs found during the sweep.

Full plan: `tasks/T03-PLAN.md`

## Task Dependencies

```
T01 (CHANGELOG.md) ───────────┐
T02 (extension.yml + docs) ───┼──> T03 (verification + final sweep)
```

T01 and T02 are independent and can execute concurrently. T03 depends
on both because it validates the artifacts they produce and runs the
final doctor sweep.

## Files Likely Touched

- `CHANGELOG.md` (update — add M002-M006 entries)
- `extension.yml` (update — register check-docs.sh, verify inventory)
- `CLAUDE.md` (update — project status, key files, recent changes)
- `scripts/diagnostics/check-docs.sh` (create)
- `scripts/diagnostics/run-doctor.sh` (update — add check-docs invocation)
- `scripts/verify/m006-p06-changelog-m002.sh` (create)
- `scripts/verify/m006-p06-changelog-m003.sh` (create)
- `scripts/verify/m006-p06-changelog-m004.sh` (create)
- `scripts/verify/m006-p06-changelog-m005.sh` (create)
- `scripts/verify/m006-p06-changelog-m006.sh` (create)
- `scripts/verify/m006-p06-extyml-commands.sh` (create)
- `scripts/verify/m006-p06-extxml-scripts.sh` (create)
- `scripts/verify/m006-p06-check-docs-exists.sh` (create)
- `scripts/verify/m006-p06-doctor-docs.sh` (create)
- `scripts/verify/m006-p06-claude-md-status.sh` (create)
- Bug fix commits for any issues found during sweep (files TBD)
