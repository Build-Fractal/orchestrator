#!/usr/bin/env bash
# scripts/verify/m027-p03-suppression-matrix.sh -- M027/P03 Truth #5.
#
# Exercises the 5-condition suppression matrix on
# scripts/diagnostics/check-anomalies.sh:
#
#   1. --no-anomaly                                  -> empty stdout, exit 0
#   2. --yes                                         -> empty stdout, exit 0
#   3. ORCHESTRATOR_AUTO=1                           -> empty stdout, exit 0
#   4. ORCH_ANOMALY_CHECK_ENABLED=false              -> empty stdout, exit 0
#   5. sample-floor structural carve-out             -> "insufficient sample"
#      (default mode; under any of the 4 flags above the surface stays empty)
#
# Plus an over-ride sanity check: M021 below-floor + --no-anomaly
# produces empty stdout (the 4 actively-suppressing conditions override
# the structural carve-out).
#
# Bash 3.2 compatible. MEM004 carve-out -- env / pipes used internally.

set -u

NAME="m027-p03-suppression-matrix.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

HELPER="scripts/diagnostics/check-anomalies.sh"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -x "$HELPER" ]; then
  fail "$HELPER not executable"
fi

assert_suppressed() {
  label="$1"
  out="$2"
  rc="$3"
  if [ "$rc" -ne 0 ]; then
    fail "$label produced non-zero exit ($rc)"
  fi
  if [ -n "$out" ]; then
    fail "$label produced non-empty stdout: $(printf '%s' "$out" | head -c 80)"
  fi
}

# Path 1: --no-anomaly
out1="$(bash "$HELPER" --no-anomaly --milestone M013 2>/dev/null)"
rc1=$?
assert_suppressed "--no-anomaly" "$out1" "$rc1"

# Path 2: --yes
out2="$(bash "$HELPER" --yes --milestone M013 2>/dev/null)"
rc2=$?
assert_suppressed "--yes" "$out2" "$rc2"

# Path 3: ORCHESTRATOR_AUTO=1
out3="$(env ORCHESTRATOR_AUTO=1 bash "$HELPER" --milestone M013 2>/dev/null)"
rc3=$?
assert_suppressed "ORCHESTRATOR_AUTO=1" "$out3" "$rc3"

# Path 4: ORCH_ANOMALY_CHECK_ENABLED=false
out4="$(env ORCH_ANOMALY_CHECK_ENABLED=false bash "$HELPER" --milestone M013 2>/dev/null)"
rc4=$?
assert_suppressed "ORCH_ANOMALY_CHECK_ENABLED=false" "$out4" "$rc4"

# Path 5: sample-floor structural carve-out (default mode emits the line).
out5="$(bash "$HELPER" --milestone M021 --sample-floor 5 2>/dev/null)"
rc5=$?
if [ "$rc5" -ne 0 ]; then
  fail "structural-carve-out exited non-zero ($rc5)"
fi
if ! printf '%s' "$out5" | grep -q "insufficient sample"; then
  fail "structural-carve-out missing 'insufficient sample' literal"
fi

# Override sanity: --no-anomaly overrides the structural carve-out.
out6="$(bash "$HELPER" --milestone M021 --sample-floor 5 --no-anomaly 2>/dev/null)"
rc6=$?
assert_suppressed "--no-anomaly+below-floor (structural override)" "$out6" "$rc6"

echo "PASS: $NAME 5/5 suppression paths green (+1 override sanity)"
exit 0
