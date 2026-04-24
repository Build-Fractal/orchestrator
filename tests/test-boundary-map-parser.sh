#!/usr/bin/env bash
# tests/test-boundary-map-parser.sh — Issue #1 regression test
#
# check-boundary-map.sh previously split Produces: cells on comma without
# understanding that parenthetical commentary or narrative prose can
# contain commas. Every M026 phase shipped with 7 FAILs nobody was
# expected to act on (commas from "patched X (FR-1, FR-2); ..." were
# treated as path delimiters and each fragment fs-checked).
#
# Fix: strip parenthetical commentary before splitting; skip fragments
# that aren't path-shaped (allow only [A-Za-z0-9._/*-]).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK="$PROJECT_ROOT/scripts/verify/check-boundary-map.sh"
FIXTURE="$PROJECT_ROOT/tests/fixtures/boundary-map-parser/roadmap-with-prose.md"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- Test 1: P01 — two real paths, both exist ---
out1=$(bash "$CHECK" "$FIXTURE" P01 --root "$PROJECT_ROOT" 2>&1 || true)
if echo "$out1" | grep -qE "PASS: boundary-map P01 produces tests/fixtures/boundary-map-parser/roadmap-with-prose.md"; then
  pass "P01 real path 1 found"
else
  fail "P01 real path 1 (got: '$out1')"
fi
if echo "$out1" | grep -qE "PASS: boundary-map P01 produces tests/fixtures/boundary-map-parser/sample-file.txt"; then
  pass "P01 real path 2 found"
else
  fail "P01 real path 2 (got: '$out1')"
fi
fail_count_p01=$(echo "$out1" | grep -c '^FAIL:' || true)
if [[ "$fail_count_p01" -eq 0 ]]; then
  pass "P01 emits zero FAIL lines"
else
  fail "P01 emits zero FAIL lines (got $fail_count_p01: '$out1')"
fi

# --- Test 2: P02 — prose-only Produces, should emit zero checks (prose filtered out) ---
out2=$(bash "$CHECK" "$FIXTURE" P02 --root "$PROJECT_ROOT" 2>&1 || true)
fail_count_p02=$(echo "$out2" | grep -c '^FAIL:' || true)
if [[ "$fail_count_p02" -eq 0 ]]; then
  pass "P02 prose-mixed Produces emits zero FAIL lines (prose fragments filtered)"
else
  fail "P02 prose-mixed Produces should emit zero FAIL lines (got $fail_count_p02: '$out2')"
fi

# --- Test 3: P03 — real paths with parenthetical annotation ---
out3=$(bash "$CHECK" "$FIXTURE" P03 --root "$PROJECT_ROOT" 2>&1 || true)
if echo "$out3" | grep -qE "PASS: boundary-map P03 produces tests/fixtures/boundary-map-parser/sample-file.txt"; then
  pass "P03 path with '(touched)' annotation passes after parens strip"
else
  fail "P03 path with '(touched)' annotation (got: '$out3')"
fi
fail_count_p03=$(echo "$out3" | grep -c '^FAIL:' || true)
if [[ "$fail_count_p03" -eq 0 ]]; then
  pass "P03 emits zero FAIL lines"
else
  fail "P03 emits zero FAIL lines (got $fail_count_p03: '$out3')"
fi

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
