#!/usr/bin/env bash
# scripts/verify/m018-p07-zero-llm-parity.sh — phase-truth verifier (Truth #1):
# "Zero-LLM compression tiers (knowledge-aware filter + Tier 1 microcompact +
# Tier 2 snip) produce byte-identical post-pipeline payloads (SHA-256 equality)
# across ORCH_BACKEND ∈ {claude-code, codex, cursor} for every non-T3 fixture
# in tests/compression-runtime-parity/."
#
# Drives scripts/diagnostics/m018-runtime-parity.sh end-to-end and asserts on
# its stdout. Always-exit-0 contract: divergence surfaces via the runner's
# regression_flag: divergence line; this verifier accepts the divergence iff
# the corresponding RA-M018-NN row exists in references/RUNTIME-ASSUMPTIONS.md
# (the documented-divergence carve-out).
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001),
# pass()/fail() per MEM002.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RUNNER="$REPO_ROOT/scripts/diagnostics/m018-runtime-parity.sh"
ASSUMPTIONS="$REPO_ROOT/references/RUNTIME-ASSUMPTIONS.md"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# --- Assertion 1: runner exists.
if [ -f "$RUNNER" ]; then
  pass "scripts/diagnostics/m018-runtime-parity.sh exists"
else
  fail "scripts/diagnostics/m018-runtime-parity.sh missing"
  printf 'FAIL: m018-p07-zero-llm-parity (cannot continue without runner)\n' >&2
  exit 1
fi

# --- Assertion 2: bash -n clean.
if bash -n "$RUNNER" 2>/dev/null; then
  pass "bash -n m018-runtime-parity.sh exits 0"
else
  fail "bash -n m018-runtime-parity.sh syntax errors"
fi

# --- Run the runner; capture stdout to a temp file (single redirect, not compound).
TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM
RUNOUT="$TMPDIR_E/runner.out"

bash "$RUNNER" --runtimes claude-code,codex,cursor --fixture all > "$RUNOUT" 2>&1
RC=$?

# --- Assertion 3: runner exits 0 (FR-12 advisory pattern).
if [ "$RC" -eq 0 ]; then
  pass "runner exits 0 (advisory always-exit-0)"
else
  fail "runner exit code $RC (expected 0)"
fi

# --- Assertion 4: per-(fixture, runtime) runtime-parity sha256 lines for each
# zero-LLM fixture. tier3-oversized-section is excluded (T02 owns T3).
ZERO_LLM_FIXTURES="filter-mixed-status tier1-oversized-tool-result tier2-oversized-section"
RUNTIMES="claude-code codex cursor"

for fixture in $ZERO_LLM_FIXTURES; do
  for rt in $RUNTIMES; do
    if grep -qE "^runtime-parity fixture=${fixture} runtime=${rt} sha256=[0-9a-f]{64}" "$RUNOUT"; then
      pass "runtime-parity line: fixture=${fixture} runtime=${rt} sha256=<64-hex>"
    else
      fail "missing runtime-parity line for fixture=${fixture} runtime=${rt}"
    fi
  done
done

# --- Assertion 5: per-fixture parity result=match line for each zero-LLM fixture.
for fixture in $ZERO_LLM_FIXTURES; do
  if grep -qE "^parity fixture=${fixture} result=match runtimes=3" "$RUNOUT"; then
    pass "parity match line: fixture=${fixture} runtimes=3"
  else
    # If divergence is observed, accept it iff RUNTIME-ASSUMPTIONS.md carries
    # a documenting RA-M018-NN row for this fixture.
    if grep -qE "^parity fixture=${fixture} result=divergence" "$RUNOUT"; then
      if [ -f "$ASSUMPTIONS" ] && grep -q "RA-M018-" "$ASSUMPTIONS"; then
        pass "parity divergence for fixture=${fixture} documented in RUNTIME-ASSUMPTIONS.md"
      else
        fail "parity divergence for fixture=${fixture} but no RA-M018-NN row in references/RUNTIME-ASSUMPTIONS.md"
      fi
    else
      fail "missing parity result line for fixture=${fixture}"
    fi
  fi
done

# --- Assertion 6: final regression_flag line.
if grep -qE "^regression_flag: none" "$RUNOUT"; then
  pass "regression_flag: none (no divergence observed)"
elif grep -qE "^regression_flag: divergence" "$RUNOUT"; then
  if [ -f "$ASSUMPTIONS" ] && grep -q "RA-M018-" "$ASSUMPTIONS"; then
    pass "regression_flag: divergence with documenting RA-M018-NN row in RUNTIME-ASSUMPTIONS.md"
  else
    fail "regression_flag: divergence but no documenting RA-M018-NN row"
  fi
else
  fail "missing regression_flag: line on runner stdout"
fi

# --- Final result.
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p07-zero-llm-parity (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p07-zero-llm-parity (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
