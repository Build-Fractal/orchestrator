#!/usr/bin/env bash
# m033-p01-disambiguation-question-shape.sh
#
# T03 verifier: asserts the US-1 AS-5 + MIT-006 / RISK-006
# disambiguation question is implemented inline in
# scripts/lifecycle/start.sh with the load-bearing tokens.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/lifecycle/start.sh"

pass=0
fail=0

check_pass() {
    pass=$((pass + 1))
    echo "PASS: $1"
}

check_fail() {
    fail=$((fail + 1))
    echo "FAIL: $1"
}

if [ ! -f "$target" ]; then
    echo "FAIL: scripts/lifecycle/start.sh missing at $target"
    echo "SUMMARY: m033-p01-disambiguation-question-shape.sh pass=0 fail=1"
    exit 1
fi

# Load-bearing tokens.
required_tokens=(
    'disambiguation:'
    'recommended:'
    'MIT-006'
    'git history present but only'
    'recommended: greenfield-empty'
    'branch-override:'
)
for tok in "${required_tokens[@]}"; do
    if grep -qF -- "$tok" "$target"; then
        check_pass "token present: '$tok'"
    else
        check_fail "token missing: '$tok'"
    fi
done

echo "SUMMARY: m033-p01-disambiguation-question-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
