#!/usr/bin/env bash
# scripts/verify/m026-p03-phase-suite.sh -- M026/P03/T05 orchestrator.
# Invokes all P03 gates + cross-milestone DC-2 invariants in dependency
# order, tallies pass/fail, prints the SUMMARY line and exits 0 only
# when every gate passes.
#
# Order:
#   1. m026-p03-edition-required-diagnostic.sh   (T01)
#   2. m026-p03-doc-surface-coverage.sh          (T02)
#   3. m026-p03-mem-graduation.sh                (T03)
#   4. m026-p03-decision-row.sh                  (T04)
#   5. m026-p03-recent-changes.sh                (T05, OQ-10 dual-write parity)
#   6. m011-p07-conversus-adapter-shape.sh       (DC-2 cross-milestone)
#   7. m011-p07-gate-pass-block.sh               (DC-2 cross-milestone)
#   8. m011-p07-bash32-compat.sh                 (DC-2 cross-milestone)
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Mirrors P02 suite.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0

GATES="
m026-p03-edition-required-diagnostic.sh
m026-p03-doc-surface-coverage.sh
m026-p03-mem-graduation.sh
m026-p03-decision-row.sh
m026-p03-recent-changes.sh
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
echo "SUMMARY: m026-p03-phase-suite.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p03-phase-suite.sh"
  exit 0
fi
echo "FAIL: m026-p03-phase-suite.sh" >&2
exit 1
