#!/usr/bin/env bash
# tools/verify/p04-escalation-fields-enum.sh -- M030/P04 escalation fields gate.
#
# Asserts that the new escalation_count + escalation_reason fields appear
# on every shadow-on dispatch_usage record post-T03, with values drawn
# from the closed-enum sequences for each scenario:
#
#   Scenario A (no-failure, plan-mechanical-no-override, counter=0):
#     1 record. (count=0, reason="").
#   Scenario B (fail-twice-then-pass, counter=2):
#     3 records. (count=0, reason=verifier_fail) (count=1, reason=verifier_fail)
#                (count=2, reason="").
#   Scenario C (fail-three-times, counter=3):
#     3 records. (count=0, reason=verifier_fail) (count=1, reason=verifier_fail)
#                (count=2, reason=verifier_fail) + 1 escalation_cap_hit record.
#
# Seven assertions: 1 + 3 + 3 across the three scenarios.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Tmp-file
# intermediates per AP-009.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p04"
PLAN_NO_FAIL="$FIXTURES/plans/plan-mechanical-no-override.md"
PLAN_FAIL_TWICE="$FIXTURES/plans/plan-fail-twice-then-pass.md"
PLAN_FAIL_THRICE="$FIXTURES/plans/plan-fail-three-times.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-live-true.yml"
READY_CORPUS="$FIXTURES/shadow-corpus-ready.jsonl"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

ok=1
for f in "$PLAN_NO_FAIL" "$PLAN_FAIL_TWICE" "$PLAN_FAIL_THRICE" \
         "$PAYLOAD" "$INTENSITY_META" "$CONFIG" "$READY_CORPUS" "$DISPATCH"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -ne 1 ]; then
  printf 'SUMMARY: p04-escalation-fields-enum.sh pass=%d fail=1\n' "$pass"
  exit 1
fi

# --- Helpers ---
_extract_field() {
  printf '%s' "$1" | grep -oE "\"$2\":\"[^\"]*\"" | head -n 1 | sed -E 's/.*:"([^"]*)".*/\1/'
}
_extract_int_field() {
  printf '%s' "$1" | grep -oE "\"$2\":[0-9]+" | head -n 1 | sed -E 's/.*:([0-9]+).*/\1/'
}

# Run a dispatch + return path to filtered dispatch_usage tmp file.
# $1 = label, $2 = plan, $3 = counter value
_run_dispatch() {
  _label="$1"
  _plan="$2"
  _counter="$3"
  _tmp_root="$(mktemp -d 2>/dev/null)"
  if [ -z "$_tmp_root" ]; then
    _tmp_root="/tmp/p04-efe-${_label}-fallback-$$"
    rm -rf "$_tmp_root" 2>/dev/null
    mkdir -p "$_tmp_root" 2>/dev/null
  fi
  mkdir -p "$_tmp_root/.orchestrator" 2>/dev/null
  mkdir -p "$_tmp_root/phases" 2>/dev/null
  cp "$CONFIG" "$_tmp_root/.orchestrator/config.yml" 2>/dev/null
  _log_file="$_tmp_root/execution-log.jsonl"
  _ctr="$_tmp_root/fail-counter.txt"
  printf '%s\n' "$_counter" > "$_ctr"
  _inv="$_tmp_root/invocations.txt"
  : > "$_inv"

  unset ORCH_MODEL
  export ORCHESTRATOR_ROOT="$_tmp_root"
  export M030_SHADOW_MODE=1
  export CLAUDECODE=1
  export M030_SHADOW_COMPARE_CORPUS="$READY_CORPUS"
  export STUB_FAIL_COUNTER_FILE="$_ctr"
  export STUB_FAIL_COUNTER_INVOCATIONS_FILE="$_inv"

  bash "$DISPATCH" \
    --task-plan "$_plan" \
    --payload "$PAYLOAD" \
    --intensity-metadata "$INTENSITY_META" \
    --backend stub-fail-n \
    > /dev/null 2>/dev/null
  # NB: dispatch may exit nonzero (cap scenario) -- that's expected.

  # Filter dispatch_usage records into a stable tmp output path.
  _out_usage="/tmp/p04-efe-${_label}-usage.txt"
  rm -f "$_out_usage" 2>/dev/null
  grep -F '"record_type":"dispatch_usage"' "$_log_file" > "$_out_usage" 2>/dev/null

  # Stash _tmp_root for cleanup later.
  printf '%s\n' "$_tmp_root" > "/tmp/p04-efe-${_label}-tmproot.txt"
  printf '%s\n' "$_out_usage"
}

# --- Scenario A: no-failure ---
USAGE_A_PATH="$(_run_dispatch "A" "$PLAN_NO_FAIL" 0)"
LC_A_TMP="/tmp/p04-efe-A-lc.txt"
rm -f "$LC_A_TMP" 2>/dev/null
wc -l < "$USAGE_A_PATH" > "$LC_A_TMP" 2>/dev/null
LC_A="$(tr -d '[:space:]' < "$LC_A_TMP")"
rm -f "$LC_A_TMP" 2>/dev/null

# Assertion A.1: 1 record AND count=0 reason=""
if [ "$LC_A" = "1" ]; then
  L_A_TMP="/tmp/p04-efe-A-line.txt"
  rm -f "$L_A_TMP" 2>/dev/null
  head -n 1 "$USAGE_A_PATH" > "$L_A_TMP" 2>/dev/null
  L_A="$(head -n 1 "$L_A_TMP")"
  rm -f "$L_A_TMP" 2>/dev/null
  EC_A="$(_extract_int_field "$L_A" escalation_count)"
  ER_A="$(_extract_field "$L_A" escalation_reason)"
  if [ "$EC_A" = "0" ] && [ -z "$ER_A" ]; then
    pass=$((pass + 1))
    printf 'PASS: scenario A (no-fail) -- 1 record count=0 reason=""\n'
  else
    fail=$((fail + 1))
    printf 'FAIL: scenario A -- count=%s reason=%s, expected 0/""\n' "$EC_A" "$ER_A"
  fi
else
  fail=$((fail + 1))
  printf 'FAIL: scenario A -- expected 1 record, found %s\n' "$LC_A"
fi

# --- Scenario B: fail-twice-then-pass ---
USAGE_B_PATH="$(_run_dispatch "B" "$PLAN_FAIL_TWICE" 2)"
B_LINE1_TMP="/tmp/p04-efe-B-line1.txt"
B_LINE2_TMP="/tmp/p04-efe-B-line2.txt"
B_LINE3_TMP="/tmp/p04-efe-B-line3.txt"
rm -f "$B_LINE1_TMP" "$B_LINE2_TMP" "$B_LINE3_TMP" 2>/dev/null
sed -n '1p' "$USAGE_B_PATH" > "$B_LINE1_TMP" 2>/dev/null
sed -n '2p' "$USAGE_B_PATH" > "$B_LINE2_TMP" 2>/dev/null
sed -n '3p' "$USAGE_B_PATH" > "$B_LINE3_TMP" 2>/dev/null
B_LINE1="$(head -n 1 "$B_LINE1_TMP")"
B_LINE2="$(head -n 1 "$B_LINE2_TMP")"
B_LINE3="$(head -n 1 "$B_LINE3_TMP")"
rm -f "$B_LINE1_TMP" "$B_LINE2_TMP" "$B_LINE3_TMP" 2>/dev/null

# Assertion B.1: record 1 (count=0, reason=verifier_fail)
B_EC1="$(_extract_int_field "$B_LINE1" escalation_count)"
B_ER1="$(_extract_field "$B_LINE1" escalation_reason)"
if [ "$B_EC1" = "0" ] && [ "$B_ER1" = "verifier_fail" ]; then
  pass=$((pass + 1))
  printf 'PASS: scenario B record 1 -- count=0 reason=verifier_fail\n'
else
  fail=$((fail + 1))
  printf 'FAIL: scenario B record 1 -- count=%s reason=%s, expected 0/verifier_fail\n' \
    "$B_EC1" "$B_ER1"
fi

# Assertion B.2: record 2 (count=1, reason=verifier_fail)
B_EC2="$(_extract_int_field "$B_LINE2" escalation_count)"
B_ER2="$(_extract_field "$B_LINE2" escalation_reason)"
if [ "$B_EC2" = "1" ] && [ "$B_ER2" = "verifier_fail" ]; then
  pass=$((pass + 1))
  printf 'PASS: scenario B record 2 -- count=1 reason=verifier_fail\n'
else
  fail=$((fail + 1))
  printf 'FAIL: scenario B record 2 -- count=%s reason=%s, expected 1/verifier_fail\n' \
    "$B_EC2" "$B_ER2"
fi

# Assertion B.3: record 3 (count=2, reason="" -- success)
B_EC3="$(_extract_int_field "$B_LINE3" escalation_count)"
B_ER3="$(_extract_field "$B_LINE3" escalation_reason)"
if [ "$B_EC3" = "2" ] && [ -z "$B_ER3" ]; then
  pass=$((pass + 1))
  printf 'PASS: scenario B record 3 -- count=2 reason="" (success after 2 escalations)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: scenario B record 3 -- count=%s reason=%s, expected 2/""\n' \
    "$B_EC3" "$B_ER3"
fi

# --- Scenario C: fail-three-times (cap hit) ---
USAGE_C_PATH="$(_run_dispatch "C" "$PLAN_FAIL_THRICE" 3)"
C_LINE1_TMP="/tmp/p04-efe-C-line1.txt"
C_LINE2_TMP="/tmp/p04-efe-C-line2.txt"
C_LINE3_TMP="/tmp/p04-efe-C-line3.txt"
rm -f "$C_LINE1_TMP" "$C_LINE2_TMP" "$C_LINE3_TMP" 2>/dev/null
sed -n '1p' "$USAGE_C_PATH" > "$C_LINE1_TMP" 2>/dev/null
sed -n '2p' "$USAGE_C_PATH" > "$C_LINE2_TMP" 2>/dev/null
sed -n '3p' "$USAGE_C_PATH" > "$C_LINE3_TMP" 2>/dev/null
C_LINE1="$(head -n 1 "$C_LINE1_TMP")"
C_LINE2="$(head -n 1 "$C_LINE2_TMP")"
C_LINE3="$(head -n 1 "$C_LINE3_TMP")"
rm -f "$C_LINE1_TMP" "$C_LINE2_TMP" "$C_LINE3_TMP" 2>/dev/null

# Assertion C.1: record 1 (count=0, reason=verifier_fail)
C_EC1="$(_extract_int_field "$C_LINE1" escalation_count)"
C_ER1="$(_extract_field "$C_LINE1" escalation_reason)"
if [ "$C_EC1" = "0" ] && [ "$C_ER1" = "verifier_fail" ]; then
  pass=$((pass + 1))
  printf 'PASS: scenario C record 1 -- count=0 reason=verifier_fail\n'
else
  fail=$((fail + 1))
  printf 'FAIL: scenario C record 1 -- count=%s reason=%s, expected 0/verifier_fail\n' \
    "$C_EC1" "$C_ER1"
fi

# Assertion C.2: record 2 (count=1, reason=verifier_fail)
C_EC2="$(_extract_int_field "$C_LINE2" escalation_count)"
C_ER2="$(_extract_field "$C_LINE2" escalation_reason)"
if [ "$C_EC2" = "1" ] && [ "$C_ER2" = "verifier_fail" ]; then
  pass=$((pass + 1))
  printf 'PASS: scenario C record 2 -- count=1 reason=verifier_fail\n'
else
  fail=$((fail + 1))
  printf 'FAIL: scenario C record 2 -- count=%s reason=%s, expected 1/verifier_fail\n' \
    "$C_EC2" "$C_ER2"
fi

# Assertion C.3: record 3 (count=2, reason=verifier_fail -- cap hit)
C_EC3="$(_extract_int_field "$C_LINE3" escalation_count)"
C_ER3="$(_extract_field "$C_LINE3" escalation_reason)"
if [ "$C_EC3" = "2" ] && [ "$C_ER3" = "verifier_fail" ]; then
  pass=$((pass + 1))
  printf 'PASS: scenario C record 3 -- count=2 reason=verifier_fail (cap hit)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: scenario C record 3 -- count=%s reason=%s, expected 2/verifier_fail\n' \
    "$C_EC3" "$C_ER3"
fi

# --- Cleanup ---
for label in A B C; do
  TR_TMP="/tmp/p04-efe-${label}-tmproot.txt"
  if [ -f "$TR_TMP" ]; then
    TR_DIR_TMP="/tmp/p04-efe-${label}-tr-dir.txt"
    rm -f "$TR_DIR_TMP" 2>/dev/null
    head -n 1 "$TR_TMP" > "$TR_DIR_TMP" 2>/dev/null
    TR_DIR="$(head -n 1 "$TR_DIR_TMP")"
    rm -f "$TR_DIR_TMP" 2>/dev/null
    if [ -n "$TR_DIR" ] && [ -d "$TR_DIR" ]; then
      rm -rf "$TR_DIR" 2>/dev/null
    fi
    rm -f "$TR_TMP" 2>/dev/null
  fi
  rm -f "/tmp/p04-efe-${label}-usage.txt" 2>/dev/null
done
unset M030_SHADOW_COMPARE_CORPUS STUB_FAIL_COUNTER_FILE STUB_FAIL_COUNTER_INVOCATIONS_FILE

printf 'SUMMARY: p04-escalation-fields-enum.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
