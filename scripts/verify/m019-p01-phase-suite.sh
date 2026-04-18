#!/usr/bin/env bash
# scripts/verify/m019-p01-phase-suite.sh — P01 phase integration gate.
#
# Orchestrates the eight P01 verify gates:
#   1. m019-p01-emitter-presence.sh         — exercises m019-schema.sh end-to-end
#   2. m019-p01-pricing-degradation.sh      — stale pricing null-cost behavior
#   3. m019-p01-source-enum.sh              — closed source enum
#   4. m019-p01-zero-token-growth.sh        — SC-6 / C1 payload byte-parity
#   5. m019-p01-fixture-rollup.sh           — SC-7 greppability demo
#   6. m019-p01-additive-compat.sh          — SC-10 pre-M019 additivity
#   7. m019-p01-no-pre-p00-emission.sh      — SC-12 ordering guard
#   8. m019-p01-bash32-compat.sh            — Constitution VIII compliance
#
# Reports PASS: N / FAIL: M (of 8 P01 gates). Exit 0 on all-pass, 1 otherwise.
# Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GATES="
scripts/verify/m019-p01-emitter-presence.sh
scripts/verify/m019-p01-pricing-degradation.sh
scripts/verify/m019-p01-source-enum.sh
scripts/verify/m019-p01-zero-token-growth.sh
scripts/verify/m019-p01-fixture-rollup.sh
scripts/verify/m019-p01-additive-compat.sh
scripts/verify/m019-p01-no-pre-p00-emission.sh
scripts/verify/m019-p01-bash32-compat.sh
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
echo "PASS: $pass_count / FAIL: $fail_count (of $total P01 gates)"
if [ "$fail_count" -eq 0 ] && [ "$pass_count" -eq 8 ]; then
  echo "PASS: m019-p01-phase-suite.sh"
  exit 0
else
  echo "FAIL: m019-p01-phase-suite.sh"
  exit 1
fi
