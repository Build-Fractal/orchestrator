#!/usr/bin/env bash
# tools/verify/m036-p04-acceptance-harness-passes.sh -- M036 P04 T04.
# Strict pass-rate gate: asserts tests/test-reference-ingest-fixture.sh
# exits 0 specifically (complement to permissive shape verifier above).
# Pattern from M036/P03/T04.
# Single-script-file shape per AD-19. Bash 3.2 per CON-2.
set -eu
ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
HARNESS="$ROOT/tests/test-reference-ingest-fixture.sh"
fail=0
if [ ! -f "$HARNESS" ]; then
  echo "FAIL: harness missing $HARNESS"
  echo "SUMMARY: m036-p04-acceptance-harness-passes.sh fail=1"
  exit 1
fi
ORCHESTRATOR_ROOT="$ROOT" bash "$HARNESS" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "PASS: harness exit 0 (strict)"
else
  echo "FAIL: harness exit $rc (strict; expected 0)"
  fail=$((fail + 1))
fi
echo "SUMMARY: m036-p04-acceptance-harness-passes.sh fail=$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
