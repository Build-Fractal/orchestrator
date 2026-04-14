#!/usr/bin/env bash
# Verifies check-graph-health.sh exists and sources graph-db.sh.
set -eu

f="scripts/diagnostics/check-graph-health.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }
grep -q 'graph-db\.sh' "$f" || { echo "FAIL: $f does not source graph-db.sh"; exit 1; }
grep -q 'db_query' "$f" || { echo "FAIL: $f does not use db_query"; exit 1; }
wc_lines="$(wc -l < "$f" | tr -d ' ')"
test "$wc_lines" -ge 80 || { echo "FAIL: $f has only $wc_lines lines (expected >= 80)"; exit 1; }
echo "PASS: check-graph-health.sh exists and sources graph-db.sh"
