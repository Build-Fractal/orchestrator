#!/usr/bin/env bash
# tools/verify/m033-p05-customblock-draft-md-shape.sh
# Asserts commands/customblock-draft.md MEM012 shape + load-bearing tokens
# (M033/P05/T01 FR-13 surface).
set -u
PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

DOC="commands/customblock-draft.md"

if [ -f "$DOC" ]; then
    pass "doc exists"
else
    fail "doc missing: $DOC"
fi

for tok in 'orchestrator:customblock-draft' 'FR-13' 'FR-14' 'customblock-draft.sh' \
           'BEGIN CUSTOM' 'END CUSTOM' '## Project' '## Stack' '## Source-Docs' \
           '## Entry Points' '## Conventions' '## Decisions' 'customblock_drafted' \
           'customblock-draft.complete' 'constitution not present' 'no LLM' \
           'Constitution XV' 'customblock-format.md'; do
    if grep -qF -- "$tok" "$DOC"; then
        pass "token present: $tok"
    else
        fail "token absent: $tok"
    fi
done

LINES=$(wc -l < "$DOC")
if [ "$LINES" -ge 60 ]; then
    pass "min 60 lines (got $LINES)"
else
    fail "below 60 lines (got $LINES)"
fi

printf 'SUMMARY: m033-p05-customblock-draft-md-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
else
    exit 1
fi
