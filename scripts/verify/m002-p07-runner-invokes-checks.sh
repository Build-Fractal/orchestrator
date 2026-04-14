#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/run-doctor.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'check-orphaned.sh' "$f" || { echo "FAIL: run-doctor.sh does not invoke check-orphaned.sh"; exit 1; }
grep -q 'check-stale.sh' "$f" || { echo "FAIL: run-doctor.sh does not invoke check-stale.sh"; exit 1; }
grep -q 'check-scope.sh' "$f" || { echo "FAIL: run-doctor.sh does not invoke check-scope.sh"; exit 1; }
grep -q 'check-cost-spikes.sh' "$f" || { echo "FAIL: run-doctor.sh does not invoke check-cost-spikes.sh"; exit 1; }
grep -q 'run_check' "$f" || { echo "FAIL: run-doctor.sh missing run_check function"; exit 1; }
echo "PASS: run-doctor.sh invokes all four core diagnostic check scripts"
