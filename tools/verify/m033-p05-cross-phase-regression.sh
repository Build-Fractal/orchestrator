#!/usr/bin/env bash
# tools/verify/m033-p05-cross-phase-regression.sh
# AD-15 cross-phase regression: re-run P01..P04 phase-suites + the
# scripts/verify/standalone-gate.sh constitution surface against the
# post-P05 working tree. Asserts each exits 0.
#
# CON-3 / Principle XVI invariant -- the customblock-draft surface
# (T01) MUST NOT introduce any speckit.* references; the
# standalone-gate carries that invariant across the full M033 surface
# at close-state.
#
# AD-19 single-script-file shape -- each gate is `bash <path>` only.
# Bash 3.2 compatible (MEM001).

set -u
PASS=0
FAIL=0

SUITES="
tools/verify/m033-p01-phase-suite.sh
tools/verify/m033-p02-phase-suite.sh
tools/verify/m033-p03-phase-suite.sh
tools/verify/m033-p04-phase-suite.sh
"

OLDIFS="$IFS"
IFS='
'
for s in $SUITES; do
    [ -z "$s" ] && continue
    bash "$s" > /dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        PASS=$((PASS + 1))
        printf 'PASS: %s\n' "$s"
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL: %s (rc=%d)\n' "$s" "$rc"
    fi
done
IFS="$OLDIFS"

# CON-3 / Principle XVI -- standalone-gate constitution surface must
# still exit 0 after P05's customblock-draft surface lands.
bash scripts/verify/standalone-gate.sh constitution > /dev/null 2>&1
GATE_RC=$?
if [ "$GATE_RC" -eq 0 ]; then
    PASS=$((PASS + 1))
    printf 'PASS: standalone-gate constitution (CON-3 / Principle XVI)\n'
else
    FAIL=$((FAIL + 1))
    printf 'FAIL: standalone-gate constitution (rc=%d)\n' "$GATE_RC"
fi

printf 'SUMMARY: m033-p05-cross-phase-regression.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -eq 0 ]; then
    exit 0
fi
exit 1
