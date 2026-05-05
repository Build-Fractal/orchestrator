#!/usr/bin/env bash
# m033-p01-subflow-stubs-shape.sh
#
# T03 verifier: asserts the four sub-flow stubs are present in
# scripts/lifecycle/start.sh and each emits a 'would-execute:'
# diagnostic line. Stubs are deliberately vacuous in P01.

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
    echo "SUMMARY: m033-p01-subflow-stubs-shape.sh pass=0 fail=1"
    exit 1
fi

# Four stub names.
for stub in 'ideation-stub' 'materials-intake-stub' 'ingest-codebase-stub' 'migrate-routing-stub'; do
    if grep -qF -- "$stub" "$target"; then
        check_pass "stub name present: '$stub'"
    else
        check_fail "stub name missing: '$stub'"
    fi
done

# would-execute: token must appear at least 4 times (once per stub).
we_count=$(grep -cF -- 'would-execute:' "$target" 2>/dev/null || echo 0)
we_count=$(printf '%s' "$we_count" | tr -d ' ')
if [ "$we_count" -ge 4 ]; then
    check_pass "would-execute: token appears $we_count times (≥4)"
else
    check_fail "would-execute: token appears $we_count times (expected ≥4)"
fi

echo "SUMMARY: m033-p01-subflow-stubs-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
