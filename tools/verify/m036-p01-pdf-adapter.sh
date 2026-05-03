#!/usr/bin/env bash
# tools/verify/m036-p01-pdf-adapter.sh -- M036 P01 pdf adapter behavioral
# verifier. Asserts that scripts/dispatch/adapters/format/pdf.sh exits 0 on
# the M036 pdf fixture and that stdout contains every token listed in
# tests/fixtures/m036-tier-1-adapters/expected/sample-pdf.txt.
#
# Skip semantic: when pdftotext is absent on PATH the verifier emits
# "SKIP: pdftotext-absent" and exits 0 informationally. This is host-tooling-
# aware so a CI host without poppler-utils does not false-FAIL the suite;
# the operator should run scripts/lifecycle/probe-extraction-tools.sh for
# install hints. The dev host is expected to have pdftotext present.
#
# Single-script-file shape per AD-19 / AP-009.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
ADAPTER="$ROOT/scripts/dispatch/adapters/format/pdf.sh"
FIXTURE="$ROOT/tests/fixtures/m036-tier-1-adapters/sample.pdf"
ALLOWLIST="$ROOT/tests/fixtures/m036-tier-1-adapters/expected/sample-pdf.txt"
TMP="${TMPDIR:-/tmp}/m036-p01-pdf-adapter.$$.out"
pass=0
fail=0

if ! command -v pdftotext >/dev/null 2>&1; then
  echo "SKIP: pdftotext-absent (install via probe hints: scripts/lifecycle/probe-extraction-tools.sh)"
  echo "SUMMARY: m036-p01-pdf-adapter pass=0 fail=0 skipped=1"
  exit 0
fi

if [ ! -f "$ADAPTER" ]; then
  echo "FAIL: adapter-missing ($ADAPTER)"
  echo "SUMMARY: m036-p01-pdf-adapter pass=0 fail=1"
  exit 1
fi
if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: fixture-missing ($FIXTURE)"
  echo "SUMMARY: m036-p01-pdf-adapter pass=0 fail=1"
  exit 1
fi
if [ ! -f "$ALLOWLIST" ]; then
  echo "FAIL: allowlist-missing ($ALLOWLIST)"
  echo "SUMMARY: m036-p01-pdf-adapter pass=0 fail=1"
  exit 1
fi

set +e
bash "$ADAPTER" "$FIXTURE" >"$TMP" 2>/dev/null
rc=$?
set -e

if [ "$rc" -eq 0 ]; then
  echo "PASS: exit-0"
  pass=$((pass + 1))
else
  echo "FAIL: exit-0 (rc=$rc)"
  fail=$((fail + 1))
fi

if [ -s "$TMP" ]; then
  echo "PASS: non-empty-output"
  pass=$((pass + 1))
else
  echo "FAIL: non-empty-output (stdout was empty)"
  fail=$((fail + 1))
fi

while IFS= read -r token || [ -n "$token" ]; do
  case "$token" in
    ""|\#*) continue ;;
  esac
  if grep -q -F "$token" "$TMP"; then
    echo "PASS: token-$token"
    pass=$((pass + 1))
  else
    echo "FAIL: token-$token (not found in adapter stdout)"
    fail=$((fail + 1))
  fi
done <"$ALLOWLIST"

rm -f "$TMP"

echo "SUMMARY: m036-p01-pdf-adapter pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
