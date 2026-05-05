#!/usr/bin/env bash
# AD-15 cross-phase regression discipline — re-runs every prior-phase
# phase-suite (P01, P02, P03) and asserts each exits 0. The check
# verifies that T01-T04 deliverables under P04 did not silently regress
# any earlier-phase contract.
#
# Bash 3.2 compatible. Single-script invocations only.

set -e
set -u

PASS=0
FAIL=0

SUITES='m033-p01-phase-suite.sh
m033-p02-phase-suite.sh
m033-p03-phase-suite.sh'

OLD_IFS="$IFS"
IFS='
'
for suite in $SUITES; do
    if bash "tools/verify/$suite" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
        printf 'PASS: cross-phase regression — %s exits 0\n' "$suite"
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL: cross-phase regression — %s does not exit 0\n' "$suite" 1>&2
    fi
done
IFS="$OLD_IFS"

printf 'SUMMARY: m033-p04-cross-phase-regression.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
exit 0
