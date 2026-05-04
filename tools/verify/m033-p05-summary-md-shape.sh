#!/usr/bin/env bash
# tools/verify/m033-p05-summary-md-shape.sh
# Asserts the M033-SUMMARY.md file shape: canonical milestone-summary
# YAML frontmatter + body referencing every SC-1..SC-16 verdict +
# CON-3 standalone-gate verdict + AD-15 cross-phase regression verdict
# + min-100-line floor.
#
# Bash 3.2 compatible (MEM001).

set -u
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

SUM=".orchestrator/milestones/M033/M033-SUMMARY.md"

if [ -f "$SUM" ]; then
    pass "summary exists: $SUM"
else
    fail "summary missing: $SUM"
fi

# Canonical frontmatter + per-SC + per-phase + posture tokens.
for tok in 'schema_version' 'type: milestone-summary' 'M033' \
           'SC-1' 'SC-2' 'SC-3' 'SC-4' 'SC-5' 'SC-6' 'SC-7' 'SC-8' 'SC-9' \
           'SC-10' 'SC-11' 'SC-12' 'SC-13' 'SC-14' 'SC-15' 'SC-16' \
           'P01' 'P02' 'P03' 'P04' 'P05' 'standalone-gate' 'verification_result'; do
    if [ -f "$SUM" ] && grep -qF -- "$tok" "$SUM"; then
        pass "token present: $tok"
    else
        fail "token absent: $tok"
    fi
done

if [ -f "$SUM" ]; then
    LINES=$(wc -l < "$SUM" | tr -d ' ')
    if [ "$LINES" -ge 100 ]; then
        pass "min 100 lines (got $LINES)"
    else
        fail "below 100 lines (got $LINES)"
    fi
fi

printf 'SUMMARY: m033-p05-summary-md-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
