#!/usr/bin/env bash
# tools/verify/p04-partial-flip-routing.sh -- M030/P04 D-A3 partial-flip routing.
#
# Asserts: with model_routing.live: true AND a partially_ready shadow corpus
# (verdict partially_ready, withheld_classes=novel), per-class authorization
# applies. Two stages:
#   STAGE A (mechanical, flippable):
#     - JSONL model_used == resolution.fast.claude-code
#     - JSONL partial_flip_active == true
#     - JSONL withheld_classes == novel
#   STAGE B (novel, withheld):
#     - JSONL model_used == runtime default (intensity-metadata model: field)
#     - JSONL partial_flip_active == true
#     - JSONL withheld_classes == novel
#
# Six assertions (3 per stage). Bash 3.2 compatible. AD-19 single-script-
# file shape. Tmp-file intermediates per AP-009.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p04"
PLAN_MECH="$FIXTURES/plans/plan-mechanical-no-override.md"
PLAN_NOVEL="$FIXTURES/plans/plan-novel-class.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-live-true.yml"
PARTIAL_CORPUS="$FIXTURES/shadow-corpus-partially-ready.jsonl"
ROUTING_TABLE="$REPO_ROOT/templates/model-routing.yml"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

ok=1
for f in "$PLAN_MECH" "$PLAN_NOVEL" "$PAYLOAD" "$INTENSITY_META" "$CONFIG" \
         "$PARTIAL_CORPUS" "$ROUTING_TABLE" "$DISPATCH"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -ne 1 ]; then
  printf 'SUMMARY: p04-partial-flip-routing.sh pass=%d fail=1\n' "$pass"
  exit 1
fi

# --- Resolve EXPECTED_FAST (resolution.fast.claude-code) ---
EXPECTED_FAST_TMP="/tmp/p04-pf-expected-fast.txt"
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

# --- Resolve runtime default from intensity-metadata.txt model: field ---
RUNTIME_DEFAULT_TMP="/tmp/p04-pf-runtime-default.txt"
rm -f "$RUNTIME_DEFAULT_TMP" 2>/dev/null
grep -E '^model:' "$INTENSITY_META" > "$RUNTIME_DEFAULT_TMP" 2>/dev/null
RUNTIME_DEFAULT_RAW="$(head -n 1 "$RUNTIME_DEFAULT_TMP")"
rm -f "$RUNTIME_DEFAULT_TMP" 2>/dev/null
RUNTIME_DEFAULT="$(printf '%s' "$RUNTIME_DEFAULT_RAW" | sed -E 's/^model:[[:space:]]*"?([^"]*)"?.*/\1/')"

if [ -z "$EXPECTED_FAST" ] || [ -z "$RUNTIME_DEFAULT" ]; then
  printf 'FAIL: could not resolve EXPECTED_FAST=%s RUNTIME_DEFAULT=%s\n' \
    "$EXPECTED_FAST" "$RUNTIME_DEFAULT"
  printf 'SUMMARY: p04-partial-flip-routing.sh pass=0 fail=1\n'
  exit 1
fi

_run_stage() {
  # $1 = label
  # $2 = task plan path
  # Outputs: writes the JSONL line of the dispatch_usage record to
  # /tmp/p04-pf-line.txt and the dispatch exit code to /tmp/p04-pf-rc.txt.
  local label="$1"
  local plan="$2"

  local stage_root
  stage_root="$(mktemp -d 2>/dev/null)"
  if [ -z "$stage_root" ]; then
    stage_root="/tmp/p04-pf-stage-$$-${RANDOM}"
    rm -rf "$stage_root" 2>/dev/null
    mkdir -p "$stage_root" 2>/dev/null
  fi
  mkdir -p "$stage_root/.orchestrator" 2>/dev/null
  mkdir -p "$stage_root/phases" 2>/dev/null
  cp "$CONFIG" "$stage_root/.orchestrator/config.yml" 2>/dev/null
  local stage_log="$stage_root/execution-log.jsonl"

  unset ORCH_MODEL
  export ORCHESTRATOR_ROOT="$stage_root"
  export M030_SHADOW_MODE=1
  export CLAUDECODE=1
  export M030_SHADOW_COMPARE_CORPUS="$PARTIAL_CORPUS"

  bash "$DISPATCH" \
    --task-plan "$plan" \
    --payload "$PAYLOAD" \
    --intensity-metadata "$INTENSITY_META" \
    --backend stub-record-model \
    > /dev/null 2> /dev/null
  local rc=$?

  printf '%d\n' "$rc" > /tmp/p04-pf-rc.txt
  rm -f /tmp/p04-pf-line.txt 2>/dev/null
  grep -F '"record_type":"dispatch_usage"' "$stage_log" > /tmp/p04-pf-line.txt 2>/dev/null

  rm -rf "$stage_root" 2>/dev/null
  unset M030_SHADOW_COMPARE_CORPUS
}

_extract_field() {
  # $1 = field name; reads from /tmp/p04-pf-line.txt; writes to stdout.
  local field="$1"
  local val_tmp="/tmp/p04-pf-val.txt"
  rm -f "$val_tmp" 2>/dev/null
  grep -oE "\"${field}\":(\"[^\"]*\"|true|false|null|[0-9.]+)" /tmp/p04-pf-line.txt > "$val_tmp" 2>/dev/null
  local raw
  raw="$(head -n 1 "$val_tmp")"
  rm -f "$val_tmp" 2>/dev/null
  # Strip "field": prefix and any surrounding quotes.
  printf '%s' "$raw" | sed -E "s/^\"${field}\":\"?([^\"]*)\"?$/\1/"
}

# ---------- STAGE A: mechanical (flippable) ----------
_run_stage "A" "$PLAN_MECH"
A_MODEL_USED="$(_extract_field "model_used")"
A_PARTIAL="$(_extract_field "partial_flip_active")"
A_WITHHELD="$(_extract_field "withheld_classes")"

if [ "$A_MODEL_USED" = "$EXPECTED_FAST" ]; then
  pass=$((pass + 1))
  printf 'PASS: STAGE A mechanical model_used=%s (live-routed to fast tier)\n' "$A_MODEL_USED"
else
  fail=$((fail + 1))
  printf 'FAIL: STAGE A mechanical model_used=%s, expected %s\n' "$A_MODEL_USED" "$EXPECTED_FAST"
fi
if [ "$A_PARTIAL" = "true" ]; then
  pass=$((pass + 1))
  printf 'PASS: STAGE A partial_flip_active=true\n'
else
  fail=$((fail + 1))
  printf 'FAIL: STAGE A partial_flip_active=%s, expected true\n' "$A_PARTIAL"
fi
if [ "$A_WITHHELD" = "novel" ]; then
  pass=$((pass + 1))
  printf 'PASS: STAGE A withheld_classes=novel\n'
else
  fail=$((fail + 1))
  printf 'FAIL: STAGE A withheld_classes=%s, expected novel\n' "$A_WITHHELD"
fi

# ---------- STAGE B: novel (withheld) ----------
_run_stage "B" "$PLAN_NOVEL"
B_MODEL_USED="$(_extract_field "model_used")"
B_PARTIAL="$(_extract_field "partial_flip_active")"
B_WITHHELD="$(_extract_field "withheld_classes")"

if [ "$B_MODEL_USED" = "$RUNTIME_DEFAULT" ]; then
  pass=$((pass + 1))
  printf 'PASS: STAGE B novel model_used=%s (runtime default; class withheld)\n' "$B_MODEL_USED"
else
  fail=$((fail + 1))
  printf 'FAIL: STAGE B novel model_used=%s, expected runtime default %s\n' \
    "$B_MODEL_USED" "$RUNTIME_DEFAULT"
fi
if [ "$B_PARTIAL" = "true" ]; then
  pass=$((pass + 1))
  printf 'PASS: STAGE B partial_flip_active=true\n'
else
  fail=$((fail + 1))
  printf 'FAIL: STAGE B partial_flip_active=%s, expected true\n' "$B_PARTIAL"
fi
if [ "$B_WITHHELD" = "novel" ]; then
  pass=$((pass + 1))
  printf 'PASS: STAGE B withheld_classes=novel\n'
else
  fail=$((fail + 1))
  printf 'FAIL: STAGE B withheld_classes=%s, expected novel\n' "$B_WITHHELD"
fi

# --- Cleanup ---
rm -f /tmp/p04-pf-line.txt /tmp/p04-pf-rc.txt 2>/dev/null

printf 'SUMMARY: p04-partial-flip-routing.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
