#!/usr/bin/env bash
# scripts/dispatch/dispatch-interface.sh — Uniform dispatch interface
#
# Thin router that accepts a task plan + context payload + intensity
# metadata, resolves a backend adapter (via backend-registry.sh or an
# explicit --backend flag), and invokes the adapter as a subprocess.
#
# On success: emits the adapter's stdout (a dispatch-result.md
# conforming document) unchanged, exit 0.
#
# On failure: synthesizes a dispatch-error.md conforming document on
# stderr and exits non-zero. Failure modes:
#   - missing required inputs (--task-plan, --payload)
#   - explicit --backend that does not exist in adapters/backend/
#   - no backends available (registry reports default_backend empty)
#   - adapter subprocess exits non-zero without emitting a result
#
# Usage:
#   dispatch-interface.sh --task-plan <path> --payload <path> \
#                         --intensity-metadata <path> [--backend <name>]
#
# FR-009: uniform interface, structured result.
# FR-011: no backend-specific branching -- adapters are resolved purely
#         by filename lookup in scripts/dispatch/adapters/backend/.
# FR-012: structured error schema on failure.
# SC-003: new backends = new files; zero edits to this file required.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY="${SCRIPT_DIR}/backend-registry.sh"
ADAPTERS_DIR="${SCRIPT_DIR}/adapters/backend"

# M019/P01/T03: Source pricing helpers for dispatch_usage emitter.
# Sourced lazily at top; library is idempotent (sourced-guard). If the lib
# is absent, the emitter degrades to a no-op via type-check in the helper.
_DI_PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
if [ -r "$_DI_PROJECT_ROOT/scripts/lib/pricing.sh" ]; then
  # shellcheck disable=SC1091
  . "$_DI_PROJECT_ROOT/scripts/lib/pricing.sh"
fi

TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""
BACKEND=""

# --- M020/P02/T03: --query subcommand passthrough (OQ-4) ---------------------
# When the FIRST argument is --query, delegate to scripts/knowledge/query.sh
# and exec out, preserving exit code + stdout + stderr byte-equivalent. Never
# reaches backend resolution or the dispatch_usage JSONL emitter — query is
# a side-effect-free knowledge-layer read (FR-8 / CON-1 / SC-7).
if [ "${1:-}" = "--query" ]; then
  shift
  query_script="$SCRIPT_DIR/../knowledge/query.sh"
  if [ ! -x "$query_script" ]; then
    echo "FAIL: query.sh missing or not executable at $query_script" >&2
    exit 1
  fi
  exec bash "$query_script" "$@"
fi
# -----------------------------------------------------------------------------

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-plan)
      TASK_PLAN="${2:-}"; shift 2 ;;
    --payload)
      PAYLOAD="${2:-}"; shift 2 ;;
    --intensity-metadata)
      INTENSITY_METADATA="${2:-}"; shift 2 ;;
    --backend)
      BACKEND="${2:-}"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Helper: emit a dispatch-error document on stderr ---
emit_error() {
  local error_type="$1"
  local retry_eligible="$2"
  local escalation="$3"
  local backend="$4"
  local error_message="$5"
  local error_context="$6"
  local suggested_action="$7"
  local occurred_at
  occurred_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  cat >&2 <<EOF
---
schema_version: "1.0"
type: "dispatch-error"
error_type: "${error_type}"
retry_eligible: "${retry_eligible}"
escalation: "${escalation}"
backend: "${backend}"
occurred_at: "${occurred_at}"
---

# Dispatch Error

## Error Type

${error_type}

## Retry Eligibility

retry_eligible: ${retry_eligible}

## Escalation

escalation: ${escalation}

## Error Message

${error_message}

## Context

${error_context}

## Suggested Action

${suggested_action}
EOF
}

# --- M018/P05/T01: dispatch_usage savings-field rollup ---
# Reads the same-unitId payload_breakdown record(s) from the in-flight log
# file and emits six integers on stdout (one per line, in order):
#   filter_dropped_tokens, tier1_savings_tokens, tier2_savings_tokens,
#   tier1_invocations, tier3_compression_savings_tokens, tier3_invocations
# (Last two fields appended by M018/P06/T02 — CON-5 additive carry-forward.)
# Records lacking a field contribute 0. Multiple matching records sum.
# Bail-safe: missing log file or zero matches emits "0\n0\n0\n0\n0\n0\n".
# MEM004 emitter-internal carve-out — pipes/awk/$() permitted in body.
_di_rollup_savings_fields() {
  local log_file="$1"
  local unit_id="$2"
  if [ -z "$log_file" ] || [ ! -f "$log_file" ] || [ -z "$unit_id" ]; then
    printf '0\n0\n0\n0\n0\n0\n'
    return 0
  fi
  awk -v uid="$unit_id" '
    BEGIN { fdrop = 0; t1s = 0; t2s = 0; t1i = 0; t3s = 0; t3i = 0 }
    /"record_type":"payload_breakdown"/ {
      if (index($0, "\"unitId\":\"" uid "\"") == 0) next
      if (match($0, /"filter_dropped_tokens":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); fdrop += v + 0
      }
      if (match($0, /"tier1_savings_tokens":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t1s += v + 0
      }
      if (match($0, /"tier2_savings_tokens":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t2s += v + 0
      }
      if (match($0, /"tier1_invocations":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t1i += v + 0
      }
      # M018/P06/T02 — additive tier3 fields.
      if (match($0, /"tier3_compression_savings_tokens":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t3s += v + 0
      }
      if (match($0, /"tier3_invocations":[0-9]+/)) {
        v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t3i += v + 0
      }
    }
    END { printf "%d\n%d\n%d\n%d\n%d\n%d\n", fdrop, t1s, t2s, t1i, t3s, t3i }
  ' "$log_file" 2>/dev/null || printf '0\n0\n0\n0\n0\n0\n'
}

# --- M030/P03/T02: numeric tier-rank for floor comparison ---
# Maps symbolic tier names to numeric ranks (fast<balanced<smart). Higher
# rank = stricter floor. Returns rank on stdout; unknown tier returns -1.
# POSIX-safe (case statement); no bash 4 features.
_di_tier_rank() {
  case "$1" in
    fast) echo 0 ;;
    balanced) echo 1 ;;
    smart) echo 2 ;;
    *) echo -1 ;;
  esac
}

# --- M019/P01/T03: dispatch_usage JSONL emitter ---
# Emits exactly one `dispatch_usage` record per dispatch invocation after
# BACKEND is resolved. Called from the happy-path end AND each post-BACKEND
# error branch. Bail-safe: mkdir/append failures emit a single stderr note
# and return 0 so dispatch exit codes are never affected by log-write
# failures. SC-1: one record per dispatch. SC-6: no stdout side effects.
# C4: pricing degradation -> estimated_cost_usd:null + pricing_warning.
# MEM004 carve-out: pipes/$()/awk permitted (dispatch-internal emitter).
_di_emit_dispatch_usage() {
  # $1 = override pricing_warning reason (e.g., "adapter-failed"). Empty ->
  # use the pricing-lib resolution (happy path or missing/stale/no-rate).
  local warning_override="${1:-}"

  # M019/P01/T05: test seam — ORCH_M019_EMIT=0 disables emission so the
  # zero-token-growth gate can assert no bytes are appended to any log.
  if [ "${ORCH_M019_EMIT:-1}" = "0" ]; then
    return 0
  fi

  # Skip silently if pricing lib was not loadable (no helpers present).
  if ! type chars_to_tokens_quartile >/dev/null 2>&1; then
    return 0
  fi

  local payload_bytes input_tokens output_tokens model cost_usd warning
  local pricing_version ts log_dir log_file
  local escaped_warning

  payload_bytes=0
  if [ -n "${PAYLOAD:-}" ] && [ -f "$PAYLOAD" ]; then
    payload_bytes="$(wc -c < "$PAYLOAD" 2>/dev/null | tr -d ' ')"
    [ -n "$payload_bytes" ] || payload_bytes=0
  fi
  input_tokens="$(chars_to_tokens_quartile "$payload_bytes")"
  output_tokens=0

  model="${ORCH_MODEL:-}"
  if [ -z "$model" ] && [ -n "${INTENSITY_METADATA:-}" ] && [ -f "$INTENSITY_METADATA" ]; then
    model="$(grep -E '^model:' "$INTENSITY_METADATA" | head -n 1 | sed -E 's/^model:[[:space:]]*"?([^"]*)"?.*/\1/')"
  fi

  # Run the estimator in the CURRENT shell (not a subshell) so the module-
  # scoped _PRICING_WARNING_REASON side-channel survives for the downstream
  # pricing_warning_reason read. Route stdout through a tmp file to capture
  # the dollar estimate without losing the warning state.
  local _di_cost_tmp
  _di_cost_tmp="$(mktemp 2>/dev/null || printf '/tmp/di_cost_%d' "$$")"
  pricing_estimate_cost_usd "$input_tokens" "$output_tokens" "$model" > "$_di_cost_tmp" 2>/dev/null || true
  cost_usd="$(tr -d '[:space:]' < "$_di_cost_tmp")"
  rm -f "$_di_cost_tmp" 2>/dev/null || true
  warning="$(pricing_warning_reason)"
  pricing_version="$(pricing_last_updated)"

  # Override branch: adapter-failed forces cost=null regardless of pricing.
  if [ -n "$warning_override" ]; then
    cost_usd=""
    warning="$warning_override"
  fi

  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Fixture-mode carve-out mirrors build-context.sh T02: when ORCH_ROOT is
  # already the milestone dir (contains phases/), log there directly.
  # Otherwise require MILESTONE_ID to route the log. When both are missing,
  # the task plan path is too non-canonical to route — skip the emit silently
  # (typically a test fixture that did not opt into the emitter).
  if [ -d "$ORCH_ROOT/phases" ]; then
    log_dir="$ORCH_ROOT"
  elif [ -n "$MILESTONE_ID" ]; then
    log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
  else
    return 0
  fi
  log_file="$log_dir/execution-log.jsonl"

  # M018/P05/T01: roll up the same-unitId payload_breakdown savings fields.
  # Reads from the in-flight log; missing log / zero matches → all zeros.
  # M018/P06/T02: extended with tier3_compression_savings_tokens / tier3_invocations.
  local _di_savings _di_filter_dropped _di_tier1_savings _di_tier2_savings _di_tier1_invocs
  local _di_tier3_savings _di_tier3_invocs
  _di_savings="$(_di_rollup_savings_fields "$log_file" "$UNIT_ID")"
  _di_filter_dropped="$(printf '%s\n' "$_di_savings" | sed -n '1p')"
  _di_tier1_savings="$(printf '%s\n' "$_di_savings" | sed -n '2p')"
  _di_tier2_savings="$(printf '%s\n' "$_di_savings" | sed -n '3p')"
  _di_tier1_invocs="$(printf '%s\n' "$_di_savings" | sed -n '4p')"
  _di_tier3_savings="$(printf '%s\n' "$_di_savings" | sed -n '5p')"
  _di_tier3_invocs="$(printf '%s\n' "$_di_savings" | sed -n '6p')"
  [ -n "$_di_filter_dropped" ] || _di_filter_dropped=0
  [ -n "$_di_tier1_savings" ] || _di_tier1_savings=0
  [ -n "$_di_tier2_savings" ] || _di_tier2_savings=0
  [ -n "$_di_tier1_invocs" ] || _di_tier1_invocs=0
  [ -n "$_di_tier3_savings" ] || _di_tier3_savings=0
  [ -n "$_di_tier3_invocs" ] || _di_tier3_invocs=0

  mkdir -p "$log_dir" 2>/dev/null || {
    printf 'dispatch-interface.sh: dispatch_usage emit skipped (mkdir failed on %s)\n' "$log_dir" >&2
    return 0
  }

  # JSON-escape backslashes + double quotes in the warning string (belt-and-
  # suspenders; pricing-lib reasons are ascii-safe by construction).
  escaped_warning="$(printf '%s' "$warning" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  # --- M030/P02/T02: shadow-mode classifier + routing-table fields ---
  # Gated by BOTH env vars: M030_SHADOW_MODE=1 (operator flag) AND
  # CLAUDECODE=1 (CC-only launch posture per CON-3 + spec edge case
  # "Runtime that does not support model selection"). Codex CLI / Cursor
  # fall through to the pre-P02 emit (no new fields).
  # Indirection target for resolution: templates/model-routing.yml (CON-3).
  local shadow_routed shadow_used shadow_partial shadow_withheld shadow_confidence
  local _di_classifier_out _di_shadow_character
  shadow_routed=""
  shadow_used=""
  shadow_partial=""
  shadow_withheld=""
  shadow_confidence=""
  # M030/P03/T02: override-resolution locals.
  local shadow_override_source override_kill override_min_tier override_plan
  local _di_config_yml _plan_rank _floor_rank
  shadow_override_source=""
  override_kill=""
  override_min_tier=""
  override_plan=""
  _di_config_yml=""
  _plan_rank=""
  _floor_rank=""
  if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then
    # 1. Classify the task plan (P01/T02 deliverable; FR-1 + FR-2).
    _di_classifier_out="$(bash "$_DI_PROJECT_ROOT/scripts/dispatch/classify-task.sh" "$TASK_PLAN" 2>/dev/null)"
    _di_shadow_character="$(printf '%s\n' "$_di_classifier_out" | grep -E '^character=' | head -n 1 | sed 's/^character=//')"
    # 1b. M030/P02/T03: capture classifier confidence enum {high, medium, low}
    #     for downstream rolling-variance stability check in shadow-compare.sh.
    shadow_confidence="$(printf '%s\n' "$_di_classifier_out" | grep -E '^confidence=' | head -n 1 | sed 's/^confidence=//')"

    # --- M030/P03/T02: override-resolution path (CON-4 / D-A5 / FR-11..14) ---
    # Precedence chain:
    #   1. KILL SWITCH (config: model_routing_enabled: false) -> disabled
    #      If min_tier is also active: emit one-line stderr warning naming the
    #      bypassed value (CON-4 / D-A5 compound case).
    #   2. PLAN FRONTMATTER (plan: model_override: <tier>) -> plan_frontmatter
    #      If milestone min_tier raises above plan tier: bump to milestone_floor
    #      (FR-14 conflict case; emit stderr warning naming both knobs).
    #   3. MILESTONE FLOOR (config: model_routing.min_tier: <tier>) -> milestone_floor
    #   4. PLAIN ROUTED -> none (the existing routing-table awk extraction
    #      below produces the routed tier; override_source=none).

    # Resolve per-project config path. Three candidate locations:
    #   a) $ORCH_ROOT/config.yml -- canonical when ORCH_ROOT IS .orchestrator/.
    #   b) $ORCH_ROOT/.orchestrator/config.yml -- when ORCH_ROOT is the
    #      project root or a fixture-staged dir holding a .orchestrator/ subdir.
    #   c) $ORCH_ROOT/../config.yml -- less-canonical fallback.
    if [ -f "$ORCH_ROOT/config.yml" ]; then
      _di_config_yml="$ORCH_ROOT/config.yml"
    elif [ -f "$ORCH_ROOT/.orchestrator/config.yml" ]; then
      _di_config_yml="$ORCH_ROOT/.orchestrator/config.yml"
    elif [ -f "$ORCH_ROOT/../config.yml" ]; then
      _di_config_yml="$ORCH_ROOT/../config.yml"
    fi

    # Read kill switch (top-level `model_routing_enabled:` boolean).
    if [ -n "$_di_config_yml" ] && [ -f "$_di_config_yml" ]; then
      override_kill="$(grep -E '^model_routing_enabled:' "$_di_config_yml" 2>/dev/null | head -n 1 | sed -E 's/^model_routing_enabled:[[:space:]]*"?([^"#]*)"?.*/\1/' | tr -d '[:space:]')"
    fi

    # Read plan-frontmatter override (top-level `model_override:` in plan YAML).
    if [ -n "${TASK_PLAN:-}" ] && [ -f "$TASK_PLAN" ]; then
      override_plan="$(grep -E '^model_override:' "$TASK_PLAN" 2>/dev/null | head -n 1 | sed -E 's/^model_override:[[:space:]]*"?([^"#]*)"?.*/\1/' | tr -d '[:space:]')"
    fi

    # Read milestone floor (nested `min_tier:` under `model_routing:` block).
    # Awk section-walker scoped to model_routing: block; same pattern as P02.
    if [ -n "$_di_config_yml" ] && [ -f "$_di_config_yml" ]; then
      override_min_tier="$(awk '
        BEGIN { in_block = 0 }
        /^model_routing:/                 { in_block = 1; next }
        in_block && /^[a-zA-Z_]/          { exit }
        in_block && /^[[:space:]]+min_tier:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_di_config_yml")"
    fi

    # Apply precedence. Kill switch first (D-A5).
    if [ "$override_kill" = "false" ]; then
      shadow_override_source="disabled"
      # Compound case (CON-4): emit one-line stderr warning naming the
      # bypassed min_tier value. Operator hears the conflict mid-run.
      if [ -n "$override_min_tier" ]; then
        printf 'model_routing_enabled=false: min_tier: %s is inactive\n' "$override_min_tier" >&2
      fi
    elif [ -n "$override_plan" ]; then
      shadow_override_source="plan_frontmatter"
      shadow_routed="$override_plan"
      # Floor-wins-conflict (FR-14): if min_tier raises strictly above plan
      # tier, bump to milestone_floor and emit stderr warning naming both.
      if [ -n "$override_min_tier" ]; then
        _plan_rank="$(_di_tier_rank "$override_plan")"
        _floor_rank="$(_di_tier_rank "$override_min_tier")"
        if [ "$_plan_rank" -ge 0 ] && [ "$_floor_rank" -ge 0 ] && [ "$_floor_rank" -gt "$_plan_rank" ]; then
          shadow_override_source="milestone_floor"
          shadow_routed="$override_min_tier"
          printf 'model_override=%s overridden by min_tier=%s (floor wins)\n' "$override_plan" "$override_min_tier" >&2
        fi
      fi
    elif [ -n "$override_min_tier" ]; then
      shadow_override_source="milestone_floor"
      shadow_routed="$override_min_tier"
    else
      shadow_override_source="none"
    fi

    # 2. Resolve symbolic tier via templates/model-routing.yml routing: block.
    #    Awk section-walker (P01 pattern; no jq dependency).
    #    Skipped under disabled (kill switch) or when shadow_routed is already
    #    set by plan-frontmatter / milestone-floor override.
    if [ "$shadow_override_source" = "none" ]; then
      shadow_routed="$(awk -v ch="$_di_shadow_character" '
        BEGIN { in_routing = 0; in_class = 0 }
        /^routing:/                       { in_routing = 1; next }
        /^resolution:/                    { exit }
        in_routing && /^  [a-z_]+:$/      { in_class = ($1 == (ch ":")) ? 1 : 0; next }
        in_routing && in_class && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
      # 3. Resolve symbolic tier -> runtime model ID via resolution: block.
      shadow_used="$(awk -v tier="$shadow_routed" '
        BEGIN { in_resolution = 0; in_tier = 0 }
        /^resolution:/                    { in_resolution = 1; next }
        /^cost_rates:/                    { exit }
        in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
        in_resolution && in_tier && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
    elif [ "$shadow_override_source" = "plan_frontmatter" ] || [ "$shadow_override_source" = "milestone_floor" ]; then
      # shadow_routed is already set by override block. Resolve shadow_used
      # from the resolution: block scoped to that tier.
      shadow_used="$(awk -v tier="$shadow_routed" '
        BEGIN { in_resolution = 0; in_tier = 0 }
        /^resolution:/                    { in_resolution = 1; next }
        /^cost_rates:/                    { exit }
        in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
        in_resolution && in_tier && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
    fi
    if [ "$shadow_override_source" = "disabled" ]; then
      # Kill switch: routing skipped; runtime-default channel used directly.
      shadow_routed=""
      shadow_used="$model"
    fi
    # 4. P03/P04 placeholders — emitted as no-op-empty in P02.
    shadow_partial="false"
    shadow_withheld=""
  fi

  if [ -n "$cost_usd" ] && [ -z "$warning" ]; then
    # Happy path — numeric cost, no warning field.
    # M018/P00/T01: emission_point="dispatch-interface" disambiguates from
    # build-context co-located emissions (CON-5 additive field).
    if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then
      # Shadow-on emit: pre-M030 fields + 4 P02 additive fields + P03 override_source.
      printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":%s,"pricing_version":"%s","filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier2_savings_tokens":%d,"tier1_invocations":%d,"tier3_compression_savings_tokens":%d,"tier3_invocations":%d,"model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s","classifier_confidence":"%s","model_routed":"%s","model_used":"%s","partial_flip_active":%s,"withheld_classes":"%s","override_source":"%s"}\n' \
        "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
        "$input_tokens" "$output_tokens" "$cost_usd" \
        "$pricing_version" \
        "$_di_filter_dropped" "$_di_tier1_savings" "$_di_tier2_savings" "$_di_tier1_invocs" \
        "$_di_tier3_savings" "$_di_tier3_invocs" \
        "$model" "$ts" \
        "$shadow_confidence" "$shadow_routed" "$shadow_used" "$shadow_partial" "$shadow_withheld" \
        "$shadow_override_source" \
        >> "$log_file" 2>/dev/null || {
        printf 'dispatch-interface.sh: dispatch_usage append failed on %s\n' "$log_file" >&2
        return 0
      }
    else
      # Shadow-off emit: byte-identical to pre-P02 (preserves SC-11).
      printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":%s,"pricing_version":"%s","filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier2_savings_tokens":%d,"tier1_invocations":%d,"tier3_compression_savings_tokens":%d,"tier3_invocations":%d,"model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s"}\n' \
        "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
        "$input_tokens" "$output_tokens" "$cost_usd" \
        "$pricing_version" \
        "$_di_filter_dropped" "$_di_tier1_savings" "$_di_tier2_savings" "$_di_tier1_invocs" \
        "$_di_tier3_savings" "$_di_tier3_invocs" \
        "$model" "$ts" \
        >> "$log_file" 2>/dev/null || {
        printf 'dispatch-interface.sh: dispatch_usage append failed on %s\n' "$log_file" >&2
        return 0
      }
    fi
  else
    # Degradation path — cost=null JSON literal, pricing_warning present.
    # M018/P00/T01: emission_point="dispatch-interface" disambiguates from
    # build-context co-located emissions (CON-5 additive field).
    if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then
      # Shadow-on degradation emit: pre-M030 fields + 4 P02 additive fields + P03 override_source.
      printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":null,"pricing_version":"%s","filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier2_savings_tokens":%d,"tier1_invocations":%d,"tier3_compression_savings_tokens":%d,"tier3_invocations":%d,"pricing_warning":"%s","model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s","classifier_confidence":"%s","model_routed":"%s","model_used":"%s","partial_flip_active":%s,"withheld_classes":"%s","override_source":"%s"}\n' \
        "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
        "$input_tokens" "$output_tokens" \
        "$pricing_version" \
        "$_di_filter_dropped" "$_di_tier1_savings" "$_di_tier2_savings" "$_di_tier1_invocs" \
        "$_di_tier3_savings" "$_di_tier3_invocs" \
        "$escaped_warning" "$model" "$ts" \
        "$shadow_confidence" "$shadow_routed" "$shadow_used" "$shadow_partial" "$shadow_withheld" \
        "$shadow_override_source" \
        >> "$log_file" 2>/dev/null || {
        printf 'dispatch-interface.sh: dispatch_usage append failed on %s\n' "$log_file" >&2
        return 0
      }
    else
      # Shadow-off degradation emit: byte-identical to pre-P02 (preserves SC-11).
      printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":null,"pricing_version":"%s","filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier2_savings_tokens":%d,"tier1_invocations":%d,"tier3_compression_savings_tokens":%d,"tier3_invocations":%d,"pricing_warning":"%s","model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s"}\n' \
        "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
        "$input_tokens" "$output_tokens" \
        "$pricing_version" \
        "$_di_filter_dropped" "$_di_tier1_savings" "$_di_tier2_savings" "$_di_tier1_invocs" \
        "$_di_tier3_savings" "$_di_tier3_invocs" \
        "$escaped_warning" "$model" "$ts" \
        >> "$log_file" 2>/dev/null || {
        printf 'dispatch-interface.sh: dispatch_usage append failed on %s\n' "$log_file" >&2
        return 0
      }
    fi
  fi
  return 0
}

# --- Validate inputs ---

if [[ -z "$TASK_PLAN" ]] || [[ ! -f "$TASK_PLAN" ]]; then
  emit_error "input_invalid" "false" "developer" "" \
    "--task-plan is required and must point to an existing file" \
    "Received --task-plan='${TASK_PLAN}'" \
    "Provide a valid --task-plan path."
  exit 2
fi
if [[ -z "$PAYLOAD" ]] || [[ ! -f "$PAYLOAD" ]]; then
  emit_error "input_invalid" "false" "developer" "" \
    "--payload is required and must point to an existing file" \
    "Received --payload='${PAYLOAD}'" \
    "Provide a valid --payload path."
  exit 2
fi

# --- M019/P01/T03: Derive unit identifiers from the task plan path ---
# Regex-extract M###/P##/T## from the task plan path. If any component is
# missing, fall back to the basename-without-extension (schema validator
# accepts any UNIT_ID string). ORCH_ROOT follows the standard env override.
MILESTONE_ID="$(printf '%s' "$TASK_PLAN" | grep -oE 'M[0-9]{3}' | head -n 1)"
PHASE_ID="$(printf '%s' "$TASK_PLAN" | grep -oE 'P[0-9]{2}(\.[0-9]+)?' | head -n 1)"
TASK_ID="$(printf '%s' "$TASK_PLAN" | grep -oE 'T[0-9]{2}' | head -n 1)"
if [ -n "$MILESTONE_ID" ] && [ -n "$PHASE_ID" ] && [ -n "$TASK_ID" ]; then
  UNIT_ID="${MILESTONE_ID}/${PHASE_ID}/${TASK_ID}"
else
  UNIT_ID="$(basename "$TASK_PLAN" .md)"
fi
ORCH_ROOT="${ORCHESTRATOR_ROOT:-.orchestrator}"


# --- Resolve backend ---

if [[ -z "$BACKEND" ]]; then
  # Query registry for default
  if [[ ! -x "$REGISTRY" ]]; then
    emit_error "registry_error" "false" "developer" "" \
      "backend-registry.sh is missing or not executable" \
      "Expected at ${REGISTRY}" \
      "Restore the registry script or pass --backend <name> explicitly."
    exit 3
  fi
  registry_output="$(bash "$REGISTRY" 2>/dev/null)"
  BACKEND="$(echo "$registry_output" | grep -E '^default_backend=' | head -n 1 | cut -d= -f2)"
  if [[ -z "$BACKEND" ]]; then
    available="$(echo "$registry_output" | grep -E '^backends_available=' | head -n 1 | cut -d= -f2)"
    emit_error "backend_unavailable" "false" "developer" "" \
      "No dispatch backends reported available" \
      "Registry output: backends_available=${available}" \
      "Install a supported backend (e.g., Claude Code with SPECKIT_AGENT_TOOL=1, or Codex CLI) or register a new adapter in scripts/dispatch/adapters/backend/."
    exit 4
  fi
fi

# --- Resolve adapter path by filename (no backend-specific branching) ---

ADAPTER="${ADAPTERS_DIR}/${BACKEND}.sh"
if [[ ! -f "$ADAPTER" ]]; then
  emit_error "backend_unavailable" "false" "developer" "${BACKEND}" \
    "Requested backend '${BACKEND}' has no adapter script" \
    "Expected adapter at ${ADAPTER}" \
    "Drop an adapter file at the expected path, or pass --backend with a registered name (see 'bash ${REGISTRY} --list')."
  exit 4
fi

# --- Invoke adapter as a subprocess ---

adapter_rc=0
adapter_output="$(bash "$ADAPTER" \
  --task-plan "$TASK_PLAN" \
  --payload "$PAYLOAD" \
  --intensity-metadata "$INTENSITY_METADATA" 2>/dev/null)" || adapter_rc=$?

if [[ $adapter_rc -ne 0 ]]; then
  emit_error "backend_crashed" "true" "developer" "${BACKEND}" \
    "Adapter subprocess exited with code ${adapter_rc}" \
    "Adapter: ${ADAPTER}" \
    "Inspect adapter stderr or re-run with the adapter directly for diagnostics."
  _di_emit_dispatch_usage "adapter-failed" || true
  exit 5
fi

# Minimal conformance check: adapter output must contain schema_version
# and type: "dispatch-result" frontmatter.
if ! echo "$adapter_output" | grep -q '^schema_version:'; then
  emit_error "backend_malformed" "false" "developer" "${BACKEND}" \
    "Adapter output missing schema_version frontmatter" \
    "Adapter: ${ADAPTER}" \
    "Adapter must emit a dispatch-result.md conforming document. See templates/dispatch-result.md."
  _di_emit_dispatch_usage "adapter-malformed" || true
  exit 6
fi
if ! echo "$adapter_output" | grep -q '^type: "dispatch-result"'; then
  emit_error "backend_malformed" "false" "developer" "${BACKEND}" \
    "Adapter output missing type: dispatch-result frontmatter" \
    "Adapter: ${ADAPTER}" \
    "Adapter must emit a dispatch-result.md conforming document. See templates/dispatch-result.md."
  _di_emit_dispatch_usage "adapter-malformed" || true
  exit 6
fi

# --- M019/P01/T03: happy-path dispatch_usage emission ---
_di_emit_dispatch_usage "" || true

# --- Emit adapter output unchanged ---
echo "$adapter_output"
exit 0
