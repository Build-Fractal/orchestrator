#!/usr/bin/env bash
# tools/verify/m036-p01-fixture-corpus-shape.sh -- M036 P01 fixture-corpus
# shape verifier. Asserts the four sample fixture files and the four
# expected-output files exist under tests/fixtures/m036-tier-1-adapters/.
# Single-script-file shape per AD-19 / AP-009.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
FIX="$ROOT/tests/fixtures/m036-tier-1-adapters"
pass=0
fail=0

check() {
  local rel="$1"
  if [ -f "$FIX/$rel" ]; then
    echo "PASS: $rel"
    pass=$((pass + 1))
  else
    echo "FAIL: $rel (missing)"
    fail=$((fail + 1))
  fi
}

check sample.md
check sample.pdf
check sample.docx
check sample.xlsx
check expected/sample-pdf.txt
check expected/sample-docx.txt
check expected/sample-xlsx-sheet1.csv
check expected/sample-xlsx-sheet2.csv

echo "SUMMARY: m036-p01-fixture-corpus-shape pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
