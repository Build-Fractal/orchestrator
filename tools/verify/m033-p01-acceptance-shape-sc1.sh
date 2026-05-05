#!/usr/bin/env bash
set -u -o pipefail

# m033-p01-acceptance-shape-sc1.sh
# Verifies the SC-1 acceptance script (p01-start-branch-routing.sh)
# exists, is executable, and contains the required content tokens.
# Then executes it and propagates the exit code (the wrapper invocation
# is the load-bearing assertion for SC-1's mechanical claim).

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="$PROJECT_ROOT/tests/m033-acceptance/p01-start-branch-routing.sh"

pass=0
fail=0

pass() { pass=$((pass+1)); echo "PASS: $1"; }
fail() { fail=$((fail+1)); echo "FAIL: $1" >&2; }

[ -f "$TARGET" ] && pass "p01-start-branch-routing.sh exists" || fail "p01-start-branch-routing.sh missing"
[ -x "$TARGET" ] && pass "p01-start-branch-routing.sh executable" || fail "p01-start-branch-routing.sh not executable"

for tok in "SC-1" "FR-1" "FR-2" "greenfield-empty" "greenfield-with-materials" "existing-codebase" "migrating" "MIT-006" "init already complete"; do
  if grep -q -- "$tok" "$TARGET"; then
    pass "token present: $tok"
  else
    fail "token missing: $tok"
  fi
done

# Execute the SC-1 acceptance script and propagate its exit code.
if bash "$TARGET" >/dev/null 2>&1; then
  pass "p01-start-branch-routing.sh exits 0"
else
  fail "p01-start-branch-routing.sh exited non-zero"
fi

echo "SUMMARY: m033-p01-acceptance-shape-sc1.sh pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
