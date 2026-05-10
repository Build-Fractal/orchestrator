---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P07"
milestone: "M002"
name: "Validate Core Diagnostic Check Scripts"
depends_on: [T01]
---

## Prerequisites

T01 must be complete -- all 9 verification scripts exist under `scripts/verify/m002-p07-*.sh`.

## Description

Run all 9 verification scripts against the existing diagnostics implementation. Fix any failures found. Verify that each check script correctly integrates with P01-P06 delivered libraries (index-utils.sh, staleness.sh, detail-utils.sh).

Since the diagnostics scripts already exist from prior milestones, this task follows the "validation-as-task" pattern: the primary work is confirming correctness rather than writing new code. Fixes are only applied if verification scripts fail.

## Steps

### Step 1: Run all 9 verification scripts and record results

Run each script individually and record the output:

```
bash scripts/verify/m002-p07-runner-invokes-checks.sh
bash scripts/verify/m002-p07-orphaned-detects-both.sh
bash scripts/verify/m002-p07-stale-threshold.sh
bash scripts/verify/m002-p07-scope-flags-unscoped.sh
bash scripts/verify/m002-p07-cost-spike-threshold.sh
bash scripts/verify/m002-p07-history-append.sh
bash scripts/verify/m002-p07-doctor-md-sections.sh
bash scripts/verify/m002-p07-extension-registration.sh
bash scripts/verify/m002-p07-bash32-compat.sh
```

Expected: all 9 print `PASS:` and exit 0.

### Step 2: If any scripts fail, diagnose and fix

For each failing script:

1. Read the failing verification script to understand what it checks.
2. Read the target diagnostics script to understand its current implementation.
3. Determine if the fix should be in the diagnostics script (missing behavior) or in the verification script (too-strict assertion).
4. Apply the minimum fix required.

**Priority order for fixes:**
- Missing integrations (e.g., not sourcing the right library) -- fix in diagnostics script
- Missing output format (e.g., warning message wording) -- fix in diagnostics script
- Overly brittle assertions (e.g., exact string match where regex would be appropriate) -- fix in verification script

### Step 3: Re-run all 9 scripts to confirm all pass

After any fixes, re-run the full suite:

```
bash scripts/verify/m002-p07-runner-invokes-checks.sh
bash scripts/verify/m002-p07-orphaned-detects-both.sh
bash scripts/verify/m002-p07-stale-threshold.sh
bash scripts/verify/m002-p07-scope-flags-unscoped.sh
bash scripts/verify/m002-p07-cost-spike-threshold.sh
bash scripts/verify/m002-p07-history-append.sh
bash scripts/verify/m002-p07-doctor-md-sections.sh
bash scripts/verify/m002-p07-extension-registration.sh
bash scripts/verify/m002-p07-bash32-compat.sh
```

All 9 must print `PASS:` and exit 0.

## Must-Haves

This task validates these phase must-haves:
- check-orphaned.sh sources index-utils.sh and scans for both orphan directions
- check-stale.sh sources staleness.sh and flags entries past 90-day threshold
- check-scope.sh flags entries with no scope tags
- check-cost-spikes.sh flags tasks costing >5x average
- run-doctor.sh invokes all four core check scripts
- All diagnostics scripts maintain Bash 3.2 compatibility

## Verification

```
bash scripts/verify/m002-p07-runner-invokes-checks.sh
bash scripts/verify/m002-p07-orphaned-detects-both.sh
bash scripts/verify/m002-p07-stale-threshold.sh
bash scripts/verify/m002-p07-scope-flags-unscoped.sh
bash scripts/verify/m002-p07-cost-spike-threshold.sh
bash scripts/verify/m002-p07-history-append.sh
bash scripts/verify/m002-p07-doctor-md-sections.sh
bash scripts/verify/m002-p07-extension-registration.sh
bash scripts/verify/m002-p07-bash32-compat.sh
```

Expected output for each: `PASS: <description>`

## Inputs

### From Previous Tasks
- `scripts/verify/m002-p07-*.sh` (from T01)
  - Key API: Each script is a standalone bash executable that prints `PASS: <message>` or `FAIL: <message>` and exits 0 or 1 respectively. No arguments required.
  - Key types: Exit code 0 = pass, 1 = fail. Output is one line to stdout.

### From Disk (Pre-existing)
- `scripts/diagnostics/run-doctor.sh` -- runner that invokes `run_check()` for each diagnostic. Parses `DOCTOR:` structured output or falls back to exit code. Tallies pass/fail, prints health report, appends JSON to `doctor-history.jsonl`.
- `scripts/diagnostics/check-orphaned.sh` -- sources `scripts/knowledge/lib/index-utils.sh`. Reads `KNOWLEDGE-INDEX.md`, checks each entry ID against `knowledge/{category}/{id}.md`. Scans `knowledge/*/*.md` (excluding archive) and checks each against index via `index_has_entry()`.
- `scripts/diagnostics/check-stale.sh` -- sources both `index-utils.sh` and `staleness.sh`. Parses `verified:YYYY-MM-DD` and `hits:N` from index columns. Calls `days_since()` and `compute_effective_confidence()`. Threshold: 90 days, hit_count <= 10.
- `scripts/diagnostics/check-scope.sh` -- sources `index-utils.sh`. Reads index column 2 (scope tag). Flags empty scope tags.
- `scripts/diagnostics/check-cost-spikes.sh` -- reads `execution-log.jsonl`, extracts `cost_estimated` via sed, computes average with awk, flags entries >5x average. Includes `unit_id` in warning.

## Constraints

- Do not modify scripts unless a verification check fails
- Fixes must maintain Bash 3.2 compatibility (no associative arrays, no mapfile, no readarray)
- Fixes must maintain idempotent behavior (NFR-103)
- Fixes must not break existing check scripts added in [M005](../../../../../milestones/M005/index.md) phases (check-instructions, check-providers, check-constitution, check-events, check-hashes, check-run-ids, check-plans, check-permissions)

## Expected Output

All 9 verification scripts pass. If any diagnostics scripts required modification, the changes are minimal and targeted.
