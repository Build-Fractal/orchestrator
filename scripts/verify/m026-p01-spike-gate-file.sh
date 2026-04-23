#!/usr/bin/env bash
# m026-p01-spike-gate-file.sh
# Asserts: P01-SPIKE-GATE.md exists with required frontmatter, contains
# exactly one of `gate=GO` or `gate=NO-GO` on its own line, and on NO-GO
# carries an operator-visible `## Halt` section enumerating the three
# halt options (OQ-2 narrow-scope, new D-row, upstream-handoff).
# Bash 3.2 safe (MEM001). Single-script-file shape per AD-19.

set -euo pipefail

GATE=".orchestrator/milestones/M026/phases/P01/P01-SPIKE-GATE.md"
PASS=0
FAIL=0
GATE_VALUE=""

check_exists() {
  if [ ! -f "$GATE" ]; then
    echo "FAIL: gate file not found at $GATE"
    FAIL=$((FAIL + 1))
    return 1
  fi
  echo "PASS: gate file exists at $GATE"
  PASS=$((PASS + 1))
  return 0
}

check_frontmatter_key() {
  key="$1"
  expected="$2"
  actual=""
  actual=$(grep -E "^${key}:" "$GATE" | head -n 1 | sed -E "s/^${key}:[[:space:]]*//;s/[[:space:]]*$//")
  if [ "$actual" = "$expected" ]; then
    echo "PASS: frontmatter ${key} = ${expected}"
    PASS=$((PASS + 1))
    return 0
  fi
  echo "FAIL: frontmatter ${key} expected '${expected}' got '${actual}'"
  FAIL=$((FAIL + 1))
  return 1
}

check_gate_line() {
  # Exactly one line must match `^gate=GO$` or `^gate=NO-GO$`. No other
  # gate-prefix shapes permitted (DC-6 binary verdict).
  go_count=0
  nogo_count=0
  go_count=$(grep -cE '^gate=GO$' "$GATE" || true)
  nogo_count=$(grep -cE '^gate=NO-GO$' "$GATE" || true)
  total=$((go_count + nogo_count))
  if [ "$total" != "1" ]; then
    echo "FAIL: expected exactly one gate= line, got GO=${go_count} NO-GO=${nogo_count}"
    FAIL=$((FAIL + 1))
    return 1
  fi
  if [ "$go_count" = "1" ]; then
    GATE_VALUE="GO"
  else
    GATE_VALUE="NO-GO"
  fi
  echo "PASS: gate line present (gate=${GATE_VALUE})"
  PASS=$((PASS + 1))
  return 0
}

check_halt_section_when_nogo() {
  if [ "$GATE_VALUE" != "NO-GO" ]; then
    echo "PASS: gate=GO — Halt section not required"
    PASS=$((PASS + 1))
    return 0
  fi
  # On NO-GO: require ## Halt section + the three operator options.
  if ! grep -qE '^## Halt$' "$GATE"; then
    echo "FAIL: gate=NO-GO requires '## Halt' section"
    FAIL=$((FAIL + 1))
    return 1
  fi
  # Three halt-option markers per the plan's Step 7 NO-GO skeleton.
  if ! grep -qE 'OQ-2' "$GATE"; then
    echo "FAIL: NO-GO Halt section missing OQ-2 narrow-scope option"
    FAIL=$((FAIL + 1))
    return 1
  fi
  if ! grep -qE 'D-row' "$GATE"; then
    echo "FAIL: NO-GO Halt section missing new D-row option"
    FAIL=$((FAIL + 1))
    return 1
  fi
  if ! grep -qE 'CONVERSUS-PR-HANDOFF' "$GATE"; then
    echo "FAIL: NO-GO Halt section missing upstream-handoff option (CONVERSUS-PR-HANDOFF)"
    FAIL=$((FAIL + 1))
    return 1
  fi
  echo "PASS: gate=NO-GO Halt section present with all three operator options"
  PASS=$((PASS + 1))
  return 0
}

# Run all checks. Failures do not short-circuit — we want a full SUMMARY.
check_exists || true
check_frontmatter_key "schema_version" '"1.0"' || true
check_frontmatter_key "type" "spike-gate" || true
check_frontmatter_key "phase" '"P01"' || true
check_frontmatter_key "milestone" '"M026"' || true
check_gate_line || true
check_halt_section_when_nogo || true

echo "SUMMARY: pass=${PASS} fail=${FAIL}"
if [ "$FAIL" -gt "0" ]; then
  exit 1
fi
exit 0
