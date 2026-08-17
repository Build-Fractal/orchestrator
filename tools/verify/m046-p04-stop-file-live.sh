#!/usr/bin/env sh
# m046-p04-stop-file-live.sh -- M046 FR-10 / SC-6 stop-file live-kill harness.
#
# Drives the REAL driver (scripts/lifecycle/self-continue-drive.sh) + REAL
# envelope watchdog (scripts/lifecycle/unattended-envelope.sh) end-to-end. The
# only substitution is the LLM child: a live shell stand-in (the P02
# m046-p02-child-abort.sh precedent). NO seeded markers, NO fabricated
# kill-reason file, NO seeded terminal.
#
# SC-6 core (Case 1): a stop-file that appears WHILE a live segment is running
# SIGKILLs the child and terminates the driver within BOUNDED WALL-CLOCK latency
# -- asserted against measured wall-clock elapsed (poll + kill + reap), NOT the
# one-full-segment (>= child natural duration) latency the pre-M046 pre-loop-only
# stop check would have incurred. The distinct terminal is
# SELF_CONTINUE:STOPPED reason=stop-file stage=mid-segment; the child's
# natural-completion sentinel is ABSENT (proof the live child was killed,
# not allowed to finish) and no CHILD_ABORT line leaks (the envelope terminal
# takes precedence over the generic FR-14 abort line).
#
# Case 2 pins M045 parity: a stop-file present BEFORE launch still short-circuits
# at the driver's top-of-loop pre-spawn stop check (SELF_CONTINUE:STOPPED
# reason=stop-file, NO stage=mid-segment), the child never spawns, and no
# per-segment reserve is written to the ledger.
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
# Case 1 -- mid-segment live kill (SC-6 core).
#   Child: sleep 15 (long-running live segment), then touch natural-end,
#   write a 'complete' marker + JSON, exit 0 -- none of which is reached because
#   the stop-file kills it mid-sleep. The driver is BACKGROUNDED; 2s in (child
#   mid-sleep) the harness creates the stop-file and measures wall-clock latency
#   to driver exit.
# ===========================================================================
M1="$scratch/M1"; mkdir -p "$M1"
STOP1="$scratch/stop1"
STUB1="$scratch/stub-sleep15.sh"
printf '#!/usr/bin/env sh\nNE="%s"\nOM="%s"\n' \
  "$M1/natural-end" "$M1/.self-continue-outcome" > "$STUB1"
cat >> "$STUB1" <<'CHILDEOF'
sleep 15
touch "$NE"
printf 'complete\n' > "$OM"
printf '{"total_cost_usd":0.01,"result":"fixture"}\n'
exit 0
CHILDEOF
chmod +x "$STUB1"

sh "$DRIVER" "$M1" --unattended --max-budget-usd 5 --max-continuations 3 \
  --max-wall-clock-s 120 --min-interval 0 --watchdog-poll-s 1 \
  --stop-file "$STOP1" --auto-cmd "sh $STUB1" > "$scratch/out1.txt" 2>/dev/null &
DPID=$!
sleep 2
t0=$(date +%s)
touch "$STOP1"
wr=0
wait "$DPID" || wr=$?
t1=$(date +%s)
elapsed1=$((t1 - t0))
out1="$scratch/out1.txt"
LEDGER1="$M1/.self-continue-budget-ledger"

c1_ok=1
grep -q "SELF_CONTINUE:STOPPED reason=stop-file stage=mid-segment" "$out1" \
  || { c1_ok=0; echo "  (1) missing STOPPED stage=mid-segment terminal"; }
[ "$elapsed1" -le 6 ] \
  || { c1_ok=0; echo "  (1) latency ${elapsed1}s > 6s -- kill did not land mid-segment (one-full-segment would be >= 15s)"; }
[ ! -f "$M1/natural-end" ] \
  || { c1_ok=0; echo "  (1) natural-end present -- live child finished instead of being killed"; }
if grep -q "SELF_CONTINUE:CHILD_ABORT" "$out1"; then
  c1_ok=0; echo "  (1) CHILD_ABORT line leaked -- envelope STOPPED terminal did not take precedence"
fi
grep -q "^reserve segment=1 " "$LEDGER1" \
  || { c1_ok=0; echo "  (1) ledger missing reserve segment=1"; }
grep -q "^forfeit segment=1 " "$LEDGER1" \
  || { c1_ok=0; echo "  (1) ledger missing forfeit segment=1 (killed child's reserve counted as spent)"; }
[ "$wr" -eq 0 ] || { c1_ok=0; echo "  (1) driver exit $wr != 0 (terminal, not crash)"; }
if [ "$c1_ok" -eq 1 ]; then
  pass "case=1 mid-segment live kill: STOPPED stage=mid-segment within ${elapsed1}s (bounded, wall-clock-asserted), natural-end absent, no CHILD_ABORT leak, forfeit segment=1"
else
  fail "case=1 elapsed=${elapsed1}s rc=$wr output='$(cat "$out1")' ledger='$(cat "$LEDGER1" 2>/dev/null || echo ABSENT)'"
fi

# ===========================================================================
# Case 2 -- pre-loop stop still works (M045 parity).
#   Stop-file created BEFORE launch. The driver's top-of-loop pre-spawn stop
#   check fires immediately: SELF_CONTINUE:STOPPED reason=stop-file (NO
#   stage=mid-segment). The benign child never spawns (sentinel absent) and no
#   per-segment reserve is written (the stop check precedes the reserve block).
# ===========================================================================
M2="$scratch/M2"; mkdir -p "$M2"
STOP2="$scratch/stop2"
touch "$STOP2"
SENT2="$M2/benign-ran"
STUB2="$scratch/stub-benign.sh"
printf '#!/usr/bin/env sh\nSENT="%s"\nOM="%s"\n' \
  "$SENT2" "$M2/.self-continue-outcome" > "$STUB2"
cat >> "$STUB2" <<'CHILDEOF'
touch "$SENT"
printf 'complete\n' > "$OM"
printf '{"total_cost_usd":0.01}\n'
exit 0
CHILDEOF
chmod +x "$STUB2"
rc2=0
sh "$DRIVER" "$M2" --unattended --max-budget-usd 5 --max-continuations 3 \
  --max-wall-clock-s 120 --min-interval 0 --watchdog-poll-s 1 \
  --stop-file "$STOP2" --auto-cmd "sh $STUB2" > "$scratch/out2.txt" 2>/dev/null || rc2=$?
out2="$scratch/out2.txt"
LEDGER2="$M2/.self-continue-budget-ledger"

c2_ok=1
grep -q "SELF_CONTINUE:STOPPED reason=stop-file continuations=" "$out2" \
  || { c2_ok=0; echo "  (2) missing pre-loop STOPPED reason=stop-file line"; }
if grep -q "stage=mid-segment" "$out2"; then
  c2_ok=0; echo "  (2) stage=mid-segment present -- pre-loop stop wrongly took the live-kill path"
fi
[ ! -f "$SENT2" ] || { c2_ok=0; echo "  (2) benign child ran -- pre-loop stop did not prevent the spawn"; }
if grep -q "^reserve " "$LEDGER2" 2>/dev/null; then
  c2_ok=0; echo "  (2) a per-segment reserve was written despite the pre-loop stop"
fi
[ "$rc2" -eq 0 ] || { c2_ok=0; echo "  (2) driver exit $rc2 != 0"; }
if [ "$c2_ok" -eq 1 ]; then
  pass "case=2 pre-loop stop: STOPPED reason=stop-file (no stage=mid-segment), child never spawned, no reserve in ledger"
else
  fail "case=2 rc=$rc2 output='$(cat "$out2")' ledger='$(cat "$LEDGER2" 2>/dev/null || echo ABSENT)'"
fi

echo "SUMMARY: pass=$passes fail=$fails"
if [ "$fails" -eq 0 ]; then
  exit 0
else
  exit 1
fi
