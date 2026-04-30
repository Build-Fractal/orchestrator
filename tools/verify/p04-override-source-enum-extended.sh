#!/usr/bin/env bash
# tools/verify/p04-override-source-enum-extended.sh -- M030/P04 enum gate (extended).
#
# T01 deliverable. Pre-amendment-tolerant: ships BEFORE T02 amends
# scripts/dispatch/dispatch-interface.sh to introduce the live-routing
# branch and the sixth `override_source` enum value `shadow_gate_blocked`.
#
# Extends the P03 5-scenario harness (Scenarios A-E) with a new Scenario F:
# live-routing-true + empty shadow corpus -> shadow_gate_blocked (post-T02).
# Pre-T02, the live branch does not exist; dispatch falls through to the
# pre-existing override-resolution chain and emits `none` (or any other
# P03 enum value if upstream overrides happen to fire). The verifier
# accepts the pre-T02 fallback path as PASS for Scenario F via the
# tolerant-mode predicate.
#
# Strict mode (post-T02): Scenario F MUST emit exactly `shadow_gate_blocked`.
# Tolerant mode (pre-T02): Scenario F MAY emit any P03 enum value.
#
# Six scenarios (A-E inherited verbatim from p03-override-source-enum.sh;
# F is new):
#   A) shadow-on, baseline plan + baseline config       -> none           (strict)
#   B) shadow-on, baseline plan + routing-disabled cfg  -> disabled       (strict)
#   C) shadow-on, override-smart plan + baseline cfg    -> plan_frontmatter (strict)
#   D) shadow-on, baseline plan + min-tier-smart cfg    -> milestone_floor (strict)
#   E) shadow-off, override-smart plan + min-tier-smart -> zero tokens    (strict)
#   F) shadow-on, baseline plan + live-true cfg + empty -> shadow_gate_blocked (tolerant)
#
# Each scenario stages a fresh tmp_root (mktemp -d) whose .orchestrator/
# config.yml is copied from the scenario's fixture. The tmp_root contains
# a phases/ subdir so dispatch-interface.sh's ORCH_ROOT/phases/ carve-out
# routes the appended log to <tmp_root>/execution-log.jsonl directly.
#
# Bash 3.2 compatible. AD-19 single-script-file shape. No compound chains
# beyond two-link cap. Per-scenario tmp-file intermediates. Exit 0 iff
# fail == 0. Emits SUMMARY: line at end.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# P03 fixtures (Scenarios A-E re-use these verbatim).
P03_FIXTURES="$REPO_ROOT/tests/fixtures/m030-p03"
PLAN_BASELINE_P03="$P03_FIXTURES/plans/plan-mechanical-no-override.md"
PLAN_OVERRIDE_P03="$P03_FIXTURES/plans/plan-with-frontmatter-override.md"
PAYLOAD_P03="$P03_FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META_P03="$P03_FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG_BASELINE="$P03_FIXTURES/configs/config-baseline.yml"
CONFIG_DISABLED="$P03_FIXTURES/configs/config-with-routing-disabled.yml"
CONFIG_MIN_SMART="$P03_FIXTURES/configs/config-with-min-tier-smart.yml"

# P04 fixtures (Scenario F).
P04_FIXTURES="$REPO_ROOT/tests/fixtures/m030-p04"
PLAN_BASELINE_P04="$P04_FIXTURES/plans/plan-mechanical-no-override.md"
PAYLOAD_P04="$P04_FIXTURES/round-trip-stage/payload.txt"
INTENSITY_META_P04="$P04_FIXTURES/round-trip-stage/intensity-metadata.txt"
CONFIG_LIVE_TRUE="$P04_FIXTURES/configs/config-with-live-true.yml"
CORPUS_EMPTY="$P04_FIXTURES/shadow-corpus-empty.jsonl"

DISPATCH="$REPO_ROOT/scripts/dispatch/dispatch-interface.sh"

pass=0
fail=0

# ---------- Gate 0: prerequisites exist ----------
ok=1
for f in \
    "$PLAN_BASELINE_P03" "$PLAN_OVERRIDE_P03" "$PAYLOAD_P03" "$INTENSITY_META_P03" \
    "$CONFIG_BASELINE" "$CONFIG_DISABLED" "$CONFIG_MIN_SMART" \
    "$PLAN_BASELINE_P04" "$PAYLOAD_P04" "$INTENSITY_META_P04" \
    "$CONFIG_LIVE_TRUE" "$CORPUS_EMPTY" "$DISPATCH"; do
  if [ ! -f "$f" ]; then
    ok=0
    printf 'FAIL: prerequisite missing at %s\n' "$f"
  fi
done
if [ "$ok" -eq 1 ]; then
  pass=$((pass + 1))
else
  fail=$((fail + 1))
  printf 'SUMMARY: p04-override-source-enum-extended.sh pass=%d fail=%d\n' "$pass" "$fail"
  exit 1
fi
# Adjust pass back -- prereq gate is not counted toward the per-scenario tally.
pass=$((pass - 1))

# Stage helper: build a tmp_root with .orchestrator/config.yml + phases/.
# Writes the tmp_root path to TMP_ROOT_OUT_FILE so caller can read without
# using $() compound substitution.
TMP_ROOT_OUT_FILE="/tmp/p04-override-source-enum-tmproot.txt"

_stage_tmp_root() {
  # $1 = source config path
  local src_config="$1"
  local tmp_root
  tmp_root="$(mktemp -d 2>/dev/null)"
  if [ -z "$tmp_root" ]; then
    tmp_root="/tmp/p04-override-source-enum-fallback-$$"
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
  # $2 = payload path
  # $3 = intensity-metadata path
  local plan="$1"
  local payload="$2"
  local meta="$3"
  bash "$DISPATCH" \
    --task-plan "$plan" \
    --payload "$payload" \
    --intensity-metadata "$meta" \
    --backend stub \
    > /dev/null 2>&1
}

# Per-scenario STRICT enum check.
# $1 = scenario label
# $2 = log file path
# $3 = expected enum value
_check_enum_strict() {
  local label="$1"
  local log_file="$2"
  local expected_value="$3"

  local line_tmp="/tmp/p04-override-source-enum-line.txt"
  rm -f "$line_tmp" 2>/dev/null
  grep -F '"record_type":"dispatch_usage"' "$log_file" > "$line_tmp" 2>/dev/null

  local lc_tmp="/tmp/p04-override-source-enum-lc.txt"
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

  local tok_tmp="/tmp/p04-override-source-enum-tok.txt"
  rm -f "$tok_tmp" 2>/dev/null
  grep -o '"override_source"' "$line_tmp" > "$tok_tmp" 2>/dev/null
  local tok_count_tmp="/tmp/p04-override-source-enum-tokc.txt"
  rm -f "$tok_count_tmp" 2>/dev/null
  wc -l < "$tok_tmp" > "$tok_count_tmp" 2>/dev/null
  local tok_count
  tok_count="$(tr -d '[:space:]' < "$tok_count_tmp")"
  rm -f "$tok_tmp" 2>/dev/null
  rm -f "$tok_count_tmp" 2>/dev/null
  if [ -z "$tok_count" ]; then tok_count=0; fi

  if [ "$tok_count" != "1" ]; then
    fail=$((fail + 1))
    printf 'FAIL: %s -- override_source token count %s, expected 1\n' "$label" "$tok_count"
    rm -f "$line_tmp" 2>/dev/null
    return 0
  fi

  # Extract value via grep+sed to a tmp file.
  local val_tmp="/tmp/p04-override-source-enum-val.txt"
  rm -f "$val_tmp" 2>/dev/null
  grep -oE '"override_source":"[^"]*"' "$line_tmp" > "$val_tmp" 2>/dev/null
  local value_raw
  value_raw="$(head -n 1 "$val_tmp")"
  rm -f "$val_tmp" 2>/dev/null
  rm -f "$line_tmp" 2>/dev/null
  local value
  value="$(printf '%s' "$value_raw" | sed -E 's/.*:"([^"]*)".*/\1/')"

  if [ "$value" = "$expected_value" ]; then
    pass=$((pass + 1))
    printf 'PASS: %s (override_source=%s)\n' "$label" "$value"
  else
    fail=$((fail + 1))
    printf 'FAIL: %s -- override_source=%s, expected %s\n' "$label" "$value" "$expected_value"
  fi
}

# Per-scenario STRICT zero-tokens check (shadow-off).
_check_enum_strict_zero() {
  local label="$1"
  local log_file="$2"

  local line_tmp="/tmp/p04-override-source-enum-line.txt"
  rm -f "$line_tmp" 2>/dev/null
  grep -F '"record_type":"dispatch_usage"' "$log_file" > "$line_tmp" 2>/dev/null

  local lc_tmp="/tmp/p04-override-source-enum-lc.txt"
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

  local tok_tmp="/tmp/p04-override-source-enum-tok.txt"
  rm -f "$tok_tmp" 2>/dev/null
  grep -o '"override_source"' "$line_tmp" > "$tok_tmp" 2>/dev/null
  local tok_count_tmp="/tmp/p04-override-source-enum-tokc.txt"
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
    printf 'FAIL: %s -- shadow-off emitted %s override_source token(s); MUST be zero\n' "$label" "$tok_count"
  fi
}

# Per-scenario TOLERANT enum check (Scenario F pre-amendment-tolerant).
# PASS if extracted value == "shadow_gate_blocked" (strict post-T02)
# OR value is in the P03 closed enum (pre-T02 fallback).
# $1 = scenario label
# $2 = log file path
# $3 = strict expected value (recorded for diagnostic; the predicate also
#      accepts the pre-T02 fallback values).
_check_enum_tolerant_f() {
  local label="$1"
  local log_file="$2"
  local strict_expected="$3"

  local line_tmp="/tmp/p04-override-source-enum-line.txt"
  rm -f "$line_tmp" 2>/dev/null
  grep -F '"record_type":"dispatch_usage"' "$log_file" > "$line_tmp" 2>/dev/null

  local lc_tmp="/tmp/p04-override-source-enum-lc.txt"
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

  local tok_tmp="/tmp/p04-override-source-enum-tok.txt"
  rm -f "$tok_tmp" 2>/dev/null
  grep -o '"override_source"' "$line_tmp" > "$tok_tmp" 2>/dev/null
  local tok_count_tmp="/tmp/p04-override-source-enum-tokc.txt"
  rm -f "$tok_count_tmp" 2>/dev/null
  wc -l < "$tok_tmp" > "$tok_count_tmp" 2>/dev/null
  local tok_count
  tok_count="$(tr -d '[:space:]' < "$tok_count_tmp")"
  rm -f "$tok_tmp" 2>/dev/null
  rm -f "$tok_count_tmp" 2>/dev/null
  if [ -z "$tok_count" ]; then tok_count=0; fi

  if [ "$tok_count" != "1" ]; then
    fail=$((fail + 1))
    printf 'FAIL: %s -- override_source token count %s, expected 1\n' "$label" "$tok_count"
    rm -f "$line_tmp" 2>/dev/null
    return 0
  fi

  local val_tmp="/tmp/p04-override-source-enum-val.txt"
  rm -f "$val_tmp" 2>/dev/null
  grep -oE '"override_source":"[^"]*"' "$line_tmp" > "$val_tmp" 2>/dev/null
  local value_raw
  value_raw="$(head -n 1 "$val_tmp")"
  rm -f "$val_tmp" 2>/dev/null
  rm -f "$line_tmp" 2>/dev/null
  local value
  value="$(printf '%s' "$value_raw" | sed -E 's/.*:"([^"]*)".*/\1/')"

  case "$value" in
    shadow_gate_blocked)
      pass=$((pass + 1))
      printf 'PASS: %s (post-amendment strict, override_source=%s)\n' "$label" "$value"
      ;;
    plan_frontmatter|milestone_floor|disabled|none)
      pass=$((pass + 1))
      printf 'PASS: %s (pre-amendment tolerant, override_source=%s; strict expects %s post-T02)\n' \
        "$label" "$value" "$strict_expected"
      ;;
    *)
      fail=$((fail + 1))
      printf 'FAIL: %s -- override_source=%s not in extended closed enum {plan_frontmatter, milestone_floor, disabled, shadow_gate_blocked, none}\n' \
        "$label" "$value"
      ;;
  esac
}

# Common env reset helper.
_reset_env() {
  unset ORCH_MODEL
  unset M030_SHADOW_COMPARE_CORPUS
  unset M030_SHADOW_MODE
  unset CLAUDECODE
}

# ---------- Scenario A: shadow-on, baseline plan + baseline config ----------
_reset_env
_stage_tmp_root "$CONFIG_BASELINE"
TMP_ROOT_A="$(cat "$TMP_ROOT_OUT_FILE")"
export ORCHESTRATOR_ROOT="$TMP_ROOT_A"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
_invoke_dispatch "$PLAN_BASELINE_P03" "$PAYLOAD_P03" "$INTENSITY_META_P03"
_check_enum_strict "Scenario A (shadow-on, baseline plan, baseline config)" \
  "$TMP_ROOT_A/execution-log.jsonl" "none"
rm -rf "$TMP_ROOT_A" 2>/dev/null

# ---------- Scenario B: shadow-on, baseline plan + routing-disabled config ----------
_reset_env
_stage_tmp_root "$CONFIG_DISABLED"
TMP_ROOT_B="$(cat "$TMP_ROOT_OUT_FILE")"
export ORCHESTRATOR_ROOT="$TMP_ROOT_B"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
_invoke_dispatch "$PLAN_BASELINE_P03" "$PAYLOAD_P03" "$INTENSITY_META_P03"
_check_enum_strict "Scenario B (shadow-on, baseline plan, routing-disabled config)" \
  "$TMP_ROOT_B/execution-log.jsonl" "disabled"
rm -rf "$TMP_ROOT_B" 2>/dev/null

# ---------- Scenario C: shadow-on, override-smart plan + baseline config ----------
_reset_env
_stage_tmp_root "$CONFIG_BASELINE"
TMP_ROOT_C="$(cat "$TMP_ROOT_OUT_FILE")"
export ORCHESTRATOR_ROOT="$TMP_ROOT_C"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
_invoke_dispatch "$PLAN_OVERRIDE_P03" "$PAYLOAD_P03" "$INTENSITY_META_P03"
_check_enum_strict "Scenario C (shadow-on, override-smart plan, baseline config)" \
  "$TMP_ROOT_C/execution-log.jsonl" "plan_frontmatter"
rm -rf "$TMP_ROOT_C" 2>/dev/null

# ---------- Scenario D: shadow-on, baseline plan + min-tier-smart config ----------
_reset_env
_stage_tmp_root "$CONFIG_MIN_SMART"
TMP_ROOT_D="$(cat "$TMP_ROOT_OUT_FILE")"
export ORCHESTRATOR_ROOT="$TMP_ROOT_D"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
_invoke_dispatch "$PLAN_BASELINE_P03" "$PAYLOAD_P03" "$INTENSITY_META_P03"
_check_enum_strict "Scenario D (shadow-on, baseline plan, min-tier-smart config)" \
  "$TMP_ROOT_D/execution-log.jsonl" "milestone_floor"
rm -rf "$TMP_ROOT_D" 2>/dev/null

# ---------- Scenario E: shadow-off, override-smart plan + min-tier-smart ----------
# Most-overlay-rich case: even with both a plan-frontmatter override AND a
# milestone-floor config in play, the shadow-off branch must NOT emit any
# override_source token (additive-only-when-shadow-on contract).
_reset_env
_stage_tmp_root "$CONFIG_MIN_SMART"
TMP_ROOT_E="$(cat "$TMP_ROOT_OUT_FILE")"
export ORCHESTRATOR_ROOT="$TMP_ROOT_E"
export CLAUDECODE=1
_invoke_dispatch "$PLAN_OVERRIDE_P03" "$PAYLOAD_P03" "$INTENSITY_META_P03"
_check_enum_strict_zero "Scenario E (shadow-off, override-smart plan, min-tier-smart config)" \
  "$TMP_ROOT_E/execution-log.jsonl"
rm -rf "$TMP_ROOT_E" 2>/dev/null

# ---------- Scenario F: shadow-on, baseline plan + live-true cfg + empty corpus ----------
# Pre-T02: dispatch-interface.sh has no live-routing branch. The dispatch
# falls through to the pre-existing override-resolution chain. With baseline
# plan + config-with-live-true (no kill switch / no min_tier / no plan-
# frontmatter override), the chain emits override_source=none. Tolerant
# predicate accepts any P03 enum value as PASS.
#
# Post-T02: the live branch reads the corpus via shadow-compare; verdict
# evidence_insufficient -> shadow_gate_blocked -> strict predicate fires.
#
# M030_SHADOW_COMPARE_CORPUS env var is consumed by T02's amendment; pre-
# T02 it has no effect.
_reset_env
_stage_tmp_root "$CONFIG_LIVE_TRUE"
TMP_ROOT_F="$(cat "$TMP_ROOT_OUT_FILE")"
export ORCHESTRATOR_ROOT="$TMP_ROOT_F"
export M030_SHADOW_MODE=1
export CLAUDECODE=1
export M030_SHADOW_COMPARE_CORPUS="$CORPUS_EMPTY"
_invoke_dispatch "$PLAN_BASELINE_P04" "$PAYLOAD_P04" "$INTENSITY_META_P04"
_check_enum_tolerant_f "Scenario F (shadow-on, baseline plan, live-true config, empty corpus)" \
  "$TMP_ROOT_F/execution-log.jsonl" "shadow_gate_blocked"
rm -rf "$TMP_ROOT_F" 2>/dev/null

_reset_env
rm -f "$TMP_ROOT_OUT_FILE" 2>/dev/null

printf 'SUMMARY: p04-override-source-enum-extended.sh pass=%d fail=%d\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then
  exit 0
fi
exit 1
