#!/usr/bin/env bash
# scripts/verify/m027-p03-t03-shape-precheck.sh -- T03-scoped precheck verifier.
#
# Asserts the M027/P03/T03 must-haves: run-doctor.sh has the --config-check and
# --no-anomaly arg-parse cases, the two new advisory run_check invocations, and
# the script smoke-runs without crashing under --no-anomaly.
#
# Bash 3.2 compatible. Read-only (FR-12). Zero LLM tokens (FR-21).
#
# T04 ships scripts/verify/m027-p03-run-doctor-integration.sh which subsumes
# this precheck.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

fail() { echo "FAIL: m027-p03-t03-shape-precheck $1" >&2; exit 1; }

[ -f scripts/diagnostics/run-doctor.sh ] || fail "missing run-doctor.sh"

# File-size floor.
line_count=$(wc -l < scripts/diagnostics/run-doctor.sh | tr -d ' ')
[ "$line_count" -ge 140 ] || fail "run-doctor.sh too short ($line_count < 140 lines)"

# Arg-parse additions.
grep -q -- "--config-check" scripts/diagnostics/run-doctor.sh || fail "missing --config-check arg"
grep -q -- "--no-anomaly" scripts/diagnostics/run-doctor.sh || fail "missing --no-anomaly arg"
grep -q "CONFIG_CHECK=" scripts/diagnostics/run-doctor.sh || fail "missing CONFIG_CHECK init"
grep -q "NO_ANOMALY=" scripts/diagnostics/run-doctor.sh || fail "missing NO_ANOMALY init"

# run_check invocations.
grep -q 'run_check "Anomaly Detection"' scripts/diagnostics/run-doctor.sh || fail "missing Anomaly Detection run_check"
grep -q 'run_check "Config Drift"' scripts/diagnostics/run-doctor.sh || fail "missing Config Drift run_check"
grep -q "check-anomalies.sh" scripts/diagnostics/run-doctor.sh || fail "missing check-anomalies.sh ref"
grep -q "check-config-drift.sh" scripts/diagnostics/run-doctor.sh || fail "missing check-config-drift.sh ref"

# Advisory marker (the trailing "1" arg in run_check invocations for both new checks).
grep -E 'run_check "Anomaly Detection".*"1"' scripts/diagnostics/run-doctor.sh >/dev/null || fail "Anomaly Detection not advisory"
grep -E 'run_check "Config Drift".*"1"' scripts/diagnostics/run-doctor.sh >/dev/null || fail "Config Drift not advisory"

# Behavioral: run-doctor.sh smoke-test runs without crashing.
out=$(bash scripts/diagnostics/run-doctor.sh --no-anomaly 2>&1 | head -3)
echo "$out" | grep -q "Orchestrator Diagnostics" || fail "run-doctor.sh failed smoke test"

echo "PASS: m027-p03-t03-shape-precheck"
exit 0
