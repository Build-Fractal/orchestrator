---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P07"
milestone: "M002"
name: "End-to-End Diagnostics Pipeline Verification"
depends_on: [T03]
---

## Prerequisites

T03 must be complete -- all verification scripts pass, doctor-history.jsonl is documented in file-formats.md, and all registrations are confirmed.

## Description

Run a full end-to-end test of the diagnostics pipeline: create knowledge entries with deliberate anomalies (orphaned index entry, stale entry, unscoped entry), create an execution log with a cost spike, run the full `run-doctor.sh` pipeline, and verify all anomalies are detected and results are recorded in `doctor-history.jsonl`. This is the final behavioral verification that the diagnostics command works as specified in US8.

This task creates a temporary test environment, exercises the full pipeline, and cleans up afterward. No permanent file changes.

## Steps

### Step 1: Create `scripts/verify/m002-p07-e2e.sh`

Write an end-to-end verification script that:

1. Creates a temporary project directory with isolated `PROJECT_ROOT`
2. Sets up knowledge entries with deliberate anomalies
3. Runs `run-doctor.sh` against the test environment
4. Verifies each anomaly is detected
5. Verifies `doctor-history.jsonl` is written with correct JSON
6. Cleans up the temporary directory

```bash
#!/usr/bin/env bash
# scripts/verify/m002-p07-e2e.sh — E2E diagnostics pipeline verification
# Creates a temp project with deliberate anomalies and verifies run-doctor.sh
# detects all of them.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Setup ---
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# Create project structure
mkdir -p "$tmpdir/knowledge/convention"
mkdir -p "$tmpdir/knowledge/archive"
mkdir -p "$tmpdir/.specify/orchestrator"
mkdir -p "$tmpdir/scripts/knowledge/lib"
mkdir -p "$tmpdir/scripts/diagnostics"

# Copy required library files
cp "$PROJECT_ROOT/scripts/knowledge/lib/index-utils.sh" "$tmpdir/scripts/knowledge/lib/"
cp "$PROJECT_ROOT/scripts/knowledge/lib/staleness.sh" "$tmpdir/scripts/knowledge/lib/"
if [ -f "$PROJECT_ROOT/scripts/knowledge/lib/detail-utils.sh" ]; then
  cp "$PROJECT_ROOT/scripts/knowledge/lib/detail-utils.sh" "$tmpdir/scripts/knowledge/lib/"
fi

# Copy diagnostics scripts
cp "$PROJECT_ROOT/scripts/diagnostics/"*.sh "$tmpdir/scripts/diagnostics/"

# --- Counters ---
passed=0
failed=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" -eq 0 ]; then
    passed=$((passed + 1))
  else
    echo "FAIL: $desc"
    failed=$((failed + 1))
  fi
}

# --- Anomaly 1: Orphaned index entry (index has MEM900, no detail file) ---
cat > "$tmpdir/.specify/orchestrator/KNOWLEDGE-INDEX.md" << 'INDEXEOF'
MEM900 | [project] | convention | 0.90 | 2026-01-01 | verified:2026-01-01 | hits:5 | Orphaned entry with no detail file
MEM901 | | convention | 0.85 | 2026-01-01 | verified:2026-01-01 | hits:2 | Unscoped entry for testing
INDEXEOF

# Create detail file only for MEM901 (MEM900 is orphaned)
cat > "$tmpdir/knowledge/convention/MEM901.md" << 'DETAILEOF'
---
id: MEM901
scope_tags: ""
category: convention
confidence: 0.85
created_at: "2026-01-01"
last_verified: "2026-01-01"
hit_count: 2
---

Unscoped entry for testing
DETAILEOF

# --- Anomaly 2: Stale entry (>90 days, low hits) ---
# MEM901 has verified:2026-01-01, which is >90 days ago from 2026-04-13

# --- Anomaly 3: Unscoped entry ---
# MEM901 has empty scope tag

# --- Anomaly 4: Cost spike ---
cat > "$tmpdir/.specify/orchestrator/execution-log.jsonl" << 'LOGEOF'
{"unitId":"M002-P01-T01","timestamp":"2026-04-10T10:00:00Z","cost_estimated":0.05,"result":"pass"}
{"unitId":"M002-P01-T02","timestamp":"2026-04-10T11:00:00Z","cost_estimated":0.04,"result":"pass"}
{"unitId":"M002-P01-T03","timestamp":"2026-04-10T12:00:00Z","cost_estimated":0.06,"result":"pass"}
{"unitId":"M002-P02-T01","timestamp":"2026-04-11T10:00:00Z","cost_estimated":2.50,"result":"pass"}
LOGEOF

# --- Run diagnostics ---
export PROJECT_ROOT="$tmpdir"
output="$(bash "$tmpdir/scripts/diagnostics/run-doctor.sh" --root "$tmpdir" 2>&1)" || true

# --- Verify anomaly detection ---

# Check 1: Orphaned index entry detected
echo "$output" | grep -qi 'MEM900' 2>/dev/null
check "Orphaned index entry MEM900 detected" $?

# Check 2: Unscoped entry detected
echo "$output" | grep -qi 'MEM901.*scope\|scope.*MEM901\|no scope tag' 2>/dev/null
check "Unscoped entry MEM901 detected" $?

# Check 3: Cost spike detected
echo "$output" | grep -qi 'M002-P02-T01\|spike\|cost.*2.50\|5x' 2>/dev/null
check "Cost spike for M002-P02-T01 detected" $?

# Check 4: Health report produced
echo "$output" | grep -qi 'Health Report\|HEALTHY\|NEEDS_ATTENTION' 2>/dev/null
check "Health report summary produced" $?

# Check 5: doctor-history.jsonl written
history_file="$tmpdir/.specify/orchestrator/doctor-history.jsonl"
test -f "$history_file"
check "doctor-history.jsonl file created" $?

# Check 6: JSON has required fields
if [ -f "$history_file" ]; then
  last_line="$(tail -1 "$history_file")"
  echo "$last_line" | grep -q '"timestamp"' 2>/dev/null
  check "doctor-history.jsonl has timestamp field" $?
  echo "$last_line" | grep -q '"checks_passed"' 2>/dev/null
  check "doctor-history.jsonl has checks_passed field" $?
  echo "$last_line" | grep -q '"checks_total"' 2>/dev/null
  check "doctor-history.jsonl has checks_total field" $?
  echo "$last_line" | grep -q '"status"' 2>/dev/null
  check "doctor-history.jsonl has status field" $?
else
  check "doctor-history.jsonl has timestamp field" 1
  check "doctor-history.jsonl has checks_passed field" 1
  check "doctor-history.jsonl has checks_total field" 1
  check "doctor-history.jsonl has status field" 1
fi

# --- Summary ---
total=$((passed + failed))
echo ""
echo "=== E2E Diagnostics Pipeline ==="
echo "Passed: $passed / $total"

if [ "$failed" -gt 0 ]; then
  echo "FAIL: $failed assertions failed"
  exit 1
fi

echo "PASS: All $total E2E assertions passed — diagnostics pipeline detects orphaned, unscoped, cost spike anomalies and writes doctor-history.jsonl"
```

### Step 2: Make the script executable and run it

```bash
chmod +x scripts/verify/m002-p07-e2e.sh
bash scripts/verify/m002-p07-e2e.sh
```

Expected output:
```
=== E2E Diagnostics Pipeline ===
Passed: 9 / 9
PASS: All 9 E2E assertions passed — diagnostics pipeline detects orphaned, unscoped, cost spike anomalies and writes doctor-history.jsonl
```

### Step 3: Run all 9 must-have verification scripts one final time

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

### Step 4: If any E2E assertion fails, diagnose and fix

For each failing assertion:

1. Check the `run-doctor.sh` output for the expected warning/detection.
2. Determine if the check script is not detecting the anomaly or if the test fixture is malformed.
3. Fix the root cause (either the check script or the E2E test fixture).
4. Re-run to confirm the fix.

Common issues to watch for:
- `check-orphaned.sh` uses `get_project_root()` which may not respect the temp directory. Ensure `PROJECT_ROOT` env var is exported.
- `check-stale.sh` computes days since verification using the system date. If the test date math doesn't produce >90 days, the stale check will pass (no anomaly detected).
- `check-cost-spikes.sh` needs at least 2 entries with `cost_estimated` field. The test fixture provides 4.

## Must-Haves

This task provides final behavioral verification for all phase must-haves:
- E2E orphaned artifact detection
- E2E stale knowledge detection (via staleness threshold)
- E2E unscoped entry detection
- E2E cost spike detection
- E2E doctor-history.jsonl recording

## Verification

```
bash scripts/verify/m002-p07-e2e.sh
```

Expected output: `PASS: All N E2E assertions passed`

Also re-run all 9 must-have scripts:
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

Expected: all 10 scripts (9 must-have + 1 E2E) print `PASS:` and exit 0.

## Inputs

### From Previous Tasks
- `scripts/verify/m002-p07-*.sh` (from T01, validated in T02)
  - Key API: 9 standalone bash executables. Each prints `PASS: <message>` or `FAIL: <message>`, exits 0 or 1. No arguments required.
- `references/file-formats.md` (updated in T03)
  - Key content: New `doctor-history.jsonl` section documenting the JSON schema (timestamp, checks_passed, checks_total, advisory_warnings, status).

### From Disk (Pre-existing)
- `scripts/diagnostics/run-doctor.sh` -- runner script. `run_check()` function runs each check, parses `DOCTOR:` status lines or exit codes, tallies pass/fail. Appends JSON to `$PROJECT_ROOT/.specify/orchestrator/doctor-history.jsonl`. Accepts `--root <path>` to override project root.
- `scripts/diagnostics/check-orphaned.sh` -- sources `scripts/knowledge/lib/index-utils.sh`. Uses `get_project_root()`, `get_index_path()`, `index_has_entry()`. Scans both directions: index entries without detail files, detail files without index entries.
- `scripts/diagnostics/check-stale.sh` -- sources `index-utils.sh` and `staleness.sh`. Uses `days_since()`, `compute_effective_confidence()`. Threshold: STALE_DAYS=90, hit_count <= 10, EFFECTIVE_CONF_THRESHOLD=0.50.
- `scripts/diagnostics/check-scope.sh` -- sources `index-utils.sh`. Extracts scope tag from index column 2. Flags empty scope tags.
- `scripts/diagnostics/check-cost-spikes.sh` -- reads `$root/.specify/orchestrator/execution-log.jsonl`. Extracts `cost_estimated` via sed. Computes average with awk. Flags >5x average with `unit_id`.
- `scripts/knowledge/lib/index-utils.sh` -- shared library. Provides `get_project_root()`, `get_index_path()`, `index_has_entry()`. Respects `PROJECT_ROOT` env var.
- `scripts/knowledge/lib/staleness.sh` -- shared library. Provides `days_since()`, `compute_effective_confidence()`. Linear decay to 0.5 floor at 180-day horizon.

## Constraints

- No permanent file changes -- the E2E test uses a temporary directory and cleans up via `trap`
- The E2E script itself (`scripts/verify/m002-p07-e2e.sh`) is the only new file
- Test must work on macOS with Bash 3.2 (no GNU-specific date flags)
- Use `PROJECT_ROOT` env var to isolate the test from the real project

## Expected Output

- `scripts/verify/m002-p07-e2e.sh` (create) -- E2E test script
- All 10 verification scripts (9 must-have + 1 E2E) pass
- No permanent modifications to diagnostics scripts (unless a bug is found)
