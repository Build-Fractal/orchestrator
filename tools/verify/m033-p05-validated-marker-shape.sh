#!/usr/bin/env bash
# tools/verify/m033-p05-validated-marker-shape.sh
# Asserts the M033-VALIDATED marker file exists with non-empty content
# and documents the AD-7 three-part close gate (SC-14 + SC-15 + SC-16).
#
# Bash 3.2 compatible (MEM001).

set -u
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

MARKER=".orchestrator/milestones/M033/M033-VALIDATED"

if [ -f "$MARKER" ]; then
    pass "marker exists: $MARKER"
else
    fail "marker missing: $MARKER"
fi

# AD-7 three-part close gate documentation tokens.
for tok in 'M033' 'VALIDATED' 'AD-7' 'SC-14' 'SC-15' 'SC-16'; do
    if [ -f "$MARKER" ] && grep -qF -- "$tok" "$MARKER"; then
        pass "token present: $tok"
    else
        fail "token absent: $tok"
    fi
done

if [ -f "$MARKER" ]; then
    LINES=$(wc -l < "$MARKER" | tr -d ' ')
    if [ "$LINES" -ge 5 ]; then
        pass "min 5 lines (got $LINES)"
    else
        fail "below 5 lines (got $LINES)"
    fi
fi

printf 'SUMMARY: m033-p05-validated-marker-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
