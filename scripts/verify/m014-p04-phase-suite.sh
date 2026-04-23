#!/usr/bin/env bash
# P04 phase verification suite — twelve gates.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

GATES="
scripts/verify/m014-p04-complexity-thresholds-pinned.sh
scripts/verify/m014-p04-complexity-probe-full.sh
scripts/verify/m014-p04-pressure-test-preset.sh
scripts/verify/m014-p04-specify-command-wiring.sh
scripts/verify/m014-p04-three-way-prompt.sh
scripts/verify/m014-p04-split-subcommand.sh
scripts/verify/m014-p04-amend-three-case.sh
scripts/verify/m014-p04-runtime-assumptions-fr5-fr7.sh
scripts/verify/m014-p04-spec-management-reference-complete.sh
scripts/verify/m014-p04-bash32-and-lint.sh
scripts/verify/m014-p04-zero-prompts.sh
scripts/verify/m014-p04-observability-records.sh
"

total=0
passed=0
failed=0
FAILED_GATES=""

for g in $GATES; do
  total=$((total+1))
  GPATH="${PROJECT_ROOT}/${g}"
  if [ ! -x "$GPATH" ]; then
    failed=$((failed+1))
    echo "FAIL: ${g} (missing or not executable)"
    FAILED_GATES="${FAILED_GATES}
  - $g (missing or not executable)"
    continue
  fi
  bash "$GPATH" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    passed=$((passed+1))
    echo "PASS: ${g}"
  else
    failed=$((failed+1))
    echo "FAIL: ${g} (rc=${rc})"
    FAILED_GATES="${FAILED_GATES}
  - $g (rc=${rc})"
  fi
done

echo "PHASE-SUITE: M014/P04 total=${total} passed=${passed} failed=${failed}"
if [ "$failed" -eq 0 ]; then
  echo "PASS: M014/P04 phase suite — ${passed}/${total} gates green"
  exit 0
else
  echo "FAIL: M014/P04 phase suite — ${failed} gate(s) failed:${FAILED_GATES}" >&2
  exit 1
fi
