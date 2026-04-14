#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/check-stale.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'staleness.sh' "$f" || { echo "FAIL: does not source staleness.sh"; exit 1; }
grep -q 'compute_effective_confidence' "$f" || { echo "FAIL: does not compute effective confidence"; exit 1; }
grep -q 'STALE_DAYS=90\|90' "$f" || { echo "FAIL: missing 90-day staleness threshold"; exit 1; }
grep -q 'days_since' "$f" || { echo "FAIL: does not compute days since last verified"; exit 1; }
grep -q 'hit_count\|hits' "$f" || { echo "FAIL: does not check hit count for keep-alive exemption"; exit 1; }
grep -q 'WARNING.*stale' "$f" || { echo "FAIL: missing stale entry warning message"; exit 1; }
echo "PASS: check-stale.sh flags entries past 90-day threshold with low hits"
