#!/usr/bin/env bash
# scripts/verify/m026-p03-decision-row.sh
# Verifies M026/P03/T04: D022 row in DECISIONS.md + M026 entry in CHANGELOG.md.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

pass=0; fail=0
_pass() { pass=$((pass+1)); echo "PASS: $1"; }
_fail() { fail=$((fail+1)); echo "FAIL: $1"; }

DECISIONS="${REPO_ROOT}/.orchestrator/DECISIONS.md"
CHANGELOG="${REPO_ROOT}/CHANGELOG.md"

if grep -qE '^\| D022 \|' "$DECISIONS"; then _pass "DECISIONS.md contains D022 row"; else _fail "DECISIONS.md missing D022 row"; fi
if grep -qiE 'D022.*edition-resolution' "$DECISIONS"; then _pass "D022 names edition-resolution"; else _fail "D022 does not reference edition-resolution"; fi
if grep -qE 'D022.*MEM029' "$DECISIONS"; then _pass "D022 cross-references MEM029"; else _fail "D022 missing MEM029 cross-ref"; fi
if grep -qE 'D022.*MEM030' "$DECISIONS"; then _pass "D022 cross-references MEM030"; else _fail "D022 missing MEM030 cross-ref"; fi

if grep -qE 'M026.*conversus-OSS' "$CHANGELOG"; then _pass "CHANGELOG.md mentions M026 conversus-OSS migration"; else _fail "CHANGELOG.md missing M026 entry"; fi
if grep -qE 'CONVERSUS_EDITION' "$CHANGELOG"; then _pass "CHANGELOG.md mentions CONVERSUS_EDITION"; else _fail "CHANGELOG.md missing CONVERSUS_EDITION mention"; fi

echo "----"
echo "SUMMARY: $(basename "$0") pass=${pass} fail=${fail}"
if [ "$fail" -gt 0 ]; then exit 1; fi
echo "PASS: $(basename "$0")"
exit 0
