#!/usr/bin/env bash
# Verifies scripts/lib/verdicts.sh exists with required exports and functions.
set -eu
f="scripts/lib/verdicts.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '_VERDICTS_SOURCED' "$f" || { echo "FAIL: double-sourcing guard missing"; exit 1; }
grep -q 'emit_verdict' "$f" || { echo "FAIL: emit_verdict function missing"; exit 1; }
grep -q 'parse_verdict' "$f" || { echo "FAIL: parse_verdict function missing"; exit 1; }
grep -q 'orch_is_verdict' "$f" || { echo "FAIL: orch_is_verdict function missing"; exit 1; }
grep -q 'ORCH_VERDICT_PASS' "$f" || { echo "FAIL: ORCH_VERDICT_PASS constant missing"; exit 1; }
grep -q 'ORCH_VERDICT_BLOCK' "$f" || { echo "FAIL: ORCH_VERDICT_BLOCK constant missing"; exit 1; }
grep -q 'ORCH_VERDICT_WARN' "$f" || { echo "FAIL: ORCH_VERDICT_WARN constant missing"; exit 1; }
grep -q 'ORCH_VERDICT_NEEDS_REVIEW' "$f" || { echo "FAIL: ORCH_VERDICT_NEEDS_REVIEW constant missing"; exit 1; }
lines="$(wc -l < "$f" | tr -d ' ')"
test "$lines" -ge 60 || { echo "FAIL: expected at least 60 lines, found $lines"; exit 1; }
echo "PASS: verdicts.sh exists with all required exports ($lines lines)"
