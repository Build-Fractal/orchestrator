#!/usr/bin/env bash
# Verify references/events.md documents the EVENT: line format with fields.
set -eu
f="references/events.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "EVENT:" "$f" || { echo "FAIL: missing EVENT: format documentation"; exit 1; }
grep -q "timestamp" "$f" || { echo "FAIL: missing timestamp field documentation"; exit 1; }
grep -q "run_id" "$f" || { echo "FAIL: missing run_id field documentation"; exit 1; }
echo "PASS: events.md EVENT: line format with field documentation"
