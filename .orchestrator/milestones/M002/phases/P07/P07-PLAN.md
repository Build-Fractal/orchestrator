---
schema_version: "1.0"
type: phase-plan
phase: "P07"
milestone: "M002"
goal: "Validate and harden the diagnostics command — verify that run-doctor.sh orchestrates all checks, each check script detects its target anomaly, results append to doctor-history.jsonl, and doctor.md + extension.yml registrations are complete."
demo_sentence: "Running /speckit.orchestrator.doctor detects orphaned artifacts, stale knowledge, unscoped entries, scope mismatches, and cost spikes; results appear on screen and are appended to doctor-history.jsonl for trend tracking."
risk: "low"
depends_on: [P01, P02, P03, P04, P05, P06]
---

## Must-Haves

### Truths

- run-doctor.sh invokes check-orphaned.sh, check-stale.sh, check-scope.sh, and check-cost-spikes.sh as part of its check suite
  - Check: `bash scripts/verify/m002-p07-runner-invokes-checks.sh`
- check-orphaned.sh sources index-utils.sh and scans for index entries without detail files and detail files without index entries
  - Check: `bash scripts/verify/m002-p07-orphaned-detects-both.sh`
- check-stale.sh sources staleness.sh and flags entries past the 90-day staleness threshold with low hit counts
  - Check: `bash scripts/verify/m002-p07-stale-threshold.sh`
- check-scope.sh flags entries with no scope tags as "unscoped — will be injected into ALL dispatches"
  - Check: `bash scripts/verify/m002-p07-scope-flags-unscoped.sh`
- check-cost-spikes.sh flags tasks costing >5x the average with unit ID and cost details
  - Check: `bash scripts/verify/m002-p07-cost-spike-threshold.sh`
- run-doctor.sh appends a JSON line to doctor-history.jsonl with timestamp, checks_passed, checks_total, and status fields
  - Check: `bash scripts/verify/m002-p07-history-append.sh`
- doctor.md describes all four core check categories (orphaned, stale, scope, cost)
  - Check: `bash scripts/verify/m002-p07-doctor-md-sections.sh`
- extension.yml registers speckit.orchestrator.doctor command and all diagnostics scripts
  - Check: `bash scripts/verify/m002-p07-extension-registration.sh`
- All diagnostics scripts maintain Bash 3.2 compatibility (no associative arrays, no mapfile, no readarray)
  - Check: `bash scripts/verify/m002-p07-bash32-compat.sh`

### Artifacts

- commands/doctor.md (min 10 lines, contains "speckit.orchestrator.doctor")
- scripts/diagnostics/run-doctor.sh (min 50 lines, contains "check-orphaned")
- scripts/diagnostics/check-orphaned.sh (min 20 lines, contains "index_has_entry")
- scripts/diagnostics/check-stale.sh (min 20 lines, contains "compute_effective_confidence")
- scripts/diagnostics/check-scope.sh (min 15 lines, contains "scope tag")
- scripts/diagnostics/check-cost-spikes.sh (min 20 lines, contains "cost_estimated")

### Key Links

- commands/doctor.md -> run-doctor.sh (doctor command references runner script)
- scripts/diagnostics/run-doctor.sh -> check-orphaned.sh (runner invokes orphan check)
- scripts/diagnostics/run-doctor.sh -> check-stale.sh (runner invokes stale check)
- scripts/diagnostics/run-doctor.sh -> check-scope.sh (runner invokes scope check)
- scripts/diagnostics/run-doctor.sh -> check-cost-spikes.sh (runner invokes cost check)
- extension.yml -> commands/doctor.md (extension manifest registers command)

## Tasks

### T01: Create verification scripts for all P07 must-haves

Write 9 verification scripts under `scripts/verify/m002-p07-*.sh` that mechanically check each truth statement. These scripts verify the existing diagnostics implementation against the M002 knowledge architecture requirements.

### T02: Validate core diagnostic check scripts

Run all 9 verification scripts against the existing check-orphaned.sh, check-stale.sh, check-scope.sh, and check-cost-spikes.sh scripts. Fix any failures found. Verify that each check script correctly integrates with P01-P06 delivered libraries.

### T03: Validate run-doctor.sh orchestration and doctor-history.jsonl output

Verify that run-doctor.sh correctly orchestrates all check scripts, produces a scored health report, and appends results to doctor-history.jsonl with the required JSON schema. Verify doctor.md and extension.yml registrations are complete. Document doctor-history.jsonl format in references/file-formats.md.

### T04: End-to-end diagnostics pipeline verification

Run a full E2E test: create knowledge entries with deliberate anomalies (orphaned, stale, unscoped), create an execution log with cost spikes, run the full doctor pipeline, and verify all anomalies are detected and results are recorded in doctor-history.jsonl.

## Task Dependencies

T01 -> T02 -> T03 -> T04

## Files Likely Touched

- scripts/verify/m002-p07-runner-invokes-checks.sh (create)
- scripts/verify/m002-p07-orphaned-detects-both.sh (create)
- scripts/verify/m002-p07-stale-threshold.sh (create)
- scripts/verify/m002-p07-scope-flags-unscoped.sh (create)
- scripts/verify/m002-p07-cost-spike-threshold.sh (create)
- scripts/verify/m002-p07-history-append.sh (create)
- scripts/verify/m002-p07-doctor-md-sections.sh (create)
- scripts/verify/m002-p07-extension-registration.sh (create)
- scripts/verify/m002-p07-bash32-compat.sh (create)
- scripts/verify/m002-p07-e2e.sh (create)
- references/file-formats.md (modify)
- commands/doctor.md (modify — if sections need expansion)
- extension.yml (modify — if registrations are missing)
