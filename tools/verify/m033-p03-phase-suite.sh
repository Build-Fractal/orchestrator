#!/usr/bin/env bash
# m033-p03-phase-suite.sh
#
# P03 phase-suite aggregator. Runs the 13 documented P03 sub-verifiers
# in dependency order (T01 -> T04 task-shape verifiers, then T05's two
# acceptance-shape verifiers). Emits the canonical SUMMARY: line
# consumed by scripts/verify/validate-milestone.sh and milestone-level
# aggregation.
#
# The cross-phase-regression and scope-guard verifiers are additional
# T05 deliverables, run separately (per the AD-15 / SC-13 invariants).
# The phase-suite focuses on the in-phase shape contract.
#
# Adding or removing a sub-gate is a contract change requiring a
# P03-PLAN.md amendment.
#
# Bash 3.2 compatible (MEM001).

set -e -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

verifiers="
tools/verify/m033-p03-constitution-md-shape.sh
tools/verify/m033-p03-constitution-author-sh-shape.sh
tools/verify/m033-p03-constitution-starter-templates-shape.sh
tools/verify/m033-p03-constitution-starter-format-ref-shape.sh
tools/verify/m033-p03-constitution-shape-lint-shape.sh
tools/verify/m033-p03-standalone-gate-sh-shape.sh
tools/verify/m033-p03-ingest-codebase-md-shape.sh
tools/verify/m033-p03-ingest-codebase-sh-shape.sh
tools/verify/m033-p03-rich-context-import-shape.sh
tools/verify/m033-p03-imported-context-sentinel-shape.sh
tools/verify/m033-p03-stack-fixtures-shape.sh
tools/verify/m033-p03-acceptance-shape-sc2.sh
tools/verify/m033-p03-acceptance-shape-sc3.sh
"

IFSO="$IFS"
IFS=$'\n'
for v in $verifiers; do
    v_trim=$(echo "$v" | tr -d '[:space:]')
    if [ -z "$v_trim" ]; then
        continue
    fi
    if bash "$PROJECT_ROOT/$v_trim" > /dev/null 2>&1; then
        PASS=$((PASS + 1))
        echo "PASS: $v_trim"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $v_trim"
    fi
done
IFS="$IFSO"

printf 'SUMMARY: m033-p03-phase-suite.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
