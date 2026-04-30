#!/usr/bin/env bash
# tools/verify/p03-sc6-frontmatter-override.sh -- M030 P03 SC-6 gate (FR-11).
#
# Asserts that a plan whose frontmatter declares `model_override: smart`
# AND whose body matches the mechanical-classifier signature dispatches
# (under shadow-on, no kill switch, no min_tier floor) with:
#   1. classifier sanity: classifier alone returns character=mechanical
#      (proves the override actually changes the routed tier rather than
#      rubber-stamping a tier the classifier would have chosen anyway).
#   2. override_source=plan_frontmatter (the plan-frontmatter override
#      branch fires; floor is absent so no escalation to milestone_floor).
#   3. model_routed=smart (post-override symbolic tier).
#   4. model_used matches the literal at templates/model-routing.yml
#      resolution.smart.claude-code (currently claude-opus-4-7). The
#      verifier reads this literal at runtime via awk extraction so the
#      verifier source remains free of hardcoded model IDs (CON-3).
#
# Round-trip dispatch shape mirrors p03-min-tier-floor.sh and
# p03-sc7-kill-switch.sh.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. Tmp-file
# intermediates per AP-009. Exit 0 iff fail == 0.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p03"
PLAN="$FIXTURES/plans/plan-with-frontmatter-override.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG="$FIXTURES/configs/config-baseline.yml"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"
CLASSIFIER="$REPO_ROOT/scripts/dispatch/classify-task.sh"
ROUTING_YML="$REPO_ROOT/templates/model-routing.yml"

pass=0
fail=0

# ---------- Gate 0: prerequisites exist ----------
ok=1
for f in "$PLAN" "$PAYLOAD" "$INTENSITY_META" "$CONFIG" "$DISPATCH" \
         "$CLASSIFIER" "$ROUTING_YML"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -ne 1 ]; then
  fail=$((fail + 1))
  printf 'SUMMARY: p03-sc6-frontmatter-override.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---------- Derive expected smart-tier model ID from routing YAML ----------
# CON-3: do NOT hardcode the literal in this verifier; read it from the
# resolution.smart.claude-code field at runtime via awk section-walker.
EXPECTED_MODEL_TMP="/tmp/p03-sc6-expected-model.txt"
rm -f "$EXPECTED_MODEL_TMP" 2>/dev/null
awk '
  BEGIN { in_resolution = 0; in_tier = 0 }
  /^resolution:/                    { in_resolution = 1; next }
  /^cost_rates:/                    { exit }
  in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == "smart:") ? 1 : 0; next }
  in_resolution && in_tier && /^    claude-code:/ {
    val = $2; gsub(/[",]/, "", val); print val; exit
  }
' "$ROUTING_YML" > "$EXPECTED_MODEL_TMP" 2>/dev/null
EXPECTED_MODEL="$(head -n 1 "$EXPECTED_MODEL_TMP" | tr -d '[:space:]')"
rm -f "$EXPECTED_MODEL_TMP" 2>/dev/null

if [ -z "$EXPECTED_MODEL" ]; then
  fail=$((fail + 1))
  printf 'FAIL: could not extract resolution.smart.claude-code from %s\n' "$ROUTING_YML"
  printf 'SUMMARY: p03-sc6-frontmatter-override.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---------- Assertion 1: classifier sanity ----------
# Independently invoke the classifier on the plan and assert it returns
# character=mechanical (so the override actually changes the routed tier).
CLASSIFY_TMP="/tmp/p03-sc6-classifier.txt"
rm -f "$CLASSIFY_TMP" 2>/dev/null
bash "$CLASSIFIER" "$PLAN" > "$CLASSIFY_TMP" 2>/dev/null
CHAR_TMP="/tmp/p03-sc6-char.txt"
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

# ---------- Stage tmp_root ----------
TMP_ROOT="$(mktemp -d 2>/dev/null)"
if [ -z "$TMP_ROOT" ]; then
  TMP_ROOT="/tmp/p03-sc6-fallback-$$"
  rm -rf "$TMP_ROOT" 2>/dev/null
  mkdir -p "$TMP_ROOT" 2>/dev/null
fi
mkdir -p "$TMP_ROOT/.orchestrator" 2>/dev/null
mkdir -p "$TMP_ROOT/phases" 2>/dev/null
cp "$CONFIG" "$TMP_ROOT/.orchestrator/config.yml" 2>/dev/null
LOG_FILE="$TMP_ROOT/execution-log.jsonl"

# ---------- Round-trip dispatch invocation ----------
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

# ---------- Read appended JSONL line ----------
LINE_TMP="/tmp/p03-sc6-line.txt"
rm -f "$LINE_TMP" 2>/dev/null
grep -F '"record_type":"dispatch_usage"' "$LOG_FILE" > "$LINE_TMP" 2>/dev/null

LC_TMP="/tmp/p03-sc6-lc.txt"
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
  printf 'SUMMARY: p03-sc6-frontmatter-override.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# ---------- Assertion 2: override_source=plan_frontmatter ----------
OS_TMP="/tmp/p03-sc6-ostok.txt"
rm -f "$OS_TMP" 2>/dev/null
grep -F '"override_source":"plan_frontmatter"' "$LINE_TMP" > "$OS_TMP" 2>/dev/null
OS_LC_TMP="/tmp/p03-sc6-oslc.txt"
rm -f "$OS_LC_TMP" 2>/dev/null
wc -l < "$OS_TMP" > "$OS_LC_TMP" 2>/dev/null
OS_LC="$(tr -d '[:space:]' < "$OS_LC_TMP")"
rm -f "$OS_TMP" "$OS_LC_TMP" 2>/dev/null
[ -n "$OS_LC" ] || OS_LC=0
if [ "$OS_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: override_source=plan_frontmatter\n'
else
  fail=$((fail + 1))
  printf 'FAIL: override_source=plan_frontmatter token missing from %s\n' "$LOG_FILE"
fi

# ---------- Assertion 3: model_routed=smart ----------
ROUTED_TMP="/tmp/p03-sc6-routedtok.txt"
rm -f "$ROUTED_TMP" 2>/dev/null
grep -F '"model_routed":"smart"' "$LINE_TMP" > "$ROUTED_TMP" 2>/dev/null
ROUTED_LC_TMP="/tmp/p03-sc6-routedlc.txt"
rm -f "$ROUTED_LC_TMP" 2>/dev/null
wc -l < "$ROUTED_TMP" > "$ROUTED_LC_TMP" 2>/dev/null
ROUTED_LC="$(tr -d '[:space:]' < "$ROUTED_LC_TMP")"
rm -f "$ROUTED_TMP" "$ROUTED_LC_TMP" 2>/dev/null
[ -n "$ROUTED_LC" ] || ROUTED_LC=0
if [ "$ROUTED_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: model_routed=smart (override raised mechanical/fast -> smart)\n'
else
  fail=$((fail + 1))
  printf 'FAIL: model_routed=smart token missing from %s\n' "$LOG_FILE"
fi

# ---------- Assertion 4: model_used matches resolution.smart.claude-code ----------
# Compose the expected grep pattern dynamically from the awk-extracted
# literal so the verifier source contains no hardcoded model ID.
MU_TMP="/tmp/p03-sc6-mu.txt"
rm -f "$MU_TMP" 2>/dev/null
EXPECTED_MU_TOKEN="\"model_used\":\"${EXPECTED_MODEL}\""
grep -F "$EXPECTED_MU_TOKEN" "$LINE_TMP" > "$MU_TMP" 2>/dev/null
MU_LC_TMP="/tmp/p03-sc6-mulc.txt"
rm -f "$MU_LC_TMP" 2>/dev/null
wc -l < "$MU_TMP" > "$MU_LC_TMP" 2>/dev/null
MU_LC="$(tr -d '[:space:]' < "$MU_LC_TMP")"
rm -f "$MU_TMP" "$MU_LC_TMP" 2>/dev/null
[ -n "$MU_LC" ] || MU_LC=0
if [ "$MU_LC" -ge 1 ]; then
  pass=$((pass + 1))
  printf 'PASS: model_used=%s matches resolution.smart.claude-code\n' "$EXPECTED_MODEL"
else
  fail=$((fail + 1))
  printf 'FAIL: model_used=%s token missing from %s\n' "$EXPECTED_MODEL" "$LOG_FILE"
fi

# ---------- Cleanup ----------
rm -f "$LINE_TMP" 2>/dev/null
rm -rf "$TMP_ROOT" 2>/dev/null

printf 'SUMMARY: p03-sc6-frontmatter-override.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
