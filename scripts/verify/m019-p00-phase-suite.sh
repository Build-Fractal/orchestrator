#!/usr/bin/env bash
# scripts/verify/m019-p00-phase-suite.sh — P00 phase integration gate.
#
# Orchestrates the four P00 verify gates:
#   1. m019-p00-payload-shape.sh      — L1..L5 + pricing.yml presence
#   2. m019-p00-evaluate-preflight-additivity.sh — AD-7 byte-identical preservation
#   3. m019-p00-no-regression.sh      — SC-13 regression guard
#   4. m019-p00-bash32-compat.sh      — Constitution VIII compliance
#
# Reports PASS: 4 / FAIL: 0 on green. Exit 0 on all-pass, 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GATES="
scripts/verify/m019-p00-payload-shape.sh
scripts/verify/m019-p00-evaluate-preflight-additivity.sh
scripts/verify/m019-p00-no-regression.sh
scripts/verify/m019-p00-bash32-compat.sh
"

pass_count=0
fail_count=0
for rel in $GATES; do
  f="$REPO_ROOT/$rel"
  if [ ! -x "$f" ]; then
    echo "FAIL: $rel (not executable)"
    fail_count=$((fail_count + 1))
    continue
  fi
  if bash "$f" >/dev/null 2>&1; then
    echo "PASS: $rel"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $rel"
    fail_count=$((fail_count + 1))
  fi
done

total=$((pass_count + fail_count))
echo "PASS: $pass_count / FAIL: $fail_count (of $total P00 gates)"
if [ "$fail_count" -eq 0 ] && [ "$pass_count" -eq 4 ]; then
  echo "PASS: m019-p00-phase-suite.sh"
  exit 0
else
  echo "FAIL: m019-p00-phase-suite.sh"
  exit 1
fi
