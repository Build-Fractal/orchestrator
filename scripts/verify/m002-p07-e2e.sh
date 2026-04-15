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
mkdir -p "$tmpdir/.orchestrator"
mkdir -p "$tmpdir/scripts/knowledge/lib"
mkdir -p "$tmpdir/scripts/diagnostics"
mkdir -p "$tmpdir/scripts/lib"
mkdir -p "$tmpdir/scripts/lifecycle"

# Copy required library files
cp "$PROJECT_ROOT/scripts/knowledge/lib/index-utils.sh" "$tmpdir/scripts/knowledge/lib/"
cp "$PROJECT_ROOT/scripts/knowledge/lib/staleness.sh" "$tmpdir/scripts/knowledge/lib/"
if [ -f "$PROJECT_ROOT/scripts/knowledge/lib/detail-utils.sh" ]; then
  cp "$PROJECT_ROOT/scripts/knowledge/lib/detail-utils.sh" "$tmpdir/scripts/knowledge/lib/"
fi

# Copy supporting library files needed by some check scripts
if [ -f "$PROJECT_ROOT/scripts/lib/errors.sh" ]; then
  cp "$PROJECT_ROOT/scripts/lib/errors.sh" "$tmpdir/scripts/lib/"
fi
if [ -f "$PROJECT_ROOT/scripts/lib/events.sh" ]; then
  cp "$PROJECT_ROOT/scripts/lib/events.sh" "$tmpdir/scripts/lib/"
fi
if [ -f "$PROJECT_ROOT/scripts/lifecycle/generate-permissions.sh" ]; then
  cp "$PROJECT_ROOT/scripts/lifecycle/generate-permissions.sh" "$tmpdir/scripts/lifecycle/"
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
cat > "$tmpdir/KNOWLEDGE-INDEX.md" << 'INDEXEOF'
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
cat > "$tmpdir/.orchestrator/execution-log.jsonl" << 'LOGEOF'
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
r=0; echo "$output" | grep -qi 'MEM900' 2>/dev/null || r=1
check "Orphaned index entry MEM900 detected" $r

# Check 2: Unscoped entry detected
r=0; echo "$output" | grep -qiE 'MEM901.*scope|scope.*MEM901|no scope tag' 2>/dev/null || r=1
check "Unscoped entry MEM901 detected" $r

# Check 3: Cost spike detected
r=0; echo "$output" | grep -qiE 'M002-P02-T01|spike|cost.*2\.50|5x' 2>/dev/null || r=1
check "Cost spike for M002-P02-T01 detected" $r

# Check 4: Health report produced
r=0; echo "$output" | grep -qiE 'Health Report|HEALTHY|NEEDS_ATTENTION' 2>/dev/null || r=1
check "Health report summary produced" $r

# Check 5: doctor-history.jsonl written
history_file="$tmpdir/.orchestrator/doctor-history.jsonl"
r=0; test -f "$history_file" || r=1
check "doctor-history.jsonl file created" $r

# Check 6: JSON has required fields
if [ -f "$history_file" ]; then
  last_line="$(tail -1 "$history_file")"
  r=0; echo "$last_line" | grep -q '"timestamp"' 2>/dev/null || r=1
  check "doctor-history.jsonl has timestamp field" $r
  r=0; echo "$last_line" | grep -q '"checks_passed"' 2>/dev/null || r=1
  check "doctor-history.jsonl has checks_passed field" $r
  r=0; echo "$last_line" | grep -q '"checks_total"' 2>/dev/null || r=1
  check "doctor-history.jsonl has checks_total field" $r
  r=0; echo "$last_line" | grep -q '"status"' 2>/dev/null || r=1
  check "doctor-history.jsonl has status field" $r
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
