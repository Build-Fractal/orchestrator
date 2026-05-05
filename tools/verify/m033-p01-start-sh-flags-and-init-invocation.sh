#!/usr/bin/env bash
# m033-p01-start-sh-flags-and-init-invocation.sh
#
# T03 verifier: asserts scripts/lifecycle/start.sh exists, is
# executable, accepts the documented FR-1 flag set, invokes
# init-project.sh, and emits the load-bearing 'init already complete'
# diagnostic string.

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
    echo "SUMMARY: m033-p01-start-sh-flags-and-init-invocation.sh pass=0 fail=1"
    exit 1
fi
check_pass "scripts/lifecycle/start.sh exists"

if [ -x "$target" ]; then
    check_pass "scripts/lifecycle/start.sh is executable"
else
    check_fail "scripts/lifecycle/start.sh is NOT executable (chmod +x missing)"
fi

# FR-1 flag tokens.
flag_tokens=(
    '--project-dir'
    '--yes'
    '--branch'
    '--stack'
    '--dry-run'
)
for tok in "${flag_tokens[@]}"; do
    if grep -qF -- "$tok" "$target"; then
        check_pass "flag token present: '$tok'"
    else
        check_fail "flag token missing: '$tok'"
    fi
done

# init-project.sh invocation.
if grep -qF -- 'init-project.sh' "$target"; then
    check_pass "invokes init-project.sh"
else
    check_fail "missing init-project.sh invocation"
fi

# Load-bearing idempotency diagnostic.
if grep -qF -- 'init already complete' "$target"; then
    check_pass "idempotency diagnostic 'init already complete' present"
else
    check_fail "idempotency diagnostic 'init already complete' missing"
fi

# Usage diagnostic shape.
if grep -qF -- 'usage: start.sh' "$target"; then
    check_pass "usage diagnostic 'usage: start.sh' present"
else
    check_fail "usage diagnostic 'usage: start.sh' missing"
fi

echo "SUMMARY: m033-p01-start-sh-flags-and-init-invocation.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
