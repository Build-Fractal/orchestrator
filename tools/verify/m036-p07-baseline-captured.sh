#!/usr/bin/env bash
# tools/verify/m036-p07-baseline-captured.sh — M036 P07 T03 sanity
# verifier asserting the SC-7 golden baseline file exists and is
# non-empty. AD-19. Load-bearing CON-1/SC-7 sequencing guard.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
F="$ROOT/tests/fixtures/m036-p07-baseline/payload-no-scope.expected.txt"
pass=0
fail=0
if [ ! -f "$F" ]; then
  echo "FAIL: baseline-file-missing ($F)"
  fail=$((fail + 1))
elif [ ! -s "$F" ]; then
  echo "FAIL: baseline-file-empty"
  fail=$((fail + 1))
else
  echo "PASS: baseline-exists-and-non-empty"
  pass=$((pass + 1))
  # Sanity: baseline should contain the canonical Manifest header
  # emitted by build-context.sh's manifest builder.
  if grep -qF -e "Manifest" "$F"; then
    echo "PASS: baseline-contains-Manifest-header"
    pass=$((pass + 1))
  else
    echo "FAIL: baseline-missing-Manifest-header"
    fail=$((fail + 1))
  fi
fi
echo "SUMMARY: m036-p07-baseline-captured.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
