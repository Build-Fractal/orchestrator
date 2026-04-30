#!/usr/bin/env bash
# tools/verify/p04-sc4-escalation-sequence.sh -- M030/P04 SC-4 escalation sequence.
#
# Asserts: with model_routing.live: true AND a ready-verdict shadow corpus
# AND the stub-fail-n.sh adapter (counter=2 -- fail twice then pass), the
# dispatch-interface escalation loop walks fast -> balanced -> smart and
# the third attempt succeeds. Six assertions:
#
#   1. dispatch-interface exits 0 (third attempt succeeded).
#   2. Exactly 3 dispatch_usage records appended.
#   3. Record 1 model_used == resolution.fast.claude-code.
#   4. Record 2 model_used == resolution.balanced.claude-code.
#   5. Record 3 model_used == resolution.smart.claude-code.
#   6. Record 3 escalation_count=2 AND escalation_reason="" (success record).
#
# CON-3-clean: expected model IDs read from templates/model-routing.yml at
# runtime via awk section-walker; zero hardcoded literals here.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Tmp-file
# intermediates per AP-009.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p04"
PLAN="$FIXTURES/plans/plan-fail-twice-then-pass.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-live-true.yml"
READY_CORPUS="$FIXTURES/shadow-corpus-ready.jsonl"
ROUTING_TABLE="$REPO_ROOT/templates/model-routing.yml"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

ok=1
for f in "$PLAN" "$PAYLOAD" "$INTENSITY_META" "$CONFIG" "$READY_CORPUS" "$ROUTING_TABLE" "$DISPATCH"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -ne 1 ]; then
  printf 'SUMMARY: p04-sc4-escalation-sequence.sh pass=%d fail=1\n' "$pass"
  exit 1
fi

# --- Resolve EXPECTED_FAST / EXPECTED_BALANCED / EXPECTED_SMART from SSOT ---
_resolve_tier() {
  # $1 = symbolic tier (fast|balanced|smart). Echoes resolution.<tier>.claude-code.
  awk -v tier="$1" '
    BEGIN { in_resolution = 0; in_tier = 0 }
    /^resolution:/                    { in_resolution = 1; next }
    /^cost_rates:/                    { exit }
    in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
    in_resolution && in_tier && /^    claude-code:/ {
      val = $2; gsub(/[",]/, "", val); print val; exit
    }
  ' "$ROUTING_TABLE"
}
EXPECTED_FAST="$(_resolve_tier fast)"
EXPECTED_BALANCED="$(_resolve_tier balanced)"
EXPECTED_SMART="$(_resolve_tier smart)"
if [ -z "$EXPECTED_FAST" ] || [ -z "$EXPECTED_BALANCED" ] || [ -z "$EXPECTED_SMART" ]; then
  printf 'FAIL: could not resolve expected tier model IDs (fast=%s balanced=%s smart=%s)\n' \
    "$EXPECTED_FAST" "$EXPECTED_BALANCED" "$EXPECTED_SMART"
  printf 'SUMMARY: p04-sc4-escalation-sequence.sh pass=0 fail=1\n'
  exit 1
fi

# --- Stage tmp_root + counter file (value=2 -> fail twice, then pass) ---
TMP_ROOT="$(mktemp -d 2>/dev/null)"
if [ -z "$TMP_ROOT" ]; then
  TMP_ROOT="/tmp/p04-sc4-fallback-$$"
  rm -rf "$TMP_ROOT" 2>/dev/null
  mkdir -p "$TMP_ROOT" 2>/dev/null
fi
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml" 2>/dev/null
LOG_FILE="$TMP_ROOT/execution-log.jsonl"

COUNTER_FILE="$TMP_ROOT/fail-counter.txt"
printf '2\n' > "$COUNTER_FILE"
INVOCATIONS_FILE="$TMP_ROOT/invocations.txt"
: > "$INVOCATIONS_FILE"

unset ORCH_MODEL
export ORCHESTRATOR_ROOT="$TMP_ROOT"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
export M030_SHADOW_COMPARE_CORPUS="$READY_CORPUS"
export STUB_FAIL_COUNTER_FILE="$COUNTER_FILE"
export STUB_FAIL_COUNTER_INVOCATIONS_FILE="$INVOCATIONS_FILE"

DISPATCH_OUT_TMP="/tmp/p04-sc4-out.txt"
DISPATCH_ERR_TMP="/tmp/p04-sc4-err.txt"
rm -f "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub-fail-n \
  > "$DISPATCH_OUT_TMP" 2> "$DISPATCH_ERR_TMP"
DISPATCH_RC=$?

# --- Assertion 1: dispatch-interface exits 0 ---
if [ "$DISPATCH_RC" -eq 0 ]; then
  pass=$((pass + 1))
  printf 'PASS: dispatch-interface exited 0 (third attempt succeeded)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: dispatch-interface exited %d, expected 0\n' "$DISPATCH_RC"
fi

# --- Assertion 2: exactly 3 dispatch_usage records ---
LINE_TMP="/tmp/p04-sc4-lines.txt"
LC_TMP="/tmp/p04-sc4-lc.txt"
rm -f "$LINE_TMP" "$LC_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null
wc -l < "$LINE_TMP" > "$LC_TMP" 2>/dev/null
LC="$(tr -d '[:space:]' < "$LC_TMP")"
if [ "$LC" = "3" ]; then
  pass=$((pass + 1))
  printf 'PASS: exactly 3 dispatch_usage records appended\n'
else
  fail=$((fail + 1))
  printf 'FAIL: expected 3 dispatch_usage records, found %s\n' "$LC"
fi

# --- Helper: extract a JSON string field from a single JSONL line ---
_extract_field() {
  # $1 = line, $2 = field name. Echoes value.
  printf '%s' "$1" | grep -oE "\"$2\":\"[^\"]*\"" | head -n 1 | sed -E 's/.*:"([^"]*)".*/\1/'
}
_extract_int_field() {
  # $1 = line, $2 = field name. Echoes integer value (no quotes).
  printf '%s' "$1" | grep -oE "\"$2\":[0-9]+" | head -n 1 | sed -E 's/.*:([0-9]+).*/\1/'
}

LINE1_TMP="/tmp/p04-sc4-line1.txt"
LINE2_TMP="/tmp/p04-sc4-line2.txt"
LINE3_TMP="/tmp/p04-sc4-line3.txt"
rm -f "$LINE1_TMP" "$LINE2_TMP" "$LINE3_TMP" 2>/dev/null
sed -n '1p' "$LINE_TMP" > "$LINE1_TMP" 2>/dev/null
sed -n '2p' "$LINE_TMP" > "$LINE2_TMP" 2>/dev/null
sed -n '3p' "$LINE_TMP" > "$LINE3_TMP" 2>/dev/null
LINE1="$(head -n 1 "$LINE1_TMP")"
LINE2="$(head -n 1 "$LINE2_TMP")"
LINE3="$(head -n 1 "$LINE3_TMP")"

# --- Assertion 3: Record 1 model_used == EXPECTED_FAST ---
M1="$(_extract_field "$LINE1" model_used)"
if [ "$M1" = "$EXPECTED_FAST" ]; then
  pass=$((pass + 1))
  printf 'PASS: record 1 model_used=%s (resolution.fast.claude-code)\n' "$M1"
else
  fail=$((fail + 1))
  printf 'FAIL: record 1 model_used=%s, expected %s\n' "$M1" "$EXPECTED_FAST"
fi

# --- Assertion 4: Record 2 model_used == EXPECTED_BALANCED ---
M2="$(_extract_field "$LINE2" model_used)"
if [ "$M2" = "$EXPECTED_BALANCED" ]; then
  pass=$((pass + 1))
  printf 'PASS: record 2 model_used=%s (resolution.balanced.claude-code)\n' "$M2"
else
  fail=$((fail + 1))
  printf 'FAIL: record 2 model_used=%s, expected %s\n' "$M2" "$EXPECTED_BALANCED"
fi

# --- Assertion 5: Record 3 model_used == EXPECTED_SMART ---
M3="$(_extract_field "$LINE3" model_used)"
if [ "$M3" = "$EXPECTED_SMART" ]; then
  pass=$((pass + 1))
  printf 'PASS: record 3 model_used=%s (resolution.smart.claude-code)\n' "$M3"
else
  fail=$((fail + 1))
  printf 'FAIL: record 3 model_used=%s, expected %s\n' "$M3" "$EXPECTED_SMART"
fi

# --- Assertion 6: Record 3 escalation_count=2 AND escalation_reason="" ---
EC3="$(_extract_int_field "$LINE3" escalation_count)"
ER3="$(_extract_field "$LINE3" escalation_reason)"
if [ "$EC3" = "2" ] && [ -z "$ER3" ]; then
  pass=$((pass + 1))
  printf 'PASS: record 3 escalation_count=%s reason=<empty> (success after 2 escalations)\n' "$EC3"
else
  fail=$((fail + 1))
  printf 'FAIL: record 3 escalation_count=%s reason=%s, expected 2 and empty\n' "$EC3" "$ER3"
fi

# --- Cleanup ---
rm -f "$LINE_TMP" "$LC_TMP" "$LINE1_TMP" "$LINE2_TMP" "$LINE3_TMP" \
  "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null
unset M030_SHADOW_COMPARE_CORPUS STUB_FAIL_COUNTER_FILE STUB_FAIL_COUNTER_INVOCATIONS_FILE

printf 'SUMMARY: p04-sc4-escalation-sequence.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
