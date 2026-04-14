#!/usr/bin/env bash
# Verify references/architecture.md contains ASCII engine pipeline diagram with 7 stages.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "## Engine Pipeline" "$f" || { echo "FAIL: missing Engine Pipeline section"; exit 1; }
grep -q "Init" "$f" || { echo "FAIL: missing Init stage"; exit 1; }
grep -q "Build" "$f" || { echo "FAIL: missing Build stage"; exit 1; }
grep -q "Compress" "$f" || { echo "FAIL: missing Compress stage"; exit 1; }
grep -q "Dispatch" "$f" || { echo "FAIL: missing Dispatch stage"; exit 1; }
grep -q "Verify" "$f" || { echo "FAIL: missing Verify stage"; exit 1; }
grep -q "Record" "$f" || { echo "FAIL: missing Record stage"; exit 1; }
echo "PASS: architecture.md engine pipeline diagram"
