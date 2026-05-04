#!/usr/bin/env bash
# m033-p03-acceptance-shape-sc3.sh
#
# T05 verifier: shape of tests/m033-acceptance/p03-ingest-codebase.sh
# (SC-3 acceptance script). Asserts existence + executable bit +
# load-bearing tokens + functional smoke (script exits 0 with fail=0).
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m033-p03-acceptance-shape-sc3.sh
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

acceptance="$PROJECT_ROOT/tests/m033-acceptance/p03-ingest-codebase.sh"

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

if [ ! -f "$acceptance" ]; then
    echo "FAIL: tests/m033-acceptance/p03-ingest-codebase.sh missing at $acceptance"
    echo "SUMMARY: m033-p03-acceptance-shape-sc3.sh pass=0 fail=1"
    exit 1
fi
check_pass "tests/m033-acceptance/p03-ingest-codebase.sh exists"

if [ -x "$acceptance" ]; then
    check_pass "acceptance script is executable"
else
    check_fail "acceptance script is NOT executable"
fi

# Load-bearing tokens.
for token in SC-3 FR-7 FR-8 ingest-codebase.sh knowledge/architecture knowledge/conventions knowledge/decisions re-ingest "context_source: imported-from-existing" _imported-context MEM-DR-DEMO-001 MEM-DR-DEMO-002 build-context.sh "--profile" "imported_context_loaded" "missing"; do
    if grep -F -q -- "$token" "$acceptance"; then
        check_pass "token present: $token"
    else
        check_fail "token missing: $token"
    fi
done

# Functional smoke test.
smoke_out=$(mktemp)
rc=0
bash "$acceptance" > "$smoke_out" 2>&1 || rc=$?

if [ "$rc" -eq 0 ]; then
    check_pass "functional smoke: acceptance exits 0"
else
    check_fail "functional smoke: acceptance exits $rc"
fi

if grep -F -q 'SUMMARY: p03-ingest-codebase.sh' "$smoke_out"; then
    check_pass "functional smoke: SUMMARY: line emitted"
else
    check_fail "functional smoke: SUMMARY: line missing"
fi

if grep -F -q 'fail=0' "$smoke_out"; then
    check_pass "functional smoke: fail=0"
else
    check_fail "functional smoke: fail=0 not present"
fi

rm -f "$smoke_out"

echo "SUMMARY: m033-p03-acceptance-shape-sc3.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
