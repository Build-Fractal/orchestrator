#!/usr/bin/env sh
# m046-p04-reserve-spend.sh -- M046 FR-8 / SC-4 reserve-then-spend accounting.
#
# Drives the REAL driver + REAL envelope ledger to prove the fail-closed
# budget-lease accounting: a per-segment reserve is written BEFORE the spawn,
# so a child that dies before flushing its authoritative total_cost_usd leaves
# that reserve counted as SPENT (unreconciled = forfeited), the persisted ledger
# binds the NEXT run's pre-spawn cap check across process boundaries, and a
# normally-exiting child's ledger entry is trued-up from its actual
# total_cost_usd (freeing the unspent portion of the reserve).
#
# The only substitution is the LLM child (a live shell stand-in). No pre-seeded
# ledger, no seeded markers. POSIX sh, bash-3.2-safe, no jq. All scratch.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVER="$REPO_ROOT/scripts/lifecycle/self-continue-drive.sh"
ENVELOPE="$REPO_ROOT/scripts/lifecycle/unattended-envelope.sh"

[ -f "$DRIVER" ] || { echo "FAIL: driver not found: $DRIVER"; exit 1; }
[ -f "$ENVELOPE" ] || { echo "FAIL: envelope lib not found: $ENVELOPE"; exit 1; }

# Source the envelope library (defines functions only, zero side effects) so
# Case 3 can assert spend via the SAME envelope_spent_total production uses.
# shellcheck disable=SC1090
. "$ENVELOPE"

passes=0
fails=0
pass() { echo "PASS: $1"; passes=$((passes + 1)); }
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# ===========================================================================
# Case 1 -- killed-before-flush decrements (SC-4 core).
#   Child kill -9 $$ immediately: no records, no JSON result, no marker. The
#   reserve ($1.00) was written pre-spawn; because the child never flushed a
#   total_cost_usd, the reserve is forfeited as spent (fail-closed). The kill
#   was the CHILD's own (not the watchdog), so the P02 truth table owns the
#   terminal: SELF_CONTINUE:CHILD_ABORT.
# ===========================================================================
M1="$scratch/M1"; mkdir -p "$M1"
STUB1="$scratch/stub-kill-self.sh"
printf '#!/usr/bin/env sh\nkill -9 $$\n' > "$STUB1"
chmod +x "$STUB1"
rc1=0
sh "$DRIVER" "$M1" --unattended --max-budget-usd 1.50 --max-continuations 3 \
  --max-wall-clock-s 60 --min-interval 0 --watchdog-poll-s 1 \
  --segment-reserve-usd 1.00 --auto-cmd "sh $STUB1" > "$scratch/out1.txt" 2>/dev/null || rc1=$?
out1="$scratch/out1.txt"
LEDGER1="$M1/.self-continue-budget-ledger"

c1_ok=1
grep -q "SELF_CONTINUE:CHILD_ABORT" "$out1" || { c1_ok=0; echo "  (1) missing CHILD_ABORT (child crashed; envelope did not kill it)"; }
grep -q "^reserve segment=1 amount_usd=1.00 " "$LEDGER1" || { c1_ok=0; echo "  (1) ledger missing reserve segment=1 amount_usd=1.00"; }
grep -q "^forfeit segment=1 amount_usd=1.00.*source=unreconciled" "$LEDGER1" || { c1_ok=0; echo "  (1) ledger missing forfeit segment=1 amount_usd=1.00 source=unreconciled"; }
if grep -q "^reconcile " "$LEDGER1"; then c1_ok=0; echo "  (1) unexpected reconcile line (child never flushed total_cost_usd)"; fi
if [ "$c1_ok" -eq 1 ]; then
  pass "case=1 killed-before-flush: reserve \$1.00 forfeited as spent (unreconciled), distinct CHILD_ABORT terminal, no reconcile"
else
  fail "case=1 rc=$rc1 output='$(cat "$out1")' ledger='$(cat "$LEDGER1" 2>/dev/null || echo ABSENT)'"
fi

# ===========================================================================
# Case 2 -- cross-run cap binding (the decrement is real).
#   Re-run the driver against the SAME M1 dir + ledger with a benign child that
#   WOULD write a sentinel/marker/JSON if it ran. Persisted spend (forfeit
#   1.00) + reserve 1.00 = 2.00 > cap 1.50, so the pre-spawn check refuses:
#   BUDGET_EXCEEDED stage=pre-spawn, the child never spawns (sentinel absent),
#   no new reserve is written, and combined spend never crossed the cap.
# ===========================================================================
SENTINEL="$M1/benign-ran"
STUB2="$scratch/stub-benign.sh"
printf '#!/usr/bin/env sh\nSENTINEL="%s"\nOM="%s"\n' "$SENTINEL" "$M1/.self-continue-outcome" > "$STUB2"
cat >> "$STUB2" <<'S2EOF'
touch "$SENTINEL"
printf 'complete\n' > "$OM"
printf '{"total_cost_usd":0.05,"result":"fixture"}\n'
exit 0
S2EOF
chmod +x "$STUB2"
rc2=0
sh "$DRIVER" "$M1" --unattended --max-budget-usd 1.50 --max-continuations 3 \
  --max-wall-clock-s 60 --min-interval 0 --watchdog-poll-s 1 \
  --segment-reserve-usd 1.00 --auto-cmd "sh $STUB2" > "$scratch/out2.txt" 2>/dev/null || rc2=$?
out2="$scratch/out2.txt"

c2_ok=1
grep -q "SELF_CONTINUE:BUDGET_EXCEEDED stage=pre-spawn" "$out2" || { c2_ok=0; echo "  (2) missing BUDGET_EXCEEDED stage=pre-spawn"; }
[ ! -f "$SENTINEL" ] || { c2_ok=0; echo "  (2) benign child ran -- pre-spawn refusal did not prevent the spawn"; }
if grep -q "^reserve segment=2 " "$LEDGER1"; then c2_ok=0; echo "  (2) a reserve segment=2 was written despite the refusal"; fi
[ "$rc2" -eq 0 ] || { c2_ok=0; echo "  (2) driver exit $rc2 != 0"; }
if [ "$c2_ok" -eq 1 ]; then
  pass "case=2 cross-run cap binding: persisted \$1.00 + reserve \$1.00 > cap \$1.50 refuses pre-spawn, child never spawned, no reserve seg2"
else
  fail "case=2 rc=$rc2 output='$(cat "$out2")'"
fi

# ===========================================================================
# Case 3 -- true-up reconcile (spend is actual, not reserve).
#   Fresh dir, cap $5. The child flushes {"total_cost_usd":0.30} and a
#   continue-class marker, exits 0; --max-continuations 1 ends after one
#   segment. The ledger must reconcile from the authoritative 0.30 and the
#   envelope_spent_total must read 0.30 (NOT the 1.00 reserve) -- the true-up
#   freed the unspent portion of the lease.
# ===========================================================================
M3="$scratch/M3"; mkdir -p "$M3"
STUB3="$scratch/stub-trueup.sh"
printf '#!/usr/bin/env sh\nOM="%s"\n' "$M3/.self-continue-outcome" > "$STUB3"
cat >> "$STUB3" <<'S3EOF'
printf 'rotation P01\n' > "$OM"
printf '{"total_cost_usd":0.30,"result":"fixture"}\n'
exit 0
S3EOF
chmod +x "$STUB3"
rc3=0
sh "$DRIVER" "$M3" --unattended --max-budget-usd 5 --max-continuations 1 \
  --max-wall-clock-s 60 --min-interval 0 --watchdog-poll-s 1 \
  --segment-reserve-usd 1.00 --auto-cmd "sh $STUB3" > "$scratch/out3.txt" 2>/dev/null || rc3=$?
out3="$scratch/out3.txt"
LEDGER3="$M3/.self-continue-budget-ledger"

c3_ok=1
grep -q "^reconcile segment=1 actual_usd=0.30 source=total_cost_usd" "$LEDGER3" || { c3_ok=0; echo "  (3) ledger missing true-up reconcile actual_usd=0.30 source=total_cost_usd"; }
spent3="$(envelope_spent_total "$LEDGER3")"
if awk -v v="$spent3" 'BEGIN { exit !(v + 0 > 0.29 && v + 0 < 0.31) }'; then :; else
  c3_ok=0; echo "  (3) envelope_spent_total='$spent3' != 0.30 (reserve not freed by reconcile)"
fi
if [ "$c3_ok" -eq 1 ]; then
  pass "case=3 true-up: reconcile from total_cost_usd=0.30, envelope_spent_total=$spent3 (reserve freed, spend is actual not lease)"
else
  fail "case=3 rc=$rc3 spent='$spent3' output='$(cat "$out3")' ledger='$(cat "$LEDGER3" 2>/dev/null || echo ABSENT)'"
fi

echo "SUMMARY: pass=$passes fail=$fails"
if [ "$fails" -eq 0 ]; then
  exit 0
else
  exit 1
fi
