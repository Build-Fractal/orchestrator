#!/usr/bin/env bash
# tools/verify/m036-p01-markdown-adapter.sh -- M036 P01 markdown adapter
# behavioral verifier. Asserts that scripts/dispatch/adapters/format/markdown.sh
# exits 0 on the M036 markdown fixture and emits byte-identical output (the
# Tier 1 contract for already-normalized content is verbatim passthrough).
# Single-script-file shape per AD-19 / AP-009.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
ADAPTER="$ROOT/scripts/dispatch/adapters/format/markdown.sh"
FIXTURE="$ROOT/tests/fixtures/m036-tier-1-adapters/sample.md"
TMP="${TMPDIR:-/tmp}/m036-p01-markdown-adapter.$$.out"
pass=0
fail=0

if [ ! -f "$ADAPTER" ]; then
  echo "FAIL: adapter-missing ($ADAPTER)"
  echo "SUMMARY: m036-p01-markdown-adapter pass=0 fail=1"
  exit 1
fi
if [ ! -f "$FIXTURE" ]; then
  echo "FAIL: fixture-missing ($FIXTURE)"
  echo "SUMMARY: m036-p01-markdown-adapter pass=0 fail=1"
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

if diff -q "$TMP" "$FIXTURE" >/dev/null 2>&1; then
  echo "PASS: byte-identical"
  pass=$((pass + 1))
else
  echo "FAIL: byte-identical (diff differed)"
  fail=$((fail + 1))
fi

rm -f "$TMP"

echo "SUMMARY: m036-p01-markdown-adapter pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
