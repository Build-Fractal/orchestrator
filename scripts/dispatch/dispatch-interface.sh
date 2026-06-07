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

# --- M034/P02/T01: --probe-renderer subcommand passthrough (PC-4 / D-P02-1) -
# When the FIRST argument is --probe-renderer, resolve the interactive-review
# renderer state and exit. This is the CON-7 renderer-selection seam:
# interactive-review.sh routes through here, never calling a question
# primitive directly. Emits exactly one line:
#   renderer=interactive-cc | interactive-cursor | headless
# Precedence (PC-4, M034-P01-ADDENDUM.md):
#   ORCH_HEADLESS=1 -> headless (highest, unconditional)
#   else local-agent probe available=true -> interactive-cc
#   else cursor-agent probe available=true -> interactive-cursor (P03 renders)
#   else -> headless
if [ "${1:-}" = "--probe-renderer" ]; then
  if [ "${ORCH_HEADLESS:-0}" = "1" ]; then
    echo "renderer=headless"
    exit 0
  fi
  _pr_registry="$SCRIPT_DIR/backend-registry.sh"
  _pr_cc="$(bash "$_pr_registry" --probe local-agent 2>/dev/null | grep -E '^available=' | head -n 1 | cut -d= -f2)"
  if [ "$_pr_cc" = "true" ]; then
    echo "renderer=interactive-cc"
    exit 0
  fi
  _pr_cursor="$(bash "$_pr_registry" --probe cursor-agent 2>/dev/null | grep -E '^available=' | head -n 1 | cut -d= -f2)"
  if [ "$_pr_cursor" = "true" ]; then
    echo "renderer=interactive-cursor"
    exit 0
  fi
  echo "renderer=headless"
  exit 0
fi
# ---------------------------------------------------------------------------

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

# --- M030/P04/T03: inverse tier-rank for escalation progression ---
# Maps numeric rank to symbolic tier name (fast=0, balanced=1, smart=2).
# Returns "" for unknown rank. Used by the escalation loop to compute the
# next-higher tier on verifier failure. CON-3-clean (symbolic only; no
# concrete provider model IDs).
_di_tier_at_rank() {
  case "$1" in
    0) echo fast ;;
    1) echo balanced ;;
    2) echo smart ;;
    *) echo "" ;;
  esac
}

# --- M030/P04/T02: live-routing resolution helper ---
# Centralizes the override-resolution + live-routing + flip-gate logic so
# the dispatcher can run it BEFORE adapter invocation (gate-block needs to
# fire before the adapter is called). Idempotent via _DI_RESOLVED sentinel.
# Outputs (top-level, not local — read by both dispatcher + emitter):
#   _DI_SHADOW_CONFIDENCE        classifier confidence (high|medium|low|"")
#   _DI_SHADOW_ROUTED            symbolic tier (fast|balanced|smart|"")
#   _DI_SHADOW_USED              concrete model id used (live: routing-table
#                                resolution; shadow-only: $model fallback)
#   _DI_SHADOW_PARTIAL           "true"|"false" partial-flip-active flag
#   _DI_SHADOW_WITHHELD          comma-separated withheld classes (or "")
#   _DI_SHADOW_OVERRIDE_SOURCE   none|disabled|plan_frontmatter|
#                                milestone_floor|shadow_gate_blocked|""
#   _DI_LIVE_MODEL_FLAG          model id to pass via --model (or "" / unset
#                                when not live-routed)
#   _DI_LIVE_GATE_BLOCKED        1 when live verdict is evidence_insufficient
#                                or block; 0 otherwise
#
# Shadow gate (CC-only launch posture): runs ONLY when both M030_SHADOW_MODE=1
# AND CLAUDECODE=1. Otherwise leaves all _DI_SHADOW_* / _DI_LIVE_* empty.
# CON-3: every concrete model id flows through templates/model-routing.yml's
# resolution: block via awk; no hardcoded model literals.
# CON-4 / D-A5: kill switch evaluated FIRST; live: true is inactive when
# kill switch fires (one-line stderr warning emitted in that case).
# D-A2: live: true verdict is gated programmatically via shadow-compare.sh.
# D-A3: per-class authorization on partially_ready — only flippable classes
# route live; withheld classes fall back to runtime default.
# MEM004 carve-out: pipes / $() / awk permitted in body.
_di_resolve_live_routing() {
  if [ "${_DI_RESOLVED:-0}" = "1" ]; then
    return 0
  fi
  _DI_RESOLVED=1

  _DI_SHADOW_CONFIDENCE=""
  _DI_SHADOW_CHARACTER=""
  _DI_SHADOW_ROUTED=""
  _DI_SHADOW_USED=""
  _DI_SHADOW_PARTIAL=""
  _DI_SHADOW_WITHHELD=""
  _DI_SHADOW_OVERRIDE_SOURCE=""
  _DI_LIVE_MODEL_FLAG=""
  _DI_LIVE_GATE_BLOCKED=0

  # CC-only short-circuit. Codex CLI / Cursor leave outputs empty so the
  # emitter's shadow-on branch does not fire.
  if [ "${M030_SHADOW_MODE:-0}" != "1" ] || [ "${CLAUDECODE:-0}" != "1" ]; then
    return 0
  fi

  # Resolve per-project config path. Three candidate locations (P03 chain).
  local _di_config_yml=""
  if [ -f "${ORCH_ROOT:-}/config.yml" ]; then
    _di_config_yml="$ORCH_ROOT/config.yml"
  elif [ -f "${ORCH_ROOT:-}/.orchestrator/config.yml" ]; then
    _di_config_yml="$ORCH_ROOT/.orchestrator/config.yml"
  elif [ -f "${ORCH_ROOT:-}/../config.yml" ]; then
    _di_config_yml="$ORCH_ROOT/../config.yml"
  fi

  # 1. Classify task plan.
  local _di_classifier_out _di_shadow_character
  _di_classifier_out="$(bash "$_DI_PROJECT_ROOT/scripts/dispatch/classify-task.sh" "$TASK_PLAN" 2>/dev/null)"
  _di_shadow_character="$(printf '%s\n' "$_di_classifier_out" | grep -E '^character=' | head -n 1 | sed 's/^character=//')"
  _DI_SHADOW_CHARACTER="$_di_shadow_character"
  _DI_SHADOW_CONFIDENCE="$(printf '%s\n' "$_di_classifier_out" | grep -E '^confidence=' | head -n 1 | sed 's/^confidence=//')"

  # Resolve $model the same way the emitter does (runtime-default channel).
  local _di_model="${ORCH_MODEL:-}"
  if [ -z "$_di_model" ] && [ -n "${INTENSITY_METADATA:-}" ] && [ -f "$INTENSITY_METADATA" ]; then
    _di_model="$(grep -E '^model:' "$INTENSITY_METADATA" | head -n 1 | sed -E 's/^model:[[:space:]]*"?([^"]*)"?.*/\1/')"
  fi

  # 2. Read override knobs.
  local override_kill="" override_min_tier="" override_plan="" override_live=""
  if [ -n "$_di_config_yml" ] && [ -f "$_di_config_yml" ]; then
    override_kill="$(grep -E '^model_routing_enabled:' "$_di_config_yml" 2>/dev/null | head -n 1 | sed -E 's/^model_routing_enabled:[[:space:]]*"?([^"#]*)"?.*/\1/' | tr -d '[:space:]')"
  fi
  if [ -n "${TASK_PLAN:-}" ] && [ -f "$TASK_PLAN" ]; then
    override_plan="$(grep -E '^model_override:' "$TASK_PLAN" 2>/dev/null | head -n 1 | sed -E 's/^model_override:[[:space:]]*"?([^"#]*)"?.*/\1/' | tr -d '[:space:]')"
  fi
  if [ -n "$_di_config_yml" ] && [ -f "$_di_config_yml" ]; then
    override_min_tier="$(awk '
      BEGIN { in_block = 0 }
      /^model_routing:/                 { in_block = 1; next }
      in_block && /^[a-zA-Z_]/          { exit }
      in_block && /^[[:space:]]+min_tier:/ {
        val = $2; gsub(/[",]/, "", val); print val; exit
      }
    ' "$_di_config_yml")"
    override_live="$(awk '
      BEGIN { in_block = 0 }
      /^model_routing:/                 { in_block = 1; next }
      in_block && /^[a-zA-Z_]/          { exit }
      in_block && /^[[:space:]]+live:/  {
        val = $2; gsub(/[",]/, "", val); print val; exit
      }
    ' "$_di_config_yml")"
  fi

  # 3. Apply precedence (kill switch first).
  local _plan_rank _floor_rank
  if [ "$override_kill" = "false" ]; then
    _DI_SHADOW_OVERRIDE_SOURCE="disabled"
    if [ -n "$override_min_tier" ]; then
      printf 'model_routing_enabled=false: min_tier: %s is inactive\n' "$override_min_tier" >&2
    fi
    if [ "$override_live" = "true" ]; then
      printf 'model_routing_enabled=false: live: true is inactive\n' >&2
    fi
  elif [ -n "$override_plan" ]; then
    _DI_SHADOW_OVERRIDE_SOURCE="plan_frontmatter"
    _DI_SHADOW_ROUTED="$override_plan"
    if [ -n "$override_min_tier" ]; then
      _plan_rank="$(_di_tier_rank "$override_plan")"
      _floor_rank="$(_di_tier_rank "$override_min_tier")"
      if [ "$_plan_rank" -ge 0 ] && [ "$_floor_rank" -ge 0 ] && [ "$_floor_rank" -gt "$_plan_rank" ]; then
        _DI_SHADOW_OVERRIDE_SOURCE="milestone_floor"
        _DI_SHADOW_ROUTED="$override_min_tier"
        printf 'model_override=%s overridden by min_tier=%s (floor wins)\n' "$override_plan" "$override_min_tier" >&2
      fi
    fi
  elif [ -n "$override_min_tier" ]; then
    _DI_SHADOW_OVERRIDE_SOURCE="milestone_floor"
    _DI_SHADOW_ROUTED="$override_min_tier"
  else
    _DI_SHADOW_OVERRIDE_SOURCE="none"
  fi

  # 4. M030/P04/T02: live-routing branch (FR-9 / D-A2 / D-A3). Runs only
  #    when no override fired AND live: true. Verdict from shadow-compare.sh
  #    gates the adapter call.
  if [ "$_DI_SHADOW_OVERRIDE_SOURCE" = "none" ] && [ "$override_live" = "true" ]; then
    local _di_compare_corpus _di_compare_tmp _di_verdict _di_withheld_line
    _di_compare_corpus="${M030_SHADOW_COMPARE_CORPUS:-}"
    if [ -z "$_di_compare_corpus" ]; then
      # Default: in-flight log file derived the same way the emitter derives it.
      if [ -d "$ORCH_ROOT/phases" ]; then
        _di_compare_corpus="$ORCH_ROOT/execution-log.jsonl"
      elif [ -n "${MILESTONE_ID:-}" ]; then
        _di_compare_corpus="$ORCH_ROOT/milestones/$MILESTONE_ID/execution-log.jsonl"
      fi
    fi
    _di_compare_tmp="$(mktemp 2>/dev/null || printf '/tmp/p04_compare_%d' "$$")"
    if [ -n "$_di_compare_corpus" ] && [ -f "$_di_compare_corpus" ]; then
      bash "$_DI_PROJECT_ROOT/scripts/diagnostics/shadow-compare.sh" --corpus "$_di_compare_corpus" > "$_di_compare_tmp" 2>/dev/null || true
    else
      # Missing corpus path: synthesize evidence_insufficient verdict.
      printf 'flip_recommendation=evidence_insufficient\n' > "$_di_compare_tmp"
    fi
    _di_verdict="$(grep -E '^flip_recommendation=' "$_di_compare_tmp" | head -n 1 | sed -E 's/^flip_recommendation=([^[:space:]]+).*/\1/')"
    _di_withheld_line="$(grep -E '^withheld_classes=' "$_di_compare_tmp" | head -n 1 | sed -E 's/^withheld_classes=//')"
    rm -f "$_di_compare_tmp" 2>/dev/null

    if [ "$_di_verdict" = "evidence_insufficient" ] || [ "$_di_verdict" = "block" ]; then
      _DI_SHADOW_OVERRIDE_SOURCE="shadow_gate_blocked"
      _DI_SHADOW_ROUTED=""
      _DI_SHADOW_USED="$_di_model"
      _DI_SHADOW_PARTIAL="false"
      _DI_SHADOW_WITHHELD=""
      _DI_LIVE_GATE_BLOCKED=1
    elif [ "$_di_verdict" = "ready" ]; then
      _DI_SHADOW_ROUTED="$(awk -v ch="$_di_shadow_character" '
        BEGIN { in_routing = 0; in_class = 0 }
        /^routing:/                       { in_routing = 1; next }
        /^resolution:/                    { exit }
        in_routing && /^  [a-z_]+:$/      { in_class = ($1 == (ch ":")) ? 1 : 0; next }
        in_routing && in_class && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
      _DI_SHADOW_USED="$(awk -v tier="$_DI_SHADOW_ROUTED" '
        BEGIN { in_resolution = 0; in_tier = 0 }
        /^resolution:/                    { in_resolution = 1; next }
        /^cost_rates:/                    { exit }
        in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
        in_resolution && in_tier && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
      _DI_SHADOW_PARTIAL="false"
      _DI_SHADOW_WITHHELD=""
      _DI_LIVE_MODEL_FLAG="$_DI_SHADOW_USED"
    elif [ "$_di_verdict" = "partially_ready" ]; then
      _DI_SHADOW_PARTIAL="true"
      _DI_SHADOW_WITHHELD="$_di_withheld_line"
      # Per-class authorization (D-A3): if task class is in withheld_classes,
      # fall back to runtime default. Otherwise route live.
      local _di_is_withheld _di_w _di_w_first
      _di_is_withheld=0
      _di_w="$_di_withheld_line"
      while [ -n "$_di_w" ]; do
        _di_w_first="${_di_w%%,*}"
        if [ "$_di_w_first" = "$_di_shadow_character" ]; then
          _di_is_withheld=1
          break
        fi
        case "$_di_w" in
          *,*) _di_w="${_di_w#*,}" ;;
          *) _di_w="" ;;
        esac
      done
      if [ "$_di_is_withheld" -eq 1 ]; then
        _DI_SHADOW_ROUTED=""
        _DI_SHADOW_USED="$_di_model"
        # _DI_LIVE_MODEL_FLAG stays empty -- adapter receives no --model flag.
      else
        _DI_SHADOW_ROUTED="$(awk -v ch="$_di_shadow_character" '
          BEGIN { in_routing = 0; in_class = 0 }
          /^routing:/                       { in_routing = 1; next }
          /^resolution:/                    { exit }
          in_routing && /^  [a-z_]+:$/      { in_class = ($1 == (ch ":")) ? 1 : 0; next }
          in_routing && in_class && /^    claude-code:/ {
            val = $2; gsub(/[",]/, "", val); print val; exit
          }
        ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
        _DI_SHADOW_USED="$(awk -v tier="$_DI_SHADOW_ROUTED" '
          BEGIN { in_resolution = 0; in_tier = 0 }
          /^resolution:/                    { in_resolution = 1; next }
          /^cost_rates:/                    { exit }
          in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
          in_resolution && in_tier && /^    claude-code:/ {
            val = $2; gsub(/[",]/, "", val); print val; exit
          }
        ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
        _DI_LIVE_MODEL_FLAG="$_DI_SHADOW_USED"
      fi
    fi
  fi

  # 5. Resolve symbolic tier -> concrete model id for non-live cases when
  #    routed is set (kill-switch / plan / floor / none paths). Live-on
  #    branches above already populated _DI_SHADOW_USED.
  if [ -z "$_DI_SHADOW_USED" ]; then
    if [ "$_DI_SHADOW_OVERRIDE_SOURCE" = "disabled" ]; then
      _DI_SHADOW_ROUTED=""
      _DI_SHADOW_USED="$_di_model"
    elif [ "$_DI_SHADOW_OVERRIDE_SOURCE" = "none" ] && [ -z "$_DI_SHADOW_ROUTED" ]; then
      _DI_SHADOW_ROUTED="$(awk -v ch="$_di_shadow_character" '
        BEGIN { in_routing = 0; in_class = 0 }
        /^routing:/                       { in_routing = 1; next }
        /^resolution:/                    { exit }
        in_routing && /^  [a-z_]+:$/      { in_class = ($1 == (ch ":")) ? 1 : 0; next }
        in_routing && in_class && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
      _DI_SHADOW_USED="$(awk -v tier="$_DI_SHADOW_ROUTED" '
        BEGIN { in_resolution = 0; in_tier = 0 }
        /^resolution:/                    { in_resolution = 1; next }
        /^cost_rates:/                    { exit }
        in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
        in_resolution && in_tier && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
    elif [ -n "$_DI_SHADOW_ROUTED" ]; then
      _DI_SHADOW_USED="$(awk -v tier="$_DI_SHADOW_ROUTED" '
        BEGIN { in_resolution = 0; in_tier = 0 }
        /^resolution:/                    { in_resolution = 1; next }
        /^cost_rates:/                    { exit }
        in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
        in_resolution && in_tier && /^    claude-code:/ {
          val = $2; gsub(/[",]/, "", val); print val; exit
        }
      ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
    fi
  fi

  # 6. P03/P04 placeholders default to false/empty when unset.
  if [ -z "$_DI_SHADOW_PARTIAL" ]; then
    _DI_SHADOW_PARTIAL="false"
  fi
  return 0
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

  # --- M030/P02-P04: shadow-mode classifier + routing-table fields ---
  # All resolution work is delegated to _di_resolve_live_routing (top-level
  # helper added in M030/P04/T02). The helper is idempotent — calling it
  # here is a no-op when the dispatcher already invoked it before adapter
  # invocation (live-routing flip-gate path). It writes its outputs into
  # top-level _DI_SHADOW_* / _DI_LIVE_* variables; this emitter copies the
  # shadow_* values into local variables so the shadow-on printf branches
  # below preserve their existing format-string substitutions verbatim.
  #
  # Gating still happens inside the helper (M030_SHADOW_MODE=1 AND
  # CLAUDECODE=1 — CC-only launch posture). When shadow is off, the helper
  # leaves _DI_SHADOW_* empty; the shadow-off printf branch is unaffected.
  local shadow_routed shadow_used shadow_partial shadow_withheld shadow_confidence
  local shadow_override_source shadow_character
  shadow_routed=""
  shadow_used=""
  shadow_partial=""
  shadow_withheld=""
  shadow_confidence=""
  shadow_override_source=""
  shadow_character=""
  if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then
    _di_resolve_live_routing
    shadow_confidence="${_DI_SHADOW_CONFIDENCE:-}"
    shadow_routed="${_DI_SHADOW_ROUTED:-}"
    shadow_used="${_DI_SHADOW_USED:-}"
    shadow_partial="${_DI_SHADOW_PARTIAL:-false}"
    shadow_withheld="${_DI_SHADOW_WITHHELD:-}"
    shadow_override_source="${_DI_SHADOW_OVERRIDE_SOURCE:-}"
    shadow_character="${_DI_SHADOW_CHARACTER:-unknown}"
    if [ -z "$shadow_character" ]; then
      shadow_character="unknown"
    fi
    # Disabled path: runtime-default channel — emitter's $model is the
    # authoritative source after pricing-lib resolution at line ~227.
    if [ "$shadow_override_source" = "disabled" ]; then
      shadow_used="$model"
    fi
  fi

  if [ -n "$cost_usd" ] && [ -z "$warning" ]; then
    # Happy path — numeric cost, no warning field.
    # M018/P00/T01: emission_point="dispatch-interface" disambiguates from
    # build-context co-located emissions (CON-5 additive field).
    if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ]; then
      # Shadow-on emit: pre-M030 fields + 4 P02 additive fields + P03 override_source
      # + P04/T03 escalation_count + escalation_reason (read from shell-scoped
      # parent variables; defaults applied if unset).
      printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":%s,"pricing_version":"%s","filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier2_savings_tokens":%d,"tier1_invocations":%d,"tier3_compression_savings_tokens":%d,"tier3_invocations":%d,"model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s","classifier_confidence":"%s","model_routed":"%s","model_used":"%s","partial_flip_active":%s,"withheld_classes":"%s","override_source":"%s","escalation_count":%d,"escalation_reason":"%s","character":"%s"}\n' \
        "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
        "$input_tokens" "$output_tokens" "$cost_usd" \
        "$pricing_version" \
        "$_di_filter_dropped" "$_di_tier1_savings" "$_di_tier2_savings" "$_di_tier1_invocs" \
        "$_di_tier3_savings" "$_di_tier3_invocs" \
        "$model" "$ts" \
        "$shadow_confidence" "$shadow_routed" "$shadow_used" "$shadow_partial" "$shadow_withheld" \
        "$shadow_override_source" \
        "${escalation_count:-0}" "${escalation_reason:-}" \
        "$shadow_character" \
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
      # Shadow-on degradation emit: pre-M030 fields + 4 P02 additive fields + P03 override_source
      # + P04/T03 escalation_count + escalation_reason.
      printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":null,"pricing_version":"%s","filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier2_savings_tokens":%d,"tier1_invocations":%d,"tier3_compression_savings_tokens":%d,"tier3_invocations":%d,"pricing_warning":"%s","model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s","classifier_confidence":"%s","model_routed":"%s","model_used":"%s","partial_flip_active":%s,"withheld_classes":"%s","override_source":"%s","escalation_count":%d,"escalation_reason":"%s","character":"%s"}\n' \
        "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
        "$input_tokens" "$output_tokens" \
        "$pricing_version" \
        "$_di_filter_dropped" "$_di_tier1_savings" "$_di_tier2_savings" "$_di_tier1_invocs" \
        "$_di_tier3_savings" "$_di_tier3_invocs" \
        "$escaped_warning" "$model" "$ts" \
        "$shadow_confidence" "$shadow_routed" "$shadow_used" "$shadow_partial" "$shadow_withheld" \
        "$shadow_override_source" \
        "${escalation_count:-0}" "${escalation_reason:-}" \
        "$shadow_character" \
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

# --- M030/P04/T03: escalation_cap_hit emission helper ---
# Writes a single escalation_cap_hit JSONL record after the live-mode
# escalation loop hits the CON-5 hard-cap (3 attempts all failing). Same
# log-file resolution logic as _di_emit_dispatch_usage; bail-safe; the
# caller guarantees at most one invocation per dispatch (one cap event).
# Append-only via `>>` (CON-6); no `mv`/`cp`/swap. Gated CC-only the same
# way the rest of the M030 shadow path is gated.
# MEM004 carve-out: pipes / $() permitted in dispatch-internal helpers.
_di_emit_escalation_cap_hit() {
  if [ "${M030_SHADOW_MODE:-0}" != "1" ] || [ "${CLAUDECODE:-0}" != "1" ]; then
    return 0
  fi
  local cap_log_dir cap_log_file cap_ts
  if [ -d "$ORCH_ROOT/phases" ]; then
    cap_log_dir="$ORCH_ROOT"
  elif [ -n "${MILESTONE_ID:-}" ]; then
    cap_log_dir="$ORCH_ROOT/milestones/$MILESTONE_ID"
  else
    return 0
  fi
  cap_log_file="$cap_log_dir/execution-log.jsonl"
  cap_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$cap_log_dir" 2>/dev/null || return 0
  printf '{"record_type":"escalation_cap_hit","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","final_count":2,"timestamp":"%s"}\n' \
    "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$cap_ts" \
    >> "$cap_log_file" 2>/dev/null || true
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

# --- M030/P04/T03: shell-scoped escalation state ---
# Declared here so _di_emit_dispatch_usage (line ~607 / ~640 shadow-on
# printfs) can read them via parent-shell scope without a signature
# change. Both default to "no escalation" semantics — escalation_count=0
# (initial dispatch) + escalation_reason="" (no verifier failure on this
# attempt). The escalation loop (below) updates these locals as it
# iterates; the gate-block path + non-live single-shot path leave them
# at the defaults so the emitted record carries `"escalation_count":0,
# "escalation_reason":""` (which is the correct shape for those paths).
escalation_count=0
escalation_reason=""

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

# --- M030/P04/T02: live-routing flip-gate (D-A2) ---
# Resolve override + live-routing state BEFORE invoking the adapter so the
# evidence_insufficient/block verdict can short-circuit the adapter call.
# Idempotent: the emitter will call the same helper later (no-op when
# already resolved). Helper is silent under shadow-off / non-CC runtimes.
_di_resolve_live_routing

# Shadow-gate-block branch (FR-9 / SC-2a). When live: true AND the corpus
# verdict is evidence_insufficient or block, the dispatcher MUST refuse the
# adapter call, emit a dispatch-error doc, append the dispatch_usage record
# (so the gate-block is observable in JSONL), and exit nonzero. Exit code 7
# disambiguates from adapter-failed=5 / adapter-malformed=6.
if [ "${_DI_LIVE_GATE_BLOCKED:-0}" = "1" ]; then
  emit_error "shadow_gate_blocked" "true" "operator" "${BACKEND}" \
    "Live routing requested but shadow corpus did not pass flip-readiness check" \
    "Shadow-compare verdict: evidence_insufficient or block" \
    "Either populate the shadow corpus to >=50 records per class with stable confidence, set model_routing.live: false, or set model_routing_enabled: false to bypass routing entirely."
  _di_emit_dispatch_usage "" || true
  exit 7
fi

# --- Invoke adapter as a subprocess ---
# M030/P04/T02: when live-routing resolved a concrete model id, pass it
# through to the adapter via --model. Two explicit invocation paths (rather
# than dynamic flag splicing) preserve word-splitting safety per AD-19.
#
# M030/P04/T03: live-mode escalation loop wraps the invocation. Active only
# when M030_SHADOW_MODE=1 AND CLAUDECODE=1 AND _DI_LIVE_MODEL_FLAG non-empty
# (i.e. live-routing flip-gate cleared AND task class is flippable).
# Otherwise the original single-shot invocation runs. The loop walks
# fast → balanced → smart on rc != 0, capped at 2 escalations (CON-5).
# On cap-hit: emits a final dispatch_usage record + ONE escalation_cap_hit
# record + dispatch-error.md, exits 5. Prior records remain bit-identical
# (CON-6) — every emit is `>>` append-only via the helpers.

adapter_rc=0
adapter_output=""
escalation_active=0
if [ "${M030_SHADOW_MODE:-0}" = "1" ] && [ "${CLAUDECODE:-0}" = "1" ] && [ -n "${_DI_LIVE_MODEL_FLAG:-}" ]; then
  escalation_active=1
fi

if [ "$escalation_active" -eq 1 ]; then
  # Live-mode escalation loop. Up to 3 attempts (initial + 2 escalations).
  # MEM004 carve-out: this is dispatch-internal logic; pipes / $() / awk
  # are permitted in the body. AD-19 governs verifier-invocation shape,
  # not internal dispatch logic.
  while : ; do
    adapter_rc=0
    adapter_output="$(bash "$ADAPTER" \
      --task-plan "$TASK_PLAN" \
      --payload "$PAYLOAD" \
      --intensity-metadata "$INTENSITY_METADATA" \
      --model "$_DI_LIVE_MODEL_FLAG" 2>/dev/null)" || adapter_rc=$?

    if [ "$adapter_rc" -eq 0 ]; then
      # Success on this attempt. escalation_count reflects the number of
      # preceding failures (0 if this is the initial dispatch, N>0 if
      # escalated N times). escalation_reason is empty on success — the
      # successful attempt itself is not a verifier failure.
      escalation_reason=""
      _di_emit_dispatch_usage "" || true
      break
    fi

    # Failure on this attempt.
    if [ "$escalation_count" -ge 2 ]; then
      # CON-5 cap hit: 3 attempts all failed. Emit the final failed
      # dispatch_usage record (escalation_count=2, reason=verifier_fail),
      # emit ONE escalation_cap_hit record, emit dispatch-error.md, exit 5.
      # NO fourth adapter invocation — the loop terminates here.
      escalation_reason="verifier_fail"
      _di_emit_dispatch_usage "adapter-failed" || true
      _di_emit_escalation_cap_hit
      emit_error "backend_crashed" "false" "developer" "${BACKEND}" \
        "Adapter failed after escalation cap of 2 escalations" \
        "Adapter: ${ADAPTER}; final tier: ${_DI_SHADOW_ROUTED:-}" \
        "Inspect adapter stderr; consider lowering min_tier or disabling routing for this task."
      exit 5
    fi

    # Mid-loop failure (escalation_count < 2). Emit the current-iteration
    # dispatch_usage record FIRST (with current escalation_count value),
    # THEN increment and recompute next tier. This ordering matters: the
    # success record on iteration N reads escalation_count=N (number of
    # preceding failures), so the increment must follow the emit.
    escalation_reason="verifier_fail"
    _di_emit_dispatch_usage "adapter-failed" || true

    escalation_count=$((escalation_count + 1))
    _di_curr_rank="$(_di_tier_rank "${_DI_SHADOW_ROUTED:-}")"
    _di_next_rank=$((_di_curr_rank + 1))
    _DI_SHADOW_ROUTED="$(_di_tier_at_rank "$_di_next_rank")"
    if [ -z "$_DI_SHADOW_ROUTED" ]; then
      # Defensive: tier progression exhausted before cap-hit branch fired.
      # Should not happen under normal flow (count>=2 catches smart-tier
      # failure first). Treat as cap-hit to avoid infinite loop.
      _di_emit_escalation_cap_hit
      emit_error "backend_crashed" "false" "developer" "${BACKEND}" \
        "Adapter failed; tier progression exhausted before cap" \
        "Adapter: ${ADAPTER}" \
        "Reduce escalation aggressiveness or set model_routing.live: false."
      exit 5
    fi
    # Re-resolve _DI_SHADOW_USED + _DI_LIVE_MODEL_FLAG for the new tier.
    # CON-3-clean: reads from templates/model-routing.yml resolution: block
    # via awk section-walker; no hardcoded provider model IDs introduced.
    _DI_SHADOW_USED="$(awk -v tier="$_DI_SHADOW_ROUTED" '
      BEGIN { in_resolution = 0; in_tier = 0 }
      /^resolution:/                    { in_resolution = 1; next }
      /^cost_rates:/                    { exit }
      in_resolution && /^  [a-z_]+:$/   { in_tier = ($1 == (tier ":")) ? 1 : 0; next }
      in_resolution && in_tier && /^    claude-code:/ {
        val = $2; gsub(/[",]/, "", val); print val; exit
      }
    ' "$_DI_PROJECT_ROOT/templates/model-routing.yml")"
    _DI_LIVE_MODEL_FLAG="$_DI_SHADOW_USED"
  done
else
  # Non-live-mode single-shot dispatch. Preserves T02 + pre-T02 behavior
  # (shadow-off / Codex CLI / Cursor / no flippable class / kill-switch).
  if [ -n "${_DI_LIVE_MODEL_FLAG:-}" ]; then
    adapter_output="$(bash "$ADAPTER" \
      --task-plan "$TASK_PLAN" \
      --payload "$PAYLOAD" \
      --intensity-metadata "$INTENSITY_METADATA" \
      --model "$_DI_LIVE_MODEL_FLAG" 2>/dev/null)" || adapter_rc=$?
  else
    adapter_output="$(bash "$ADAPTER" \
      --task-plan "$TASK_PLAN" \
      --payload "$PAYLOAD" \
      --intensity-metadata "$INTENSITY_METADATA" 2>/dev/null)" || adapter_rc=$?
  fi

  if [[ $adapter_rc -ne 0 ]]; then
    emit_error "backend_crashed" "true" "developer" "${BACKEND}" \
      "Adapter subprocess exited with code ${adapter_rc}" \
      "Adapter: ${ADAPTER}" \
      "Inspect adapter stderr or re-run with the adapter directly for diagnostics."
    _di_emit_dispatch_usage "adapter-failed" || true
    exit 5
  fi
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
# M030/P04/T03: gate this emit on `escalation_active=0`. When the
# escalation loop ran, the success record was already appended inside the
# loop body (the `if adapter_rc -eq 0: emit + break` branch); firing this
# again would produce a duplicate dispatch_usage record per dispatch
# (violating SC-1 + the SC-4 record-count assertion).
if [ "${escalation_active:-0}" -ne 1 ]; then
  _di_emit_dispatch_usage "" || true
fi

# --- Emit adapter output unchanged ---
echo "$adapter_output"
exit 0
