#!/usr/bin/env bash
# tests/test-find-active-milestone-target.sh — Issue #2 regression test
#
# find-active-milestone.sh previously had no way to target a named
# milestone — orchestrator:auto milestone=M026 hit a finder that picked
# the numerically-first planning milestone (M014), silently bypassing
# the caller's intent.
#
# Fix: --milestone M### flag validates existence, tier C, and
# auto-eligible state, failing loud with a specific reason.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FINDER="$PROJECT_ROOT/scripts/state/find-active-milestone.sh"
ORCH_ROOT="$PROJECT_ROOT/tests/fixtures/find-active-milestone/orchestrator-state"

PASS_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); echo "PASS: $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL: $1"; }

# --- Test 1: default behavior unchanged — picks numerically-first ---
default_out=$(bash "$FINDER" "$ORCH_ROOT" 2>/dev/null || echo "ERROR")
default_id=$(echo "$default_out" | awk '{print $1}')
if [[ "$default_id" = "M014" ]]; then
  pass "default returns numerically-first auto-eligible milestone (M014)"
else
  fail "default returns M014 (got '$default_id', full: '$default_out')"
fi

# --- Test 2: --milestone M026 returns M026 instead of default ---
target_out=$(bash "$FINDER" "$ORCH_ROOT" --milestone M026 2>/dev/null || echo "ERROR")
target_id=$(echo "$target_out" | awk '{print $1}')
if [[ "$target_id" = "M026" ]]; then
  pass "--milestone M026 returns M026 (not numerically-first)"
else
  fail "--milestone M026 returns M026 (got '$target_id', full: '$target_out')"
fi

# --- Test 3: --milestone=M026 (equals form) works ---
target_eq=$(bash "$FINDER" "$ORCH_ROOT" --milestone=M026 2>/dev/null || echo "ERROR")
target_eq_id=$(echo "$target_eq" | awk '{print $1}')
if [[ "$target_eq_id" = "M026" ]]; then
  pass "--milestone=M026 (equals form) works"
else
  fail "--milestone=M026 equals form (got '$target_eq_id')"
fi

# --- Test 4: nonexistent milestone fails loud with specific error ---
err_capture=$(mktemp)
if bash "$FINDER" "$ORCH_ROOT" --milestone M999 2>"$err_capture"; then
  fail "--milestone M999 (nonexistent) should exit non-zero"
else
  if grep -q "not found" "$err_capture"; then
    pass "--milestone M999 (nonexistent) emits 'not found' error"
  else
    fail "--milestone M999 emits 'not found' (got: '$(cat "$err_capture")')"
  fi
fi
rm -f "$err_capture"

# --- Test 5: malformed --milestone arg rejected ---
err_capture=$(mktemp)
if bash "$FINDER" "$ORCH_ROOT" --milestone garbage 2>"$err_capture"; then
  fail "--milestone garbage should exit non-zero"
else
  if grep -q "M-prefixed identifier" "$err_capture"; then
    pass "--milestone garbage emits format hint"
  else
    fail "--milestone garbage emits format hint (got: '$(cat "$err_capture")')"
  fi
fi
rm -f "$err_capture"

# --- Test 6: --all and --milestone are mutually exclusive ---
err_capture=$(mktemp)
if bash "$FINDER" "$ORCH_ROOT" --all --milestone M026 2>"$err_capture"; then
  fail "--all + --milestone should exit non-zero"
else
  if grep -q "mutually exclusive" "$err_capture"; then
    pass "--all + --milestone rejected as mutually exclusive"
  else
    fail "--all + --milestone rejected (got: '$(cat "$err_capture")')"
  fi
fi
rm -f "$err_capture"

echo "----"
echo "PASS: $PASS_COUNT  FAIL: $FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
