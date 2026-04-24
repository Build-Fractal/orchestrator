#!/usr/bin/env bash
# scripts/verify/m026-p02-phase-suite.sh -- M026/P02/T05 orchestrator.
# Invokes all P02 gates + cross-milestone DC-2 invariants in dependency
# order, tallies pass/fail, prints the SUMMARY line and exits 0 only
# when every gate passes.
#
# Order:
#   1. edition-detection-contract     (T01, FR-1/FR-3)
#   2. adapter-invariants             (T01, CON-1..CON-3)
#   3. jsonl-edition-field            (T02, FR-4)
#   4. dual-edition-test-shape        (T03, FR-8 / SC-4 / SC-6)
#   5. gate-verdict-reliability       (T04, F1/F2/F3, OQ-16)
#   6. recent-changes                 (T05, OQ-10 dual-write parity)
#   7. m011-p07-conversus-adapter-shape.sh   (DC-2 cross-milestone)
#   8. m011-p07-gate-pass-block.sh           (DC-2 cross-milestone)
#   9. m011-p07-bash32-compat.sh             (DC-2 cross-milestone)
#
# Note: M026/P01 phase-suite does NOT invoke tests/test-conversus-adapter-shim.sh,
# so T05 omits it too for parity.
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0

GATES="
m026-p02-edition-detection-contract.sh
m026-p02-adapter-invariants.sh
m026-p02-jsonl-edition-field.sh
m026-p02-dual-edition-test-shape.sh
m026-p02-gate-verdict-reliability.sh
m026-p02-recent-changes.sh
m011-p07-conversus-adapter-shape.sh
m011-p07-gate-pass-block.sh
m011-p07-bash32-compat.sh
"

IFS='
'
for g in $GATES; do
  IFS=' '
  [ -n "$g" ] || continue
  gpath="${SCRIPT_DIR}/${g}"
  if [ ! -f "$gpath" ]; then
    echo "FAIL: ${g} missing"
    failed=$((failed + 1))
    IFS='
'
    continue
  fi
  echo "---- ${g} ----"
  if bash "$gpath"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
  fi
  IFS='
'
done
IFS=' '

echo ""
echo "SUMMARY: m026-p02-phase-suite.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p02-phase-suite.sh"
  exit 0
fi
echo "FAIL: m026-p02-phase-suite.sh" >&2
exit 1
