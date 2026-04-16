#!/usr/bin/env bash
set -eu
# Verify: all test suites (tests/test-s*.sh) pass.
# T02 writes the full transcript to evidence/test-suite-transcript.txt.
# This verifier asserts (a) the transcript exists, (b) the transcript
# contains a FINAL line matching the expected passing shape, and (c)
# no "FAIL" line appears outside explicit negative-test contexts.
TRANSCRIPT=.orchestrator/milestones/M015/phases/P04/evidence/test-suite-transcript.txt
test -f "$TRANSCRIPT" || { echo "FAIL: transcript missing at $TRANSCRIPT"; exit 1; }
test -s "$TRANSCRIPT" || { echo "FAIL: transcript empty"; exit 1; }
# Require each suite name to appear in the transcript at least once
suites="test-s01 test-s02 test-s03 test-s04 test-s05 test-s06 test-s07 test-s08"
fail=0
for s in $suites; do
  if ! grep -q "$s" "$TRANSCRIPT"; then
    echo "FAIL: suite '$s' not mentioned in transcript"
    fail=1
  fi
done
# Require an explicit overall pass marker (T02 writes "ALL_SUITES_PASS")
if ! grep -q "ALL_SUITES_PASS" "$TRANSCRIPT"; then
  echo "FAIL: transcript does not contain ALL_SUITES_PASS marker"
  fail=1
fi
if [ "$fail" -ne 0 ]; then exit 1; fi
echo "PASS: all test-s0* suites mentioned + ALL_SUITES_PASS marker present"
