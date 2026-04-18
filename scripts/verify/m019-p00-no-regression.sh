#!/usr/bin/env bash
# scripts/verify/m019-p00-no-regression.sh — SC-13 regression guard.
#
# Invokes every pre-existing test suite + anti-pattern linter + M021 P04
# suite against the P00-adapted codebase. Exits 0 only when all green.
# This gate proves adaptation did not change what the orchestrator does,
# only how its dispatches are phrased.
#
# Exit 0 on all-pass, 1 on any failure. Bash 3.2 compatible.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

fail_count=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 ($2)"; fail_count=$((fail_count + 1)); }

# --- Gate 1..7: test-s01..test-s07 suites ---
for n in 01 02 03 04 05 06 07; do
  suite="$REPO_ROOT/tests/test-s${n}.sh"
  # Some test-s*.sh files have variant names (e.g., test-s04-core-commands.sh).
  # Glob-resolve the canonical name.
  if [ ! -f "$suite" ]; then
    candidate="$(ls "$REPO_ROOT"/tests/test-s${n}-*.sh 2>/dev/null | head -1)"
    [ -n "$candidate" ] && suite="$candidate"
  fi
  if [ ! -f "$suite" ]; then
    fail "suite s${n} file exists" "no tests/test-s${n}*.sh found"
    continue
  fi
  log="$(mktemp -t m019-p00-s${n}.XXXXXX)"
  if bash "$suite" >"$log" 2>&1; then
    pass "test-s${n} suite green"
  else
    fail "test-s${n} suite" "non-zero exit; log at $log"
    tail -20 "$log" >&2
  fi
done

# --- Gate 8: anti-pattern linter ---
if bash "$REPO_ROOT/scripts/verify/anti-pattern-lint.sh" >/dev/null 2>&1; then
  pass "anti-pattern-lint green"
else
  fail "anti-pattern-lint" "non-zero exit"
fi

# --- Gate 9: M021 P04 suite ---
if bash "$REPO_ROOT/scripts/verify/run-suite.sh" m021 P04 >/dev/null 2>&1; then
  pass "m021 P04 suite green"
else
  fail "m021 P04 suite" "non-zero exit from run-suite.sh m021 P04"
fi

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m019-p00-no-regression.sh"
  exit 0
else
  echo "FAIL: m019-p00-no-regression.sh ($fail_count failures)"
  exit 1
fi
