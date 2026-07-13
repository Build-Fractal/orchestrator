#!/usr/bin/env sh
# m046-p02-child-abort.sh (M046 FR-14 / SC-9 kill leg + M045 parity)
# Kill/crash/stall cases through the REAL driver
# (scripts/lifecycle/self-continue-drive.sh) with the real run_child wrapper.
# The stubs here are kill/crash stand-ins ONLY — the surface under test is the
# driver's CHILD_RC truth table, not the loop (the loop's own exit contract is
# covered non-stubbed by m046-p02-marker-exit-contract.sh):
#   rc>=128            → overwrite any marker with child_abort (mid-segment
#                        stale markers must not survive a signal kill)
#   rc 1..127, no mark → child crashed before reporting → child_abort
#   rc 1..127, marker  → keep auto-loop's exit-keyed marker (authoritative)
#   rc 0, no marker    → M045 STALLED path preserved (never fabricate abort)
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVER="$REPO_ROOT/scripts/lifecycle/self-continue-drive.sh"

[ -f "$DRIVER" ] || { echo "FAIL: driver not found: $DRIVER"; exit 1; }

passes=0
fails=0

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

MDIR="$scratch/M"
mkdir -p "$MDIR"
MARKER="$MDIR/.self-continue-outcome"

run_driver() {
  # run_driver <stub-path> — real driver, one segment max, output to $OUT
  OUT="$scratch/driver-out.txt"
  DRC=0
  sh "$DRIVER" "$MDIR" --min-interval 0 --max-continuations 1 \
    --auto-cmd "sh $1" >"$OUT" 2>/dev/null || DRC=$?
}

# --- Case 1: kill-self — deterministic mid-flight SIGKILL (rc=137) ---
STUB="$scratch/stub-kill-self.sh"
printf '#!/usr/bin/env sh\nkill -9 $$\n' > "$STUB"
chmod +x "$STUB"
rm -f "$MARKER"
run_driver "$STUB"
if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "child_abort" ] \
   && grep -q "SELF_CONTINUE:CHILD_ABORT rc=137" "$OUT"; then
  echo "PASS: case=kill-self marker=child_abort, distinct CHILD_ABORT rc=137 terminal"
  passes=$((passes + 1))
else
  echo "FAIL: case=kill-self marker='$(cat "$MARKER" 2>/dev/null || echo ABSENT)' output='$(cat "$OUT")'"
  fails=$((fails + 1))
fi

# --- Case 2: kill-after-marker — stale mid-segment marker OVERWRITTEN ---
STUB="$scratch/stub-kill-after-marker.sh"
printf '#!/usr/bin/env sh\nprintf "rotation P01\\n" > "%s"\nkill -9 $$\n' "$MARKER" > "$STUB"
chmod +x "$STUB"
rm -f "$MARKER"
run_driver "$STUB"
if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "child_abort" ] \
   && grep -q "SELF_CONTINUE:CHILD_ABORT rc=137" "$OUT" \
   && ! grep -q "SELF_CONTINUE:SCHEDULED" "$OUT"; then
  echo "PASS: case=kill-after-marker stale 'rotation P01' overwritten to child_abort, no re-spawn"
  passes=$((passes + 1))
else
  echo "FAIL: case=kill-after-marker marker='$(cat "$MARKER" 2>/dev/null || echo ABSENT)' output='$(cat "$OUT")'"
  fails=$((fails + 1))
fi

# --- Case 3: crash-no-marker — rc=3, nothing written → child_abort ---
STUB="$scratch/stub-crash.sh"
printf '#!/usr/bin/env sh\nexit 3\n' > "$STUB"
chmod +x "$STUB"
rm -f "$MARKER"
run_driver "$STUB"
if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "child_abort" ] \
   && grep -q "SELF_CONTINUE:CHILD_ABORT rc=3" "$OUT"; then
  echo "PASS: case=crash-no-marker marker=child_abort, distinct CHILD_ABORT rc=3 terminal"
  passes=$((passes + 1))
else
  echo "FAIL: case=crash-no-marker marker='$(cat "$MARKER" 2>/dev/null || echo ABSENT)' output='$(cat "$OUT")'"
  fails=$((fails + 1))
fi

# --- Case 4: error-exit-with-marker — rc=5 WITH marker → marker kept ---
# The 1..127-with-marker row: real auto-loop error exits (budget/stuck/...)
# must keep their exit-keyed marker so the distinct terminal fires.
STUB="$scratch/stub-error-with-marker.sh"
printf '#!/usr/bin/env sh\nprintf "budget\\n" > "%s"\nexit 5\n' "$MARKER" > "$STUB"
chmod +x "$STUB"
rm -f "$MARKER"
run_driver "$STUB"
if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "budget" ] \
   && grep -q "SELF_CONTINUE:TERMINAL outcome=budget" "$OUT" \
   && ! grep -q "SELF_CONTINUE:CHILD_ABORT" "$OUT"; then
  echo "PASS: case=error-exit-with-marker marker stays budget, TERMINAL outcome=budget"
  passes=$((passes + 1))
else
  echo "FAIL: case=error-exit-with-marker marker='$(cat "$MARKER" 2>/dev/null || echo ABSENT)' output='$(cat "$OUT")'"
  fails=$((fails + 1))
fi

# --- Case 5: clean-no-marker — rc=0, nothing written → STALLED (M045 parity) ---
STUB="$scratch/stub-clean.sh"
printf '#!/usr/bin/env sh\nexit 0\n' > "$STUB"
chmod +x "$STUB"
rm -f "$MARKER"
run_driver "$STUB"
if grep -q "SELF_CONTINUE:STALLED" "$OUT" \
   && ! grep -q "SELF_CONTINUE:CHILD_ABORT" "$OUT" \
   && [ ! -f "$MARKER" ]; then
  echo "PASS: case=clean-no-marker STALLED preserved, no fabricated child_abort"
  passes=$((passes + 1))
else
  echo "FAIL: case=clean-no-marker marker='$(cat "$MARKER" 2>/dev/null || echo ABSENT)' output='$(cat "$OUT")'"
  fails=$((fails + 1))
fi

echo "SUMMARY: pass=$passes fail=$fails"
if [ "$fails" -eq 0 ]; then
  exit 0
else
  exit 1
fi
