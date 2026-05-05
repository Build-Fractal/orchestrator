#!/usr/bin/env bash
# tools/verify/m033-p01-validate-report-sh-contract.sh
#
# M033 P01 T04 verifier (FR-19 / US-8 AS-5 / SC-15).
# Asserts the per-report validator script exists, is executable, and
# carries the contract tokens that bind it to the SC-15 mechanical gate.
#
# Required content tokens:
#   - friction_blockers
#   - eligible_testers
#   - not_familiar_with_orchestrator
#   - milestone close blocked
#
# Also asserts the script is bash (shebang) and bash 3.2 compatible
# (no `declare -A`).
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../.." && pwd )"
VALIDATOR="$PROJECT_ROOT/tests/m033-acceptance/friendly-tester-pass/validate-report.sh"

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
if [ -f "$VALIDATOR" ]; then
    check "validate-report.sh exists" 0
else
    check "validate-report.sh exists" 1
    printf 'SUMMARY: m033-p01-validate-report-sh-contract.sh pass=%d fail=%d\n' "$pass" "$fail"
    exit 1
fi

# 2. Executable bit.
if [ -x "$VALIDATOR" ]; then
    check "validate-report.sh is executable" 0
else
    check "validate-report.sh is executable" 1
fi

# 3. Bash shebang.
shebang=$(head -n 1 "$VALIDATOR")
case "$shebang" in
    '#!/usr/bin/env bash'|'#!/bin/bash')
        check "validate-report.sh has bash shebang ($shebang)" 0
        ;;
    *)
        printf 'FAIL: validate-report.sh shebang not bash: %s\n' "$shebang"
        fail=$((fail + 1))
        ;;
esac

# 4. Required content tokens.
for token in \
    'friction_blockers' \
    'eligible_testers' \
    'not_familiar_with_orchestrator' \
    'milestone close blocked'; do
    if grep -qF "$token" "$VALIDATOR"; then
        check "token present: $token" 0
    else
        check "token present: $token" 1
    fi
done

# 5. Bash 3.2 compatibility: no `declare -A`.
if grep -qE 'declare[[:space:]]+-A' "$VALIDATOR"; then
    check "no declare -A (bash 3.2 safe)" 1
else
    check "no declare -A (bash 3.2 safe)" 0
fi

# 6. No jq, no python invocations (MEM001). Strip comments before scanning
#    so explanatory references in comment lines don't trigger false positives.
noncomment=$(grep -vE '^[[:space:]]*#' "$VALIDATOR" || true)
if printf '%s\n' "$noncomment" | grep -qE '(^|[^[:alnum:]_])jq([^[:alnum:]_]|$)'; then
    check "no jq invocation (parser-purity per MEM001)" 1
else
    check "no jq invocation (parser-purity per MEM001)" 0
fi
if printf '%s\n' "$noncomment" | grep -qE '(^|[^[:alnum:]_])python3?([^[:alnum:]_]|$)'; then
    check "no python invocation (parser-purity per MEM001)" 1
else
    check "no python invocation (parser-purity per MEM001)" 0
fi

# 7. Length floor (>=70 lines).
lines=$(wc -l < "$VALIDATOR" | tr -d ' ')
if [ "$lines" -ge 70 ]; then
    check "validator length >=70 lines (got $lines)" 0
else
    check "validator length >=70 lines (got $lines)" 1
fi

printf 'SUMMARY: m033-p01-validate-report-sh-contract.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
    exit 0
fi
exit 1
