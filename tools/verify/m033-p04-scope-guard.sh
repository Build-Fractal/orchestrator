#!/usr/bin/env bash
# M033/P04 bidirectional scope-guard.
#
# Asserts:
#   (a) Forbidden surfaces — P05 customblock-draft + paired-launch
#       surfaces — MUST NOT be present (overflow detector).
#   (b) Allowed surfaces — every P04 T01..T05 deliverable — MUST be
#       present (underflow detector). Catches accidental deletes and
#       silent-skip task drift.
#
# The bidirectional pattern (forbidden + allowed) is inherited from
# m033-p01-scope-guard.sh and m033-p02-scope-guard.sh. Every prior-
# phase scope-guard ships this shape.
#
# Bash 3.2 compatible. Single-script invocations only.

set -e
set -u

PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Forbidden: P05 / customblock surfaces MUST NOT appear at P04 close.
# ---------------------------------------------------------------------------
FORBIDDEN='scripts/lifecycle/customblock-draft.sh
commands/customblock-draft.md
references/customblock-format.md
tools/verify/m033-p05-phase-suite.sh
tools/verify/m033-p05-scope-guard.sh'

OLD_IFS="$IFS"
IFS='
'
for f in $FORBIDDEN; do
    if [ -e "$f" ]; then
        FAIL=$((FAIL + 1))
        printf 'FAIL: forbidden P05 surface present: %s\n' "$f" 1>&2
    else
        PASS=$((PASS + 1))
    fi
done
IFS="$OLD_IFS"

# ---------------------------------------------------------------------------
# Allowed: P04 T01..T05 deliverables MUST be present.
# ---------------------------------------------------------------------------
ALLOWED='commands/materials-intake.md
commands/ideation.md
scripts/lifecycle/materials-intake.sh
scripts/lifecycle/ideation.sh
scripts/lifecycle/start.sh
scripts/lifecycle/ingest-codebase.sh
tests/m033-acceptance/p04-materials-intake.sh
tests/m033-acceptance/p04-ideation.sh
tests/m033-acceptance/p05-migrate-routing.sh
tools/verify/m033-p04-materials-intake-md-shape.sh
tools/verify/m033-p04-materials-intake-sh-shape.sh
tools/verify/m033-p04-ideation-md-shape.sh
tools/verify/m033-p04-ideation-sh-shape.sh
tools/verify/m033-p04-migrate-routing-shape.sh
tools/verify/m033-p04-migrate-then-ingest-shape.sh
tools/verify/m033-p04-acceptance-shape-sc4.sh
tools/verify/m033-p04-acceptance-shape-sc5.sh
tools/verify/m033-p04-acceptance-shape-sc6.sh
tools/verify/m033-p04-phase-suite.sh
tools/verify/m033-p04-cross-phase-regression.sh'

IFS='
'
for f in $ALLOWED; do
    if [ -e "$f" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL: required P04 deliverable missing: %s\n' "$f" 1>&2
    fi
done
IFS="$OLD_IFS"

printf 'SUMMARY: m033-p04-scope-guard.sh pass=%d fail=%d\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
exit 0
