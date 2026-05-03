#!/usr/bin/env bash
# tools/verify/m036-p01-xlsx-adapter.sh -- M036 P01 xlsx adapter behavioral
# verifier. Asserts that scripts/dispatch/adapters/format/xlsx.sh exits 0 on
# the M036 xlsx fixture and emits one CSV per sheet that is byte-identical
# to the expected fixtures under
# tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet*.csv.
#
# Skip semantic: when openpyxl cannot be imported the verifier emits
# "SKIP: openpyxl-absent" and exits 0 informationally. Mirrors the host-
# tooling-aware shape established by m036-p01-pdf-adapter.sh -- a CI host
# without openpyxl must not false-FAIL the suite. The operator should run
# scripts/lifecycle/probe-extraction-tools.sh for install hints.
#
# Single-script-file shape per AD-19 / AP-009. The verifier issues a
# sequence of independent statements (mktemp -d, run adapter, diff -q per
# file) -- no compound piped chain.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
ADAPTER="$ROOT/scripts/dispatch/adapters/format/xlsx.sh"
FIXTURE="$ROOT/tests/fixtures/m036-tier-1-adapters/sample.xlsx"
EXPECTED1="$ROOT/tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet1.csv"
EXPECTED2="$ROOT/tests/fixtures/m036-tier-1-adapters/expected/sample-xlsx-sheet2.csv"
pass=0
fail=0

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3-absent (install via probe hints: scripts/lifecycle/probe-extraction-tools.sh)"
  echo "SUMMARY: m036-p01-xlsx-adapter pass=0 fail=0 skipped=1"
  exit 0
fi
if ! python3 -c "import openpyxl" >/dev/null 2>&1; then
  echo "SKIP: openpyxl-absent (install via probe hints: scripts/lifecycle/probe-extraction-tools.sh)"
  echo "SUMMARY: m036-p01-xlsx-adapter pass=0 fail=0 skipped=1"
  exit 0
fi

if [ ! -f "$ADAPTER" ]; then
  echo "FAIL: adapter-missing ($ADAPTER)"
  echo "SUMMARY: m036-p01-xlsx-adapter pass=0 fail=1"
  exit 1
fi
if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: fixture-missing ($FIXTURE)"
  echo "SUMMARY: m036-p01-xlsx-adapter pass=0 fail=1"
  exit 1
fi
if [ ! -f "$EXPECTED1" ]; then
  echo "FAIL: expected-sheet1-missing ($EXPECTED1)"
  echo "SUMMARY: m036-p01-xlsx-adapter pass=0 fail=1"
  exit 1
fi
if [ ! -f "$EXPECTED2" ]; then
  echo "FAIL: expected-sheet2-missing ($EXPECTED2)"
  echo "SUMMARY: m036-p01-xlsx-adapter pass=0 fail=1"
  exit 1
fi

OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/m036-p01-xlsx-out.XXXXXX")"

set +e
bash "$ADAPTER" "$FIXTURE" --out-dir "$OUTDIR" >/dev/null 2>&1
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "PASS: exit-0"
  pass=$((pass + 1))
else
  echo "FAIL: exit-0 (rc=$rc)"
  fail=$((fail + 1))
fi

if [ -f "$OUTDIR/Sheet1.csv" ]; then
  echo "PASS: Sheet1.csv-exists"
  pass=$((pass + 1))
  set +e
  diff -q "$OUTDIR/Sheet1.csv" "$EXPECTED1" >/dev/null 2>&1
  drc=$?
  set -e
  if [ "$drc" -eq 0 ]; then
    echo "PASS: Sheet1.csv-byte-identical"
    pass=$((pass + 1))
  else
    echo "FAIL: Sheet1.csv-byte-identical (diff against $EXPECTED1)"
    fail=$((fail + 1))
  fi
else
  echo "FAIL: Sheet1.csv-exists ($OUTDIR/Sheet1.csv not found)"
  fail=$((fail + 1))
fi

if [ -f "$OUTDIR/Sheet2.csv" ]; then
  echo "PASS: Sheet2.csv-exists"
  pass=$((pass + 1))
  set +e
  diff -q "$OUTDIR/Sheet2.csv" "$EXPECTED2" >/dev/null 2>&1
  drc=$?
  set -e
  if [ "$drc" -eq 0 ]; then
    echo "PASS: Sheet2.csv-byte-identical"
    pass=$((pass + 1))
  else
    echo "FAIL: Sheet2.csv-byte-identical (diff against $EXPECTED2)"
    fail=$((fail + 1))
  fi
else
  echo "FAIL: Sheet2.csv-exists ($OUTDIR/Sheet2.csv not found)"
  fail=$((fail + 1))
fi

rm -rf "$OUTDIR"

echo "SUMMARY: m036-p01-xlsx-adapter pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
