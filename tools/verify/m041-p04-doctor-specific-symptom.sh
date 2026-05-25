#!/usr/bin/env bash
# tools/verify/m041-p04-doctor-specific-symptom.sh
# Verifies run-doctor.sh's detective hook names the specific failing checks
# rather than a generic count (addresses review finding B5).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

target="scripts/diagnostics/run-doctor.sh"
if [ ! -f "$target" ]; then
  echo "FAIL: $target not found"
  exit 1
fi

# The accumulator that records failing check names must exist
if ! grep -q "failed_check_names" "$target"; then
  echo "FAIL: run-doctor.sh has no failed_check_names accumulator"
  exit 1
fi

# The hook symptom must interpolate the failing-check names, not a bare count
if ! grep -q 'doctor checks failed: ${failed_check_names}' "$target"; then
  echo "FAIL: run-doctor.sh hook does not emit specific failing-check names"
  exit 1
fi

# The old generic-count symptom must be gone
if grep -q "doctor found .* failing checks — run detective" "$target"; then
  echo "FAIL: run-doctor.sh still emits the generic-count symptom"
  exit 1
fi

echo "PASS: run-doctor.sh hook names the specific failing checks"
