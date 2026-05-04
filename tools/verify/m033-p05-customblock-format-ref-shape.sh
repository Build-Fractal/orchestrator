#!/usr/bin/env bash
# tools/verify/m033-p05-customblock-format-ref-shape.sh
# Asserts references/customblock-format.md FR-14 SSOT shape
# (M033/P05/T01 FR-14 surface).
set -u
PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

REF="references/customblock-format.md"

if [ -f "$REF" ]; then
    pass "reference exists"
else
    fail "reference missing: $REF"
fi

for tok in 'FR-14' '## Project' '## Stack' '## Source-Docs' '## Entry Points' \
           '## Conventions' '## Decisions' 'BEGIN CUSTOM' 'END CUSTOM' \
           'floor' 'ceiling' 'no LLM' 'Constitution XV' 'US-7 AS-2'; do
    if grep -qF -- "$tok" "$REF"; then
        pass "token present: $tok"
    else
        fail "token absent: $tok"
    fi
done

LINES=$(wc -l < "$REF")
if [ "$LINES" -ge 60 ]; then
    pass "min 60 lines (got $LINES)"
else
    fail "below 60 lines (got $LINES)"
fi

printf 'SUMMARY: m033-p05-customblock-format-ref-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
else
    exit 1
fi
