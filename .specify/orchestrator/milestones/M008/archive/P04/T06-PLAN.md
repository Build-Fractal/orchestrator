---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P04"
milestone: "M008"
name: "Bash 3.2 compatibility sweep + standalone end-to-end integration test"
depends_on: ["T01", "T02", "T03", "T04", "T05"]
---

## Prerequisites

- T01–T05 complete. All five P04 scripts exist and are executable:
  - `scripts/state/resolve-root.sh`
  - `scripts/state/detect-speckit.sh`
  - `scripts/state/config-system.sh`
  - `scripts/migrate/migrate-state.sh`
  - `scripts/state/namespace-aliases.sh`
  - Refactored `scripts/state/derive-phase.sh`
- Bash 3.2+ available.

## Description

Two deliverables, both integration-level:

**(A) Bash 3.2 compatibility sweep.** Create `scripts/verify/m008-p04-bash32-compat.sh` that scans every P04 script for Bash 4+ idioms and fails if any are present. Forbidden tokens:

- `declare -A` (associative arrays)
- `mapfile` and `readarray`
- `[[ -v ` (variable-set test introduced in 4.2)
- `${var@Q}`, `${var@U}`, etc. (parameter transformations introduced in 4.4)
- `${!prefix*}` / `${!prefix@}` (indirect expansion — actually 3.2 safe but the more-common `${arr[@]:offset:length}` for associative arrays is not)

**(B) Standalone end-to-end integration test.** Create `scripts/verify/m008-p04-standalone-e2e.sh` that:

1. Creates a fresh temp directory with a fake `.git/` stub.
2. Sets `ORCHESTRATOR_ROOT` to an explicit path OR relies on default resolution.
3. Runs `resolve-root.sh` and asserts the output is the expected path.
4. Runs `detect-speckit.sh` and asserts `speckit_installed=false` in the clean temp dir.
5. Runs `config-system.sh set intensity.default Full` then `config-system.sh get intensity.default` and asserts the round-trip returns `Full`.
6. Runs `namespace-aliases.sh` and asserts at least one `orchestrator:` line is present.
7. Runs `migrate-state.sh` with no source and asserts a `SKIP:` line.
8. Cleans up the temp directory.

This test proves SC-004: "The orchestrator completes a full workflow in a project with no spec-kit present, producing valid state and artifacts."

## Steps

### Step 1 — Create scripts/verify/m008-p04-bash32-compat.sh

The verification script is created by T01-T05 author per script (already written as part of the verify-script deliverables below). T06 adds the cross-cutting compat scanner.

Write verbatim (see "Files to Write" section below — this step's verification script is written alongside the other verify scripts in the phase-level set).

### Step 2 — Create scripts/verify/m008-p04-standalone-e2e.sh

Written in the verify-scripts section below.

### Step 3 — Run all P04 verification scripts to confirm they pass

```bash
bash scripts/verify/m008-p04-bash32-compat.sh
bash scripts/verify/m008-p04-standalone-e2e.sh
```

Each should emit a `PASS:` line and exit 0.

### Step 4 — Run check-must-haves.sh for the phase

```bash
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M008/phases/P04
```

Expected: every Truth check in P04-PLAN.md runs; all emit `PASS:`.

## Must-Haves

This task addresses:

- All P04 scripts are Bash 3.2 compatible — no `declare -A`, no `mapfile`, no `readarray`.
- A full orchestrator workflow (state derivation + config read/write + namespace alias lookup) completes end-to-end without touching `.specify/orchestrator/` or invoking spec-kit.

## Verification

Run:

- `bash scripts/verify/m008-p04-bash32-compat.sh`
- `bash scripts/verify/m008-p04-standalone-e2e.sh`

Each must exit 0 with a `PASS:` line. Then run the phase-level `check-must-haves.sh` to confirm all Truth checks across P04 pass.

## Inputs

### From Previous Tasks

- `scripts/state/resolve-root.sh` (T01)
  - Key API: `bash resolve-root.sh [--absolute] [--verbose]` — emits root path to stdout.
- `scripts/state/detect-speckit.sh` (T02)
  - Key API: `bash detect-speckit.sh` — emits `speckit_installed=<true|false>` and `integration_mode=<enabled|disabled>`.
- `scripts/state/config-system.sh` (T03)
  - Key API: `bash config-system.sh {get|set|list} [args]` — reads/writes `<root>/config.yml`.
- `scripts/migrate/migrate-state.sh` (T04)
  - Key API: `bash migrate-state.sh [--dry-run]` — emits `MIGRATED:`, `SKIP:`, or `DRYRUN:` lines.
- `scripts/state/namespace-aliases.sh` (T05)
  - Key API: `bash namespace-aliases.sh [--markdown]` — emits mapping lines.

### From Disk (Pre-existing)

- `scripts/verify/check-must-haves.sh` — existing phase verification driver.

## Constraints

- Integration test must be hermetic: creates its own temp dir, cleans up on both success and failure (trap EXIT).
- Integration test must NOT depend on the live project's `.specify/orchestrator/` or `.orchestrator/` state.
- Integration test must NOT modify any file outside its temp dir.
- Compat scanner must run fast (under 1 second); pure grep over six files.

## Expected Output

Creating two verify scripts (see the phase-level verify script set). No new runtime code in this task — T06 is pure integration plumbing.

Sample run:

```
$ bash scripts/verify/m008-p04-bash32-compat.sh
PASS: no Bash 4+ idioms detected in P04 scripts
$ bash scripts/verify/m008-p04-standalone-e2e.sh
PASS: standalone e2e workflow completed without spec-kit
```
