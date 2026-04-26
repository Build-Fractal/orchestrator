#!/usr/bin/env bash
# tests/test-parser-bugs.sh — Regression tests for two parser bugs surfaced
# closing M001 in the bbt-companion project on 2026-04-26.
#
# Bug 1 — `scripts/verify/validate-milestone.sh` key_files parser.
#   Splits on every comma, including commas inside parenthetical descriptions.
#   Phase summaries with `path/to/file.ts (modified, secondary edit)` get
#   tokenized into bogus path fragments that fail filesystem-existence checks.
#
# Bug 2 — `scripts/state/read-roadmap.sh` decimal phase IDs.
#   Phase regex `P[0-9]+` doesn't match decimal IDs like `P09.1`. The state
#   machine becomes blind to the phase: active-phase walks past it, and the
#   milestone can be marked complete with the decimal phase still incomplete.
#
# Both fixed by extending regexes/tokenizers in:
#   - scripts/state/read-roadmap.sh
#   - scripts/verify/check-boundary-map.sh
#   - scripts/lifecycle/sync-roadmap.sh
#   - scripts/dispatch/dispatch-interface.sh
#   - scripts/verify/validate-milestone.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
READ_ROADMAP="$PROJECT_ROOT/scripts/state/read-roadmap.sh"
VALIDATE="$PROJECT_ROOT/scripts/verify/validate-milestone.sh"

DECIMAL_FIXTURE="$PROJECT_ROOT/tests/fixtures/parser-bugs/M999"
DECIMAL_ROADMAP="$DECIMAL_FIXTURE/M999-ROADMAP.md"
PARENS_FIXTURE="$PROJECT_ROOT/tests/fixtures/parser-bugs/M998"
PARENS_ROADMAP="$PARENS_FIXTURE/M998-ROADMAP.md"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# ---------------------------------------------------------------------------
# Bug 2 — read-roadmap.sh sees decimal phase IDs
# ---------------------------------------------------------------------------

# Test 2a: phases query includes P02.1
phases=$(bash "$READ_ROADMAP" "$DECIMAL_ROADMAP" phases 2>/dev/null || true)
if echo "$phases" | grep -qE '^P02\.1 '; then
  pass "read-roadmap.sh phases includes decimal P02.1"
else
  fail "read-roadmap.sh phases includes decimal P02.1 (got: '$phases')"
fi

# Test 2b: phases query does NOT collapse P02.1 into P02 (regression check —
# greedy match must capture the trailing .1, not stop at `P02`)
p02_count=$(echo "$phases" | awk '$1 == "P02"' | wc -l | tr -d ' ')
p02_1_count=$(echo "$phases" | awk '$1 == "P02.1"' | wc -l | tr -d ' ')
if [[ "$p02_count" -eq 1 && "$p02_1_count" -eq 1 ]]; then
  pass "read-roadmap.sh keeps P02 and P02.1 as distinct phase IDs"
else
  fail "read-roadmap.sh keeps P02 and P02.1 distinct (P02 count=$p02_count, P02.1 count=$p02_1_count)"
fi

# Test 2c: phase count is 4 (P01, P02, P02.1, P03)
count=$(bash "$READ_ROADMAP" "$DECIMAL_ROADMAP" count 2>/dev/null || true)
if [[ "$count" = "4" ]]; then
  pass "read-roadmap.sh count → 4 with decimal phase"
else
  fail "read-roadmap.sh count → 4 with decimal phase (got: '$count')"
fi

# Test 2d: status query for P02.1 returns 'incomplete'
p021_status=$(bash "$READ_ROADMAP" "$DECIMAL_ROADMAP" status P02.1 2>/dev/null || true)
if [[ "$p021_status" = "incomplete" ]]; then
  pass "read-roadmap.sh status P02.1 → incomplete"
else
  fail "read-roadmap.sh status P02.1 → incomplete (got: '$p021_status')"
fi

# Test 2e: active-phase returns P02.1 (the only incomplete phase, deps met)
active=$(bash "$READ_ROADMAP" "$DECIMAL_ROADMAP" active-phase 2>/dev/null || true)
if [[ "$active" = "P02.1" ]]; then
  pass "read-roadmap.sh active-phase → P02.1 (skipping decimal silently was the M001 close-bug)"
else
  fail "read-roadmap.sh active-phase → P02.1 (got: '$active')"
fi

# ---------------------------------------------------------------------------
# Bug 2 — validate-milestone.sh end-to-end on decimal phase
# ---------------------------------------------------------------------------

# Test 2f: with decimal phase summary missing, validate exits non-zero and
# names the missing phase. This is the "real fail" case — when P09.1 is
# genuinely incomplete, validate must refuse to pass the milestone.
validate_out=$(bash "$VALIDATE" "$DECIMAL_FIXTURE" 2>&1 || true)
validate_exit=$?
# Re-run to capture exit code cleanly (the `|| true` above masks it)
if bash "$VALIDATE" "$DECIMAL_FIXTURE" >/dev/null 2>&1; then
  fail "validate-milestone.sh exits non-zero when P02.1 summary is missing (got exit 0)"
else
  pass "validate-milestone.sh exits non-zero when P02.1 summary is missing"
fi
if echo "$validate_out" | grep -q "P02.1 summary MISSING"; then
  pass "validate-milestone.sh names P02.1 as missing summary"
else
  fail "validate-milestone.sh names P02.1 as missing summary (got: '$validate_out')"
fi

# Test 2g: drop in a P02.1-SUMMARY.md and validate passes. Stages a temporary
# summary, runs validate, restores. The fixture intentionally ships with the
# directory empty so this test can layer the file in.
P02_1_SUMMARY="$DECIMAL_FIXTURE/phases/P02.1/P02.1-SUMMARY.md"
cat > "$P02_1_SUMMARY" <<'EOF'
---
id: P02.1
parent: M999
key_files:
  - "tests/fixtures/parser-bugs/M999/M999-ROADMAP.md"
---

P02.1 transient summary written by test-parser-bugs.sh.
EOF
trap 'rm -f "$P02_1_SUMMARY"' EXIT

if bash "$VALIDATE" "$DECIMAL_FIXTURE" >/dev/null 2>&1; then
  pass "validate-milestone.sh exits zero when P02.1 summary is present"
else
  vout=$(bash "$VALIDATE" "$DECIMAL_FIXTURE" 2>&1 || true)
  fail "validate-milestone.sh exits zero when P02.1 summary is present (got: '$vout')"
fi

rm -f "$P02_1_SUMMARY"

# ---------------------------------------------------------------------------
# Bug 1 — validate-milestone.sh paren-aware key_files tokenizer
# ---------------------------------------------------------------------------

# Test 1a: validate runs cleanly on a phase whose key_files contains
# parenthetical commentary with internal commas. Both real paths exist on
# disk; the naive splitter would emit `secondary edit)` etc. as MISSING.
parens_out=$(bash "$VALIDATE" "$PARENS_FIXTURE" 2>&1 || true)
missing_count=$(echo "$parens_out" | grep -c 'key_file MISSING' || true)
if [[ "$missing_count" -eq 0 ]]; then
  pass "validate-milestone.sh emits zero key_file MISSING lines on paren-bearing key_files"
else
  fail "validate-milestone.sh emits zero key_file MISSING lines on paren-bearing key_files (got $missing_count: '$parens_out')"
fi

# Test 1b: end-to-end exit zero on the parens fixture
if bash "$VALIDATE" "$PARENS_FIXTURE" >/dev/null 2>&1; then
  pass "validate-milestone.sh exits zero on paren-bearing key_files"
else
  fail "validate-milestone.sh exits zero on paren-bearing key_files (out: '$parens_out')"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
