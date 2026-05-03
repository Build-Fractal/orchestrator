#!/usr/bin/env bash
# tools/verify/m036-p03-p02-regression-pass.sh -- M036 P03 T03.
# Asserts the P02 phase-suite minus the now-stale tier-2-deferred-error
# verifier still passes after P03 driver edits (operator|stub modes
# unchanged + tier!=2+auto deferral still errors).
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
  if bash "$ROOT/tools/verify/$g" >/dev/null 2>&1; then
    echo "PASS: $g"
  else
    echo "FAIL: $g (P03 driver edits regressed P02 behavior)"
    fail=$((fail + 1))
  fi
done
IFS="$old_ifs"
echo "SUMMARY: m036-p03-p02-regression-pass.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
