#!/usr/bin/env bash
# tools/verify/m036-p04-p02-regression-pass.sh -- M036 P04 T04.
# Regression guard: re-runs the P02 sub-gates and asserts they still
# pass after P04's rebuild-index.sh edits. Confirms P04 edits to
# rebuild-index.sh do not perturb the M036/P02 extract-reference.sh path.
#
# Selective-gate-list pattern carried verbatim from M036/P03/T03's
# m036-p03-p02-regression-pass.sh: explicitly enumerates 14 of the 15
# P02 sub-gates. The one excluded -- m036-p02-tier-2-deferred-error.sh --
# is the only P02 verifier whose semantics intentionally flipped at P03
# close (P03 implemented the Tier 2 path that P02 deferred). Selecting
# the gate list explicitly is superior to running the whole P02 phase-
# suite + filtering output because it is declarative which gate is
# excluded and why.
#
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
fail=0
GATES="m036-p02-manifest-contract-shape.sh
m036-p02-fixture-manifest-shape.sh
m036-p02-fixture-corpus-shape.sh
m036-p02-extract-driver-shape.sh
m036-p02-binary-preservation.sh
m036-p02-content-hash.sh
m036-p02-size-cap-external-pointer.sh
m036-p02-extract-md.sh
m036-p02-extract-pdf-host-aware.sh
m036-p02-extract-docx-host-aware.sh
m036-p02-extract-command-shape.sh
m036-p02-summary-mode-stub-vs-operator.sh
m036-p02-idempotency.sh
m036-p02-test-harness.sh"
old_ifs="$IFS"
IFS='
'
for g in $GATES; do
  if [ ! -f "$ROOT/tools/verify/$g" ]; then
    echo "FAIL: $g missing"
    fail=$((fail + 1))
    continue
  fi
  if ORCHESTRATOR_ROOT="$ROOT" bash "$ROOT/tools/verify/$g" >/dev/null 2>&1; then
    echo "PASS: $g"
  else
    echo "FAIL: $g (P04 edits regressed P02 behavior)"
    fail=$((fail + 1))
  fi
done
IFS="$old_ifs"
echo "SUMMARY: m036-p04-p02-regression-pass.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
