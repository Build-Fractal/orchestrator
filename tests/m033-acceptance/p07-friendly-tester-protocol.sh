#!/usr/bin/env bash
set -e -u -o pipefail

# SC-8: M033 P01 friendly-tester protocol acceptance test (FR-19).
# Asserts the friendly-tester artifact set under
# tests/m033-acceptance/friendly-tester-pass/ has the required shape
# and that validate-report.sh has the documented contract:
#   exit 0 iff friction_blockers == 0 AND eligible_testers >= 1.
#
# The p07- prefix is a concern-tag (per spec SC-14 amendment), not a
# phase-tag — this script ships in P01 alongside FR-19 deliverables
# even though the related US-7-domain test scripts ship in P02–P04.

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FT_DIR="$PROJECT_ROOT/tests/m033-acceptance/friendly-tester-pass"

pass=0
fail=0

pass() { pass=$((pass+1)); echo "PASS: $1"; }
fail() { fail=$((fail+1)); echo "FAIL: $1" >&2; }

[ -f "$FT_DIR/protocol.md" ] && pass "protocol.md exists" || fail "protocol.md missing"
[ -f "$FT_DIR/report-template.md" ] && pass "report-template.md exists" || fail "report-template.md missing"
[ -x "$FT_DIR/validate-report.sh" ] && pass "validate-report.sh executable" || fail "validate-report.sh not executable"
[ -f "$FT_DIR/fixtures/report-pass.md" ] && pass "report-pass.md exists" || fail "report-pass.md missing"
[ -f "$FT_DIR/fixtures/report-fail.md" ] && pass "report-fail.md exists" || fail "report-fail.md missing"

grep -q 'tester-eligibility' "$FT_DIR/protocol.md" && pass "protocol.md has tester-eligibility section" || fail "protocol.md missing tester-eligibility"
grep -q 'friction_blockers:' "$FT_DIR/report-template.md" && pass "report-template has friction_blockers field" || fail "report-template missing friction_blockers"

# Validator pass case
if bash "$FT_DIR/validate-report.sh" "$FT_DIR/fixtures/report-pass.md" >/dev/null 2>&1; then
  pass "validate-report.sh exits 0 on report-pass.md"
else
  fail "validate-report.sh did not exit 0 on report-pass.md"
fi

# Validator fail case — capture stderr, assert non-zero exit + blocker token
set +e
stderr=$(bash "$FT_DIR/validate-report.sh" "$FT_DIR/fixtures/report-fail.md" 2>&1 1>/dev/null)
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  pass "validate-report.sh exits non-zero on report-fail.md"
else
  fail "validate-report.sh did not fail on report-fail.md"
fi
echo "$stderr" | grep -q 'friction_blockers' && pass "validate-report.sh stderr names friction_blockers" || fail "validate-report.sh stderr missing friction_blockers"

echo "SUMMARY: p07-friendly-tester-protocol.sh pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
