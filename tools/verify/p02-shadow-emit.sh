#!/usr/bin/env bash
# tools/verify/p02-shadow-emit.sh — M030 P02 shadow-mode emit gate.
#
# Exercises three scenarios against scripts/dispatch/dispatch-interface.sh:
#   A) M030_SHADOW_MODE=1 + CLAUDECODE=1 -> shadow tokens MUST appear
#   B) M030_SHADOW_MODE unset + CLAUDECODE=1 -> shadow tokens MUST NOT appear
#   C) M030_SHADOW_MODE=1 + CLAUDECODE unset -> shadow tokens MUST NOT appear
#      (CC-only short-circuit per CON-3 + spec edge case)
#
# Each scenario stages a fresh log, invokes dispatch-interface.sh against the
# committed fixture stage, and asserts presence/absence of the four shadow
# tokens (model_routed, model_used, partial_flip_active, withheld_classes).
#
# Bash 3.2 compatible. AD-19 single-script-file shape. No compound chains
# beyond two-link cap. Per-scenario tmp-file intermediates.
#
# Exit 0 iff fail == 0. Emits SUMMARY: line at end.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STAGE="$REPO_ROOT/tests/fixtures/m030-p02/round-trip-stage"
PLAN="$STAGE/phases/P01/tasks/M001-T01-stage-PLAN.md"
PAYLOAD="$STAGE/phases/P01/tasks/T01-stage-PAYLOAD.md"
INTENSITY_META="$STAGE/intensity-metadata.txt"
LOG_FILE="$STAGE/execution-log.jsonl"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

# ---------- Gate 0: prerequisites exist ----------
ok=1
if [ ! -f "$PLAN" ]; then
  ok=0
  printf 'FAIL: stage plan missing at %s\n' "$PLAN"
fi
if [ ! -f "$PAYLOAD" ]; then
  ok=0
  printf 'FAIL: stage payload missing at %s\n' "$PAYLOAD"
fi
if [ ! -f "$INTENSITY_META" ]; then
  ok=0
  printf 'FAIL: stage intensity-metadata missing at %s\n' "$INTENSITY_META"
fi
if [ ! -f "$DISPATCH" ]; then
  ok=0
  printf 'FAIL: dispatch-interface.sh missing at %s\n' "$DISPATCH"
fi
if [ "$ok" -eq 1 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'SUMMARY: p02-shadow-emit.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

export ORCHESTRATOR_ROOT="$STAGE"
unset ORCH_MODEL

# Helper: stage fresh log file. Caller is in current shell scope.
_stage_log() {
  rm -f "$LOG_FILE" 2>/dev/null
  : > "$LOG_FILE"
}

_invoke_dispatch() {
  bash "$DISPATCH" \
    --task-plan "$PLAN" \
    --payload "$PAYLOAD" \
    --intensity-metadata "$INTENSITY_META" \
    --backend stub \
    > /dev/null 2>&1
}

# ---------- Scenario A: shadow on, CC on -> tokens MUST appear ----------
export M030_SHADOW_MODE=1
export CLAUDECODE=1
_stage_log
_invoke_dispatch

LINE_TMP="/tmp/p02-shadow-emit-A.jsonl"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null

a_ok=1
# JSON well-formedness (single-line, brace-bounded).
grep -q '^{.*}$' "$LINE_TMP" 2>/dev/null
if [ $? -ne 0 ]; then
  a_ok=0
  printf 'FAIL: scenario A — appended line is not brace-bounded JSON\n'
fi
grep -q -F '"model_routed"' "$LINE_TMP" 2>/dev/null
if [ $? -ne 0 ]; then
  a_ok=0
  printf 'FAIL: scenario A — model_routed token missing under shadow-on + CC-on\n'
fi
grep -q -F '"model_used"' "$LINE_TMP" 2>/dev/null
if [ $? -ne 0 ]; then
  a_ok=0
  printf 'FAIL: scenario A — model_used token missing under shadow-on + CC-on\n'
fi
grep -q -F '"partial_flip_active"' "$LINE_TMP" 2>/dev/null
if [ $? -ne 0 ]; then
  a_ok=0
  printf 'FAIL: scenario A — partial_flip_active token missing under shadow-on + CC-on\n'
fi
grep -q -F '"withheld_classes"' "$LINE_TMP" 2>/dev/null
if [ $? -ne 0 ]; then
  a_ok=0
  printf 'FAIL: scenario A — withheld_classes token missing under shadow-on + CC-on\n'
fi
rm -f "$LINE_TMP" 2>/dev/null
rm -f "$LOG_FILE" 2>/dev/null

if [ "$a_ok" -eq 1 ]; then
  pass=$((pass + 5))
else
  fail=$((fail + 1))
  pass=$((pass + 0))
fi

# ---------- Scenario B: shadow off, CC on -> tokens MUST NOT appear ----------
unset M030_SHADOW_MODE
export CLAUDECODE=1
_stage_log
_invoke_dispatch

LINE_TMP="/tmp/p02-shadow-emit-B.jsonl"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null

b_ok=1
grep -q -F '"model_routed"' "$LINE_TMP" 2>/dev/null
if [ $? -eq 0 ]; then
  b_ok=0
  printf 'FAIL: scenario B — model_routed token leaked under shadow-off\n'
fi
grep -q -F '"model_used"' "$LINE_TMP" 2>/dev/null
if [ $? -eq 0 ]; then
  b_ok=0
  printf 'FAIL: scenario B — model_used token leaked under shadow-off\n'
fi
grep -q -F '"partial_flip_active"' "$LINE_TMP" 2>/dev/null
if [ $? -eq 0 ]; then
  b_ok=0
  printf 'FAIL: scenario B — partial_flip_active token leaked under shadow-off\n'
fi
grep -q -F '"withheld_classes"' "$LINE_TMP" 2>/dev/null
if [ $? -eq 0 ]; then
  b_ok=0
  printf 'FAIL: scenario B — withheld_classes token leaked under shadow-off\n'
fi
rm -f "$LINE_TMP" 2>/dev/null
rm -f "$LOG_FILE" 2>/dev/null

if [ "$b_ok" -eq 1 ]; then
  pass=$((pass + 4))
else
  fail=$((fail + 1))
fi

# ---------- Scenario C: shadow on, CC off -> tokens MUST NOT appear ----------
export M030_SHADOW_MODE=1
unset CLAUDECODE
_stage_log
_invoke_dispatch

LINE_TMP="/tmp/p02-shadow-emit-C.jsonl"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null

c_ok=1
grep -q -F '"model_routed"' "$LINE_TMP" 2>/dev/null
if [ $? -eq 0 ]; then
  c_ok=0
  printf 'FAIL: scenario C — model_routed token leaked under CC-off (Codex CLI / Cursor simulation)\n'
fi
grep -q -F '"model_used"' "$LINE_TMP" 2>/dev/null
if [ $? -eq 0 ]; then
  c_ok=0
  printf 'FAIL: scenario C — model_used token leaked under CC-off\n'
fi
grep -q -F '"partial_flip_active"' "$LINE_TMP" 2>/dev/null
if [ $? -eq 0 ]; then
  c_ok=0
  printf 'FAIL: scenario C — partial_flip_active token leaked under CC-off\n'
fi
grep -q -F '"withheld_classes"' "$LINE_TMP" 2>/dev/null
if [ $? -eq 0 ]; then
  c_ok=0
  printf 'FAIL: scenario C — withheld_classes token leaked under CC-off\n'
fi
rm -f "$LINE_TMP" 2>/dev/null
rm -f "$LOG_FILE" 2>/dev/null

if [ "$c_ok" -eq 1 ]; then
  pass=$((pass + 4))
else
  fail=$((fail + 1))
fi

# ---------- Cleanup ----------
unset M030_SHADOW_MODE
unset CLAUDECODE

printf 'SUMMARY: p02-shadow-emit.sh pass=%d fail=%d\n' "$pass" "$fail"

if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
