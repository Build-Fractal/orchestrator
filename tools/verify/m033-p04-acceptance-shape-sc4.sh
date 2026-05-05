#!/usr/bin/env bash
# Wraps tests/m033-acceptance/p04-materials-intake.sh.
# Shape-checks load-bearing tokens then runs the script.
set -e
set -u

S='tests/m033-acceptance/p04-materials-intake.sh'
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

TOKENS='SC-4
FR-9
materials-intake.sh
m033-pbj-materials-fixture
id-misalignment
scheme-contradiction
orphan-reference
reconciled-pre-spec.md
conflicts.md
out-of-scope
materials_intake_completed'

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

printf 'SUMMARY: m033-p04-acceptance-shape-sc4.sh pass=%d fail=0\n' "$checks"
exit "$rc"
