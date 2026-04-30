#!/usr/bin/env bash
# tools/verify/p04-sc5-escalation-cap.sh -- M030/P04 SC-5 escalation cap.
#
# Asserts: with model_routing.live: true AND a ready-verdict shadow corpus
# AND the stub-fail-n.sh adapter (counter=3 -- fail every attempt up to
# the cap), the dispatch-interface escalation loop walks fast -> balanced
# -> smart, all three attempts fail, and the CON-5 hard-cap fires.
# Six assertions:
#
#   1. dispatch-interface exits nonzero (5 -- backend_crashed after cap).
#   2. Exactly 3 dispatch_usage records appended.
#   3. Exactly 1 escalation_cap_hit record appended.
#   4. escalation_cap_hit final_count=2 AND unitId matches dispatch_usage unitId.
#   5. Each of the 3 dispatch_usage records has escalation_reason=verifier_fail.
#   6. Record 3 escalation_count=2.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Tmp-file
# intermediates per AP-009.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p04"
PLAN="$FIXTURES/plans/plan-fail-three-times.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-live-true.yml"
READY_CORPUS="$FIXTURES/shadow-corpus-ready.jsonl"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

ok=1
for f in "$PLAN" "$PAYLOAD" "$INTENSITY_META" "$CONFIG" "$READY_CORPUS" "$DISPATCH"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -ne 1 ]; then
  printf 'SUMMARY: p04-sc5-escalation-cap.sh pass=%d fail=1\n' "$pass"
  exit 1
fi

# --- Stage tmp_root + counter file (value=3 -> fail three attempts) ---
TMP_ROOT="$(mktemp -d 2>/dev/null)"
if [ -z "$TMP_ROOT" ]; then
  TMP_ROOT="/tmp/p04-sc5-fallback-$$"
  rm -rf "$TMP_ROOT" 2>/dev/null
  mkdir -p "$TMP_ROOT" 2>/dev/null
fi
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml" 2>/dev/null
LOG_FILE="$TMP_ROOT/execution-log.jsonl"

COUNTER_FILE="$TMP_ROOT/fail-counter.txt"
printf '3\n' > "$COUNTER_FILE"
INVOCATIONS_FILE="$TMP_ROOT/invocations.txt"
: > "$INVOCATIONS_FILE"

unset ORCH_MODEL
export ORCHESTRATOR_ROOT="$TMP_ROOT"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
export M030_SHADOW_COMPARE_CORPUS="$READY_CORPUS"
export STUB_FAIL_COUNTER_FILE="$COUNTER_FILE"
export STUB_FAIL_COUNTER_INVOCATIONS_FILE="$INVOCATIONS_FILE"

DISPATCH_OUT_TMP="/tmp/p04-sc5-out.txt"
DISPATCH_ERR_TMP="/tmp/p04-sc5-err.txt"
rm -f "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub-fail-n \
  > "$DISPATCH_OUT_TMP" 2> "$DISPATCH_ERR_TMP"
DISPATCH_RC=$?

# --- Assertion 1: dispatch-interface exits nonzero ---
if [ "$DISPATCH_RC" -ne 0 ]; then
  pass=$((pass + 1))
  printf 'PASS: dispatch-interface exited %d (nonzero, cap hit)\n' "$DISPATCH_RC"
else
  fail=$((fail + 1))
  printf 'FAIL: dispatch-interface exited 0, expected nonzero\n'
fi

# --- Assertion 2: exactly 3 dispatch_usage records ---
USAGE_TMP="/tmp/p04-sc5-usage.txt"
USAGE_LC_TMP="/tmp/p04-sc5-usage-lc.txt"
rm -f "$USAGE_TMP" "$USAGE_LC_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$USAGE_TMP" 2>/dev/null
wc -l < "$USAGE_TMP" > "$USAGE_LC_TMP" 2>/dev/null
USAGE_LC="$(tr -d '[:space:]' < "$USAGE_LC_TMP")"
if [ "$USAGE_LC" = "3" ]; then
  pass=$((pass + 1))
  printf 'PASS: exactly 3 dispatch_usage records\n'
else
  fail=$((fail + 1))
  printf 'FAIL: expected 3 dispatch_usage records, found %s\n' "$USAGE_LC"
fi

# --- Assertion 3: exactly 1 escalation_cap_hit record ---
CAP_TMP="/tmp/p04-sc5-cap.txt"
CAP_LC_TMP="/tmp/p04-sc5-cap-lc.txt"
rm -f "$CAP_TMP" "$CAP_LC_TMP" 2>/dev/null
grep -F '"record_type":"escalation_cap_hit"' "$LOG_FILE" > "$CAP_TMP" 2>/dev/null
wc -l < "$CAP_TMP" > "$CAP_LC_TMP" 2>/dev/null
CAP_LC="$(tr -d '[:space:]' < "$CAP_LC_TMP")"
if [ "$CAP_LC" = "1" ]; then
  pass=$((pass + 1))
  printf 'PASS: exactly 1 escalation_cap_hit record\n'
else
  fail=$((fail + 1))
  printf 'FAIL: expected 1 escalation_cap_hit record, found %s\n' "$CAP_LC"
fi

# --- Helpers ---
_extract_field() {
  printf '%s' "$1" | grep -oE "\"$2\":\"[^\"]*\"" | head -n 1 | sed -E 's/.*:"([^"]*)".*/\1/'
}
_extract_int_field() {
  printf '%s' "$1" | grep -oE "\"$2\":[0-9]+" | head -n 1 | sed -E 's/.*:([0-9]+).*/\1/'
}

CAP_LINE_TMP="/tmp/p04-sc5-cap-line.txt"
rm -f "$CAP_LINE_TMP" 2>/dev/null
head -n 1 "$CAP_TMP" > "$CAP_LINE_TMP" 2>/dev/null
CAP_LINE="$(head -n 1 "$CAP_LINE_TMP")"

USAGE_LINE3_TMP="/tmp/p04-sc5-line3.txt"
rm -f "$USAGE_LINE3_TMP" 2>/dev/null
sed -n '3p' "$USAGE_TMP" > "$USAGE_LINE3_TMP" 2>/dev/null
USAGE_LINE3="$(head -n 1 "$USAGE_LINE3_TMP")"

# --- Assertion 4: cap_hit final_count=2 AND unitId matches ---
CAP_FINAL="$(_extract_int_field "$CAP_LINE" final_count)"
CAP_UID="$(_extract_field "$CAP_LINE" unitId)"
USAGE3_UID="$(_extract_field "$USAGE_LINE3" unitId)"
if [ "$CAP_FINAL" = "2" ] && [ -n "$CAP_UID" ] && [ "$CAP_UID" = "$USAGE3_UID" ]; then
  pass=$((pass + 1))
  printf 'PASS: cap_hit final_count=2 unitId=%s matches dispatch_usage unitId\n' "$CAP_UID"
else
  fail=$((fail + 1))
  printf 'FAIL: cap_hit final_count=%s unitId=%s, dispatch_usage unitId=%s\n' \
    "$CAP_FINAL" "$CAP_UID" "$USAGE3_UID"
fi

# --- Assertion 5: every dispatch_usage record has escalation_reason=verifier_fail ---
ER_TMP="/tmp/p04-sc5-er.txt"
ER_BAD_TMP="/tmp/p04-sc5-er-bad.txt"
rm -f "$ER_TMP" "$ER_BAD_TMP" 2>/dev/null
grep -oE '"escalation_reason":"[^"]*"' "$USAGE_TMP" > "$ER_TMP" 2>/dev/null
grep -v '"escalation_reason":"verifier_fail"' "$ER_TMP" > "$ER_BAD_TMP" 2>/dev/null
ER_BAD_LC_TMP="/tmp/p04-sc5-er-bad-lc.txt"
wc -l < "$ER_BAD_TMP" > "$ER_BAD_LC_TMP" 2>/dev/null
ER_BAD_LC="$(tr -d '[:space:]' < "$ER_BAD_LC_TMP")"
if [ "$ER_BAD_LC" = "0" ]; then
  pass=$((pass + 1))
  printf 'PASS: all 3 dispatch_usage records have escalation_reason=verifier_fail\n'
else
  fail=$((fail + 1))
  printf 'FAIL: %s dispatch_usage records have non-verifier_fail escalation_reason\n' "$ER_BAD_LC"
fi

# --- Assertion 6: Record 3 escalation_count=2 ---
EC3="$(_extract_int_field "$USAGE_LINE3" escalation_count)"
if [ "$EC3" = "2" ]; then
  pass=$((pass + 1))
  printf 'PASS: record 3 escalation_count=%s\n' "$EC3"
else
  fail=$((fail + 1))
  printf 'FAIL: record 3 escalation_count=%s, expected 2\n' "$EC3"
fi

# --- Cleanup ---
rm -f "$USAGE_TMP" "$USAGE_LC_TMP" "$CAP_TMP" "$CAP_LC_TMP" "$CAP_LINE_TMP" \
  "$USAGE_LINE3_TMP" "$ER_TMP" "$ER_BAD_TMP" "$ER_BAD_LC_TMP" \
  "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null
unset M030_SHADOW_COMPARE_CORPUS STUB_FAIL_COUNTER_FILE STUB_FAIL_COUNTER_INVOCATIONS_FILE

printf 'SUMMARY: p04-sc5-escalation-cap.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
