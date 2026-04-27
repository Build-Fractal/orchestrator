#!/usr/bin/env bash
# scripts/verify/m027-p03-t01-shape-precheck.sh
# T01-scoped precheck — asserts ONLY T01's must-haves.
# T04 ships the canonical phase-level verifier m027-p03-anomaly-shape.sh
# which subsumes this precheck (mirrors M027/P01/T03 + T04 + M027/P02/T01 pattern).
# Single-script-file Check shape per AD-19.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

fail() { echo "FAIL: m027-p03-t01-shape-precheck $1" >&2; exit 1; }

# 1. Helper file exists, executable, >= 120 lines.
[ -f scripts/diagnostics/check-anomalies.sh ] || fail "missing helper scripts/diagnostics/check-anomalies.sh"
[ -x scripts/diagnostics/check-anomalies.sh ] || fail "helper not executable"
lines=$(wc -l < scripts/diagnostics/check-anomalies.sh)
[ "$lines" -ge 120 ] || fail "helper too short ($lines lines, need >= 120)"

# 2. Title literal present.
grep -q "Anomaly Detection (Tier 1 baseline)" scripts/diagnostics/check-anomalies.sh \
  || fail "missing title literal 'Anomaly Detection (Tier 1 baseline)'"

# 3. Function definition present.
grep -q "check_anomalies_render" scripts/diagnostics/check-anomalies.sh \
  || fail "missing function check_anomalies_render"

# 4. Sourceable-CLI guard present.
grep -q "BASH_SOURCE" scripts/diagnostics/check-anomalies.sh \
  || fail "missing BASH_SOURCE source guard"

# 5. --no-anomaly arg-parse case present.
grep -q -- "--no-anomaly" scripts/diagnostics/check-anomalies.sh \
  || fail "missing --no-anomaly arg"

# 6. --yes arg-parse case present.
grep -q -- "--yes" scripts/diagnostics/check-anomalies.sh \
  || fail "missing --yes arg"

# 7. anomaly_check_enabled config knob honored.
grep -q "anomaly_check_enabled" scripts/diagnostics/check-anomalies.sh \
  || fail "missing anomaly_check_enabled reference"
grep -q "ORCH_ANOMALY_CHECK_ENABLED" scripts/diagnostics/check-anomalies.sh \
  || fail "missing ORCH_ANOMALY_CHECK_ENABLED env-var reference"

# 8. metrics-rollup.sh delegation.
grep -q "metrics-rollup.sh" scripts/diagnostics/check-anomalies.sh \
  || fail "missing scripts/diagnostics/metrics-rollup.sh delegation"

# 9. read-config.sh VALID_KEYS includes all four new anomaly keys.
grep -q "anomaly_cost_multiplier" scripts/state/read-config.sh \
  || fail "anomaly_cost_multiplier not in scripts/state/read-config.sh VALID_KEYS"
grep -q "anomaly_retry_threshold" scripts/state/read-config.sh \
  || fail "anomaly_retry_threshold not in scripts/state/read-config.sh VALID_KEYS"
grep -q "anomaly_pass_rate_threshold" scripts/state/read-config.sh \
  || fail "anomaly_pass_rate_threshold not in scripts/state/read-config.sh VALID_KEYS"
grep -q "anomaly_check_enabled" scripts/state/read-config.sh \
  || fail "anomaly_check_enabled not in scripts/state/read-config.sh VALID_KEYS"

# 10. Behavioral: --no-anomaly emits zero stdout / exit 0 against M013.
out=$(bash scripts/diagnostics/check-anomalies.sh --no-anomaly --milestone M013 2>/dev/null)
[ -z "$out" ] || fail "--no-anomaly produced output (expected zero stdout)"

# 11. Behavioral: --yes also suppresses stdout.
out=$(bash scripts/diagnostics/check-anomalies.sh --yes --milestone M013 2>/dev/null)
[ -z "$out" ] || fail "--yes produced output (expected zero stdout)"

# 12. Behavioral: ORCH_ANOMALY_CHECK_ENABLED=false suppresses stdout.
out=$(ORCH_ANOMALY_CHECK_ENABLED=false bash scripts/diagnostics/check-anomalies.sh --milestone M013 2>/dev/null)
[ -z "$out" ] || fail "ORCH_ANOMALY_CHECK_ENABLED=false produced output"

# 13. Behavioral: against M021 below floor, emits insufficient-sample line.
out=$(bash scripts/diagnostics/check-anomalies.sh --milestone M021 --sample-floor 5 2>/dev/null)
echo "$out" | grep -q "insufficient sample" \
  || fail "below-floor path missing 'insufficient sample' literal"
echo "$out" | grep -q "Anomaly Detection (Tier 1 baseline)" \
  || fail "below-floor path missing title line"

echo "PASS: m027-p03-t01-shape-precheck"
exit 0
