#!/usr/bin/env bash
# tools/verify/m033-p05-phase-suite.sh
# M033/P05 phase-suite aggregator -- chains 9 P05 sub-verifiers in
# dependency order. Each sub-verifier emits its own
# `SUMMARY: <verifier-name> pass=N fail=M` line on its own stdout;
# this aggregator emits the canonical phase-grain SUMMARY line.
#
# Order matches the T01->T02->T03->T04 dependency chain (T05 verifiers
# live in separate scripts -- validated-marker-shape, summary-md-shape,
# unit-close-jsonl-shape -- not aggregated by this suite, since the
# AD-7 three-part close gate fires AFTER this suite passes).
#
# AD-19 single-script-file shape: each gate is `bash <path>` only, no
# compound chains, no `$(...)` substitutions in the loop body.
# Bash 3.2 compatible (MEM001) -- no `declare -A`, no process substitution.

set -u
PASS=0
FAIL=0

VERIFIERS="
tools/verify/m033-p05-customblock-draft-md-shape.sh
tools/verify/m033-p05-customblock-draft-sh-shape.sh
tools/verify/m033-p05-customblock-format-ref-shape.sh
tools/verify/m033-p05-with-wiki-passthrough-shape.sh
tools/verify/m033-p05-with-github-passthrough-shape.sh
tools/verify/m033-p05-acceptance-shape-sc7.sh
tools/verify/m033-p05-acceptance-shape-sc9.sh
tools/verify/m033-p05-acceptance-shape-sc10.sh
tools/verify/m033-p05-acceptance-battery-shape.sh
"

OLDIFS="$IFS"
IFS='
'
for v in $VERIFIERS; do
    [ -z "$v" ] && continue
    bash "$v" > /dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        PASS=$((PASS + 1))
        printf 'PASS: %s\n' "$v"
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL: %s (rc=%d)\n' "$v" "$rc"
    fi
done
IFS="$OLDIFS"

printf 'SUMMARY: m033-p05-phase-suite.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
