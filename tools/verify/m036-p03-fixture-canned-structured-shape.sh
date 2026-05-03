#!/usr/bin/env bash
# tools/verify/m036-p03-fixture-canned-structured-shape.sh -- M036 P03 T03.
# Asserts the two canned-structured fixtures exist (T04 authors them).
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
FX="$ROOT/tests/fixtures/m036-p03-tier-2"
fail=0
for f in canned-structured.md canned-structured-low-fidelity.md; do
  if [ -f "$FX/$f" ]; then
    echo "PASS: exists $FX/$f"
  else
    echo "FAIL: missing $FX/$f"
    fail=$((fail + 1))
  fi
done
echo "SUMMARY: m036-p03-fixture-canned-structured-shape.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
