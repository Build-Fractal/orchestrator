#!/usr/bin/env bash
# tools/verify/p03-override-conflict.sh -- M030 P03 FR-14 override-conflict gate.
#
# Asserts that when a plan declares `model_override: fast` AND the per-
# project config declares `model_routing.min_tier: smart`, the floor wins:
#   1. override_source=milestone_floor (NOT plan_frontmatter)
#   2. model_routed=smart (raised from override `fast` to floor `smart`)
#   3. stderr contains a one-line warning naming the bypassed override
#      (`model_override=fast`)
#   4. stderr contains the floor value (`min_tier=smart`)
#   5. stderr explicitly states the resolution (`floor wins`)
#
# Round-trip dispatch shape mirrors p03-sc7a-compound.sh.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Tmp-file
# intermediates per AP-009. Exit 0 iff fail == 0.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p03"
PLAN="$FIXTURES/plans/plan-frontmatter-fast-vs-floor.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-with-min-tier-smart.yml"
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
  printf 'SUMMARY: p03-override-conflict.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---------- Stage tmp_root ----------
TMP_ROOT="$(mktemp -d 2>/dev/null)"
if [ -z "$TMP_ROOT" ]; then
  TMP_ROOT="/tmp/p03-override-conflict-fallback-$$"
  rm -rf "$TMP_ROOT" 2>/dev/null
  mkdir -p "$TMP_ROOT" 2>/dev/null
fi
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml" 2>/dev/null
LOG_FILE="$TMP_ROOT/execution-log.jsonl"

STDERR_TMP="/tmp/p03-conflict-stderr.txt"
rm -f "$STDERR_TMP" 2>/dev/null

# ---------- Round-trip dispatch invocation with stderr capture ----------
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

# ---------- Read appended JSONL line ----------
LINE_TMP="/tmp/p03-conflict-line.txt"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null

LC_TMP="/tmp/p03-conflict-lc.txt"
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
  printf 'SUMMARY: p03-override-conflict.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---------- Assertion 1: override_source=milestone_floor (NOT plan_frontmatter) ----------
OS_TMP="/tmp/p03-conflict-ostok.txt"
rm -f "$OS_TMP" 2>/dev/null
grep -F '"override_source":"milestone_floor"' "$LINE_TMP" > "$OS_TMP" 2>/dev/null
OS_LC_TMP="/tmp/p03-conflict-oslc.txt"
rm -f "$OS_LC_TMP" 2>/dev/null
wc -l < "$OS_TMP" > "$OS_LC_TMP" 2>/dev/null
OS_LC="$(tr -d '[:space:]' < "$OS_LC_TMP")"
rm -f "$OS_TMP" "$OS_LC_TMP" 2>/dev/null
[ -n "$OS_LC" ] || OS_LC=0
if [ "$OS_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: override_source=milestone_floor (floor wins over plan_frontmatter)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: override_source=milestone_floor token missing from %s\n' "$LOG_FILE"
fi

# ---------- Assertion 2: model_routed=smart (raised from fast to smart) ----------
ROUTED_TMP="/tmp/p03-conflict-routedtok.txt"
rm -f "$ROUTED_TMP" 2>/dev/null
grep -F '"model_routed":"smart"' "$LINE_TMP" > "$ROUTED_TMP" 2>/dev/null
ROUTED_LC_TMP="/tmp/p03-conflict-routedlc.txt"
rm -f "$ROUTED_LC_TMP" 2>/dev/null
wc -l < "$ROUTED_TMP" > "$ROUTED_LC_TMP" 2>/dev/null
ROUTED_LC="$(tr -d '[:space:]' < "$ROUTED_LC_TMP")"
rm -f "$ROUTED_TMP" "$ROUTED_LC_TMP" 2>/dev/null
[ -n "$ROUTED_LC" ] || ROUTED_LC=0
if [ "$ROUTED_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: model_routed=smart (override fast -> floor smart)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: model_routed=smart token missing from %s\n' "$LOG_FILE"
fi

# ---------- Assertion 3: stderr contains model_override=fast ----------
ERR_OV_TMP="/tmp/p03-conflict-errov.txt"
rm -f "$ERR_OV_TMP" 2>/dev/null
grep -F 'model_override=fast' "$STDERR_TMP" > "$ERR_OV_TMP" 2>/dev/null
ERR_OV_LC_TMP="/tmp/p03-conflict-errovlc.txt"
rm -f "$ERR_OV_LC_TMP" 2>/dev/null
wc -l < "$ERR_OV_TMP" > "$ERR_OV_LC_TMP" 2>/dev/null
ERR_OV_LC="$(tr -d '[:space:]' < "$ERR_OV_LC_TMP")"
rm -f "$ERR_OV_TMP" "$ERR_OV_LC_TMP" 2>/dev/null
[ -n "$ERR_OV_LC" ] || ERR_OV_LC=0
if [ "$ERR_OV_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: stderr contains model_override=fast (warning names the bypassed override)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: stderr missing "model_override=fast" -- captured at %s\n' "$STDERR_TMP"
fi

# ---------- Assertion 4: stderr contains min_tier=smart ----------
ERR_MT_TMP="/tmp/p03-conflict-errmt.txt"
rm -f "$ERR_MT_TMP" 2>/dev/null
grep -F 'min_tier=smart' "$STDERR_TMP" > "$ERR_MT_TMP" 2>/dev/null
ERR_MT_LC_TMP="/tmp/p03-conflict-errmtlc.txt"
rm -f "$ERR_MT_LC_TMP" 2>/dev/null
wc -l < "$ERR_MT_TMP" > "$ERR_MT_LC_TMP" 2>/dev/null
ERR_MT_LC="$(tr -d '[:space:]' < "$ERR_MT_LC_TMP")"
rm -f "$ERR_MT_TMP" "$ERR_MT_LC_TMP" 2>/dev/null
[ -n "$ERR_MT_LC" ] || ERR_MT_LC=0
if [ "$ERR_MT_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: stderr contains min_tier=smart (warning names the floor)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: stderr missing "min_tier=smart" -- captured at %s\n' "$STDERR_TMP"
fi

# ---------- Assertion 5: stderr contains "floor wins" ----------
ERR_FW_TMP="/tmp/p03-conflict-errfw.txt"
rm -f "$ERR_FW_TMP" 2>/dev/null
grep -F 'floor wins' "$STDERR_TMP" > "$ERR_FW_TMP" 2>/dev/null
ERR_FW_LC_TMP="/tmp/p03-conflict-errfwlc.txt"
rm -f "$ERR_FW_LC_TMP" 2>/dev/null
wc -l < "$ERR_FW_TMP" > "$ERR_FW_LC_TMP" 2>/dev/null
ERR_FW_LC="$(tr -d '[:space:]' < "$ERR_FW_LC_TMP")"
rm -f "$ERR_FW_TMP" "$ERR_FW_LC_TMP" 2>/dev/null
[ -n "$ERR_FW_LC" ] || ERR_FW_LC=0
if [ "$ERR_FW_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: stderr contains "floor wins" (warning explicitly states resolution)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: stderr missing "floor wins" -- captured at %s\n' "$STDERR_TMP"
fi

# ---------- Cleanup ----------
rm -f "$LINE_TMP" "$STDERR_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null

printf 'SUMMARY: p03-override-conflict.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
