#!/usr/bin/env bash
# Verify references/engine.md documents lifecycle stages and crash recovery.
set -eu
f="references/engine.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi "init" "$f" || { echo "FAIL: missing Init stage documentation"; exit 1; }
grep -qi "dispatch" "$f" || { echo "FAIL: missing Dispatch stage documentation"; exit 1; }
grep -qi "verify" "$f" || { echo "FAIL: missing Verify stage documentation"; exit 1; }
grep -qi "record" "$f" || { echo "FAIL: missing Record stage documentation"; exit 1; }
grep -qi "checkpoint" "$f" || { echo "FAIL: missing checkpoint documentation"; exit 1; }
grep -qi "crash.recovery\|crash recovery" "$f" || { echo "FAIL: missing crash recovery documentation"; exit 1; }
echo "PASS: engine.md lifecycle stages and crash recovery"
