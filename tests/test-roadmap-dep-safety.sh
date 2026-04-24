#!/usr/bin/env bash
# tests/test-roadmap-dep-safety.sh — Bug E regression tests
#
# Bug E: scripts/state/read-roadmap.sh active-phase mistakenly marks a
# dependency-blocked phase as ready when an upstream phase's Risk: line
# carries parenthetical commentary. The parens-pollution shifts tokens in
# the IFS=' ' split inside the active-phase loop, and a defensive `continue`
# silently skipped the malformed dep instead of refusing to schedule.
#
# This test pins both the parens-strip fix (mirrors what Depends already
# does) and the loud-fail behavior on malformed dep tokens.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROADMAP_SCRIPT="$PROJECT_ROOT/scripts/state/read-roadmap.sh"
FIXTURE_DIR="$PROJECT_ROOT/tests/fixtures/roadmap-dep-safety"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- Test 1: Risk with parens does not pollute downstream dep parse ---
# Fixture: P00 complete, P01 incomplete (Depends: P00), P02 incomplete with
# Risk: high (core product value) and Depends: P01.
# Expected active phase: P01 (P02 is blocked by incomplete P01).
result=$(bash "$ROADMAP_SCRIPT" "$FIXTURE_DIR/risk-with-parens.md" active-phase 2>/dev/null || echo "ERROR")
if [[ "$result" = "P01" ]]; then
  pass "active-phase ignores parenthetical Risk commentary (got P01)"
else
  fail "active-phase ignores parenthetical Risk commentary (expected P01, got '$result')"
fi

# Risk parse for P02 should be the bare keyword, not the parenthetical-laden form.
p02_line=$(bash "$ROADMAP_SCRIPT" "$FIXTURE_DIR/risk-with-parens.md" phase P02 2>/dev/null || echo "")
p02_risk=$(echo "$p02_line" | awk '{print $3}')
if [[ "$p02_risk" = "high" ]]; then
  pass "phase query returns clean risk='high' for P02 (parens stripped)"
else
  fail "phase query returns clean risk='high' for P02 (got '$p02_risk', full line: '$p02_line')"
fi

# --- Test 2: Malformed Depends refuses to schedule + warns to stderr ---
# Fixture: P01 has Depends: garbage text not a phase id
# Expected: active-phase returns "none"; stderr contains "unparseable dependency token".
stderr_capture=$(mktemp)
result=$(bash "$ROADMAP_SCRIPT" "$FIXTURE_DIR/malformed-depends.md" active-phase 2>"$stderr_capture" || echo "ERROR")
stderr_out=$(cat "$stderr_capture")
rm -f "$stderr_capture"

if [[ "$result" = "none" ]]; then
  pass "active-phase refuses to schedule phase with malformed dep token (got 'none')"
else
  fail "active-phase refuses to schedule phase with malformed dep token (expected 'none', got '$result')"
fi

if echo "$stderr_out" | grep -q "unparseable dependency token"; then
  pass "malformed dep emits 'unparseable dependency token' warning to stderr"
else
  fail "malformed dep emits 'unparseable dependency token' warning to stderr (stderr was: '$stderr_out')"
fi

# --- Test 3: Regression — existing roadmap-sample.md still parses correctly ---
# Sanity: P01 complete, P02 high-risk Depends P01, P03 low-risk Depends P02.
# Expected active: P02 (P01 done, P02 deps satisfied, highest risk).
sample_result=$(bash "$ROADMAP_SCRIPT" "$PROJECT_ROOT/tests/fixtures/roadmap-sample.md" active-phase 2>/dev/null || echo "ERROR")
if [[ "$sample_result" = "P02" ]]; then
  pass "regression: roadmap-sample.md active-phase still returns P02"
else
  fail "regression: roadmap-sample.md active-phase still returns P02 (got '$sample_result')"
fi

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
