#!/usr/bin/env bash
# scripts/verify/m024-p01-suite.sh — run both phase-level tests.

set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

ok=1
if ! bash "$ROOT/tests/test-intake-proposal-shape.sh"; then
  ok=0
fi
if ! bash "$ROOT/tests/test-intake-manifest-superset.sh"; then
  ok=0
fi

if [ "$ok" -eq 0 ]; then
  echo "FAIL: M024/P01 phase suite reported a failure (see above)"
  exit 1
fi

echo "PASS: M024/P01 suite — proposal-shape + manifest-superset"
exit 0
