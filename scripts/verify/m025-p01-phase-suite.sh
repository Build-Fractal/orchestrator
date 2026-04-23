#!/usr/bin/env bash
# scripts/verify/m025-p01-phase-suite.sh -- M025/P01/T03 orchestrator.
# Invokes all 10 P01 gates in dependency order, tallies pass/fail, prints
# the SUMMARY line and exits 0 only when every gate passes.
#
# Order:
#   1. hook-schema           (T01)
#   2. merge-preservation    (T02)
#   3. coexistence           (T03)
#   4. idempotency           (T02)
#   5. uninstall-reversibility (T03)
#   6. runtime-scope-guard   (T03)
#   7. bash32-compat         (T03)
#   8. docs                  (T03 -- fails until T04)
#   9. knowledge-entries     (T03 -- fails until T04)
#  10. recent-changes        (T03 -- fails until T04)
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0

GATES="
m025-p01-hook-schema.sh
m025-p01-merge-preservation.sh
m025-p01-coexistence.sh
m025-p01-idempotency.sh
m025-p01-uninstall-reversibility.sh
m025-p01-runtime-scope-guard.sh
m025-p01-bash32-compat.sh
m025-p01-docs.sh
m025-p01-knowledge-entries.sh
m025-p01-recent-changes.sh
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
echo "SUMMARY: m025-p01-phase-suite.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m025-p01-phase-suite.sh"
  exit 0
fi
echo "FAIL: m025-p01-phase-suite.sh" >&2
exit 1
