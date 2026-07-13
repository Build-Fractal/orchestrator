#!/usr/bin/env sh
# m046-p04-envelope-unit.sh (M046 P04 phase Truth 7)
# Unit-tests every function in scripts/lifecycle/unattended-envelope.sh in
# isolation against mktemp fixtures -- zero LLM spend, zero driver spawn.
# Covers: caps-problem detection (FR-13 fail-closed), reserve/reconcile/
# forfeit ledger math (FR-8: overrides beat reserves; bare reserve is spent),
# non-null-only observed-cost summation with line-offset baseline (FR-7),
# total_cost_usd parsing with fail-closed empty on malformed input (FR-8
# true-up), atomic temp+rename kill-reason writes (P02 discipline), and the
# watchdog's three kill triggers (stop-file / wall-clock / cost-derived
# budget) against real background PIDs.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lifecycle/unattended-envelope.sh"

[ -f "$LIB" ] || { echo "FAIL: library not found: $LIB"; exit 1; }

# shellcheck disable=SC1090
. "$LIB"

passes=0
fails=0

pass() { echo "PASS: $1"; passes=$((passes + 1)); }
fail() { echo "FAIL: $1"; fails=$((fails + 1)); }

# num_eq <a> <b> -- float equality within 1e-6 tolerance (awk, never shell math)
num_eq() {
  awk -v a="$1" -v b="$2" 'BEGIN { d = a - b; if (d < 0) d = -d; exit !(d < 0.000001) }'
}

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# --- envelope_caps_problems ------------------------------------------------

out="$(envelope_caps_problems "5.00" true 20 3600)"
if [ "$out" = "ok" ]; then pass "caps all-set-valid -> ok"
else fail "caps all-set-valid expected 'ok' got '$out'"; fi

out="$(envelope_caps_problems "" true 20 3600)"
if [ "$out" = "caps-unset missing=budget" ]; then pass "caps budget-missing -> missing=budget"
else fail "caps budget-missing got '$out'"; fi

# Continuations cap not explicitly set: value 20 present but set-flag false --
# the silent MAX_CONT=20 default must NOT be accepted as an explicit cap.
out="$(envelope_caps_problems "5.00" false 20 3600)"
if [ "$out" = "caps-unset missing=continuations" ]; then pass "caps cont-not-explicit -> missing=continuations (silent default rejected)"
else fail "caps cont-not-explicit got '$out'"; fi

out="$(envelope_caps_problems "5.00" true 20 "")"
if [ "$out" = "caps-unset missing=wall-clock" ]; then pass "caps wall-missing -> missing=wall-clock"
else fail "caps wall-missing got '$out'"; fi

out="$(envelope_caps_problems "" false 20 "")"
if [ "$out" = "caps-unset missing=budget,continuations,wall-clock" ]; then pass "caps all-missing -> full csv"
else fail "caps all-missing got '$out'"; fi

out="$(envelope_caps_problems "abc" true 20 3600)"
if [ "$out" = "caps-invalid invalid=budget" ]; then pass "caps budget=abc -> invalid=budget"
else fail "caps budget=abc got '$out'"; fi

out="$(envelope_caps_problems "5.00" true 20 0)"
if [ "$out" = "caps-invalid invalid=wall-clock" ]; then pass "caps wall=0 -> invalid=wall-clock (must be > 0)"
else fail "caps wall=0 got '$out'"; fi

# --- Ledger math (FR-8 fail-closed) ----------------------------------------

L="$scratch/ledger"
envelope_ledger_init "$L" 5.00 3600 20
if grep -q '^run_start ts=.* cap_usd=5.00 wall_clock_s=3600 max_continuations=20$' "$L"; then
  pass "ledger init appends run_start line with caps"
else
  fail "ledger init run_start line malformed: '$(cat "$L")'"
fi

envelope_reserve "$L" 1 1.00
got="$(envelope_spent_total "$L")"
if num_eq "$got" 1.00; then pass "bare reserve counts as spent (1.00)"
else fail "bare reserve expected 1.00 got '$got'"; fi

envelope_reconcile "$L" 1 0.30 result-json
got="$(envelope_spent_total "$L")"
if num_eq "$got" 0.30; then pass "reconcile trues-up down (0.30 overrides reserve)"
else fail "reconcile true-up expected 0.30 got '$got'"; fi

envelope_reserve "$L" 2 1.00
envelope_forfeit "$L" 2 6.00 watchdog-kill
got="$(envelope_spent_total "$L")"
if num_eq "$got" 6.30; then pass "forfeit overrides reserve and may exceed it (6.30)"
else fail "forfeit override expected 6.30 got '$got'"; fi

got="$(envelope_next_segment "$L")"
if [ "$got" = "3" ]; then pass "next_segment after 2 reserves -> 3"
else fail "next_segment expected 3 got '$got'"; fi

# Append-only invariant: a second init must not truncate prior lines.
lines_before="$(wc -l < "$L" | tr -d ' ')"
envelope_ledger_init "$L" 9.00 60 5
lines_after="$(wc -l < "$L" | tr -d ' ')"
if [ "$lines_after" -eq $((lines_before + 1)) ]; then pass "ledger init is append-only (never truncates)"
else fail "ledger init truncated: before=$lines_before after=$lines_after"; fi

got="$(envelope_spent_total "$scratch/no-such-ledger")"
if num_eq "$got" 0; then pass "missing ledger -> spent 0"
else fail "missing ledger spent expected 0 got '$got'"; fi

got="$(envelope_next_segment "$scratch/no-such-ledger")"
if [ "$got" = "1" ]; then pass "missing ledger -> next segment 1"
else fail "missing ledger next_segment expected 1 got '$got'"; fi

# --- envelope_observed_cost (FR-7, production unit_close key shape) --------

LOG="$scratch/execution-log.jsonl"
{
  printf '{"record_type":"unit_close","unitId":"T00","estimated_cost_usd":9.9,"source":"pre"}\n'
  printf '{"record_type":"unit_close","unitId":"T00b","estimated_cost_usd":8.8,"source":"pre"}\n'
  printf '{"record_type":"unit_close","unitId":"T01","estimated_cost_usd":2.5,"source":"post"}\n'
  printf '{"record_type":"unit_close","unitId":"T02","estimated_cost_usd":null,"source":"post"}\n'
  printf '{"record_type":"dispatch_usage","unitId":"T03","estimated_cost_usd":7.7,"source":"post"}\n'
} > "$LOG"
got="$(envelope_observed_cost "$LOG" 2)"
if num_eq "$got" 2.5; then pass "observed_cost: baseline honored, null ignored, foreign record types ignored (2.5)"
else fail "observed_cost expected 2.5 got '$got'"; fi

got="$(envelope_observed_cost "$scratch/no-such-log" 0)"
if num_eq "$got" 0; then pass "observed_cost: missing file -> 0"
else fail "observed_cost missing file expected 0 got '$got'"; fi

got="$(envelope_observed_cost "" 0)"
if num_eq "$got" 0; then pass "observed_cost: empty path -> 0 (never crash)"
else fail "observed_cost empty path expected 0 got '$got'"; fi

# --- envelope_parse_total_cost (FR-8 true-up, fail-closed) ------------------

J1="$scratch/result-ok.json"
printf '{"type":"result","subtype":"success","total_cost_usd":0.244,"usage":{"input_tokens":10}}\n' > "$J1"
got="$(envelope_parse_total_cost "$J1")"
if [ "$got" = "0.244" ]; then pass "parse_total_cost: numeric value extracted (0.244)"
else fail "parse_total_cost expected '0.244' got '$got'"; fi

J2="$scratch/result-no-key.json"
printf '{"type":"result","subtype":"success","usage":{}}\n' > "$J2"
got="$(envelope_parse_total_cost "$J2")"
if [ -z "$got" ]; then pass "parse_total_cost: missing key -> empty (fail-closed)"
else fail "parse_total_cost missing key expected empty got '$got'"; fi

got="$(envelope_parse_total_cost "$scratch/no-such-result.json")"
if [ -z "$got" ]; then pass "parse_total_cost: missing file -> empty (fail-closed)"
else fail "parse_total_cost missing file expected empty got '$got'"; fi

J3="$scratch/result-bad-value.json"
printf '{"total_cost_usd":"abc"}\n' > "$J3"
got="$(envelope_parse_total_cost "$J3")"
if [ -z "$got" ]; then pass "parse_total_cost: non-numeric value -> empty (fail-closed)"
else fail "parse_total_cost non-numeric expected empty got '$got'"; fi

# --- envelope_write_kill_reason: behavioral + static atomic discipline ------

KRDIR="$scratch/kr"
mkdir -p "$KRDIR"
envelope_write_kill_reason "$KRDIR/reason" "stop-file"
if [ "$(cat "$KRDIR/reason")" = "stop-file" ]; then pass "kill-reason behavioral: target contains exactly the reason line"
else fail "kill-reason content wrong: '$(cat "$KRDIR/reason" 2>/dev/null || echo ABSENT)'"; fi

residue="$(find "$KRDIR" -name '*.tmp.*' | wc -l | tr -d ' ')"
if [ "$residue" = "0" ]; then pass "kill-reason behavioral: no *.tmp.* residue"
else fail "kill-reason left $residue tmp residue file(s)"; fi

# Static leg (P02 atomic-discipline verifier pattern): temp path + mv -f
# present in the library source; zero direct redirects to the target var.
if grep -q 'tmp\.\$\$' "$LIB"; then pass "kill-reason static: tmp.\$\$ temp path present in library"
else fail "kill-reason static: no tmp.\$\$ temp path in library"; fi

if grep -q 'mv -f' "$LIB"; then pass "kill-reason static: mv -f rename present in library"
else fail "kill-reason static: no mv -f rename in library"; fi

if grep -Eq '>[[:space:]]*"\$_ek_file"' "$LIB"; then
  fail "kill-reason static: direct redirect to \$_ek_file found (atomicity violation)"
else
  pass "kill-reason static: zero direct redirects to the kill-reason target"
fi

# --- envelope_watchdog: three kill triggers against real PIDs ---------------

# Leg 1: pre-created stop-file -> kill within ~3s, reason "stop-file".
STOP="$scratch/stop-now"
touch "$STOP"
R1="$scratch/reason-1"
sleep 30 &
wd_pid=$!
t0="$(date +%s)"
envelope_watchdog "$wd_pid" 1 "$STOP" $((t0 + 9999)) 999 0 "" 0 "$R1"
t1="$(date +%s)"
wait "$wd_pid" 2>/dev/null || true
if [ $((t1 - t0)) -le 5 ] && [ "$(cat "$R1" 2>/dev/null)" = "stop-file" ] \
   && ! kill -0 "$wd_pid" 2>/dev/null; then
  pass "watchdog stop-file: killed in $((t1 - t0))s, reason=stop-file, PID dead"
else
  fail "watchdog stop-file: elapsed=$((t1 - t0))s reason='$(cat "$R1" 2>/dev/null || echo ABSENT)' alive=$(kill -0 "$wd_pid" 2>/dev/null && echo yes || echo no)"
fi

# Leg 2: deadline already past -> reason starts wall-clock-exceeded.
R2="$scratch/reason-2"
sleep 30 &
wd_pid=$!
now="$(date +%s)"
envelope_watchdog "$wd_pid" 1 "" $((now - 10)) 999 0 "" 0 "$R2" $((now - 20))
wait "$wd_pid" 2>/dev/null || true
r2="$(cat "$R2" 2>/dev/null || echo ABSENT)"
case "$r2" in
  wall-clock-exceeded*)
    if printf '%s' "$r2" | grep -q 'elapsed_s=' && printf '%s' "$r2" | grep -q 'cap_s='; then
      pass "watchdog wall-clock: reason '$r2' (prefix + elapsed_s/cap_s fields)"
    else
      fail "watchdog wall-clock: prefix ok but fields missing: '$r2'"
    fi
    ;;
  *) fail "watchdog wall-clock: reason '$r2' does not start wall-clock-exceeded" ;;
esac
if ! kill -0 "$wd_pid" 2>/dev/null; then pass "watchdog wall-clock: PID dead"
else fail "watchdog wall-clock: PID still alive"; fi

# Leg 3: cost-derived budget kill -- stub appends a live unit_close record
# with estimated_cost_usd 9.0 after 1s; cap 5, spent_before 0.
LOG3="$scratch/live-cost.jsonl"
touch "$LOG3"
STUB="$scratch/cost-stub.sh"
cat > "$STUB" <<'EOF'
#!/usr/bin/env sh
sleep 1
printf '{"record_type":"unit_close","unitId":"TLIVE","estimated_cost_usd":9.0,"source":"stub"}\n' >> "$1"
sleep 30
EOF
chmod +x "$STUB"
R3="$scratch/reason-3"
sh "$STUB" "$LOG3" &
wd_pid=$!
now="$(date +%s)"
envelope_watchdog "$wd_pid" 1 "" $((now + 9999)) 5 0 "$LOG3" 0 "$R3"
wait "$wd_pid" 2>/dev/null || true
r3="$(cat "$R3" 2>/dev/null || echo ABSENT)"
case "$r3" in
  budget-exceeded*)
    if printf '%s' "$r3" | grep -q 'observed=9' ; then
      pass "watchdog budget: cost-derived kill, reason '$r3'"
    else
      fail "watchdog budget: prefix ok but observed= wrong: '$r3'"
    fi
    ;;
  *) fail "watchdog budget: reason '$r3' does not start budget-exceeded" ;;
esac
if ! kill -0 "$wd_pid" 2>/dev/null; then pass "watchdog budget: PID dead"
else fail "watchdog budget: PID still alive"; fi

# --- Summary -----------------------------------------------------------------

echo "SUMMARY: pass=$passes fail=$fails"
if [ "$fails" -eq 0 ]; then
  exit 0
else
  exit 1
fi
