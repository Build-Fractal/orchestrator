#!/usr/bin/env bash
# tests/test-dead-infra-knobs.sh -- Regression + mutation coverage for the
# dead-infrastructure linter at scripts/diagnostics/check-dead-infra.sh.
#
# Four cases (mirrors the conversus sister-project test shape):
#   1. Live baseline: shipped template + scripts/ tree must report 0 dead.
#   2. Mutation: inject a synthetic dead knob into a temp template; linter
#      must flag it.
#   3. Consumer escape hatch: same synthetic knob with a `# consumer:`
#      annotation immediately above; linter must NOT flag it.
#   4. Generic leaf skip: a `mode:` sub-key with no reader and no
#      annotation must NOT be flagged (it's in the generic skiplist).
#
# Emits BATTERY: pass=N fail=N skip=N as last stdout line.
# Exit 0 iff fail=0.
#
# Bash 3.2 per CON-2. Single-script-file shape.
set -eu

ROOT="${ORCHESTRATOR_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
LINTER="$ROOT/scripts/diagnostics/check-dead-infra.sh"
WS="$(mktemp -d "${TMPDIR:-/tmp}/dead-infra-test.XXXXXX")"
trap 'rm -rf "$WS"' EXIT

pass=0
fail=0
skip=0

step_pass() { echo "PASS: $1"; pass=$((pass + 1)); }
step_fail() { echo "FAIL: $1"; fail=$((fail + 1)); }

if [ ! -f "$LINTER" ]; then
  step_fail "linter missing: $LINTER"
  echo "BATTERY: pass=$pass fail=$fail skip=$skip"
  exit 1
fi

# --- Case 1: live baseline must be clean ---
if bash "$LINTER" >"$WS/baseline.out" 2>"$WS/baseline.err"; then
  step_pass "live template + scripts/ baseline reports 0 dead knobs"
else
  step_fail "live baseline reported dead knobs:"
  sed -e 's/^/    /' "$WS/baseline.err" >&2
fi

# --- Case 2: synthetic dead knob is flagged ---
# Build a self-contained tree (template + empty scripts/) so the linter's
# search runs against a knob with provably zero readers.
mkdir -p "$WS/case2/templates" "$WS/case2/scripts" "$WS/case2/commands" "$WS/case2/references"
cat > "$WS/case2/templates/orchestrator-config-default.yml" <<'YAML'
fake_unread_knob_for_test: 42
YAML

if ORCHESTRATOR_ROOT="$WS/case2" bash "$LINTER" >"$WS/case2.out" 2>"$WS/case2.err"; then
  step_fail "synthetic dead knob was NOT flagged (linter exited 0)"
else
  if grep -qF "fake_unread_knob_for_test" "$WS/case2.err"; then
    step_pass "synthetic dead knob flagged in stderr"
  else
    step_fail "synthetic dead knob: linter exited non-zero but stderr lacks the leaf name"
    sed -e 's/^/    /' "$WS/case2.err" >&2
  fi
fi

# --- Case 3: consumer annotation exempts ---
mkdir -p "$WS/case3/templates" "$WS/case3/scripts" "$WS/case3/commands" "$WS/case3/references"
cat > "$WS/case3/templates/orchestrator-config-default.yml" <<'YAML'
# consumer: engine.test_consumer -- explicit attribution for the lint test
fake_orchestrator_only_knob: 7
YAML

if ORCHESTRATOR_ROOT="$WS/case3" bash "$LINTER" >"$WS/case3.out" 2>"$WS/case3.err"; then
  step_pass "consumer-annotated knob is NOT flagged"
else
  step_fail "consumer-annotated knob was flagged anyway:"
  sed -e 's/^/    /' "$WS/case3.err" >&2
fi

# --- Case 4: generic leaf (`mode`) under a sub-block is skipped ---
mkdir -p "$WS/case4/templates" "$WS/case4/scripts" "$WS/case4/commands" "$WS/case4/references"
cat > "$WS/case4/templates/orchestrator-config-default.yml" <<'YAML'
fake_block:
  mode: null
YAML

if ORCHESTRATOR_ROOT="$WS/case4" bash "$LINTER" >"$WS/case4.out" 2>"$WS/case4.err"; then
  step_pass "generic leaf 'mode' under a sub-block is skipped"
else
  step_fail "generic leaf 'mode' was flagged despite skiplist:"
  sed -e 's/^/    /' "$WS/case4.err" >&2
fi

# --- Case 5: verbose mode emits per-leaf trace ---
if bash "$LINTER" --verbose >"$WS/verbose.out" 2>"$WS/verbose.err"; then
  if grep -qE '^[[:space:]]*\+ ' "$WS/verbose.out"; then
    step_pass "verbose mode emits per-leaf trace"
  else
    step_fail "verbose mode produced no trace lines"
  fi
else
  step_fail "verbose mode exited non-zero on clean baseline"
fi

echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
