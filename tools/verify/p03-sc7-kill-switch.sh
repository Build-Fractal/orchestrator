#!/usr/bin/env bash
# tools/verify/p03-sc7-kill-switch.sh -- M030 P03 SC-7 kill-switch gate.
#
# Asserts that with `model_routing_enabled: false` in the per-project
# config, a shadow-on dispatch_usage record:
#   1. records `override_source=disabled`
#   2. `model_used` matches the runtime-default model channel (the value
#      of the `model:` field from intensity-metadata.txt, since ORCH_MODEL
#      is unset in this verifier).
#
# Round-trip dispatch shape mirrors P02/T02 verifiers. Stages a fresh
# tmp_root with .orchestrator/config.yml + phases/ subdir; sets
# ORCHESTRATOR_ROOT=tmp_root; M030_SHADOW_MODE=1; CLAUDECODE=1; invokes
# scripts/dispatch/dispatch-interface.sh against the no-override fixture
# plan. Reads the appended JSONL line and grep-asserts each property.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. No compound chains
# beyond two-link cap. Tmp-file intermediates per AP-009. Exit 0 iff
# fail == 0. Emits SUMMARY: line at end.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p03"
PLAN="$FIXTURES/plans/plan-mechanical-no-override.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-routing-disabled.yml"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

# ---------- Gate 0: prerequisites exist ----------
ok=1
for f in "$PLAN" "$PAYLOAD" "$INTENSITY_META" "$CONFIG" "$DISPATCH"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -ne 1 ]; then
  fail=$((fail + 1))
  printf 'SUMMARY: p03-sc7-kill-switch.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Read runtime-default model literal from intensity-metadata.
RUNTIME_DEFAULT_MODEL_TMP="/tmp/p03-sc7-default-model.txt"
rm -f "$RUNTIME_DEFAULT_MODEL_TMP" 2>/dev/null
grep -E '^model:' "$INTENSITY_META" > "$RUNTIME_DEFAULT_MODEL_TMP" 2>/dev/null
RUNTIME_DEFAULT_MODEL="$(head -n 1 "$RUNTIME_DEFAULT_MODEL_TMP" | sed -E 's/^model:[[:space:]]*"?([^"]*)"?.*/\1/')"
rm -f "$RUNTIME_DEFAULT_MODEL_TMP" 2>/dev/null

# Stage a fresh tmp_root.
TMP_ROOT="$(mktemp -d 2>/dev/null)"
if [ -z "$TMP_ROOT" ]; then
  TMP_ROOT="/tmp/p03-sc7-kill-switch-fallback-$$"
  rm -rf "$TMP_ROOT" 2>/dev/null
  mkdir -p "$TMP_ROOT" 2>/dev/null
fi
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml" 2>/dev/null
LOG_FILE="$TMP_ROOT/execution-log.jsonl"

# Round-trip dispatch invocation.
unset ORCH_MODEL
export ORCHESTRATOR_ROOT="$TMP_ROOT"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub \
  > /dev/null 2>&1

# Read the appended JSONL dispatch_usage line.
LINE_TMP="/tmp/p03-sc7-line.txt"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null

LC_TMP="/tmp/p03-sc7-lc.txt"
rm -f "$LC_TMP" 2>/dev/null
wc -l < "$LINE_TMP" > "$LC_TMP" 2>/dev/null
LC="$(tr -d '[:space:]' < "$LC_TMP")"
rm -f "$LC_TMP" 2>/dev/null
[ -n "$LC" ] || LC=0
if [ "$LC" -lt 1 ]; then
  fail=$((fail + 1))
  printf 'FAIL: no dispatch_usage record appended to %s\n' "$LOG_FILE"
  rm -f "$LINE_TMP" 2>/dev/null
  rm -rf "$TMP_ROOT" 2>/dev/null
  printf 'SUMMARY: p03-sc7-kill-switch.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Assertion 1: override_source=disabled.
KILL_TMP="/tmp/p03-sc7-killtok.txt"
rm -f "$KILL_TMP" 2>/dev/null
grep -F '"override_source":"disabled"' "$LINE_TMP" > "$KILL_TMP" 2>/dev/null
KILL_LC_TMP="/tmp/p03-sc7-killlc.txt"
rm -f "$KILL_LC_TMP" 2>/dev/null
wc -l < "$KILL_TMP" > "$KILL_LC_TMP" 2>/dev/null
KILL_LC="$(tr -d '[:space:]' < "$KILL_LC_TMP")"
rm -f "$KILL_TMP" "$KILL_LC_TMP" 2>/dev/null
[ -n "$KILL_LC" ] || KILL_LC=0
if [ "$KILL_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: kill-switch records override_source=disabled\n'
else
  fail=$((fail + 1))
  printf 'FAIL: override_source=disabled token missing from %s\n' "$LOG_FILE"
fi

# Assertion 2: model_used matches runtime-default model channel.
MU_TMP="/tmp/p03-sc7-mu.txt"
rm -f "$MU_TMP" 2>/dev/null
grep -oE '"model_used":"[^"]*"' "$LINE_TMP" > "$MU_TMP" 2>/dev/null
MU_RAW="$(head -n 1 "$MU_TMP")"
rm -f "$MU_TMP" 2>/dev/null
MU_VALUE="$(printf '%s' "$MU_RAW" | sed -E 's/.*:"([^"]*)".*/\1/')"

if [ "$MU_VALUE" = "$RUNTIME_DEFAULT_MODEL" ]; then
  pass=$((pass + 1))
  printf 'PASS: model_used=%s matches runtime-default channel\n' "$MU_VALUE"
else
  fail=$((fail + 1))
  printf 'FAIL: model_used=%s, expected runtime default %s\n' "$MU_VALUE" "$RUNTIME_DEFAULT_MODEL"
fi

# Cleanup.
rm -f "$LINE_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null

printf 'SUMMARY: p03-sc7-kill-switch.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
