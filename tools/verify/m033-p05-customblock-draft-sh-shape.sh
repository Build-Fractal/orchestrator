#!/usr/bin/env bash
# tools/verify/m033-p05-customblock-draft-sh-shape.sh
# Asserts scripts/lifecycle/customblock-draft.sh shape + strict-aggregation
# negative-grep (M033/P05/T01 FR-13 driver).
set -u
PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

DRV="scripts/lifecycle/customblock-draft.sh"

if [ -f "$DRV" ]; then
    pass "driver exists"
else
    fail "driver missing: $DRV"
fi
if [ -x "$DRV" ]; then
    pass "driver executable"
else
    fail "driver not executable"
fi

for tok in '--project-dir' '--yes' '--force' 'BEGIN CUSTOM' 'END CUSTOM' \
           '## Project' '## Stack' '## Source-Docs' '## Entry Points' \
           '## Conventions' '## Decisions' 'constitution not present' \
           'knowledge/architecture' 'knowledge/conventions' 'knowledge/decisions' \
           'intake/' 'reconciled-pre-spec.md' 'ideation-pre-spec.md' \
           'customblock_drafted' 'customblock-draft.complete' \
           'dual-write-runtime-md.sh' 'discards prior operator edits' 'no changes'; do
    if grep -qF -- "$tok" "$DRV"; then
        pass "token present: $tok"
    else
        fail "token absent: $tok"
    fi
done

# Negative grep: strict-aggregation invariant (Constitution XV) -- the driver
# MUST NOT call conversus, MUST NOT use model routing, MUST NOT invoke any
# dispatch path. Skip comment lines so doc-prose mentioning these tokens
# does not trip the assertion.
NONCOMMENT_TMP=$(mktemp)
grep -Ev '^[[:space:]]*#' "$DRV" > "$NONCOMMENT_TMP" || true

for forbidden in 'conversus' 'model_routing' 'claude-code.*--task' 'scripts/dispatch'; do
    if grep -qE -- "$forbidden" "$NONCOMMENT_TMP"; then
        fail "forbidden token in code path: $forbidden"
    else
        pass "no forbidden invocation: $forbidden"
    fi
done

# MEM001 bash 3.2 negative grep: no `declare -A`.
if grep -qE 'declare -A' "$NONCOMMENT_TMP"; then
    fail "bash 3.2 violation: declare -A"
else
    pass "no declare -A (bash 3.2)"
fi

rm -f "$NONCOMMENT_TMP"

LINES=$(wc -l < "$DRV")
if [ "$LINES" -ge 250 ]; then
    pass "min 250 lines (got $LINES)"
else
    fail "below 250 lines (got $LINES)"
fi

printf 'SUMMARY: m033-p05-customblock-draft-sh-shape.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
else
    exit 1
fi
