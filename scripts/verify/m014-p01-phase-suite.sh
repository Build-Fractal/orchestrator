#!/usr/bin/env bash
# scripts/verify/m014-p01-phase-suite.sh — orchestrate all M014/P01 gates.
# Runs every gate; exits 0 on green, non-zero on any failure with a
# per-gate breakdown on stderr.
# Bash 3.2 compatible.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

GATES="
template-ssot
spec-shape-lint
dual-write-helper
dual-write-outside-invariant
complexity-probe-stub
specify-command
specify-sh
specify-shape-test
config-keys
agents-md-shape
runtime-assumptions
spec-management-reference
bash32-compat
zero-prompts
"

PASS=0
FAIL=0
FAIL_NAMES=""

for g in $GATES; do
  script="${PROJECT_ROOT}/scripts/verify/m014-p01-${g}.sh"
  if [ ! -x "$script" ]; then
    echo "FAIL: m014-p01-${g}.sh missing or not executable" >&2
    FAIL=$((FAIL + 1))
    FAIL_NAMES="${FAIL_NAMES}${g} "
    continue
  fi
  if bash "$script" >/dev/null 2>&1; then
    echo "  [ok] m014-p01-${g}"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] m014-p01-${g}" >&2
    FAIL=$((FAIL + 1))
    FAIL_NAMES="${FAIL_NAMES}${g} "
  fi
done

echo ""
echo "Summary: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed gates: ${FAIL_NAMES}" >&2
  exit 1
fi

echo "PASS: m014-p01-phase-suite"
exit 0
