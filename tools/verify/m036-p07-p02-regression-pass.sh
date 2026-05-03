#!/usr/bin/env bash
# tools/verify/m036-p07-p02-regression-pass.sh — M036 P07 T03 cross-
# phase regression. Re-runs 14 of the 15 P02 sub-gates excluding
# m036-p02-tier-2-deferred-error.sh whose semantics intentionally
# flipped at P03 close. Selective-gate-list pattern carried verbatim
# from M036/P03/T03 + M036/P04/T04. AD-19.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
VDIR="$ROOT/tools/verify"
pass=0
fail=0
run() {
  local g="$1"
  if [ ! -f "$VDIR/$g" ]; then
    echo "FAIL: $g missing"
    fail=$((fail + 1))
    return
  fi
  if ORCHESTRATOR_ROOT="$ROOT" bash "$VDIR/$g" >/dev/null 2>&1; then
    echo "PASS: $g"
    pass=$((pass + 1))
  else
    echo "FAIL: $g"
    fail=$((fail + 1))
  fi
}
# 14 of 15 P02 sub-gates (excluding m036-p02-tier-2-deferred-error.sh).
run m036-p02-manifest-contract-shape.sh
run m036-p02-fixture-manifest-shape.sh
run m036-p02-fixture-corpus-shape.sh
run m036-p02-extract-driver-shape.sh
run m036-p02-binary-preservation.sh
run m036-p02-content-hash.sh
run m036-p02-size-cap-external-pointer.sh
run m036-p02-extract-md.sh
run m036-p02-extract-pdf-host-aware.sh
run m036-p02-extract-docx-host-aware.sh
run m036-p02-extract-command-shape.sh
run m036-p02-summary-mode-stub-vs-operator.sh
run m036-p02-idempotency.sh
run m036-p02-test-harness.sh
echo "SUMMARY: m036-p07-p02-regression-pass.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
