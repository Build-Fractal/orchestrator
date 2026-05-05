#!/usr/bin/env bash
# m033-p02-start-sh-resume-extension.sh
#
# T02 verifier: scripts/lifecycle/start.sh resume-extension shape +
# P01-preservation gate.
#
# Asserts:
#   - start.sh exists and is executable (P01 surface preserved).
#   - --no-resume flag token appears.
#   - Load-bearing diagnostic tokens 'start-state:' and 'resuming from'
#     appear (SC-12).
#   - Cross-reference to start-state-markers.sh appears.
#   - Branch-to-sub-flow case mapping appears (at minimum the literal
#     'materials-intake' near a case construct).
#   - P01-preservation gate (AD-15 cross-phase regression precedent):
#     re-runs tools/verify/m033-p01-start-md-shape.sh and propagates the
#     exit code — start.sh changes MUST be additive.
#
# Bash 3.2 compatible. Single-script Truth Check shape per AD-19.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

target="$PROJECT_ROOT/scripts/lifecycle/start.sh"
p01_verifier="$PROJECT_ROOT/tools/verify/m033-p01-start-md-shape.sh"

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

# Check 1: start.sh exists.
if [ ! -f "$target" ]; then
    echo "FAIL: start.sh missing at $target"
    echo "SUMMARY: m033-p02-start-sh-resume-extension.sh pass=0 fail=1"
    exit 1
fi
check_pass "start.sh exists at $target (P01 surface preserved)"

# Check 2: executable.
if [ ! -x "$target" ]; then
    check_fail "start.sh not executable: $target"
else
    check_pass "start.sh is executable"
fi

# Check 3: --no-resume flag token.
if grep -F -q -- '--no-resume' "$target"; then
    check_pass "--no-resume flag token present"
else
    check_fail "--no-resume flag token missing"
fi

# Check 4: 'start-state:' load-bearing token.
if grep -F -q 'start-state:' "$target"; then
    check_pass "'start-state:' load-bearing token present (SC-12)"
else
    check_fail "'start-state:' load-bearing token missing"
fi

# Check 5: 'resuming from' load-bearing token.
if grep -F -q 'resuming from' "$target"; then
    check_pass "'resuming from' load-bearing token present (SC-12)"
else
    check_fail "'resuming from' load-bearing token missing"
fi

# Check 6: cross-reference to start-state-markers.sh.
if grep -F -q 'start-state-markers.sh' "$target"; then
    check_pass "cross-reference to start-state-markers.sh present"
else
    check_fail "cross-reference to start-state-markers.sh missing"
fi

# Check 7: branch-to-sub-flow case mapping (at minimum 'materials-intake').
if grep -F -q 'materials-intake' "$target"; then
    check_pass "'materials-intake' sub-flow name present (branch mapping)"
else
    check_fail "'materials-intake' sub-flow name missing"
fi

# Check 8: NO_RESUME variable wiring.
if grep -F -q 'NO_RESUME' "$target"; then
    check_pass "NO_RESUME variable wiring present"
else
    check_fail "NO_RESUME variable wiring missing"
fi

# Check 9: --no-resume appears in usage line.
if grep -F -q '[--no-resume]' "$target"; then
    check_pass "[--no-resume] documented in usage"
else
    check_fail "[--no-resume] not documented in usage"
fi

# --- P01-preservation gate (AD-15 cross-phase regression precedent) ---

if [ ! -f "$p01_verifier" ]; then
    check_fail "P01 verifier missing at $p01_verifier (cannot run preservation gate)"
else
    check_pass "P01 verifier present at $p01_verifier"
    p01_out="$PROJECT_ROOT/.tmp-p01-preservation-output.txt"
    bash "$p01_verifier" > "$p01_out" 2>&1
    p01_rc=$?
    if [ "$p01_rc" -eq 0 ]; then
        check_pass "P01 preservation gate: m033-p01-start-md-shape.sh exits 0 (additive change confirmed)"
    else
        check_fail "P01 preservation gate FAILED: m033-p01-start-md-shape.sh exit=$p01_rc (T02 broke P01 contract)"
        echo "--- P01 verifier output ---" 1>&2
        cat "$p01_out" 1>&2
        echo "--- end P01 verifier output ---" 1>&2
    fi
    rm -f "$p01_out"
fi

echo "SUMMARY: m033-p02-start-sh-resume-extension.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
