#!/usr/bin/env sh
# m046-p04-wall-clock.sh -- M046 FR-7 / FR-13 / D016 wall-clock ceiling harness.
#
# Drives the REAL driver (scripts/lifecycle/self-continue-drive.sh) + REAL
# envelope watchdog (scripts/lifecycle/unattended-envelope.sh) end-to-end. The
# only substitution is the LLM child: a live shell stand-in. NO seeded markers,
# NO fabricated kill-reason file, NO seeded terminal.
#
# The D016 resolution derives BOTH enforcement legs from one DEADLINE_EPOCH:
#
#   Case 1 -- mid-segment kill: a live segment that outlives the wall-clock
#   ceiling is SIGKILLed by the watchdog with SELF_CONTINUE:WALL_CLOCK_EXCEEDED
#   stage=mid-segment, carrying the elapsed_s= / cap_s= reason fields (the driver
#   passes RUN_START_EPOCH as the watchdog's start-epoch arg). This is the
#   INVERSE of SC-3's anti-proxy leg: the budget cap is generous ($50) and the
#   child emits NO cost records, so the budget trigger is impossible by
#   construction -- the DURATION trigger produces the WALL_CLOCK terminal and
#   never the budget one. Distinctness: NO BUDGET_EXCEEDED / THRASH / CHILD_ABORT.
#
#   Case 2 -- pre-spawn refusal: a run whose ceiling is crossed BETWEEN segments
#   halts at the driver's top-of-loop pre-spawn wall check with
#   SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=pre-spawn (again elapsed_s= / cap_s=),
#   the child never re-spawns past the ceiling, and NO CAP_REACHED fires (the
#   continuation cap is generous at 50). The fast child advances the phase word
#   each segment so THRASH never fires.
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
# Case 1 -- mid-segment wall-clock kill.
#   Child: sleep 10 (well past the 3s ceiling), then touch natural-end + marker
#   + JSON. Ceiling 3s; the watchdog SIGKILLs mid-sleep ~3-4s in. Generous $50
#   budget + zero cost records makes the budget trigger impossible -- the kill
#   is duration-derived.
# ===========================================================================
MW1="$scratch/MW1"; mkdir -p "$MW1"
STUBW1="$scratch/stub-sleep10.sh"
printf '#!/usr/bin/env sh\nNE="%s"\nOM="%s"\n' \
  "$MW1/natural-end" "$MW1/.self-continue-outcome" > "$STUBW1"
cat >> "$STUBW1" <<'CHILDEOF'
sleep 10
touch "$NE"
printf 'complete\n' > "$OM"
printf '{"total_cost_usd":0.01}\n'
exit 0
CHILDEOF
chmod +x "$STUBW1"
t0=$(date +%s)
rc1=0
sh "$DRIVER" "$MW1" --unattended --max-budget-usd 50 --max-continuations 5 \
  --max-wall-clock-s 3 --min-interval 0 --watchdog-poll-s 1 \
  --auto-cmd "sh $STUBW1" > "$scratch/out1.txt" 2>/dev/null || rc1=$?
t1=$(date +%s)
elapsed1=$((t1 - t0))
out1="$scratch/out1.txt"
LEDGER1="$MW1/.self-continue-budget-ledger"

c1_ok=1
grep -q "SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=mid-segment" "$out1" \
  || { c1_ok=0; echo "  (1) missing WALL_CLOCK_EXCEEDED stage=mid-segment terminal"; }
grep -q "WALL_CLOCK_EXCEEDED.*elapsed_s=" "$out1" \
  || { c1_ok=0; echo "  (1) WALL_CLOCK line missing elapsed_s= reason field"; }
grep -q "WALL_CLOCK_EXCEEDED.*cap_s=3" "$out1" \
  || { c1_ok=0; echo "  (1) WALL_CLOCK line missing cap_s=3 reason field"; }
[ "$elapsed1" -le 8 ] \
  || { c1_ok=0; echo "  (1) elapsed ${elapsed1}s > 8s -- kill did not land mid-segment (child natural 10s)"; }
[ ! -f "$MW1/natural-end" ] \
  || { c1_ok=0; echo "  (1) natural-end present -- child finished instead of being killed"; }
if grep -Eq "BUDGET_EXCEEDED|SELF_CONTINUE:THRASH|SELF_CONTINUE:CHILD_ABORT" "$out1"; then
  c1_ok=0; echo "  (1) a non-wall-clock terminal leaked -- wall-clock terminal not distinct"
fi
grep -q "^forfeit segment=1 " "$LEDGER1" \
  || { c1_ok=0; echo "  (1) ledger missing forfeit segment=1 (killed child's reserve counted as spent)"; }
[ "$rc1" -eq 0 ] || { c1_ok=0; echo "  (1) driver exit $rc1 != 0"; }
if [ "$c1_ok" -eq 1 ]; then
  pass "case=1 mid-segment wall-clock kill: WALL_CLOCK_EXCEEDED stage=mid-segment (elapsed_s= cap_s=3) within ${elapsed1}s, natural-end absent, distinct from budget/thrash/abort, forfeit segment=1"
else
  fail "case=1 elapsed=${elapsed1}s rc=$rc1 output='$(cat "$out1")' ledger='$(cat "$LEDGER1" 2>/dev/null || echo ABSENT)'"
fi

# ===========================================================================
# Case 2 -- pre-spawn refusal (between-segment ceiling).
#   Fast child (~0.3s): advances the phase word each segment (rotation P01, P02,
#   ... via a persisted counter, so THRASH never fires), prints JSON, exits 0.
#   Ceiling 2s; the continuation cap (50) is generous. Segments respawn until
#   run-elapsed crosses 2s at a pre-spawn boundary -> WALL_CLOCK_EXCEEDED
#   stage=pre-spawn; NO CAP_REACHED.
# ===========================================================================
MW2="$scratch/MW2"; mkdir -p "$MW2"
CTRW2="$scratch/ctrw2"
STUBW2="$scratch/stub-fast.sh"
printf '#!/usr/bin/env sh\nOM="%s"\nCTR="%s"\n' \
  "$MW2/.self-continue-outcome" "$CTRW2" > "$STUBW2"
cat >> "$STUBW2" <<'CHILDEOF'
sleep 0.3 2>/dev/null || sleep 1
n=0
[ -f "$CTR" ] && n=$(cat "$CTR")
n=$((n + 1))
printf '%s' "$n" > "$CTR"
printf 'rotation P0%s\n' "$n" > "$OM"
printf '{"total_cost_usd":0.01}\n'
exit 0
CHILDEOF
chmod +x "$STUBW2"
rc2=0
sh "$DRIVER" "$MW2" --unattended --max-budget-usd 50 --max-continuations 50 \
  --max-wall-clock-s 2 --min-interval 0 --watchdog-poll-s 1 \
  --auto-cmd "sh $STUBW2" > "$scratch/out2.txt" 2>/dev/null || rc2=$?
out2="$scratch/out2.txt"

c2_ok=1
grep -q "SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=pre-spawn" "$out2" \
  || { c2_ok=0; echo "  (2) missing WALL_CLOCK_EXCEEDED stage=pre-spawn"; }
grep -q "WALL_CLOCK_EXCEEDED stage=pre-spawn.*elapsed_s=" "$out2" \
  || { c2_ok=0; echo "  (2) pre-spawn WALL_CLOCK line missing elapsed_s= reason field"; }
grep -q "WALL_CLOCK_EXCEEDED stage=pre-spawn.*cap_s=2" "$out2" \
  || { c2_ok=0; echo "  (2) pre-spawn WALL_CLOCK line missing cap_s=2 reason field"; }
if grep -q "SELF_CONTINUE:CAP_REACHED" "$out2"; then
  c2_ok=0; echo "  (2) CAP_REACHED fired -- the continuation cap, not the wall-clock ceiling, halted the run"
fi
[ "$rc2" -eq 0 ] || { c2_ok=0; echo "  (2) driver exit $rc2 != 0"; }
if [ "$c2_ok" -eq 1 ]; then
  pass "case=2 pre-spawn refusal: WALL_CLOCK_EXCEEDED stage=pre-spawn (elapsed_s= cap_s=2) between segments, no CAP_REACHED (generous cont cap 50)"
else
  fail "case=2 rc=$rc2 output='$(cat "$out2")'"
fi

echo "SUMMARY: pass=$passes fail=$fails"
if [ "$fails" -eq 0 ]; then
  exit 0
else
  exit 1
fi
