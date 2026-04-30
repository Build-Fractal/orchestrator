#!/usr/bin/env bash
# tools/verify/p03-override-source-enum.sh -- M030 P03 override_source enum gate.
#
# T01 deliverable. Pre-amendment-tolerant: ships BEFORE T02 amends
# scripts/dispatch/dispatch-interface.sh to populate the override_source
# field. Pre-T02, the emitted JSONL record contains zero override_source
# tokens (the field has not been added); the verifier accepts zero as PASS
# for shadow-on scenarios A-D. Post-T02, the verifier asserts exactly one
# override_source token whose value is in the closed enum:
#   {plan_frontmatter, milestone_floor, disabled, shadow_gate_blocked, none}
# Anything else (zero post-T02, count > 1, or non-enum value) FAILs.
#
# Scenario E (shadow-off) is STRICT: zero tokens, no tolerance, before or
# after T02. The shadow-off branch must NEVER emit override_source per the
# additive-only-when-shadow-on contract (CON-2 / FR-19 / SC-11).
#
# Five scenarios:
#   A) shadow-on, baseline plan + baseline config         -> 0 or 1=none
#   B) shadow-on, baseline plan + routing-disabled config -> 0 or 1=disabled
#   C) shadow-on, override-smart plan + baseline config   -> 0 or 1=plan_frontmatter
#   D) shadow-on, baseline plan + min-tier-smart config   -> 0 or 1=milestone_floor
#   E) shadow-off, override-smart plan + min-tier-smart   -> exactly 0 (strict)
#
# Each scenario stages a fresh tmp_root (mktemp -d) whose .orchestrator/
# config.yml is copied from the scenario's fixture. The tmp_root also
# contains a phases/ subdir so dispatch-interface.sh's ORCH_ROOT carve-out
# routes the appended log to <tmp_root>/execution-log.jsonl directly
# (avoids dependency on uppercase-M### path-regex extraction from the
# fixture-plan path under tests/fixtures/m030-p03/...).
#
# Bash 3.2 compatible. AD-19 single-script-file shape. No compound chains
# beyond two-link cap. Per-scenario tmp-file intermediates. Exit 0 iff
# fail == 0. Emits SUMMARY: line at end.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$REPO_ROOT/tests/fixtures/m030-p03"
PLAN_BASELINE="$FIXTURES/plans/plan-mechanical-no-override.md"
PLAN_OVERRIDE="$FIXTURES/plans/plan-with-frontmatter-override.md"
PAYLOAD="$FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META="$FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG_BASELINE="$FIXTURES/configs/config-baseline.yml"
CONFIG_DISABLED="$FIXTURES/configs/config-with-routing-disabled.yml"
CONFIG_MIN_SMART="$FIXTURES/configs/config-with-min-tier-smart.yml"
DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

# ---------- Gate 0: prerequisites exist ----------
ok=1
for f in "$PLAN_BASELINE" "$PLAN_OVERRIDE" "$PAYLOAD" "$INTENSITY_META" \
         "$CONFIG_BASELINE" "$CONFIG_DISABLED" "$CONFIG_MIN_SMART" "$DISPATCH"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -eq 1 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'SUMMARY: p03-override-source-enum.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi

# Stage helper: build a tmp_root with .orchestrator/config.yml + phases/.
# Writes the tmp_root path to TMP_ROOT_OUT_FILE (passed by caller) so the
# caller can read it back without using $() compound substitution.
TMP_ROOT_OUT_FILE="/tmp/p03-override-source-enum-tmproot.txt"

_stage_tmp_root() {
  # $1 = source config path
  local src_config="$1"
  local tmp_root
  tmp_root="$(mktemp -d 2>/dev/null)"
  if [ -z "$tmp_root" ]; then
    tmp_root="/tmp/p03-override-source-enum-fallback-$$"
    rm -rf "$tmp_root" 2>/dev/null
    mkdir -p "$tmp_root" 2>/dev/null
  fi
  mkdir -p "$tmp_root/.orchestrator" 2>/dev/null
  mkdir -p "$tmp_root/phases" 2>/dev/null
  cp "$src_config" "$tmp_root/.orchestrator/config.yml" 2>/dev/null
  printf '%s\n' "$tmp_root" > "$TMP_ROOT_OUT_FILE"
}

# Per-scenario invocation. Caller has already set M030_SHADOW_MODE +
# CLAUDECODE + ORCHESTRATOR_ROOT in the current shell.
_invoke_dispatch() {
  # $1 = task plan path
  local plan="$1"
  bash "$DISPATCH" \
    --task-plan "$plan" \
    --payload "$PAYLOAD" \
    --intensity-metadata "$INTENSITY_META" \
    --backend stub \
    > /dev/null 2>&1
}

# Per-scenario enum check. Reads the appended JSONL line, counts
# override_source tokens, applies the pre-amendment-tolerant rules.
# $1 = scenario label
# $2 = log file path
# $3 = expected enum value (post-T02); empty for "any enum value"
_check_enum_tolerant() {
  local label="$1"
  local log_file="$2"
  local expected_value="$3"

  # Capture the dispatch_usage line.
  local line_tmp="/tmp/p03-override-source-enum-line.txt"
  rm -f "$line_tmp" 2>/dev/null
  grep -F '"record_type":"dispatch_usage"' "$log_file" > "$line_tmp" 2>/dev/null

  # Line count must be >= 1 (a record was appended).
  local lc_tmp="/tmp/p03-override-source-enum-lc.txt"
  rm -f "$lc_tmp" 2>/dev/null
  wc -l < "$line_tmp" > "$lc_tmp" 2>/dev/null
  local lc
  lc="$(tr -d '[:space:]' < "$lc_tmp")"
  rm -f "$lc_tmp" 2>/dev/null
  if [ -z "$lc" ]; then lc=0; fi
  if [ "$lc" -lt 1 ]; then
    fail=$((fail + 1))
    printf 'FAIL: %s -- no dispatch_usage record appended to %s\n' "$label" "$log_file"
    rm -f "$line_tmp" 2>/dev/null
    return 0
  fi

  # Count override_source tokens.
  local tok_tmp="/tmp/p03-override-source-enum-tok.txt"
  rm -f "$tok_tmp" 2>/dev/null
  grep -o '"override_source"' "$line_tmp" > "$tok_tmp" 2>/dev/null
  local tok_count_tmp="/tmp/p03-override-source-enum-tokc.txt"
  rm -f "$tok_count_tmp" 2>/dev/null
  wc -l < "$tok_tmp" > "$tok_count_tmp" 2>/dev/null
  local tok_count
  tok_count="$(tr -d '[:space:]' < "$tok_count_tmp")"
  rm -f "$tok_tmp" 2>/dev/null
  rm -f "$tok_count_tmp" 2>/dev/null
  if [ -z "$tok_count" ]; then tok_count=0; fi

  if [ "$tok_count" = "0" ]; then
    pass=$((pass + 1))
    printf 'PASS: %s (pre-amendment, override_source field absent)\n' "$label"
    rm -f "$line_tmp" 2>/dev/null
    return 0
  fi

  if [ "$tok_count" != "1" ]; then
    fail=$((fail + 1))
    printf 'FAIL: %s -- override_source token count %s, expected 0 or 1\n' "$label" "$tok_count"
    rm -f "$line_tmp" 2>/dev/null
    return 0
  fi

  # Exactly one token. Extract its value via grep+sed to a tmp file.
  local val_tmp="/tmp/p03-override-source-enum-val.txt"
  rm -f "$val_tmp" 2>/dev/null
  grep -oE '"override_source":"[^"]*"' "$line_tmp" > "$val_tmp" 2>/dev/null
  local value_raw
  value_raw="$(head -n 1 "$val_tmp")"
  rm -f "$val_tmp" 2>/dev/null
  rm -f "$line_tmp" 2>/dev/null
  local value
  value="$(printf '%s' "$value_raw" | sed -E 's/.*:"([^"]*)".*/\1/')"

  case "$value" in
    plan_frontmatter|milestone_floor|disabled|shadow_gate_blocked|none)
      # Enum-valid. If caller specified an expected value, also check that.
      if [ -n "$expected_value" ] && [ "$value" != "$expected_value" ]; then
        fail=$((fail + 1))
        printf 'FAIL: %s -- override_source=%s, expected %s\n' "$label" "$value" "$expected_value"
        return 0
      fi
      pass=$((pass + 1))
      printf 'PASS: %s (post-amendment, override_source=%s)\n' "$label" "$value"
      ;;
    *)
      fail=$((fail + 1))
      printf 'FAIL: %s -- override_source value %s not in closed enum {plan_frontmatter, milestone_floor, disabled, shadow_gate_blocked, none}\n' "$label" "$value"
      ;;
  esac
}

# Per-scenario STRICT zero-tokens check (shadow-off).
_check_enum_strict_zero() {
  local label="$1"
  local log_file="$2"

  local line_tmp="/tmp/p03-override-source-enum-line.txt"
  rm -f "$line_tmp" 2>/dev/null
  grep -F '"record_type":"dispatch_usage"' "$log_file" > "$line_tmp" 2>/dev/null

  local lc_tmp="/tmp/p03-override-source-enum-lc.txt"
  rm -f "$lc_tmp" 2>/dev/null
  wc -l < "$line_tmp" > "$lc_tmp" 2>/dev/null
  local lc
  lc="$(tr -d '[:space:]' < "$lc_tmp")"
  rm -f "$lc_tmp" 2>/dev/null
  if [ -z "$lc" ]; then lc=0; fi
  if [ "$lc" -lt 1 ]; then
    fail=$((fail + 1))
    printf 'FAIL: %s -- no dispatch_usage record appended to %s\n' "$label" "$log_file"
    rm -f "$line_tmp" 2>/dev/null
    return 0
  fi

  local tok_tmp="/tmp/p03-override-source-enum-tok.txt"
  rm -f "$tok_tmp" 2>/dev/null
  grep -o '"override_source"' "$line_tmp" > "$tok_tmp" 2>/dev/null
  local tok_count_tmp="/tmp/p03-override-source-enum-tokc.txt"
  rm -f "$tok_count_tmp" 2>/dev/null
  wc -l < "$tok_tmp" > "$tok_count_tmp" 2>/dev/null
  local tok_count
  tok_count="$(tr -d '[:space:]' < "$tok_count_tmp")"
  rm -f "$tok_tmp" 2>/dev/null
  rm -f "$tok_count_tmp" 2>/dev/null
  rm -f "$line_tmp" 2>/dev/null
  if [ -z "$tok_count" ]; then tok_count=0; fi

  if [ "$tok_count" = "0" ]; then
    pass=$((pass + 1))
    printf 'PASS: %s (shadow-off, zero override_source tokens)\n' "$label"
  else
    fail=$((fail + 1))
    printf 'FAIL: %s -- shadow-off emitted %s override_source token(s); MUST be zero (additive-only-when-shadow-on contract)\n' "$label" "$tok_count"
  fi
}

# Common env unsets between scenarios.
unset ORCH_MODEL

# ---------- Scenario A: shadow-on, baseline plan + baseline config ----------
_stage_tmp_root "$CONFIG_BASELINE"
TMP_ROOT_A="$(cat "$TMP_ROOT_OUT_FILE")"
export ORCHESTRATOR_ROOT="$TMP_ROOT_A"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
_invoke_dispatch "$PLAN_BASELINE"
_check_enum_tolerant "Scenario A (shadow-on, baseline plan, baseline config)" \
  "$TMP_ROOT_A/execution-log.jsonl" "none"
rm -rf "$TMP_ROOT_A" 2>/dev/null

# ---------- Scenario B: shadow-on, baseline plan + routing-disabled config ----------
_stage_tmp_root "$CONFIG_DISABLED"
TMP_ROOT_B="$(cat "$TMP_ROOT_OUT_FILE")"
export ORCHESTRATOR_ROOT="$TMP_ROOT_B"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
_invoke_dispatch "$PLAN_BASELINE"
_check_enum_tolerant "Scenario B (shadow-on, baseline plan, routing-disabled config)" \
  "$TMP_ROOT_B/execution-log.jsonl" "disabled"
rm -rf "$TMP_ROOT_B" 2>/dev/null

# ---------- Scenario C: shadow-on, override-smart plan + baseline config ----------
_stage_tmp_root "$CONFIG_BASELINE"
TMP_ROOT_C="$(cat "$TMP_ROOT_OUT_FILE")"
export ORCHESTRATOR_ROOT="$TMP_ROOT_C"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
_invoke_dispatch "$PLAN_OVERRIDE"
_check_enum_tolerant "Scenario C (shadow-on, override-smart plan, baseline config)" \
  "$TMP_ROOT_C/execution-log.jsonl" "plan_frontmatter"
rm -rf "$TMP_ROOT_C" 2>/dev/null

# ---------- Scenario D: shadow-on, baseline plan + min-tier-smart config ----------
_stage_tmp_root "$CONFIG_MIN_SMART"
TMP_ROOT_D="$(cat "$TMP_ROOT_OUT_FILE")"
export ORCHESTRATOR_ROOT="$TMP_ROOT_D"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
_invoke_dispatch "$PLAN_BASELINE"
_check_enum_tolerant "Scenario D (shadow-on, baseline plan, min-tier-smart config)" \
  "$TMP_ROOT_D/execution-log.jsonl" "milestone_floor"
rm -rf "$TMP_ROOT_D" 2>/dev/null

# ---------- Scenario E: shadow-off, override-smart plan + min-tier-smart ----------
# CLAUDECODE stays exported (CC-only short-circuit is OFF for "shadow-off"
# meaning M030_SHADOW_MODE=unset). Most-overlay-rich case: even with both a
# plan-frontmatter override AND a milestone-floor config in play, the
# shadow-off branch must NOT emit any override_source token.
_stage_tmp_root "$CONFIG_MIN_SMART"
TMP_ROOT_E="$(cat "$TMP_ROOT_OUT_FILE")"
export ORCHESTRATOR_ROOT="$TMP_ROOT_E"
unset M030_SHADOW_MODE
export CLAUDECODE=1
_invoke_dispatch "$PLAN_OVERRIDE"
_check_enum_strict_zero "Scenario E (shadow-off, override-smart plan, min-tier-smart config)" \
  "$TMP_ROOT_E/execution-log.jsonl"
rm -rf "$TMP_ROOT_E" 2>/dev/null

rm -f "$TMP_ROOT_OUT_FILE" 2>/dev/null

printf 'SUMMARY: p03-override-source-enum.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
