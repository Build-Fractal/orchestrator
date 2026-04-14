#!/usr/bin/env bash
# Verify references/architecture.md documents the data flow stages.
set -eu
f="references/architecture.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "## Data Flow" "$f" || { echo "FAIL: missing Data Flow section"; exit 1; }
grep -q "recipe" "$f" || { echo "FAIL: missing recipe reference in data flow"; exit 1; }
grep -q "build-context" "$f" || { echo "FAIL: missing build-context reference"; exit 1; }
grep -q "compress" "$f" || { echo "FAIL: missing compress reference"; exit 1; }
grep -q "dispatch" "$f" || { echo "FAIL: missing dispatch reference"; exit 1; }
grep -q "record-result" "$f" || { echo "FAIL: missing record-result reference"; exit 1; }
echo "PASS: architecture.md data flow"
