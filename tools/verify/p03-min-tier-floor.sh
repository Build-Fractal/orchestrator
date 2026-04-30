#!/usr/bin/env bash
# tools/verify/p03-min-tier-floor.sh -- M030 P03 min_tier floor gate (FR-12).
#
# Asserts that with `model_routing.min_tier: smart` AND no kill switch
# AND no plan override, a mechanical-classified plan dispatches with:
#   1. classifier sanity: character=mechanical (so the floor ACTUALLY
#      raises the tier — mechanical's default is `fast`, raised to `smart`).
#   2. `model_routed=smart` (post-floor application)
#   3. `override_source=milestone_floor`
#
# Round-trip dispatch shape mirrors p03-sc7-kill-switch.sh.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Tmp-file
# intermediates per AP-009. Exit 0 iff fail == 0.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p03"
PLAN="$FIXTURES/plans/plan-mechanical-no-override.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-min-tier-smart.yml"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"
CLASSIFIER="$REPO_ROOT/scripts/dispatch/classify-task.sh"

pass=0
fail=0

# ---------- Gate 0: prerequisites exist ----------
ok=1
for f in "$PLAN" "$PAYLOAD" "$INTENSITY_META" "$CONFIG" "$DISPATCH" "$CLASSIFIER"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -ne 1 ]; then
  fail=$((fail + 1))
  printf 'SUMMARY: p03-min-tier-floor.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Assertion 1: classifier independently returns character=mechanical.
CLASSIFY_TMP="/tmp/p03-mintier-classify.txt"
rm -f "$CLASSIFY_TMP" 2>/dev/null
bash "$CLASSIFIER" "$PLAN" > "$CLASSIFY_TMP" 2>/dev/null
CHAR_TMP="/tmp/p03-mintier-char.txt"
rm -f "$CHAR_TMP" 2>/dev/null
grep -E '^character=' "$CLASSIFY_TMP" > "$CHAR_TMP" 2>/dev/null
CHAR_VALUE="$(head -n 1 "$CHAR_TMP" | sed -E 's/^character=//')"
rm -f "$CLASSIFY_TMP" "$CHAR_TMP" 2>/dev/null
if [ "$CHAR_VALUE" = "mechanical" ]; then
  pass=$((pass + 1))
  printf 'PASS: classifier sanity -- character=mechanical\n'
else
  fail=$((fail + 1))
  printf 'FAIL: classifier returned character=%s, expected mechanical\n' "$CHAR_VALUE"
fi

# Stage tmp_root.
TMP_ROOT="$(mktemp -d 2>/dev/null)"
if [ -z "$TMP_ROOT" ]; then
  TMP_ROOT="/tmp/p03-mintier-fallback-$$"
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

# Read appended JSONL line.
LINE_TMP="/tmp/p03-mintier-line.txt"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null

LC_TMP="/tmp/p03-mintier-lc.txt"
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
  printf 'SUMMARY: p03-min-tier-floor.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Assertion 2: override_source=milestone_floor.
FLOOR_TMP="/tmp/p03-mintier-floortok.txt"
rm -f "$FLOOR_TMP" 2>/dev/null
grep -F '"override_source":"milestone_floor"' "$LINE_TMP" > "$FLOOR_TMP" 2>/dev/null
FLOOR_LC_TMP="/tmp/p03-mintier-floorlc.txt"
rm -f "$FLOOR_LC_TMP" 2>/dev/null
wc -l < "$FLOOR_TMP" > "$FLOOR_LC_TMP" 2>/dev/null
FLOOR_LC="$(tr -d '[:space:]' < "$FLOOR_LC_TMP")"
rm -f "$FLOOR_TMP" "$FLOOR_LC_TMP" 2>/dev/null
[ -n "$FLOOR_LC" ] || FLOOR_LC=0
if [ "$FLOOR_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: floor records override_source=milestone_floor\n'
else
  fail=$((fail + 1))
  printf 'FAIL: override_source=milestone_floor token missing from %s\n' "$LOG_FILE"
fi

# Assertion 3: model_routed=smart (raised from fast by floor).
ROUTED_TMP="/tmp/p03-mintier-routedtok.txt"
rm -f "$ROUTED_TMP" 2>/dev/null
grep -F '"model_routed":"smart"' "$LINE_TMP" > "$ROUTED_TMP" 2>/dev/null
ROUTED_LC_TMP="/tmp/p03-mintier-routedlc.txt"
rm -f "$ROUTED_LC_TMP" 2>/dev/null
wc -l < "$ROUTED_TMP" > "$ROUTED_LC_TMP" 2>/dev/null
ROUTED_LC="$(tr -d '[:space:]' < "$ROUTED_LC_TMP")"
rm -f "$ROUTED_TMP" "$ROUTED_LC_TMP" 2>/dev/null
[ -n "$ROUTED_LC" ] || ROUTED_LC=0
if [ "$ROUTED_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: model_routed=smart (floor raised mechanical/fast -> smart)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: model_routed=smart token missing from %s\n' "$LOG_FILE"
fi

# Cleanup.
rm -f "$LINE_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null

printf 'SUMMARY: p03-min-tier-floor.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
