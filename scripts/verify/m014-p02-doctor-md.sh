#!/usr/bin/env bash
# Gate: verify commands/doctor.md documents runtime_instruction_drift.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOCTOR_MD="${PROJECT_ROOT}/commands/doctor.md"

if [ ! -f "$DOCTOR_MD" ]; then echo "FAIL: commands/doctor.md missing" >&2; exit 1; fi

if ! grep -q 'Runtime Instruction Drift' "$DOCTOR_MD"; then
  echo "FAIL: Runtime Instruction Drift bullet missing" >&2
  exit 1
fi
if ! grep -qE 'FR-13|runtime_instruction_drift' "$DOCTOR_MD"; then
  echo "FAIL: FR-13 / runtime_instruction_drift not named" >&2
  exit 1
fi
if ! grep -q 'scripts/diagnostics/check-docs.sh' "$DOCTOR_MD"; then
  echo "FAIL: check-docs.sh not referenced" >&2
  exit 1
fi

echo "PASS: commands/doctor.md documents runtime_instruction_drift"
exit 0
