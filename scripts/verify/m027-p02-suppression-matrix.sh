#!/usr/bin/env bash
# scripts/verify/m027-p02-suppression-matrix.sh -- M027/P02 Truth #5.
#
# Exercises the 5-condition suppression matrix on the predictive-surface
# helper. Each path must produce empty stdout AND exit 0:
#
#   1. --yes                                       (operator suppress flag)
#   2. ORCHESTRATOR_AUTO=1                         (auto-loop env)
#   3. --no-predict                                (always-on-with-override)
#   4. ORCH_PREDICTIVE_COST_SURFACE=false          (config knob env)
#   5. --intensity quick                           (tier-based suppression)
#
# Bash 3.2 compatible. MEM004 carve-out -- env / pipes used internally.

set -u

NAME="m027-p02-suppression-matrix.sh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

HELPER="scripts/dispatch/predictive-surface.sh"

fail() {
  printf 'FAIL: %s %s\n' "$NAME" "$1" >&2
  exit 1
}

if [ ! -x "$HELPER" ]; then
  fail "$HELPER not executable"
fi

# Helper to assert: empty stdout and exit 0.
# $1 = label, remaining args are full env+invocation closures.
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

# Path 1: --yes
out1="$(bash "$HELPER" --description "test" --intensity standard --yes 2>/dev/null)"
rc1=$?
assert_suppressed "--yes" "$out1" "$rc1"

# Path 2: ORCHESTRATOR_AUTO=1
out2="$(env ORCHESTRATOR_AUTO=1 bash "$HELPER" --description "test" --intensity standard 2>/dev/null)"
rc2=$?
assert_suppressed "ORCHESTRATOR_AUTO=1" "$out2" "$rc2"

# Path 3: --no-predict
out3="$(bash "$HELPER" --description "test" --intensity standard --no-predict 2>/dev/null)"
rc3=$?
assert_suppressed "--no-predict" "$out3" "$rc3"

# Path 4: ORCH_PREDICTIVE_COST_SURFACE=false
out4="$(env ORCH_PREDICTIVE_COST_SURFACE=false bash "$HELPER" --description "test" --intensity standard 2>/dev/null)"
rc4=$?
assert_suppressed "ORCH_PREDICTIVE_COST_SURFACE=false" "$out4" "$rc4"

# Path 5: intensity=quick
out5="$(bash "$HELPER" --description "test" --intensity quick 2>/dev/null)"
rc5=$?
assert_suppressed "--intensity quick" "$out5" "$rc5"

echo "PASS: $NAME 5/5 suppression paths green"
exit 0
