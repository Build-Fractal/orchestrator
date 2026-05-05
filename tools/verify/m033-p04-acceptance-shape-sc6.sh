#!/usr/bin/env bash
# Wraps tests/m033-acceptance/p05-migrate-routing.sh.
# Note: the acceptance script is named with the p05- prefix per MIT-002
# (run-acceptance-battery.sh enumerates by exact filename); the wrapper
# verifier still lives under m033-p04-* per the phase-suite namespace.
set -e
set -u

S='tests/m033-acceptance/p05-migrate-routing.sh'
checks=0

if [ -f "$S" ]; then
    checks=$((checks + 1))
else
    printf 'FAIL: %s missing\n' "$S" 1>&2
    exit 1
fi

if [ -x "$S" ]; then
    checks=$((checks + 1))
else
    printf 'FAIL: %s not executable\n' "$S" 1>&2
    exit 1
fi

TOKENS='SC-6
FR-11
FR-12
migrate-routed
proposed: orchestrator:migrate
--from gsd-v1
--from gsd-v2
--from spec-kit
derived_from_migrate
skip-duplicate-from-migrate
no orchestrator:migrate adapter'

OLD_IFS="$IFS"
IFS='
'
for tok in $TOKENS; do
    if grep -qF -- "$tok" "$S"; then
        checks=$((checks + 1))
    else
        printf 'FAIL: %s missing token %s\n' "$S" "$tok" 1>&2
        exit 1
    fi
done
IFS="$OLD_IFS"

# Functional run.
bash "$S" >/dev/null 2>&1
rc=$?

printf 'SUMMARY: m033-p04-acceptance-shape-sc6.sh pass=%d fail=0\n' "$checks"
exit "$rc"
