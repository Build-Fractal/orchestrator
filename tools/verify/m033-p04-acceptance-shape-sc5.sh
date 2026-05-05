#!/usr/bin/env bash
# Wraps tests/m033-acceptance/p04-ideation.sh.
set -e
set -u

S='tests/m033-acceptance/p04-ideation.sh'
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

TOKENS='SC-5
FR-10
MIT-007
ideation.sh
ideation-pre-spec.md
partial-answers.yml
--with-conversus-stress-test
_GRILLING_CONTRADICTION_PAIRS
contradiction:
ideation_completed'

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

printf 'SUMMARY: m033-p04-acceptance-shape-sc5.sh pass=%d fail=0\n' "$checks"
exit "$rc"
