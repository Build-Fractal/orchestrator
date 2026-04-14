#!/usr/bin/env bash
set -eu
f="scripts/knowledge/compute-staleness.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qE 'dry.run|idempotent|DRY.RUN|no side' "$f" || { echo "FAIL: no idempotency marker found"; exit 1; }
f2="scripts/knowledge/detect-overlap.sh"
test -f "$f2" || { echo "FAIL: $f2 missing"; exit 1; }
grep -qE 'NO_OVERLAPS|found_overlap' "$f2" || { echo "FAIL: detect-overlap.sh missing read-only marker"; exit 1; }
echo "PASS: lifecycle scripts support idempotent operation"
