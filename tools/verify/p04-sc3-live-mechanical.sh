#!/usr/bin/env bash
# tools/verify/p04-sc3-live-mechanical.sh -- M030/P04 SC-3 live-routing happy-path.
#
# Asserts: with model_routing.live: true AND a ready shadow corpus AND a
# mechanical-class plan, dispatch-interface routes the dispatch live:
#   - the appended JSONL record's model_used field equals
#     resolution.fast.claude-code (the mechanical class's runtime model id).
#   - the stub-record-model adapter receives the same value via --model
#     (proves the dispatcher's amended adapter invocation passes the flag).
#   - dispatch-interface exits 0 (live-routed dispatch succeeded).
#
# Three assertions. CON-3-clean: the expected fast-tier model id is read
# from templates/model-routing.yml at runtime via awk section-walker;
# zero hardcoded literals in this verifier.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Tmp-file
# intermediates per AP-009. Exit 0 iff fail == 0.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p04"
PLAN="$FIXTURES/plans/plan-mechanical-no-override.md"
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
  printf 'SUMMARY: p04-sc3-live-mechanical.sh pass=%d fail=1\n' "$pass"
  exit 1
fi

# --- Resolve expected fast-tier model id from routing-table SSOT ---
EXPECTED_FAST_TMP="/tmp/p04-sc3-expected.txt"
rm -f "$EXPECTED_FAST_TMP" 2>/dev/null
awk '
  BEGIN { in_resolution = 0; in_tier = 0 }
  /^resolution:/                    { in_resolution = 1; next }
  /^cost_rates:/                    { exit }
  in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == "fast:") ? 1 : 0; next }
  in_resolution && in_tier && /^    claude-code:/ {
    val = $2; gsub(/[",]/, "", val); print val; exit
  }
' "$ROUTING_TABLE" > "$EXPECTED_FAST_TMP"
EXPECTED_FAST="$(head -n 1 "$EXPECTED_FAST_TMP")"
rm -f "$EXPECTED_FAST_TMP" 2>/dev/null
if [ -z "$EXPECTED_FAST" ]; then
  printf 'FAIL: could not resolve resolution.fast.claude-code from %s\n' "$ROUTING_TABLE"
  printf 'SUMMARY: p04-sc3-live-mechanical.sh pass=0 fail=1\n'
  exit 1
fi

# --- Stage tmp_root ---
TMP_ROOT="$(mktemp -d 2>/dev/null)"
if [ -z "$TMP_ROOT" ]; then
  TMP_ROOT="/tmp/p04-sc3-fallback-$$"
  rm -rf "$TMP_ROOT" 2>/dev/null
  mkdir -p "$TMP_ROOT" 2>/dev/null
fi
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml" 2>/dev/null
LOG_FILE="$TMP_ROOT/execution-log.jsonl"

STUB_RECORD_FILE="$TMP_ROOT/stub-record-model.txt"
rm -f "$STUB_RECORD_FILE" 2>/dev/null

unset ORCH_MODEL
export ORCHESTRATOR_ROOT="$TMP_ROOT"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
export M030_SHADOW_COMPARE_CORPUS="$READY_CORPUS"
export STUB_RECORD_MODEL_FILE="$STUB_RECORD_FILE"

DISPATCH_OUT_TMP="/tmp/p04-sc3-out.txt"
DISPATCH_ERR_TMP="/tmp/p04-sc3-err.txt"
rm -f "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub-record-model \
  > "$DISPATCH_OUT_TMP" 2> "$DISPATCH_ERR_TMP"
DISPATCH_RC=$?

# --- Assertion 1: appended JSONL model_used == EXPECTED_FAST ---
LINE_TMP="/tmp/p04-sc3-line.txt"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null
MODEL_USED_TMP="/tmp/p04-sc3-model-used.txt"
rm -f "$MODEL_USED_TMP" 2>/dev/null
grep -oE '"model_used":"[^"]*"' "$LINE_TMP" > "$MODEL_USED_TMP" 2>/dev/null
MODEL_USED_RAW="$(head -n 1 "$MODEL_USED_TMP")"
rm -f "$MODEL_USED_TMP" 2>/dev/null
MODEL_USED="$(printf '%s' "$MODEL_USED_RAW" | sed -E 's/.*:"([^"]*)".*/\1/')"
if [ "$MODEL_USED" = "$EXPECTED_FAST" ]; then
  pass=$((pass + 1))
  printf 'PASS: JSONL model_used=%s matches resolution.fast.claude-code\n' "$MODEL_USED"
else
  fail=$((fail + 1))
  printf 'FAIL: JSONL model_used=%s, expected %s\n' "$MODEL_USED" "$EXPECTED_FAST"
fi

# --- Assertion 2: stub-record-model adapter received --model EXPECTED_FAST ---
RECORDED_TMP="/tmp/p04-sc3-recorded.txt"
rm -f "$RECORDED_TMP" 2>/dev/null
if [ -f "$STUB_RECORD_FILE" ]; then
  head -n 1 "$STUB_RECORD_FILE" > "$RECORDED_TMP" 2>/dev/null
fi
RECORDED="$(head -n 1 "$RECORDED_TMP" 2>/dev/null)"
rm -f "$RECORDED_TMP" 2>/dev/null
if [ -z "$RECORDED" ]; then RECORDED="<missing>"; fi
if [ "$RECORDED" = "$EXPECTED_FAST" ]; then
  pass=$((pass + 1))
  printf 'PASS: stub-record-model received --model %s\n' "$RECORDED"
else
  fail=$((fail + 1))
  printf 'FAIL: stub-record-model recorded %s, expected %s\n' "$RECORDED" "$EXPECTED_FAST"
fi

# --- Assertion 3: dispatch-interface exits 0 ---
if [ "$DISPATCH_RC" -eq 0 ]; then
  pass=$((pass + 1))
  printf 'PASS: dispatch-interface exited 0 (live-routed dispatch succeeded)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: dispatch-interface exited %d, expected 0\n' "$DISPATCH_RC"
fi

# --- Cleanup ---
rm -f "$LINE_TMP" "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null
unset M030_SHADOW_COMPARE_CORPUS
unset STUB_RECORD_MODEL_FILE

printf 'SUMMARY: p04-sc3-live-mechanical.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
