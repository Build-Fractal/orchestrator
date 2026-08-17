#!/usr/bin/env sh
# m046-p04-budget-kill.sh -- M046 FR-7 / SC-3 (milestone-blocking, NON-STUBBED).
#
# The cost-discriminating budget-kill harness -- the milestone's integrity crux.
# It drives the REAL driver (scripts/lifecycle/self-continue-drive.sh) and the
# REAL envelope watchdog (scripts/lifecycle/unattended-envelope.sh) end-to-end.
# The ONLY substitution is the LLM child: a live shell stand-in (the P02
# m046-p02-child-abort.sh precedent) that emits PRODUCTION-SHAPED unit_close
# records -- byte-mirroring write-summary.sh's _ws_emit_unit_close printf
# template -- appended to the LIVE default cost log path
# (<milestone-dir>/execution-log.jsonl) WHILE the child runs. The watchdog
# reads them through the same envelope_observed_cost probe production uses.
#
# NO pre-seeded log, NO seeded verdict, NO marker fabrication, NO fabricated
# kill-reason file, NO duration proxy. The kill is proven cost-derived by
# construction:
#
#   COST DISCRIMINATION -- Case A (runaway) and Case B (control) share a
#   BYTE-IDENTICAL timing structure (same 3-record emit schedule, same natural
#   sleep 8, same completion behavior). They differ ONLY in the
#   estimated_cost_usd values the child emits ($2.00 vs $0.02). Because the
#   duration is held constant, an implementation that triggered on ANY duration
#   proxy relabeled "budget-exceeded" would kill BOTH or NEITHER -- and this
#   harness fails either way (Case A demands a kill, Case B demands survival).
#   The paired result is the only way BOTH cases pass: the trigger MUST be the
#   dollar cost.
#
# Case D adds the P01 nullable-estimate honesty leg (#Q-4 verdict): null-cost
# unit_close records contribute 0 and must NOT trigger a kill.
#
# Case C is a shape-pin: the fixture records, the watchdog probe, and the
# production emitter must all use the exact same key names.
#
# Portability: POSIX sh, bash-3.2-safe. No jq. All fixture trees in mktemp
# scratch -- nothing under the repo or .orchestrator/.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DRIVER="$REPO_ROOT/scripts/lifecycle/self-continue-drive.sh"
ENVELOPE="$REPO_ROOT/scripts/lifecycle/unattended-envelope.sh"
WRITE_SUMMARY="$REPO_ROOT/scripts/knowledge/write-summary.sh"

[ -f "$DRIVER" ] || { echo "FAIL: driver not found: $DRIVER"; exit 1; }
[ -f "$ENVELOPE" ] || { echo "FAIL: envelope lib not found: $ENVELOPE"; exit 1; }
[ -f "$WRITE_SUMMARY" ] || { echo "FAIL: write-summary not found: $WRITE_SUMMARY"; exit 1; }

passes=0
fails=0
pass() { echo "PASS: $1"; passes=$((passes + 1)); }
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# gen_child <dest> <mdir> <cost> <final_sleep>
#   Writes a live-shell LLM stand-in that:
#     1. sleeps 0.3s (natural startup), then emits 3 production-shaped
#        unit_close records to <mdir>/execution-log.jsonl at <cost> each;
#     2. sleeps <final_sleep>s (the segment's natural duration);
#     3. touches <mdir>/natural-end (the natural-completion sentinel);
#     4. writes a 'complete' outcome marker + prints the authoritative JSON
#        result ({"total_cost_usd":0.05}) and exits 0.
#   The record body is a verbatim mirror of write-summary.sh _ws_emit_unit_close
#   -- every key present; only estimated_cost_usd varies between cases. The
#   header lines are printf-injected (paths/values); the body is a QUOTED
#   heredoc so $LOG/$COST/$i/$$ stay literal until the stub runs.
gen_child() {
  _dest=$1; _mdir=$2; _cost=$3; _fsleep=$4
  printf '#!/usr/bin/env sh\nLOG="%s"\nCOST="%s"\nFSLEEP=%s\nNE="%s"\nOM="%s"\n' \
    "$_mdir/execution-log.jsonl" "$_cost" "$_fsleep" \
    "$_mdir/natural-end" "$_mdir/.self-continue-outcome" > "$_dest"
  cat >> "$_dest" <<'CHILDEOF'
sleep 0.3 2>/dev/null || sleep 1
i=1
while [ $i -le 3 ]; do
  printf '{"record_type":"unit_close","granularity":"task","unitId":"MFIX/P01/T0%s","milestone":"MFIX","phase":"P01","task":"T0%s","duration_s":1,"outcome":"pass","completed_at":"2026-07-13T00:00:00Z","estimated_cost_usd":%s,"pricing_version":"fixture","verification_pass_rate":1.0,"deviation_count":0,"retry_count":0,"filter_dropped_tokens":0,"tier1_savings_tokens":0,"tier2_savings_tokens":0,"tier1_invocations":0,"tier3_compression_savings_tokens":0,"tier3_invocations":0,"source":"m046-p04-fixture","timestamp":"2026-07-13T00:00:00Z"}\n' "$i" "$i" "$COST" >> "$LOG"
  i=$((i+1))
done
sleep "$FSLEEP"
touch "$NE"
printf 'complete\n' > "$OM"
printf '{"total_cost_usd":0.05,"result":"fixture"}\n'
exit 0
CHILDEOF
  chmod +x "$_dest"
}

# ===========================================================================
# Case A -- runaway killed mid-flight (SC-3 core).
#   3 records x $2.00 = $6.00 observed; cap $5. Must be SIGKILLed mid-flight
#   with the distinct BUDGET_EXCEEDED terminal, mid-sleep (natural-end absent),
#   within bounded latency, and the spend accounted (forfeit >= observed).
# ===========================================================================
MA="$scratch/MA"; mkdir -p "$MA"
STUB_A="$scratch/stub-a.sh"
gen_child "$STUB_A" "$MA" "2.00" "8"
t0=$(date +%s)
rcA=0
sh "$DRIVER" "$MA" --unattended --max-budget-usd 5 --max-continuations 2 \
  --max-wall-clock-s 120 --min-interval 0 --watchdog-poll-s 1 \
  --auto-cmd "sh $STUB_A" > "$scratch/outA.txt" 2>/dev/null || rcA=$?
t1=$(date +%s)
elapsedA=$((t1 - t0))
outA="$scratch/outA.txt"
ledgerA="$MA/.self-continue-budget-ledger"

a_ok=1
grep -q "SELF_CONTINUE:BUDGET_EXCEEDED stage=mid-segment" "$outA" || { a_ok=0; echo "  (A) missing BUDGET_EXCEEDED mid-segment terminal"; }
# distinct-terminal leg: the generous 120s wall cap guarantees wall-clock is not
# the trigger; no thrash / child_abort / cap terminal may appear.
if grep -Eq "WALL_CLOCK_EXCEEDED|SELF_CONTINUE:THRASH|SELF_CONTINUE:CHILD_ABORT|CAP_REACHED" "$outA"; then
  a_ok=0; echo "  (A) a non-budget terminal leaked into the output"
fi
[ ! -f "$MA/natural-end" ] || { a_ok=0; echo "  (A) natural-end present -- child finished instead of being killed"; }
[ "$elapsedA" -le 6 ] || { a_ok=0; echo "  (A) latency $elapsedA > 6s -- kill did not land mid-flight"; }
grep -q "^reserve segment=1 " "$ledgerA" || { a_ok=0; echo "  (A) ledger missing reserve segment=1"; }
grep -q "^forfeit segment=1 amount_usd=6" "$ledgerA" || { a_ok=0; echo "  (A) ledger missing forfeit segment=1 amount_usd=6 (unreconciled = observed 6.00)"; }
[ "$rcA" -eq 0 ] || { a_ok=0; echo "  (A) driver exit $rcA != 0 (terminal, not crash)"; }
if [ "$a_ok" -eq 1 ]; then
  pass "case=A runaway \$6.00>\$5 SIGKILLed mid-flight (elapsed=${elapsedA}s), distinct BUDGET_EXCEEDED, natural-end absent, forfeit=6.00"
else
  fail "case=A elapsed=${elapsedA}s rc=$rcA output='$(cat "$outA")'"
fi

# ===========================================================================
# Case B -- equal-duration low-cost control completes (anti-proxy leg).
#   BYTE-IDENTICAL timing to Case A (same emit schedule, same sleep 8); only
#   the cost differs ($0.02 x 3 = $0.06 << $5). Must run to natural completion
#   UNKILLED and reconcile from the authoritative total_cost_usd. Because the
#   duration is identical to Case A, the ONLY thing that can explain Case A
#   being killed while Case B survives is the dollar cost.
# ===========================================================================
MB="$scratch/MB"; mkdir -p "$MB"
STUB_B="$scratch/stub-b.sh"
gen_child "$STUB_B" "$MB" "0.02" "8"
t0=$(date +%s)
rcB=0
sh "$DRIVER" "$MB" --unattended --max-budget-usd 5 --max-continuations 1 \
  --max-wall-clock-s 120 --min-interval 0 --watchdog-poll-s 1 \
  --auto-cmd "sh $STUB_B" > "$scratch/outB.txt" 2>/dev/null || rcB=$?
t1=$(date +%s)
elapsedB=$((t1 - t0))
outB="$scratch/outB.txt"
ledgerB="$MB/.self-continue-budget-ledger"

b_ok=1
if grep -q "BUDGET_EXCEEDED" "$outB"; then b_ok=0; echo "  (B) BUDGET_EXCEEDED fired on the low-cost control -- trigger is a proxy, not cost"; fi
[ -f "$MB/natural-end" ] || { b_ok=0; echo "  (B) natural-end absent -- control did not run to completion"; }
[ "$elapsedB" -ge 8 ] || { b_ok=0; echo "  (B) elapsed $elapsedB < 8s -- something shortened the segment"; }
grep -q "SELF_CONTINUE:TERMINAL outcome=complete" "$outB" || { b_ok=0; echo "  (B) missing TERMINAL outcome=complete"; }
grep -q "^reconcile segment=1 actual_usd=0.05 source=total_cost_usd" "$ledgerB" || { b_ok=0; echo "  (B) ledger missing true-up reconcile actual_usd=0.05 source=total_cost_usd"; }
if [ "$b_ok" -eq 1 ]; then
  pass "case=B equal-duration \$0.06<\$5 control ran UNKILLED to completion (elapsed=${elapsedB}s), reconciled from total_cost_usd -- kill in A was cost-derived"
else
  fail "case=B elapsed=${elapsedB}s rc=$rcB output='$(cat "$outB")'"
fi

# ===========================================================================
# Case C -- shape-pin. The fixture records, the watchdog probe, and the
#   production emitter must share EXACT key names. Grep the two load-bearing
#   literals in all three surfaces (production emitter, watchdog probe, this
#   harness's generated stub). Drift in any direction fails.
# ===========================================================================
c_ok=1
grep -q '"record_type":"unit_close"' "$WRITE_SUMMARY" || { c_ok=0; echo "  (C) write-summary.sh missing record_type:unit_close key"; }
grep -q '"estimated_cost_usd":' "$WRITE_SUMMARY" || { c_ok=0; echo "  (C) write-summary.sh missing estimated_cost_usd key"; }
grep -q '"record_type":"unit_close"' "$ENVELOPE" || { c_ok=0; echo "  (C) envelope probe missing record_type:unit_close key"; }
grep -q '"estimated_cost_usd":' "$ENVELOPE" || { c_ok=0; echo "  (C) envelope probe missing estimated_cost_usd key"; }
grep -q '"record_type":"unit_close"' "$STUB_A" || { c_ok=0; echo "  (C) fixture stub missing record_type:unit_close key"; }
grep -q '"estimated_cost_usd":' "$STUB_A" || { c_ok=0; echo "  (C) fixture stub missing estimated_cost_usd key"; }
if [ "$c_ok" -eq 1 ]; then
  pass "case=C shape-pin: record_type:unit_close + estimated_cost_usd present in production emitter, watchdog probe, and fixture stub"
else
  fail "case=C key-name drift between fixture, watchdog probe, and production emitter"
fi

# ===========================================================================
# Case D -- null-cost records do not trigger (nullable-estimate honesty).
#   P01 #Q-4 verdict: JSONL estimated_cost_usd is a NULLABLE advisory estimate;
#   null contributes 0. A child identical to Case A but emitting null on all 3
#   records (and a shorter natural sleep) must NOT be killed.
# ===========================================================================
MD="$scratch/MD"; mkdir -p "$MD"
STUB_D="$scratch/stub-d.sh"
gen_child "$STUB_D" "$MD" "null" "3"
rcD=0
sh "$DRIVER" "$MD" --unattended --max-budget-usd 5 --max-continuations 1 \
  --max-wall-clock-s 120 --min-interval 0 --watchdog-poll-s 1 \
  --auto-cmd "sh $STUB_D" > "$scratch/outD.txt" 2>/dev/null || rcD=$?
outD="$scratch/outD.txt"

d_ok=1
if grep -q "BUDGET_EXCEEDED" "$outD"; then d_ok=0; echo "  (D) null-cost records false-triggered a budget kill"; fi
[ -f "$MD/natural-end" ] || { d_ok=0; echo "  (D) natural-end absent -- null-cost child was wrongly killed"; }
if [ "$d_ok" -eq 1 ]; then
  pass "case=D 3x null-cost unit_close records contribute 0 -- no kill, ran to natural completion (P01 #Q-4 nullable-estimate honesty)"
else
  fail "case=D rc=$rcD output='$(cat "$outD")'"
fi

echo "SUMMARY: pass=$passes fail=$fails"
if [ "$fails" -eq 0 ]; then
  exit 0
else
  exit 1
fi
