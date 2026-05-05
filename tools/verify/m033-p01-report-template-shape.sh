#!/usr/bin/env bash
# tools/verify/m033-p01-report-template-shape.sh
#
# M033 P01 T04 verifier (FR-19 / SC-15).
# Asserts the friendly-tester report template document exists with the
# required YAML frontmatter scalar fields and tester_attestations /
# tested_branches list keys.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
TEMPLATE="$PROJECT_ROOT/tests/m033-acceptance/friendly-tester-pass/report-template.md"

pass=0
fail=0

check() {
    desc="$1"
    rc="$2"
    if [ "$rc" -eq 0 ]; then
        printf 'PASS: %s\n' "$desc"
        pass=$((pass + 1))
    else
        printf 'FAIL: %s\n' "$desc"
        fail=$((fail + 1))
    fi
}

# 1. File exists.
if [ -f "$TEMPLATE" ]; then
    check "report-template.md exists" 0
else
    check "report-template.md exists" 1
    printf 'SUMMARY: m033-p01-report-template-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Opens with YAML frontmatter delimiter.
first_line=$(head -n 1 "$TEMPLATE")
if [ "$first_line" = '---' ]; then
    check "first line is YAML frontmatter delimiter (---)" 0
else
    check "first line is YAML frontmatter delimiter (---)" 1
fi

# 3. Required frontmatter scalar / list keys.
for key in \
    'schema_version:' \
    'type: friendly-tester-report' \
    'report_date:' \
    'eligible_testers:' \
    'friction_blockers:' \
    'friction_warnings:' \
    'tester_attestations:' \
    'tested_branches:'; do
    if grep -qF "$key" "$TEMPLATE"; then
        check "frontmatter key present: $key" 0
    else
        check "frontmatter key present: $key" 1
    fi
done

# 4. Required attestation field inside the list.
if grep -qF 'not_familiar_with_orchestrator:' "$TEMPLATE"; then
    check "attestation field present: not_familiar_with_orchestrator" 0
else
    check "attestation field present: not_familiar_with_orchestrator" 1
fi

# 5. Required H1.
if grep -qE '^# M033 Friendly-Tester Report' "$TEMPLATE"; then
    check "H1 '# M033 Friendly-Tester Report' present" 0
else
    check "H1 '# M033 Friendly-Tester Report' present" 1
fi

# 6. Length floor (>=40 lines).
lines=$(wc -l < "$TEMPLATE" | tr -d ' ')
if [ "$lines" -ge 40 ]; then
    check "template length >=40 lines (got $lines)" 0
else
    check "template length >=40 lines (got $lines)" 1
fi

printf 'SUMMARY: m033-p01-report-template-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
