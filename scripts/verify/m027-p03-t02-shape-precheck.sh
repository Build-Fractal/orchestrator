#!/usr/bin/env bash
# scripts/verify/m027-p03-t02-shape-precheck.sh — T02-scoped precheck verifier.
#
# Asserts the M027/P03/T02 must-haves on the post-T02 codebase. AD-19 single
# script Check shape — invoked from T02's PLAN Verification block.
# T04 ships the canonical phase-level verifiers
# (m027-p03-config-drift-shape.sh, m027-p03-doctor-md-shape.sh,
# m027-p03-doctor-byte-identity.sh) which subsume this precheck and may
# delete it (mirrors M027/P00+P01+P02 T04-subsumes-prechecks pattern).
#
# Bash 3.2 clean. Comment hygiene: no literal bash-4 forbidden tokens in the
# file body so the T04 bash32-compat verifier regex stays clean.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

fail() {
  echo "FAIL: m027-p03-t02-shape-precheck $1" >&2
  exit 1
}

# ---- Helper file shape (check-config-drift.sh) ----
[ -f scripts/diagnostics/check-config-drift.sh ] || fail "missing config-drift helper"
[ -x scripts/diagnostics/check-config-drift.sh ] || fail "config-drift helper not executable"
lines=$(wc -l < scripts/diagnostics/check-config-drift.sh)
[ "$lines" -ge 80 ] || fail "config-drift helper too short ($lines lines, need >=80)"
grep -q "Config Drift (M027 knobs)" scripts/diagnostics/check-config-drift.sh || fail "missing literal block title"
grep -q "check_config_drift_render" scripts/diagnostics/check-config-drift.sh || fail "missing render function"
grep -q "BASH_SOURCE" scripts/diagnostics/check-config-drift.sh || fail "missing CLI entry-point guard"
grep -q "read-config.sh" scripts/diagnostics/check-config-drift.sh || fail "missing read-config.sh delegation"

# ---- doctor.md shape ----
[ -f commands/doctor.md ] || fail "missing commands/doctor.md"
doc_lines=$(wc -l < commands/doctor.md)
[ "$doc_lines" -ge 60 ] || fail "doctor.md too short ($doc_lines lines, need >=60)"
grep -q "## Anomaly Detection" commands/doctor.md || fail "missing ## Anomaly Detection section"
grep -q "## Config Drift" commands/doctor.md || fail "missing ## Config Drift section"
grep -q "scripts/diagnostics/check-anomalies.sh" commands/doctor.md || fail "missing check-anomalies.sh ref"
grep -q "scripts/diagnostics/check-config-drift.sh" commands/doctor.md || fail "missing check-config-drift.sh ref"
grep -q -- "--no-anomaly" commands/doctor.md || fail "missing --no-anomaly doc"
grep -q "ORCHESTRATOR_AUTO" commands/doctor.md || fail "missing ORCHESTRATOR_AUTO doc"
grep -q "anomaly_check_enabled" commands/doctor.md || fail "missing anomaly_check_enabled doc"
grep -q "insufficient sample" commands/doctor.md || fail "missing sample-floor doc"
grep -q "fallback=duration" commands/doctor.md || fail "missing duration-fallback disclaimer"

# Canonical pre-edit section order preserved:
# What It Checks < Runtime Instruction Drift < Anomaly Detection < Config Drift < Usage < Output < When to Run < Referenced Scripts
prev_line=0
for heading in "## What It Checks" "## Runtime Instruction Drift" "## Anomaly Detection" "## Config Drift" "## Usage" "## Output" "## When to Run" "## Referenced Scripts"; do
  line_no=$(grep -n "^${heading}" commands/doctor.md | head -1 | cut -d: -f1)
  if [ -z "$line_no" ]; then
    fail "doctor.md missing heading: $heading"
  fi
  if [ "$line_no" -le "$prev_line" ]; then
    fail "doctor.md section order violation at: $heading (line $line_no <= prev $prev_line)"
  fi
  prev_line="$line_no"
done

# ---- Fixtures ----
[ -f tests/fixtures/m027-p03/doctor-suppressed-baseline.txt ] || fail "missing doctor baseline fixture"
grep -q "Referenced Scripts" tests/fixtures/m027-p03/doctor-suppressed-baseline.txt || fail "fixture missing Referenced Scripts marker"
[ -f tests/fixtures/m027-p03/anomaly-fixture.jsonl ] || fail "missing anomaly fixture"
fixture_lines=$(wc -l < tests/fixtures/m027-p03/anomaly-fixture.jsonl)
[ "$fixture_lines" -ge 9 ] || fail "anomaly fixture too short ($fixture_lines lines, need >=9)"
grep -q "M999/P00/T09" tests/fixtures/m027-p03/anomaly-fixture.jsonl || fail "anomaly fixture missing T09 outlier row"
[ -f tests/fixtures/m027-p03/README.md ] || fail "missing fixture README"
readme_lines=$(wc -l < tests/fixtures/m027-p03/README.md)
[ "$readme_lines" -ge 5 ] || fail "fixture README too short ($readme_lines lines, need >=5)"

# ---- Behavioral: helper smoke-test ----
out=$(bash scripts/diagnostics/check-config-drift.sh --keys efficiency_footer 2>/dev/null)
echo "$out" | grep -q "Config Drift (M027 knobs)" || fail "helper missing title in output"
echo "$out" | grep -q "key=efficiency_footer" || fail "helper missing key= line"
echo "$out" | grep -q "effective=" || fail "helper missing effective= line"
echo "$out" | grep -q "env=" || fail "helper missing env= layer line"

# ---- Behavioral: --no-config-check suppresses to zero stdout ----
out=$(bash scripts/diagnostics/check-config-drift.sh --no-config-check 2>/dev/null)
[ -z "$out" ] || fail "--no-config-check produced non-empty stdout"

# ---- Behavioral: default key list audits all six M027 knobs ----
out=$(bash scripts/diagnostics/check-config-drift.sh 2>/dev/null)
for k in efficiency_footer predictive_cost_surface anomaly_cost_multiplier anomaly_retry_threshold anomaly_pass_rate_threshold anomaly_check_enabled; do
  echo "$out" | grep -q "key=$k" || fail "default key list missing $k"
done

echo "PASS: m027-p03-t02-shape-precheck"
exit 0
