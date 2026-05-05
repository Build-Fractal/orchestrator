#!/usr/bin/env bash
# tools/verify/m033-p01-friendly-tester-protocol-shape.sh
#
# M033 P01 T04 verifier (FR-19 / US-8 / SC-15).
# Asserts the friendly-tester protocol document exists in the canonical
# shape: required H1, required ## section headers, required content tokens.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
PROTOCOL="$PROJECT_ROOT/tests/m033-acceptance/friendly-tester-pass/protocol.md"

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
if [ -f "$PROTOCOL" ]; then
    check "protocol.md exists" 0
else
    check "protocol.md exists" 1
    printf 'SUMMARY: m033-p01-friendly-tester-protocol-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. H1 header.
if grep -qE '^# M033 Friendly-Tester Pass Protocol' "$PROTOCOL"; then
    check "H1 '# M033 Friendly-Tester Pass Protocol' present" 0
else
    check "H1 '# M033 Friendly-Tester Pass Protocol' present" 1
fi

# 3. Required ## section headers.
for header in \
    '## Purpose' \
    '## Tester Eligibility' \
    '## Pre-Conditions (Per Branch)' \
    '## 30-Minute Walkthrough Script (Per Branch)' \
    '## Friction Capture Template' \
    '## Reporting'; do
    if grep -qF "$header" "$PROTOCOL"; then
        check "section present: $header" 0
    else
        check "section present: $header" 1
    fi
done

# 4. Required content tokens (verifier asserts via grep -q).
for token in \
    'tester-eligibility' \
    'not_familiar_with_orchestrator' \
    'greenfield-empty' \
    'greenfield-with-materials' \
    'existing-codebase' \
    'migrating' \
    '30-minute' \
    'friction' \
    'validate-report.sh' \
    'report-template.md'; do
    if grep -qiF "$token" "$PROTOCOL"; then
        check "token present: $token" 0
    else
        check "token present: $token" 1
    fi
done

# 5. Length floor (>=100 lines).
lines=$(wc -l < "$PROTOCOL" | tr -d ' ')
if [ "$lines" -ge 100 ]; then
    check "protocol length >=100 lines (got $lines)" 0
else
    check "protocol length >=100 lines (got $lines)" 1
fi

printf 'SUMMARY: m033-p01-friendly-tester-protocol-shape.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
