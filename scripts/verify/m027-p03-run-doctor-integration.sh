#!/usr/bin/env bash
# scripts/verify/m027-p03-run-doctor-integration.sh -- M027/P03 Truth #6.
#
# Asserts scripts/diagnostics/run-doctor.sh integration shape:
#   - file present, >= 140 lines
#   - --config-check + --no-anomaly arg-parse cases present
#   - run_check "Anomaly Detection" + run_check "Config Drift" invocations present
#   - both new run_check invocations carry the trailing "1" advisory marker
#   - check-anomalies.sh + check-config-drift.sh paths referenced
#   - behavioral: --no-anomaly invocation prints the standard banner
#
# Bash 3.2 compatible. MEM004 carve-out -- pipes / grep used internally.

set -u

NAME="m027-p03-run-doctor-integration.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

DOC="scripts/diagnostics/run-doctor.sh"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -f "$DOC" ]; then
  fail "$DOC missing"
fi
lines="$(wc -l < "$DOC" | tr -d ' ')"
if [ "$lines" -lt 140 ]; then
  fail "$DOC too short ($lines lines, expected >= 140)"
fi

grep -q -- "--config-check" "$DOC" \
  || fail "$DOC missing --config-check arg-parse"
grep -q -- "--no-anomaly" "$DOC" \
  || fail "$DOC missing --no-anomaly arg-parse"
grep -q 'run_check "Anomaly Detection"' "$DOC" \
  || fail "$DOC missing run_check \"Anomaly Detection\" invocation"
grep -q 'run_check "Config Drift"' "$DOC" \
  || fail "$DOC missing run_check \"Config Drift\" invocation"
grep -q "check-anomalies.sh" "$DOC" \
  || fail "$DOC missing check-anomalies.sh reference"
grep -q "check-config-drift.sh" "$DOC" \
  || fail "$DOC missing check-config-drift.sh reference"

# Both new run_check invocations must carry the trailing "1" advisory marker.
grep -E 'run_check "Anomaly Detection".*"1"' "$DOC" >/dev/null \
  || fail "Anomaly Detection run_check missing trailing \"1\" advisory marker"
grep -E 'run_check "Config Drift".*"1"' "$DOC" >/dev/null \
  || fail "Config Drift run_check missing trailing \"1\" advisory marker"

# Behavioral: --no-anomaly invocation prints the standard banner.
banner="$(bash "$DOC" --no-anomaly 2>&1 | head -1)"
case "$banner" in
  "=== Orchestrator Diagnostics ==="*) : ;;
  *) fail "--no-anomaly first line mismatch: '$banner'" ;;
esac

echo "PASS: $NAME"
exit 0
