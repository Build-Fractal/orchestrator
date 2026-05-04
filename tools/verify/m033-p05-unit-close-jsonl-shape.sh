#!/usr/bin/env bash
# tools/verify/m033-p05-unit-close-jsonl-shape.sh
# Asserts a single milestone-grain unit_close record was appended to
# .orchestrator/execution-log.jsonl for M033 at close-state.
#
# Modeled on the M030/M031 milestone-close JSONL precedents.
# Bash 3.2 compatible (MEM001).

set -u
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

LOG=".orchestrator/execution-log.jsonl"

if [ -f "$LOG" ]; then
    pass "execution-log.jsonl exists"
else
    fail "execution-log.jsonl missing"
fi

# Find unit_close records mentioning M033 at milestone grain.
# The payload's JSON field order may interleave -- use multi-grep for
# order-independent token presence on the same line.
COUNT=0
if [ -f "$LOG" ]; then
    COUNT=$(grep -F '"event_type":"unit_close"' "$LOG" \
        | grep -F '"unit_id":"M033"' \
        | grep -cF '"unit_grain":"milestone"' 2>/dev/null || true)
    COUNT="${COUNT:-0}"
fi

if [ "${COUNT:-0}" -ge 1 ]; then
    pass "milestone unit_close record present (count=$COUNT)"
else
    fail "no milestone unit_close record for M033 (count=$COUNT)"
fi

# At least one record carries gates_passed including SC-14 + SC-16 (SC-15
# may appear under gates_passed OR gates_attested per the US-8 AS-5
# signed-attestation fallback).
if [ -f "$LOG" ] && grep -q '"gates_passed".*"SC-14".*"SC-16"' "$LOG"; then
    pass "gates_passed includes SC-14 + SC-16"
else
    fail "gates_passed field missing required SC labels"
fi

# Token-presence checks for the key fields we expect on the unit_close
# record line itself.
if [ -f "$LOG" ]; then
    for tok in 'unit_close' 'M033' 'milestone'; do
        if grep -F 'unit_close' "$LOG" | grep -qF -- "$tok"; then
            pass "field token present in unit_close lines: $tok"
        else
            fail "field token absent in unit_close lines: $tok"
        fi
    done
fi

printf 'SUMMARY: m033-p05-unit-close-jsonl-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
