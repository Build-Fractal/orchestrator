#!/usr/bin/env sh
# m046-p02-marker-unit.sh (M046 FR-14)
# Unit-grain direct invocations of the REAL scripts/lifecycle/auto-loop.sh
# asserting the deterministic outcome-marker write keyed to exit code
# (+ exit-0 substate) under ORCHESTRATOR_SELF_CONTINUE_MARKER=1, plus a
# gate-off negative. Every case runs against a fresh scratch copy of the
# checked-in fixture tree (auto-loop mutates milestone trees).
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
AUTO_LOOP="$REPO_ROOT/scripts/lifecycle/auto-loop.sh"
FIXTURE="$REPO_ROOT/tests/fixtures/m046-p02/verifying-tree/MFIX"

fails=0
passes=0
pass() { echo "PASS: $1"; passes=$((passes + 1)); }
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }

[ -f "$AUTO_LOOP" ] || { echo "FAIL: auto-loop.sh not found: $AUTO_LOOP"; exit 1; }
[ -d "$FIXTURE" ]   || { echo "FAIL: fixture tree not found: $FIXTURE"; exit 1; }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# fresh_tree — reset the scratch MFIX tree from the checked-in fixture
fresh_tree() {
  rm -rf "$scratch/MFIX"
  cp -R "$FIXTURE" "$scratch/MFIX"
  rm -f "$scratch/MFIX/.self-continue-outcome"
}

# assert_case <name> <expected-rc> <actual-rc> <expected-marker|ABSENT>
assert_case() {
  _name="$1"; _want_rc="$2"; _got_rc="$3"; _want_marker="$4"
  _marker_file="$scratch/MFIX/.self-continue-outcome"
  if [ "$_got_rc" -ne "$_want_rc" ]; then
    fail "$_name: expected exit $_want_rc, got $_got_rc"
    return 0
  fi
  if [ "$_want_marker" = "ABSENT" ]; then
    if [ -e "$_marker_file" ]; then
      fail "$_name: expected NO marker, found '$(cat "$_marker_file")'"
    else
      pass "$_name: exit $_got_rc, no marker written"
    fi
    return 0
  fi
  if [ ! -f "$_marker_file" ]; then
    fail "$_name: marker file missing (expected '$_want_marker')"
    return 0
  fi
  _got_marker="$(cat "$_marker_file")"
  if [ "$_got_marker" = "$_want_marker" ]; then
    pass "$_name: exit $_got_rc, marker '$_got_marker'"
  else
    fail "$_name: marker content: expected '$_want_marker', got '$_got_marker'"
  fi
}

# --- Case 1: phase_complete — unmodified tree, exit 0 + AUTO:PHASE_COMPLETE ---
fresh_tree
rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$scratch/MFIX" >/dev/null 2>&1 || rc=$?
assert_case "phase_complete" 0 "$rc" "phase_complete P01"

# --- Case 2: error — --step=G missing --task, exit 1 ---
fresh_tree
rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$scratch/MFIX" --step=G >/dev/null 2>&1 || rc=$?
assert_case "error" 1 "$rc" "error"

# --- Case 3: pause — pause-requested file, exit 11 ---
fresh_tree
touch "$scratch/MFIX/pause-requested"
rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$scratch/MFIX" >/dev/null 2>&1 || rc=$?
assert_case "pause" 11 "$rc" "pause"

# --- Case 4: unexpected_state — roadmap checked but no P01-SUMMARY.md (drift), exit 12 ---
fresh_tree
sed 's/- \[ \] \*\*P01\*\*/- [x] **P01**/' "$scratch/MFIX/MFIX-ROADMAP.md" > "$scratch/MFIX/MFIX-ROADMAP.md.new"
mv "$scratch/MFIX/MFIX-ROADMAP.md.new" "$scratch/MFIX/MFIX-ROADMAP.md"
rc=0
env ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
  bash "$AUTO_LOOP" "$scratch/MFIX" >/dev/null 2>&1 || rc=$?
assert_case "unexpected_state" 12 "$rc" "unexpected_state"

# --- Case 5: gate-off negative — pause case WITHOUT the env var, no marker ---
fresh_tree
touch "$scratch/MFIX/pause-requested"
rc=0
env -u ORCHESTRATOR_SELF_CONTINUE_MARKER \
  bash "$AUTO_LOOP" "$scratch/MFIX" >/dev/null 2>&1 || rc=$?
assert_case "gate-off-negative" 11 "$rc" "ABSENT"

if [ "$fails" -eq 0 ]; then
  echo "PASS: m046-p02-marker-unit — $passes/5 cases green"
  exit 0
else
  echo "FAIL: m046-p02-marker-unit — $fails case(s) failed ($passes passed)"
  exit 1
fi
