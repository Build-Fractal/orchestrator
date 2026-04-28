#!/usr/bin/env bash
# scripts/verify/m018-p07-tier3-routing.sh — phase-truth verifier (Truth #2):
# "Tier 3 routes through scripts/dispatch/lib/tier3-llm-call.sh under every
# runtime; the deterministic stub at
# tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh fires once per
# runtime in success mode; FR-9 failure-passthrough is preserved under
# --fail-stub mode (Tier 2's bytes pass through unchanged on stub-fail)."
#
# Drives scripts/diagnostics/m018-runtime-parity-tier3.sh end-to-end and
# asserts on its stdout under both success and --fail-stub invocations.
#
# AD-19 single-script-file shape, AP-009 compliant, bash 3.2 (MEM001),
# pass()/fail() per MEM002.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RUNNER="$REPO_ROOT/scripts/diagnostics/m018-runtime-parity-tier3.sh"
STUB="$REPO_ROOT/tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh"
ASSUMPTIONS="$REPO_ROOT/references/RUNTIME-ASSUMPTIONS.md"

PASS_COUNT=0
FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# --- Assertion 1: runner exists.
if [ -f "$RUNNER" ]; then
  pass "scripts/diagnostics/m018-runtime-parity-tier3.sh exists"
else
  fail "scripts/diagnostics/m018-runtime-parity-tier3.sh missing"
  printf 'FAIL: m018-p07-tier3-routing (cannot continue without runner)\n' >&2
  exit 1
fi

# --- Assertion 2: runner bash -n clean.
if bash -n "$RUNNER" 2>/dev/null; then
  pass "bash -n m018-runtime-parity-tier3.sh exits 0"
else
  fail "bash -n m018-runtime-parity-tier3.sh syntax errors"
fi

# --- Assertion 3: tier3-stub-llm.sh exists and is executable.
if [ -f "$STUB" ]; then
  pass "tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh exists"
else
  fail "tests/compression-runtime-parity/_stubs/tier3-stub-llm.sh missing"
fi
if [ -x "$STUB" ]; then
  pass "tier3-stub-llm.sh is executable (-x)"
else
  fail "tier3-stub-llm.sh is not executable"
fi

# --- Run the runner in success mode; capture stdout to a temp file.
TMPDIR_E="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_E"' EXIT INT TERM
RUNOUT_OK="$TMPDIR_E/runner-ok.out"
RUNOUT_FAIL="$TMPDIR_E/runner-fail.out"

bash "$RUNNER" --runtimes claude-code,codex,cursor > "$RUNOUT_OK" 2>&1
RC_OK=$?

# --- Assertion 4: success-mode runner exits 0.
if [ "$RC_OK" -eq 0 ]; then
  pass "runner --runtimes ... exits 0 (success mode)"
else
  fail "runner success-mode exit code $RC_OK (expected 0)"
fi

# --- Assertion 5: per-runtime tier3-routing routed lines.
RUNTIMES="claude-code codex cursor"
for rt in $RUNTIMES; do
  if grep -qE "^tier3-routing runtime=${rt} result=routed stub_invocations=1" "$RUNOUT_OK"; then
    pass "tier3-routing routed line: runtime=${rt} stub_invocations=1"
  else
    fail "missing tier3-routing routed line for runtime=${rt}"
  fi
done

# --- Assertion 6: success-mode summary line.
if grep -qE "^tier3-routing-parity result=all-routed" "$RUNOUT_OK"; then
  pass "tier3-routing-parity result=all-routed"
else
  fail "missing tier3-routing-parity result=all-routed line"
fi

# --- Assertion 7: success-mode regression_flag.
if grep -qE "^regression_flag: none" "$RUNOUT_OK"; then
  pass "success-mode regression_flag: none"
elif grep -qE "^regression_flag: divergence" "$RUNOUT_OK"; then
  if [ -f "$ASSUMPTIONS" ] && grep -q "RA-M018-" "$ASSUMPTIONS"; then
    pass "success-mode regression_flag: divergence with documenting RA-M018-NN row"
  else
    fail "success-mode regression_flag: divergence without documenting RA-M018-NN row"
  fi
else
  fail "missing regression_flag: line in success-mode stdout"
fi

# --- Run the runner in --fail-stub mode.
bash "$RUNNER" --runtimes claude-code,codex,cursor --fail-stub > "$RUNOUT_FAIL" 2>&1
RC_FAIL=$?

# --- Assertion 8: fail-stub runner exits 0 (FR-9 always-exit-0 advisory).
if [ "$RC_FAIL" -eq 0 ]; then
  pass "runner --fail-stub exits 0 (FR-9 failure-passthrough preserved)"
else
  fail "runner fail-stub exit code $RC_FAIL (expected 0)"
fi

# --- Assertion 9: per-runtime stub_fail passthrough lines.
for rt in $RUNTIMES; do
  if grep -qE "^tier3-routing runtime=${rt} stub_fail=1.*passthrough=ok" "$RUNOUT_FAIL"; then
    pass "tier3-routing fail-stub line: runtime=${rt} passthrough=ok"
  else
    fail "missing tier3-routing fail-stub passthrough line for runtime=${rt}"
  fi
done

# --- Final result.
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'PASS: m018-p07-tier3-routing (%d assertions)\n' "$PASS_COUNT"
  exit 0
fi
printf 'FAIL: m018-p07-tier3-routing (%d failed of %d)\n' "$FAIL_COUNT" "$((PASS_COUNT + FAIL_COUNT))" >&2
exit 1
