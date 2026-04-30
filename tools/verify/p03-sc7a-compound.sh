#!/usr/bin/env bash
# tools/verify/p03-sc7a-compound.sh -- M030 P03 SC-7a compound gate.
#
# Asserts that the kill switch supersedes min_tier (CON-4 / D-A5). With
# both `model_routing_enabled: false` AND `model_routing.min_tier: smart`
# in the per-project config, a shadow-on dispatch_usage record:
#   1. records `override_source=disabled` (NOT `milestone_floor`)
#   2. `model_used` matches the runtime-default model channel
#   3. stderr contains the one-line warning naming the bypassed value:
#         model_routing_enabled=false: min_tier: smart is inactive
#
# Round-trip dispatch shape mirrors p03-sc7-kill-switch.sh; adds stderr
# capture via `2> /tmp/p03-sc7a-stderr.txt`.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Tmp-file
# intermediates per AP-009. Exit 0 iff fail == 0.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p03"
PLAN="$FIXTURES/plans/plan-mechanical-no-override.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-killswitch-and-floor.yml"
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
  printf 'SUMMARY: p03-sc7a-compound.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Read runtime-default model from intensity-metadata.
RD_TMP="/tmp/p03-sc7a-default-model.txt"
rm -f "$RD_TMP" 2>/dev/null
grep -E '^model:' "$INTENSITY_META" > "$RD_TMP" 2>/dev/null
RUNTIME_DEFAULT_MODEL="$(head -n 1 "$RD_TMP" | sed -E 's/^model:[[:space:]]*"?([^"]*)"?.*/\1/')"
rm -f "$RD_TMP" 2>/dev/null

# Stage tmp_root.
TMP_ROOT="$(mktemp -d 2>/dev/null)"
if [ -z "$TMP_ROOT" ]; then
  TMP_ROOT="/tmp/p03-sc7a-fallback-$$"
  rm -rf "$TMP_ROOT" 2>/dev/null
  mkdir -p "$TMP_ROOT" 2>/dev/null
fi
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml" 2>/dev/null
LOG_FILE="$TMP_ROOT/execution-log.jsonl"
STDERR_TMP="/tmp/p03-sc7a-stderr.txt"
rm -f "$STDERR_TMP" 2>/dev/null

# Round-trip dispatch invocation with stderr capture.
unset ORCH_MODEL
export ORCHESTRATOR_ROOT="$TMP_ROOT"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub \
  > /dev/null 2> "$STDERR_TMP"

# Read appended JSONL line.
LINE_TMP="/tmp/p03-sc7a-line.txt"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null

LC_TMP="/tmp/p03-sc7a-lc.txt"
rm -f "$LC_TMP" 2>/dev/null
wc -l < "$LINE_TMP" > "$LC_TMP" 2>/dev/null
LC="$(tr -d '[:space:]' < "$LC_TMP")"
rm -f "$LC_TMP" 2>/dev/null
[ -n "$LC" ] || LC=0
if [ "$LC" -lt 1 ]; then
  fail=$((fail + 1))
  printf 'FAIL: no dispatch_usage record appended to %s\n' "$LOG_FILE"
  rm -f "$LINE_TMP" "$STDERR_TMP" 2>/dev/null
  rm -rf "$TMP_ROOT" 2>/dev/null
  printf 'SUMMARY: p03-sc7a-compound.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Assertion 1: override_source=disabled (kill switch wins, NOT milestone_floor).
KILL_TMP="/tmp/p03-sc7a-killtok.txt"
rm -f "$KILL_TMP" 2>/dev/null
grep -F '"override_source":"disabled"' "$LINE_TMP" > "$KILL_TMP" 2>/dev/null
KILL_LC_TMP="/tmp/p03-sc7a-killlc.txt"
rm -f "$KILL_LC_TMP" 2>/dev/null
wc -l < "$KILL_TMP" > "$KILL_LC_TMP" 2>/dev/null
KILL_LC="$(tr -d '[:space:]' < "$KILL_LC_TMP")"
rm -f "$KILL_TMP" "$KILL_LC_TMP" 2>/dev/null
[ -n "$KILL_LC" ] || KILL_LC=0
if [ "$KILL_LC" -ge 1 ]; then
  # Also positively assert NOT milestone_floor.
  FLOOR_TMP="/tmp/p03-sc7a-floortok.txt"
  rm -f "$FLOOR_TMP" 2>/dev/null
  grep -F '"override_source":"milestone_floor"' "$LINE_TMP" > "$FLOOR_TMP" 2>/dev/null
  FLOOR_LC_TMP="/tmp/p03-sc7a-floorlc.txt"
  rm -f "$FLOOR_LC_TMP" 2>/dev/null
  wc -l < "$FLOOR_TMP" > "$FLOOR_LC_TMP" 2>/dev/null
  FLOOR_LC="$(tr -d '[:space:]' < "$FLOOR_LC_TMP")"
  rm -f "$FLOOR_TMP" "$FLOOR_LC_TMP" 2>/dev/null
  [ -n "$FLOOR_LC" ] || FLOOR_LC=0
  if [ "$FLOOR_LC" -eq 0 ]; then
    pass=$((pass + 1))
    printf 'PASS: compound case records override_source=disabled (kill switch wins; milestone_floor absent)\n'
  else
    fail=$((fail + 1))
    printf 'FAIL: both override_source=disabled and override_source=milestone_floor present\n'
  fi
else
  fail=$((fail + 1))
  printf 'FAIL: override_source=disabled token missing from %s\n' "$LOG_FILE"
fi

# Assertion 2: model_used matches runtime-default channel.
MU_TMP="/tmp/p03-sc7a-mu.txt"
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

# Assertion 3: stderr warning naming the bypassed min_tier value.
WARN_TMP="/tmp/p03-sc7a-warn.txt"
rm -f "$WARN_TMP" 2>/dev/null
grep -E 'min_tier:.*smart.*is inactive' "$STDERR_TMP" > "$WARN_TMP" 2>/dev/null
WARN_LC_TMP="/tmp/p03-sc7a-warnlc.txt"
rm -f "$WARN_LC_TMP" 2>/dev/null
wc -l < "$WARN_TMP" > "$WARN_LC_TMP" 2>/dev/null
WARN_LC="$(tr -d '[:space:]' < "$WARN_LC_TMP")"
rm -f "$WARN_TMP" "$WARN_LC_TMP" 2>/dev/null
[ -n "$WARN_LC" ] || WARN_LC=0
if [ "$WARN_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: stderr contains "min_tier: smart is inactive" warning\n'
else
  fail=$((fail + 1))
  printf 'FAIL: stderr missing "min_tier: smart is inactive" warning. Captured stderr:\n'
  cat "$STDERR_TMP" 2>/dev/null
fi

# Cleanup.
rm -f "$LINE_TMP" "$STDERR_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null

printf 'SUMMARY: p03-sc7a-compound.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
