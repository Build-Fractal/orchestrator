#!/usr/bin/env bash
# M033/P04 phase-suite aggregator.
#
# Chains all 9 P04 verifiers (T01..T05) in dependency order and emits
# the canonical SUMMARY: m033-p04-phase-suite.sh pass=N fail=M final
# line per the M033 phase-suite-aggregator pattern.
#
# Verifier list (newline-delimited; iterated under IFS swap per MEM001):
#   T01: m033-p04-materials-intake-md-shape.sh
#        m033-p04-materials-intake-sh-shape.sh
#   T02: m033-p04-ideation-md-shape.sh
#        m033-p04-ideation-sh-shape.sh
#   T03: m033-p04-migrate-then-ingest-shape.sh
#   T04: m033-p04-migrate-routing-shape.sh
#   T05: m033-p04-acceptance-shape-sc4.sh
#        m033-p04-acceptance-shape-sc5.sh
#        m033-p04-acceptance-shape-sc6.sh
#
# Bash 3.2 compatible. Single-script invocations only.

set -e
set -u

PASS=0
FAIL=0

VERIFIERS='m033-p04-materials-intake-md-shape.sh
m033-p04-materials-intake-sh-shape.sh
m033-p04-ideation-md-shape.sh
m033-p04-ideation-sh-shape.sh
m033-p04-migrate-then-ingest-shape.sh
m033-p04-migrate-routing-shape.sh
m033-p04-acceptance-shape-sc4.sh
m033-p04-acceptance-shape-sc5.sh
m033-p04-acceptance-shape-sc6.sh'

OLD_IFS="$IFS"
IFS='
'
for v in $VERIFIERS; do
    if bash "tools/verify/$v" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
        printf 'PASS: %s\n' "$v"
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL: %s\n' "$v" 1>&2
    fi
done
IFS="$OLD_IFS"

printf 'SUMMARY: m033-p04-phase-suite.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
exit 0
