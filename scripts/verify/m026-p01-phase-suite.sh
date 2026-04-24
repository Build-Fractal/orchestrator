#!/usr/bin/env bash
# scripts/verify/m026-p01-phase-suite.sh -- M026/P01/T04 orchestrator.
# Invokes all 9 P01 gates in dependency order, tallies pass/fail, prints
# the SUMMARY line and exits 0 only when every gate passes.
#
# m026-p01-summary-shape-when-present.sh is invoked by orchestrator:verify
# at phase-close (not by the T04 suite run — it's advisory because
# P01-SUMMARY.md is authored by orchestrator:verify, not by T04).
#
# Order:
#   1. parity-matrix-shape       (T01)
#   2. parity-matrix-coverage    (T01)
#   3. spike-note-shape          (T02)
#   4. spike-gate-file           (T02)
#   5. ollama-probe              (T03)
#   6. pipx-venv-inventory       (T03 + T04 cross-artifact extension)
#   7. upstream-readonly         (T01)
#   8. bash32-compat             (T04)
#   9. recent-changes            (T04)
#
# Bash 3.2 compatible. AD-19 single-script-file shape.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

passed=0
failed=0

GATES="
m026-p01-parity-matrix-shape.sh
m026-p01-parity-matrix-coverage.sh
m026-p01-spike-note-shape.sh
m026-p01-spike-gate-file.sh
m026-p01-ollama-probe.sh
m026-p01-pipx-venv-inventory.sh
m026-p01-upstream-readonly.sh
m026-p01-bash32-compat.sh
m026-p01-recent-changes.sh
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
echo "SUMMARY: m026-p01-phase-suite.sh pass=${passed} fail=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: m026-p01-phase-suite.sh"
  exit 0
fi
echo "FAIL: m026-p01-phase-suite.sh" >&2
exit 1
