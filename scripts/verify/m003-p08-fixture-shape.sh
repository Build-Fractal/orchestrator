#!/usr/bin/env bash
# scripts/verify/m003-p08-fixture-shape.sh
# Truth: synthetic GSD2 fixture has the minimum data surface for every P01-P06
# transform to emit non-zero output.
#
# Checks:
#   - tests/fixtures/m003-p08-gsd-minimal/.gsd/gsd.db exists and is non-empty.
#   - memories-snapshot.json exists and is non-empty.
#   - At least one milestones/M* directory is present.
#
# AD-19: single-script-file invocation; no inline compound bash at call sites.
# MEM001: bash 3.2 safe.
# Exit 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
F="$REPO_ROOT/tests/fixtures/m003-p08-gsd-minimal/.gsd"

if [ ! -d "$F" ]; then
  echo "FAIL: fixture directory missing at $F"
  exit 1
fi

if [ ! -s "$F/gsd.db" ]; then
  echo "FAIL: $F/gsd.db missing or empty"
  exit 1
fi

if [ ! -s "$F/memories-snapshot.json" ]; then
  echo "FAIL: $F/memories-snapshot.json missing or empty"
  exit 1
fi

count=0
for d in "$F"/milestones/M*; do
  [ -d "$d" ] || continue
  count=$((count + 1))
done

if [ "$count" -lt 1 ]; then
  echo "FAIL: no milestone directories under $F/milestones"
  exit 1
fi

echo "PASS: fixture shape valid ($count milestone dir(s))"
exit 0
