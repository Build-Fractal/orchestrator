#!/usr/bin/env bash
# scripts/verify/m011-p07-intensity-ingest-stage.sh
#
# Asserts that scripts/engine/intensity-gate.sh registers the `ingest`
# stage with the documented policy matrix:
#   Quick    -> execute=normalize,                 skip=fidelity-gate
#   Standard -> execute=normalize,fidelity-gate    skip=none
#   Full     -> execute=normalize,fidelity-gate    skip=none
# Also asserts that an invalid intensity is rejected with non-zero exit.
#
# Bash 3.2 compatible (MEM001). Single-script-file invokable (AD-19).

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$REPO_ROOT/scripts/engine/intensity-gate.sh"

pass_count=0
fail_count=0

emit_pass() {
  echo "PASS: $1"
  pass_count=$((pass_count + 1))
}

emit_fail() {
  echo "FAIL: $1"
  fail_count=$((fail_count + 1))
}

# 1. Gate script exists.
if [ -f "$GATE" ]; then
  emit_pass "intensity-gate.sh exists at $GATE"
else
  emit_fail "intensity-gate.sh missing at $GATE"
  echo "SUMMARY: pass=$pass_count fail=$fail_count"
  exit 1
fi

# 2. `ingest)` case label present.
if grep -Fq -- 'ingest)' "$GATE"; then
  emit_pass "intensity-gate.sh contains 'ingest)' case label"
else
  emit_fail "intensity-gate.sh missing 'ingest)' case label"
fi

# 3-5. Run gate for each intensity, capture stdout, assert exact lines.
TMP_OUT="$(mktemp -t m011p07-gate.XXXXXX)"
trap 'rm -f "$TMP_OUT"' EXIT

assert_gate_output() {
  intensity="$1"
  expected_exec="$2"
  expected_skip="$3"
  label="$4"

  if bash "$GATE" --stage ingest --intensity "$intensity" >"$TMP_OUT" 2>/dev/null; then
    :
  else
    emit_fail "$label: gate exited non-zero for intensity=$intensity"
    return
  fi

  # Exact-match check via grep -Fxq (fixed-string, full line).
  if grep -Fxq -- "execute_substeps=$expected_exec" "$TMP_OUT"; then
    emit_pass "$label: execute_substeps=$expected_exec"
  else
    emit_fail "$label: expected 'execute_substeps=$expected_exec', got: $(grep -E '^execute_substeps=' "$TMP_OUT" || echo '<missing>')"
  fi

  if grep -Fxq -- "skip_substeps=$expected_skip" "$TMP_OUT"; then
    emit_pass "$label: skip_substeps=$expected_skip"
  else
    emit_fail "$label: expected 'skip_substeps=$expected_skip', got: $(grep -E '^skip_substeps=' "$TMP_OUT" || echo '<missing>')"
  fi
}

assert_gate_output "Quick"    "normalize"               "fidelity-gate" "ingest stage Quick"
assert_gate_output "Standard" "normalize,fidelity-gate" "none"          "ingest stage Standard"
assert_gate_output "Full"     "normalize,fidelity-gate" "none"          "ingest stage Full"

# 6. Invalid intensity must be rejected (non-zero exit).
if bash "$GATE" --stage ingest --intensity Bogus >/dev/null 2>&1; then
  emit_fail "invalid intensity 'Bogus' unexpectedly accepted"
else
  emit_pass "invalid intensity 'Bogus' rejected with non-zero exit"
fi

echo "SUMMARY: pass=$pass_count fail=$fail_count"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
