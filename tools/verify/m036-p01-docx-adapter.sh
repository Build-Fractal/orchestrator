#!/usr/bin/env bash
# tools/verify/m036-p01-docx-adapter.sh -- M036 P01 docx adapter behavioral
# verifier. Asserts that scripts/dispatch/adapters/format/docx.sh exits 0 on
# the M036 docx fixture and that stdout contains every token listed in
# tests/fixtures/m036-tier-1-adapters/expected/sample-docx.txt.
#
# Skip semantic: when pandoc is absent on PATH the verifier emits
# "SKIP: pandoc-absent" and exits 0 informationally. Mirrors the host-
# tooling-aware shape established by m036-p01-pdf-adapter.sh -- a CI host
# without pandoc must not false-FAIL the suite. The operator should run
# scripts/lifecycle/probe-extraction-tools.sh for install hints.
#
# Single-script-file shape per AD-19 / AP-009.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
ADAPTER="$ROOT/scripts/dispatch/adapters/format/docx.sh"
FIXTURE="$ROOT/tests/fixtures/m036-tier-1-adapters/sample.docx"
ALLOWLIST="$ROOT/tests/fixtures/m036-tier-1-adapters/expected/sample-docx.txt"
TMP="${TMPDIR:-/tmp}/m036-p01-docx-adapter.$$.out"
pass=0
fail=0

if ! command -v pandoc >/dev/null 2>&1; then
  echo "SKIP: pandoc-absent (install via probe hints: scripts/lifecycle/probe-extraction-tools.sh)"
  echo "SUMMARY: m036-p01-docx-adapter pass=0 fail=0 skipped=1"
  exit 0
fi

if [ ! -f "$ADAPTER" ]; then
  echo "FAIL: adapter-missing ($ADAPTER)"
  echo "SUMMARY: m036-p01-docx-adapter pass=0 fail=1"
  exit 1
fi
if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: fixture-missing ($FIXTURE)"
  echo "SUMMARY: m036-p01-docx-adapter pass=0 fail=1"
  exit 1
fi
if [ ! -f "$ALLOWLIST" ]; then
  echo "FAIL: allowlist-missing ($ALLOWLIST)"
  echo "SUMMARY: m036-p01-docx-adapter pass=0 fail=1"
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

echo "SUMMARY: m036-p01-docx-adapter pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
