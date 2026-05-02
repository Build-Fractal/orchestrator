#!/usr/bin/env bash
# m031-p01-build-context-profile-shape.sh
#
# Verifier for M031/P01/T01: asserts that build-context.sh accepts the new
# additive flags --profile=quick|standard|full and --meta-out <file> per
# FR-2 + AD-11. Asserts that the literal substrings required by the AD-11
# JSON sidecar contract appear in the script body, and that an integration
# smoke test produces a sidecar file with the five required keys.
#
# Bash 3.2 compatible. No mapfile/readarray, no declare -A, no process
# substitution. Single-script Truth Check shape per AD-19.
#
# Usage:
#   bash tools/verify/m031-p01-build-context-profile-shape.sh
#
# Output:
#   stdout: per-check PASS/FAIL lines + final SUMMARY: line
#   exit 0 on all-pass, 1 on any failure

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

build_context="$PROJECT_ROOT/scripts/dispatch/build-context.sh"

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

# Check 1: build-context.sh exists.
if [ ! -f "$build_context" ]; then
    echo "FAIL: build-context.sh missing at $build_context"
    echo "SUMMARY: m031-p01-build-context-profile-shape.sh pass=0 fail=1"
    exit 1
fi
check_pass "build-context.sh exists at $build_context"

# Check 2: literal substring --profile present.
if grep -q -- '--profile' "$build_context"; then
    check_pass "build-context.sh contains literal --profile"
else
    check_fail "build-context.sh missing literal --profile"
fi

# Check 3: literal substring --meta-out present.
if grep -q -- '--meta-out' "$build_context"; then
    check_pass "build-context.sh contains literal --meta-out"
else
    check_fail "build-context.sh missing literal --meta-out"
fi

# Check 4: literal substring quick present (profile enum).
if grep -q 'quick' "$build_context"; then
    check_pass "build-context.sh contains literal quick"
else
    check_fail "build-context.sh missing literal quick"
fi

# Check 5: literal substring mem_count present (sidecar key).
if grep -q 'mem_count' "$build_context"; then
    check_pass "build-context.sh contains literal mem_count"
else
    check_fail "build-context.sh missing literal mem_count"
fi

# Check 6: literal substring compression_applied present (sidecar key).
if grep -q 'compression_applied' "$build_context"; then
    check_pass "build-context.sh contains literal compression_applied"
else
    check_fail "build-context.sh missing literal compression_applied"
fi

# Check 7: integration smoke. Invoke build-context.sh against a fixture and
# confirm exit 0 + a 5-key sidecar JSON object.
fixture="$PROJECT_ROOT/tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt"
payload_out="/tmp/m031-p01-t01-payload.md"
meta_out="/tmp/m031-p01-t01-meta.json"
rm -f "$payload_out" "$meta_out"

if [ ! -f "$fixture" ]; then
    check_fail "fixture missing at $fixture (smoke test cannot run)"
else
    bash "$build_context" \
        --profile=quick \
        --task-plan "$fixture" \
        --out "$payload_out" \
        --meta-out "$meta_out" >/dev/null 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        check_pass "smoke: --profile=quick --task-plan ... --out ... --meta-out ... exits 0"
    else
        check_fail "smoke: build-context.sh exited rc=$rc"
    fi
fi

# Check 8: meta-out file exists and is non-empty.
if [ -s "$meta_out" ]; then
    check_pass "smoke: meta-out file is non-empty"
else
    check_fail "smoke: meta-out file empty or missing at $meta_out"
fi

# Check 9: meta-out contains all 5 required keys.
keys_missing=""
for k in mem_count total_tokens profile compression_applied snip_applied; do
    if [ -f "$meta_out" ] && grep -q "\"$k\"" "$meta_out"; then
        :
    else
        keys_missing="$keys_missing $k"
    fi
done
if [ -z "$keys_missing" ]; then
    check_pass "smoke: meta-out contains all 5 required keys"
else
    check_fail "smoke: meta-out missing keys:$keys_missing"
fi

# Check 10: profile value in meta-out equals quick.
if [ -f "$meta_out" ] && grep -q '"profile":"quick"' "$meta_out"; then
    check_pass "smoke: meta-out profile=quick"
else
    check_fail "smoke: meta-out profile != quick"
fi

echo "SUMMARY: m031-p01-build-context-profile-shape.sh pass=$pass fail=$fail"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
