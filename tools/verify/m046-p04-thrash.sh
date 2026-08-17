#!/usr/bin/env sh
# m046-p04-thrash.sh -- M046 FR-12 / SC-7 / FR-17 thrash-halt harness.
#
# Drives the REAL driver (scripts/lifecycle/self-continue-drive.sh) + REAL
# envelope (scripts/lifecycle/unattended-envelope.sh) end-to-end. The only
# substitution is the LLM child: a live shell stand-in emitting a real
# continue-class outcome marker each segment. NO seeded markers, NO fabricated
# terminal, NO seeded THRASH line.
#
# SC-7 core (Case 1): a no-progress fixture -- the child exits continue-class
# (rotation) every segment but writes the SAME phase word (P01) forever, so the
# driver's forward-progress counter never advances. Under --unattended the
# driver halts on SELF_CONTINUE:THRASH after the default 2 no-progress segments,
# WELL BEFORE the generous iteration (10) / budget ($50) / wall-clock (120s)
# caps -- the "before caps" clause of SC-7 (NO CAP_REACHED / BUDGET_EXCEEDED /
# WALL_CLOCK_EXCEEDED may appear).
#
# Case 2 pins FR-17 (thrash is unattended-only): the SAME no-progress fixture
# WITHOUT --unattended runs to SELF_CONTINUE:CAP_REACHED with NO THRASH line.
#
# Case 3 pins the progress-reset semantics: a child that advances the phase word
# every segment (P01, P02, P03, ... via a persisted counter) never accrues a
# no-progress segment, so no_prog never reaches the threshold -- the run reaches
# CAP_REACHED with NO THRASH even under --unattended.
#
# Portability: POSIX sh, bash-3.2-safe. No jq. All fixture trees in mktemp
# scratch -- nothing under the repo or .orchestrator/.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVER="$REPO_ROOT/scripts/lifecycle/self-continue-drive.sh"
ENVELOPE="$REPO_ROOT/scripts/lifecycle/unattended-envelope.sh"

[ -f "$DRIVER" ] || { echo "FAIL: driver not found: $DRIVER"; exit 1; }
[ -f "$ENVELOPE" ] || { echo "FAIL: envelope lib not found: $ENVELOPE"; exit 1; }

passes=0
fails=0
pass() { echo "PASS: $1"; passes=$((passes + 1)); }
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# ===========================================================================
# Case 1 -- THRASH before caps (SC-7 core).
#   Stub: same phase word (rotation P01) every invocation -> progress can never
#   advance past segment 1. Generous caps (cont 10, budget $50, wall 120s) so
#   nothing but the thrash guard can halt the loop.
# ===========================================================================
MT1="$scratch/MT1"; mkdir -p "$MT1"
STUBT1="$scratch/stub-noprog.sh"
printf '#!/usr/bin/env sh\nOM="%s"\n' "$MT1/.self-continue-outcome" > "$STUBT1"
cat >> "$STUBT1" <<'CHILDEOF'
printf 'rotation P01\n' > "$OM"
printf '{"total_cost_usd":0.01}\n'
exit 0
CHILDEOF
chmod +x "$STUBT1"
rc1=0
sh "$DRIVER" "$MT1" --unattended --max-budget-usd 50 --max-continuations 10 \
  --max-wall-clock-s 120 --min-interval 0 --watchdog-poll-s 1 \
  --auto-cmd "sh $STUBT1" > "$scratch/out1.txt" 2>/dev/null || rc1=$?
out1="$scratch/out1.txt"
sched1=$(grep -c "SELF_CONTINUE:SCHEDULED" "$out1" 2>/dev/null || echo 0)

c1_ok=1
grep -q "SELF_CONTINUE:THRASH" "$out1" || { c1_ok=0; echo "  (1) missing SELF_CONTINUE:THRASH terminal"; }
grep -q "SELF_CONTINUE:THRASH.*threshold=2" "$out1" || { c1_ok=0; echo "  (1) THRASH line missing threshold=2"; }
[ "$sched1" -le 3 ] || { c1_ok=0; echo "  (1) SCHEDULED count $sched1 > 3 -- halted too late for a 2-segment threshold"; }
if grep -Eq "CAP_REACHED|BUDGET_EXCEEDED|WALL_CLOCK_EXCEEDED" "$out1"; then
  c1_ok=0; echo "  (1) a cap terminal fired -- thrash did not halt BEFORE the generous caps"
fi
[ "$rc1" -eq 0 ] || { c1_ok=0; echo "  (1) driver exit $rc1 != 0"; }
if [ "$c1_ok" -eq 1 ]; then
  pass "case=1 no-progress fixture halts on THRASH threshold=2 after $sched1 SCHEDULED segment(s), before generous caps (no CAP/BUDGET/WALL_CLOCK)"
else
  fail "case=1 rc=$rc1 sched=$sched1 output='$(cat "$out1")'"
fi

# ===========================================================================
# Case 2 -- attended control (FR-17: thrash is unattended-only).
#   SAME no-progress stub, driver WITHOUT --unattended, --max-continuations 3.
#   The thrash guard does not exist on the attended path, so the loop runs to
#   the ordinary CAP_REACHED with NO THRASH line.
# ===========================================================================
MT2="$scratch/MT2"; mkdir -p "$MT2"
STUBT2="$scratch/stub-noprog2.sh"
printf '#!/usr/bin/env sh\nOM="%s"\n' "$MT2/.self-continue-outcome" > "$STUBT2"
cat >> "$STUBT2" <<'CHILDEOF'
printf 'rotation P01\n' > "$OM"
printf '{"total_cost_usd":0.01}\n'
exit 0
CHILDEOF
chmod +x "$STUBT2"
rc2=0
sh "$DRIVER" "$MT2" --max-continuations 3 --min-interval 0 \
  --auto-cmd "sh $STUBT2" > "$scratch/out2.txt" 2>/dev/null || rc2=$?
out2="$scratch/out2.txt"

c2_ok=1
grep -q "SELF_CONTINUE:CAP_REACHED" "$out2" || { c2_ok=0; echo "  (2) missing CAP_REACHED"; }
if grep -q "SELF_CONTINUE:THRASH" "$out2"; then
  c2_ok=0; echo "  (2) THRASH fired on the ATTENDED path -- thrash is not unattended-only"
fi
[ "$rc2" -eq 0 ] || { c2_ok=0; echo "  (2) driver exit $rc2 != 0"; }
if [ "$c2_ok" -eq 1 ]; then
  pass "case=2 attended control: same no-progress fixture reaches CAP_REACHED with NO THRASH (thrash is unattended-only, FR-17)"
else
  fail "case=2 rc=$rc2 output='$(cat "$out2")'"
fi

# ===========================================================================
# Case 3 -- progress resets the counter.
#   Stub advances the phase word every segment (rotation P01, P02, P03, ... via
#   a persisted counter). Because every segment advances progress, no_prog is
#   reset to 0 each time and never reaches the threshold -- the run reaches
#   CAP_REACHED with NO THRASH even under --unattended (threshold 2, cont 3).
# ===========================================================================
MT3="$scratch/MT3"; mkdir -p "$MT3"
CTR3="$scratch/ctr3"
STUBT3="$scratch/stub-progress.sh"
printf '#!/usr/bin/env sh\nOM="%s"\nCTR="%s"\n' \
  "$MT3/.self-continue-outcome" "$CTR3" > "$STUBT3"
cat >> "$STUBT3" <<'CHILDEOF'
n=0
[ -f "$CTR" ] && n=$(cat "$CTR")
n=$((n + 1))
printf '%s' "$n" > "$CTR"
printf 'rotation P0%s\n' "$n" > "$OM"
printf '{"total_cost_usd":0.01}\n'
exit 0
CHILDEOF
chmod +x "$STUBT3"
rc3=0
sh "$DRIVER" "$MT3" --unattended --max-budget-usd 50 --max-continuations 3 \
  --max-wall-clock-s 120 --min-interval 0 --watchdog-poll-s 1 \
  --thrash-threshold 2 --auto-cmd "sh $STUBT3" > "$scratch/out3.txt" 2>/dev/null || rc3=$?
out3="$scratch/out3.txt"

c3_ok=1
grep -q "SELF_CONTINUE:CAP_REACHED" "$out3" || { c3_ok=0; echo "  (3) missing CAP_REACHED"; }
if grep -q "SELF_CONTINUE:THRASH" "$out3"; then
  c3_ok=0; echo "  (3) THRASH fired despite every segment advancing the phase word -- progress did not reset no_prog"
fi
[ "$rc3" -eq 0 ] || { c3_ok=0; echo "  (3) driver exit $rc3 != 0"; }
if [ "$c3_ok" -eq 1 ]; then
  pass "case=3 progress-reset: every segment advances the phase word, no_prog never reaches 2, run reaches CAP_REACHED with NO THRASH (unattended, threshold 2)"
else
  fail "case=3 rc=$rc3 output='$(cat "$out3")'"
fi

echo "SUMMARY: pass=$passes fail=$fails"
if [ "$fails" -eq 0 ]; then
  exit 0
else
  exit 1
fi
