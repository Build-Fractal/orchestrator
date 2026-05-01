#!/usr/bin/env bash
# tools/verify/p07-partial-flip-jsonl-fields.sh — M030/P07/T02 partial-flip
# JSONL field-shape gate at acceptance scale.
#
# Asserts: under the at-scale partially_ready corpus
# (tests/m030-acceptance/corpus-2-class-only.jsonl, 100 records / 50 each
# of mechanical+standard / 0 novel -> shadow-compare.sh emits
# `flip_recommendation=partially_ready` + `withheld_classes=novel`),
# dispatching a `novel`-classified PLAN.md with `model_routing.live: true`
# produces a JSONL `dispatch_usage` record with:
#   1) `partial_flip_active=true`
#   2) `withheld_classes=novel`
#
# This is the at-scale field-shape verification of the FR-9 / D-A3 partial-
# flip fields that P04's `p04-partial-flip-routing.sh` exercises with a
# 5-record corpus. T02's gate layers a P07-grade SHAPE assertion against
# the 100-record acceptance corpus produced by T01's synthesizer.
#
# Real-dispatch path: invokes scripts/dispatch/dispatch-interface.sh end-
# to-end via the same stub-record-model adapter pattern P04 uses, against
# the T01 acceptance corpus. The dispatch-interface gates `novel` as a
# withheld class under partially_ready and emits the JSONL record with the
# documented field shape. Plan-Time Discipline rule 5 (real-app smoke
# test) honored — this is an actual dispatch invocation, not a printf
# equivalence.
#
# Bash 3.2 compatible. AD-19 single-script-file shape; staging extracted
# into _stage_carve_out helper. Tmp-file intermediates per AP-009.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

CORPUS="$PROJECT_ROOT/tests/m030-acceptance/corpus-2-class-only.jsonl"
PLAN_NOVEL="$PROJECT_ROOT/tests/fixtures/m030-p04/plans/plan-novel-class.md"
PAYLOAD="$PROJECT_ROOT/tests/fixtures/m030-p04/round-trip-stage/payload.txt"
INTENSITY_META="$PROJECT_ROOT/tests/fixtures/m030-p04/round-trip-stage/intensity-metadata.txt"
CONFIG="$PROJECT_ROOT/tests/fixtures/m030-p04/configs/config-with-live-true.yml"
DISPATCH="$PROJECT_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

ok=1
for f in "$CORPUS" "$PLAN_NOVEL" "$PAYLOAD" "$INTENSITY_META" "$CONFIG" "$DISPATCH"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -ne 1 ]; then
  printf 'SUMMARY: p07-partial-flip-jsonl-fields.sh pass=0 fail=1\n'
  exit 1
fi

_stage_carve_out() {
  local stage_root="$1"
  mkdir -p "$stage_root/.orchestrator"
  mkdir -p "$stage_root/phases"
  cp "$CONFIG" "$stage_root/.orchestrator/config.yml"
}

STAGE_ROOT="$(mktemp -d -t p07-partial-flip-stage.XXXXXX)"
LINE_TMP="$(mktemp -t p07-partial-flip-line.XXXXXX)"
trap 'rm -rf "$STAGE_ROOT"; rm -f "$LINE_TMP"' EXIT

_stage_carve_out "$STAGE_ROOT"
STAGE_LOG="$STAGE_ROOT/execution-log.jsonl"

# Invoke dispatch-interface end-to-end: novel-classified plan + live: true
# config + the acceptance partially_ready corpus driving partial-flip
# authorization. The stub-record-model adapter satisfies the dispatch
# without a real backend call.
unset ORCH_MODEL
ORCHESTRATOR_ROOT="$STAGE_ROOT" \
M030_SHADOW_MODE=1 \
CLAUDECODE=1 \
M030_SHADOW_COMPARE_CORPUS="$CORPUS" \
  bash "$DISPATCH" \
    --task-plan "$PLAN_NOVEL" \
    --payload "$PAYLOAD" \
    --intensity-metadata "$INTENSITY_META" \
    --backend stub-record-model \
    > /dev/null 2> /dev/null
disp_rc=$?

# Extract the dispatch_usage record line.
grep -F '"record_type":"dispatch_usage"' "$STAGE_LOG" > "$LINE_TMP" 2>/dev/null
record_line="$(head -n 1 "$LINE_TMP")"

if [ -n "$record_line" ]; then
  pass=$((pass + 1))
  echo "OK: dispatch_usage record present in execution-log (dispatch rc=$disp_rc)"
else
  fail=$((fail + 1))
  echo "FAIL: no dispatch_usage record found in $STAGE_LOG (dispatch rc=$disp_rc)"
fi

# Assert partial_flip_active=true via anchored grep on the record line.
if printf '%s\n' "$record_line" | grep -qE '"partial_flip_active":true'; then
  pass=$((pass + 1))
  echo "OK: partial_flip_active=true in dispatch_usage record"
else
  fail=$((fail + 1))
  echo "FAIL: partial_flip_active=true absent from dispatch_usage record"
fi

# Assert withheld_classes contains 'novel'.
if printf '%s\n' "$record_line" | grep -qE '"withheld_classes":"[^"]*novel[^"]*"'; then
  pass=$((pass + 1))
  echo "OK: withheld_classes contains 'novel' in dispatch_usage record"
else
  fail=$((fail + 1))
  echo "FAIL: withheld_classes does not contain 'novel' in dispatch_usage record"
fi

echo "SUMMARY: p07-partial-flip-jsonl-fields.sh pass=$pass fail=$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
