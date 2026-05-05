#!/usr/bin/env bash
# m033-p02-phase-suite.sh
#
# P02 phase-suite aggregator. Runs all 10 P02 verifiers and emits the
# canonical SUMMARY line consumed by scripts/verify/validate-milestone.sh
# and milestone-level aggregation.
#
# The 10 sub-gates plus the SUMMARY: line equal 11 line outputs on
# success. Adding or removing a sub-gate is a contract change requiring
# a P02-PLAN.md amendment (see T05 task plan, Constraints).
#
# Bash 3.2 compatible (MEM001).

set -e -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERIFIER_DIR="$PROJECT_ROOT/tools/verify"

PASS=0
FAIL=0

verifiers="
tools/verify/m033-p02-grilling-shell-shape.sh
tools/verify/m033-p02-grilling-shell-contradiction-detection.sh
tools/verify/m033-p02-glossary-writer-shape.sh
tools/verify/m033-p02-jsonl-event-schema.sh
tools/verify/m033-p02-start-state-markers-shape.sh
tools/verify/m033-p02-start-sh-resume-extension.sh
tools/verify/m033-p02-fr21-convention-shape.sh
tools/verify/m033-p02-acceptance-shape-sc11.sh
tools/verify/m033-p02-acceptance-shape-sc12.sh
tools/verify/m033-p02-acceptance-shape-sc13.sh
"

IFSO="$IFS"
IFS=$'\n'
for v in $verifiers; do
    v_trim="$(echo "$v" | tr -d '[:space:]')"
    [ -z "$v_trim" ] && continue
    if bash "$PROJECT_ROOT/$v_trim" > /dev/null 2>&1; then
        PASS=$((PASS + 1))
        echo "PASS: $v_trim"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $v_trim"
    fi
done
IFS="$IFSO"

printf 'SUMMARY: m033-p02-phase-suite.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
