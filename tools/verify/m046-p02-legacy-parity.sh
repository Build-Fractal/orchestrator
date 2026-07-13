#!/usr/bin/env sh
# m046-p02-legacy-parity.sh (M046 FR-17)
# With the marker gate absent, auto-loop.sh stdout and exit code are
# byte-identical to the pinned legacy golden and NO marker file is written.
# With the gate present (ORCHESTRATOR_SELF_CONTINUE_MARKER=1), stdout stays
# byte-identical and only the marker side effect is added.
# Runs against a scratch copy of the checked-in fixture tree (auto-loop
# mutates milestone trees; never point it at tests/fixtures/ directly).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AUTO_LOOP="$REPO_ROOT/scripts/lifecycle/auto-loop.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/m046-p02/verifying-tree/MFIX"
GOLDEN="$REPO_ROOT/tests/fixtures/m046-p02/legacy-parity.golden"

fails=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }

[ -f "$AUTO_LOOP" ] || { echo "FAIL: auto-loop.sh not found: $AUTO_LOOP"; exit 1; }
[ -d "$FIXTURE" ]   || { echo "FAIL: fixture tree not found: $FIXTURE"; exit 1; }
[ -f "$GOLDEN" ]    || { echo "FAIL: golden not found: $GOLDEN"; exit 1; }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# --- Leg 1: gate OFF — byte-identical legacy behavior, no marker ---
cp -R "$FIXTURE" "$scratch/MFIX"
rc=0
env -u ORCHESTRATOR_SELF_CONTINUE_MARKER \
  bash "$AUTO_LOOP" "$scratch/MFIX" >"$scratch/stdout-off.txt" 2>/dev/null || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "leg1 gate-off exit code 0"
else
  fail "leg1 gate-off exit code: expected 0, got $rc"
fi

if cmp -s "$scratch/stdout-off.txt" "$GOLDEN"; then
  pass "leg1 gate-off stdout byte-equal to golden"
else
  fail "leg1 gate-off stdout drifted from golden (expected: $(cat "$GOLDEN"); actual: $(cat "$scratch/stdout-off.txt"))"
fi

if [ ! -e "$scratch/MFIX/.self-continue-outcome" ]; then
  pass "leg1 gate-off wrote no marker file"
else
  fail "leg1 gate-off wrote a marker file: $(cat "$scratch/MFIX/.self-continue-outcome")"
fi

# --- Leg 2: gate ON — stdout unchanged, marker side effect added ---
rm -rf "$scratch/MFIX"
cp -R "$FIXTURE" "$scratch/MFIX"
rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$scratch/MFIX" >"$scratch/stdout-on.txt" 2>/dev/null || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "leg2 gate-on exit code 0"
else
  fail "leg2 gate-on exit code: expected 0, got $rc"
fi

if cmp -s "$scratch/stdout-on.txt" "$GOLDEN"; then
  pass "leg2 gate-on stdout byte-equal to the SAME golden"
else
  fail "leg2 gate-on stdout drifted from golden (expected: $(cat "$GOLDEN"); actual: $(cat "$scratch/stdout-on.txt"))"
fi

marker="$scratch/MFIX/.self-continue-outcome"
if [ -f "$marker" ] && [ "$(cat "$marker")" = "phase_complete P01" ]; then
  pass "leg2 gate-on marker content is exactly 'phase_complete P01'"
else
  if [ -f "$marker" ]; then
    fail "leg2 gate-on marker content: expected 'phase_complete P01', got '$(cat "$marker")'"
  else
    fail "leg2 gate-on marker file missing"
  fi
fi

if [ "$fails" -eq 0 ]; then
  echo "PASS: m046-p02-legacy-parity — 6/6 assertions green (FR-17 byte parity holds)"
  exit 0
else
  echo "FAIL: m046-p02-legacy-parity — $fails assertion(s) failed"
  exit 1
fi
