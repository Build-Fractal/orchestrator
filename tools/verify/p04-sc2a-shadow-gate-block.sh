#!/usr/bin/env bash
# tools/verify/p04-sc2a-shadow-gate-block.sh -- M030/P04 SC-2a / FR-9 / D-A2 gate.
#
# Asserts: with model_routing.live: true AND an empty shadow corpus,
# scripts/dispatch/dispatch-interface.sh refuses to invoke any backend
# adapter, exits nonzero, and writes override_source=shadow_gate_blocked
# to the appended dispatch_usage record.
#
# Three assertions:
#   1. dispatch-interface exits nonzero.
#   2. The appended JSONL line carries override_source=shadow_gate_blocked.
#   3. NO dispatch-result frontmatter was written to stdout (adapter never
#      invoked).
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
EMPTY_CORPUS="$FIXTURES/shadow-corpus-empty.jsonl"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

# --- Prerequisite gate ---
ok=1
for f in "$PLAN" "$PAYLOAD" "$INTENSITY_META" "$CONFIG" "$EMPTY_CORPUS" "$DISPATCH"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -ne 1 ]; then
  printf 'SUMMARY: p04-sc2a-shadow-gate-block.sh pass=%d fail=1\n' "$pass"
  exit 1
fi

# --- Stage tmp_root ---
TMP_ROOT="$(mktemp -d 2>/dev/null)"
if [ -z "$TMP_ROOT" ]; then
  TMP_ROOT="/tmp/p04-sc2a-fallback-$$"
  rm -rf "$TMP_ROOT" 2>/dev/null
  mkdir -p "$TMP_ROOT" 2>/dev/null
fi
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml" 2>/dev/null
LOG_FILE="$TMP_ROOT/execution-log.jsonl"

unset ORCH_MODEL
export ORCHESTRATOR_ROOT="$TMP_ROOT"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
export M030_SHADOW_COMPARE_CORPUS="$EMPTY_CORPUS"

DISPATCH_OUT_TMP="/tmp/p04-sc2a-out.txt"
DISPATCH_ERR_TMP="/tmp/p04-sc2a-err.txt"
rm -f "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
bash "$DISPATCH" \
  --task-plan "$PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_META" \
  --backend stub \
  > "$DISPATCH_OUT_TMP" 2> "$DISPATCH_ERR_TMP"
DISPATCH_RC=$?

# --- Assertion 1: dispatch-interface exits nonzero ---
if [ "$DISPATCH_RC" -ne 0 ]; then
  pass=$((pass + 1))
  printf 'PASS: dispatch-interface exits nonzero (rc=%d)\n' "$DISPATCH_RC"
else
  fail=$((fail + 1))
  printf 'FAIL: dispatch-interface exited 0; expected nonzero on shadow-gate-block\n'
fi

# --- Assertion 2: appended JSONL line carries override_source=shadow_gate_blocked ---
LINE_TMP="/tmp/p04-sc2a-line.txt"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null
SGB_TMP="/tmp/p04-sc2a-sgb.txt"
rm -f "$SGB_TMP" 2>/dev/null
grep -F '"override_source":"shadow_gate_blocked"' "$LINE_TMP" > "$SGB_TMP" 2>/dev/null
SGB_LC_TMP="/tmp/p04-sc2a-sgblc.txt"
rm -f "$SGB_LC_TMP" 2>/dev/null
wc -l < "$SGB_TMP" > "$SGB_LC_TMP" 2>/dev/null
SGB_LC="$(tr -d '[:space:]' < "$SGB_LC_TMP")"
[ -n "$SGB_LC" ] || SGB_LC=0
if [ "$SGB_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: override_source=shadow_gate_blocked recorded\n'
else
  fail=$((fail + 1))
  printf 'FAIL: override_source=shadow_gate_blocked token missing in %s\n' "$LOG_FILE"
fi

# --- Assertion 3: no dispatch-result emitted on stdout (adapter never invoked) ---
DRT_TMP="/tmp/p04-sc2a-drt.txt"
rm -f "$DRT_TMP" 2>/dev/null
grep -F 'type: "dispatch-result"' "$DISPATCH_OUT_TMP" > "$DRT_TMP" 2>/dev/null
DRT_LC_TMP="/tmp/p04-sc2a-drtlc.txt"
rm -f "$DRT_LC_TMP" 2>/dev/null
wc -l < "$DRT_TMP" > "$DRT_LC_TMP" 2>/dev/null
DRT_LC="$(tr -d '[:space:]' < "$DRT_LC_TMP")"
[ -n "$DRT_LC" ] || DRT_LC=0
if [ "$DRT_LC" -eq 0 ]; then
  pass=$((pass + 1))
  printf 'PASS: no dispatch-result emitted (adapter not invoked)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: dispatch-result was emitted; adapter was invoked despite gate-block\n'
fi

# --- Cleanup ---
rm -f "$LINE_TMP" "$SGB_TMP" "$SGB_LC_TMP" "$DRT_TMP" "$DRT_LC_TMP" \
      "$DISPATCH_OUT_TMP" "$DISPATCH_ERR_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null

unset M030_SHADOW_COMPARE_CORPUS

printf 'SUMMARY: p04-sc2a-shadow-gate-block.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
