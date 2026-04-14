#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/run-doctor.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'doctor-history.jsonl' "$f" || { echo "FAIL: does not reference doctor-history.jsonl"; exit 1; }
grep -q 'timestamp' "$f" || { echo "FAIL: missing timestamp field in history output"; exit 1; }
grep -q 'checks_passed' "$f" || { echo "FAIL: missing checks_passed field in history output"; exit 1; }
grep -q 'checks_total' "$f" || { echo "FAIL: missing checks_total field in history output"; exit 1; }
grep -q 'status' "$f" || { echo "FAIL: missing status field in history output"; exit 1; }
grep -q '>>' "$f" || { echo "FAIL: does not append (>>) to history file"; exit 1; }
echo "PASS: run-doctor.sh appends JSON with required fields to doctor-history.jsonl"
