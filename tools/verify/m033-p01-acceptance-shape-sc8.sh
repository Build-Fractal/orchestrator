#!/usr/bin/env bash
set -u -o pipefail

# m033-p01-acceptance-shape-sc8.sh
# Verifies the SC-8 acceptance script (p07-friendly-tester-protocol.sh)
# exists, is executable, and contains the required content tokens.
# Then executes it and propagates the exit code.

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="$PROJECT_ROOT/tests/m033-acceptance/p07-friendly-tester-protocol.sh"

pass=0
fail=0

pass() { pass=$((pass+1)); echo "PASS: $1"; }
fail() { fail=$((fail+1)); echo "FAIL: $1" >&2; }

[ -f "$TARGET" ] && pass "p07-friendly-tester-protocol.sh exists" || fail "p07-friendly-tester-protocol.sh missing"
[ -x "$TARGET" ] && pass "p07-friendly-tester-protocol.sh executable" || fail "p07-friendly-tester-protocol.sh not executable"

for tok in "SC-8" "FR-19" "validate-report.sh" "report-pass.md" "report-fail.md"; do
  if grep -q -- "$tok" "$TARGET"; then
    pass "token present: $tok"
  else
    fail "token missing: $tok"
  fi
done

# Execute the SC-8 acceptance script and propagate its exit code.
if bash "$TARGET" >/dev/null 2>&1; then
  pass "p07-friendly-tester-protocol.sh exits 0"
else
  fail "p07-friendly-tester-protocol.sh exited non-zero"
fi

echo "SUMMARY: m033-p01-acceptance-shape-sc8.sh pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
