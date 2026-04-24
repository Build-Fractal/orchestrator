#!/usr/bin/env bash
# scripts/verify/m026-p01-summary-shape-when-present.sh -- M026/P01/T04
# advisory gate. P01-SUMMARY.md is authored later by orchestrator:verify
# at phase-close, not by T04. This gate passes trivially when that file
# is absent, and asserts shape when it is present.
#
# When P01-SUMMARY.md exists, the gate requires:
#   1. a line `Verdict: GO` OR `Verdict: NO-GO` (copied verbatim from the
#      spike note)
#   2. a reference to `M026-CONVERSUS-PARITY.md`
#
# Bash 3.2 safe (MEM001). AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

SUMMARY="${REPO_ROOT}/.orchestrator/milestones/M026/phases/P01/P01-SUMMARY.md"
passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }

if [ ! -f "$SUMMARY" ]; then
  pass "P01-SUMMARY.md absent — advisory skipped"
  echo "SUMMARY: m026-p01-summary-shape-when-present.sh pass=${passed} fail=${failed}"
  echo "PASS: m026-p01-summary-shape-when-present.sh"
  exit 0
fi

# File present — assert shape.
if grep -qE '^Verdict: (GO|NO-GO)$' "$SUMMARY"; then
  pass "P01-SUMMARY.md carries a Verdict: GO or Verdict: NO-GO line"
else
  fail "P01-SUMMARY.md missing 'Verdict: GO' or 'Verdict: NO-GO' line"
fi

if grep -q 'M026-CONVERSUS-PARITY.md' "$SUMMARY"; then
  pass "P01-SUMMARY.md references M026-CONVERSUS-PARITY.md"
else
  fail "P01-SUMMARY.md missing reference to M026-CONVERSUS-PARITY.md"
fi

echo "SUMMARY: m026-p01-summary-shape-when-present.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p01-summary-shape-when-present.sh"
  exit 0
fi
echo "FAIL: m026-p01-summary-shape-when-present.sh" >&2
exit 1
