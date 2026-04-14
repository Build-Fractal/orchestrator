#!/usr/bin/env bash
set -eu
f="scripts/knowledge/compute-staleness.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'staleness\.sh' "$f" || { echo "FAIL: does not source staleness.sh"; exit 1; }
grep -q 'index-utils\.sh' "$f" || { echo "FAIL: does not source index-utils.sh"; exit 1; }
grep -q 'compute_effective_confidence' "$f" || { echo "FAIL: does not call compute_effective_confidence"; exit 1; }
echo "PASS: compute-staleness.sh sources lib/staleness.sh and lib/index-utils.sh and calls compute_effective_confidence"
