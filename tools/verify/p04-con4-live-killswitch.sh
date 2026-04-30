#!/usr/bin/env bash
# tools/verify/p04-con4-live-killswitch.sh -- M030/P04 CON-4 / D-A5 / SC-7a-style.
#
# Asserts: with both model_routing_enabled: false (kill switch) AND
# model_routing.live: true AND model_routing.min_tier: smart, dispatch
# records override_source=disabled (NOT shadow_gate_blocked) and emits
# stderr warnings naming both the bypassed min_tier AND live: true.
# The live-routing block MUST NOT engage; shadow-compare.sh MUST NOT be
# invoked (gated structurally by the precedence chain).
#
# Four assertions:
#   1. JSONL override_source == "disabled".
#   2. JSONL model_used == runtime default (intensity-metadata model: field).
#   3. Stderr contains "live: true is inactive".
#   4. Stderr contains "min_tier: ... is inactive".
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Tmp-file
# intermediates per AP-009. Exit 0 iff fail == 0.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p04"
PLAN="$FIXTURES/plans/plan-mechanical-no-override.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-live-and-killswitch.yml"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

ok=1
for f in "$PLAN" "$PAYLOAD" "$INTENSITY_META" "$CONFIG" "$DISPATCH"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -ne 1 ]; then
  printf 'SUMMARY: p04-con4-live-killswitch.sh pass=%d fail=1\n' "$pass"
  exit 1
fi

# --- Resolve runtime default ---
RD_TMP="/tmp/p04-con4-rd.txt"
rm -f "$RD_TMP" 2>/dev/null
grep -E '^model:' "$INTENSITY_META" > "$RD_TMP" 2>/dev/null
RD_RAW="$(head -n 1 "$RD_TMP")"
rm -f "$RD_TMP" 2>/dev/null
RUNTIME_DEFAULT="$(printf '%s' "$RD_RAW" | sed -E 's/^model:[[:space:]]*"?([^"]*)"?.*/\1/')"

# --- Stage tmp_root ---
TMP_ROOT="$(mktemp -d 2>/dev/null)"
if [ -z "$TMP_ROOT" ]; then
  TMP_ROOT="/tmp/p04-con4-fallback-$$"
  rm -rf "$TMP_ROOT" 2>/dev/null
  mkdir -p "$TMP_ROOT" 2>/dev/null
fi
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml" 2>/dev/null
LOG_FILE="$TMP_ROOT/execution-log.jsonl"

unset ORCH_MODEL
unset M030_SHADOW_COMPARE_CORPUS
export ORCHESTRATOR_ROOT="$TMP_ROOT"
export M030_SHADOW_MODE=1
export CLAUDECODE=1

DISPATCH_OUT_TMP="/tmp/p04-con4-out.txt"
DISPATCH_ERR_TMP="/tmp/p04-con4-err.txt"
rm -f "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub \
  > "$DISPATCH_OUT_TMP" 2> "$DISPATCH_ERR_TMP"

# --- Assertion 1: JSONL override_source == disabled ---
LINE_TMP="/tmp/p04-con4-line.txt"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null
OS_TMP="/tmp/p04-con4-os.txt"
rm -f "$OS_TMP" 2>/dev/null
grep -oE '"override_source":"[^"]*"' "$LINE_TMP" > "$OS_TMP" 2>/dev/null
OS_RAW="$(head -n 1 "$OS_TMP")"
rm -f "$OS_TMP" 2>/dev/null
OS_VALUE="$(printf '%s' "$OS_RAW" | sed -E 's/.*:"([^"]*)".*/\1/')"
if [ "$OS_VALUE" = "disabled" ]; then
  pass=$((pass + 1))
  printf 'PASS: override_source=disabled (kill switch wins over live: true)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: override_source=%s, expected disabled (kill switch should beat live)\n' "$OS_VALUE"
fi

# --- Assertion 2: JSONL model_used == runtime default ---
MU_TMP="/tmp/p04-con4-mu.txt"
rm -f "$MU_TMP" 2>/dev/null
grep -oE '"model_used":"[^"]*"' "$LINE_TMP" > "$MU_TMP" 2>/dev/null
MU_RAW="$(head -n 1 "$MU_TMP")"
rm -f "$MU_TMP" 2>/dev/null
MU_VALUE="$(printf '%s' "$MU_RAW" | sed -E 's/.*:"([^"]*)".*/\1/')"
if [ "$MU_VALUE" = "$RUNTIME_DEFAULT" ]; then
  pass=$((pass + 1))
  printf 'PASS: model_used=%s matches runtime-default channel\n' "$MU_VALUE"
else
  fail=$((fail + 1))
  printf 'FAIL: model_used=%s, expected runtime default %s\n' "$MU_VALUE" "$RUNTIME_DEFAULT"
fi

# --- Assertion 3: stderr contains "live: true is inactive" ---
LIVE_TMP="/tmp/p04-con4-live.txt"
rm -f "$LIVE_TMP" 2>/dev/null
grep -F 'live: true is inactive' "$DISPATCH_ERR_TMP" > "$LIVE_TMP" 2>/dev/null
LIVE_LC_TMP="/tmp/p04-con4-live-lc.txt"
rm -f "$LIVE_LC_TMP" 2>/dev/null
wc -l < "$LIVE_TMP" > "$LIVE_LC_TMP" 2>/dev/null
LIVE_LC="$(tr -d '[:space:]' < "$LIVE_LC_TMP")"
[ -n "$LIVE_LC" ] || LIVE_LC=0
rm -f "$LIVE_TMP" "$LIVE_LC_TMP" 2>/dev/null
if [ "$LIVE_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: stderr names "live: true is inactive"\n'
else
  fail=$((fail + 1))
  printf 'FAIL: stderr missing "live: true is inactive" warning\n'
fi

# --- Assertion 4: stderr contains "min_tier: <value> is inactive" ---
MT_TMP="/tmp/p04-con4-mt.txt"
rm -f "$MT_TMP" 2>/dev/null
grep -E 'min_tier: .* is inactive' "$DISPATCH_ERR_TMP" > "$MT_TMP" 2>/dev/null
MT_LC_TMP="/tmp/p04-con4-mt-lc.txt"
rm -f "$MT_LC_TMP" 2>/dev/null
wc -l < "$MT_TMP" > "$MT_LC_TMP" 2>/dev/null
MT_LC="$(tr -d '[:space:]' < "$MT_LC_TMP")"
[ -n "$MT_LC" ] || MT_LC=0
rm -f "$MT_TMP" "$MT_LC_TMP" 2>/dev/null
if [ "$MT_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: stderr names "min_tier: ... is inactive"\n'
else
  fail=$((fail + 1))
  printf 'FAIL: stderr missing "min_tier: ... is inactive" warning\n'
fi

# --- Cleanup ---
rm -f "$LINE_TMP" "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null

printf 'SUMMARY: p04-con4-live-killswitch.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
