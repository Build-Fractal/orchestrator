#!/usr/bin/env bash
set -eu
files="scripts/diagnostics/run-doctor.sh scripts/diagnostics/check-orphaned.sh scripts/diagnostics/check-stale.sh scripts/diagnostics/check-scope.sh scripts/diagnostics/check-cost-spikes.sh"
for f in $files; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
for f in $files; do
  grep -nE 'declare -A|readarray|mapfile' "$f" | grep -v '^[0-9]*:[[:space:]]*#' && { echo "FAIL: Bash 3.2 incompatible constructs found in $f"; exit 1; }
done
echo "PASS: all diagnostics scripts are Bash 3.2 compatible"
