#!/usr/bin/env bash
# tools/verify/m033-p05-acceptance-shape-sc7.sh
# Wrapper for tests/m033-acceptance/p06-customblock-draft.sh.
#
# Asserts the SC-7 acceptance script exists, is executable, contains the
# load-bearing tokens (FR-13/FR-14 contract surface), and exits 0 when run.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1"; }

SCRIPT="tests/m033-acceptance/p06-customblock-draft.sh"
if [ -f "$SCRIPT" ]; then
    pass "script exists"
else
    fail "script missing"
fi
if [ -x "$SCRIPT" ]; then
    pass "script executable"
else
    fail "script not executable"
fi

# Token-presence shape check.
for tok in 'SC-7' 'FR-13' 'FR-14' 'customblock-draft.sh' 'BEGIN CUSTOM' \
           '## Project' '## Stack' '## Conventions' '## Decisions' \
           'constitution not present' 'no changes' 'discards prior operator edits' \
           '## Notes' '## Source-Docs' 'customblock_drafted'; do
    if grep -qF -- "$tok" "$SCRIPT"; then
        pass "token present: $tok"
    else
        fail "token absent: $tok"
    fi
done

LINES=$(wc -l < "$SCRIPT")
if [ "$LINES" -ge 130 ]; then
    pass "min 130 lines (got $LINES)"
else
    fail "below 130 lines (got $LINES)"
fi

# Functional run + exit propagation.
bash "$SCRIPT" > /dev/null 2> /dev/null
RC=$?
if [ "$RC" -eq 0 ]; then
    pass "functional rc=0"
else
    fail "functional rc=$RC"
fi

printf 'SUMMARY: m033-p05-acceptance-shape-sc7.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
