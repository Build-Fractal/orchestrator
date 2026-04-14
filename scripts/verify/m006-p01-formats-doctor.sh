#!/usr/bin/env bash
# Verify references/file-formats.md documents doctor-history.jsonl format.
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "doctor-history.jsonl" "$f" || { echo "FAIL: missing doctor-history.jsonl documentation"; exit 1; }
grep -q "checks_passed" "$f" || { echo "FAIL: missing checks_passed field"; exit 1; }
grep -q "checks_total" "$f" || { echo "FAIL: missing checks_total field"; exit 1; }
grep -q "advisory_warnings" "$f" || { echo "FAIL: missing advisory_warnings field"; exit 1; }
echo "PASS: file-formats.md documents doctor-history.jsonl"
