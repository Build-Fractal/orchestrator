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

  mkdir -p "$log_dir" 2>/dev/null || {
    printf 'dispatch-interface.sh: dispatch_usage emit skipped (mkdir failed on %s)\n' "$log_dir" >&2
    return 0
  }

  # JSON-escape backslashes + double quotes in the warning string (belt-and-
  # suspenders; pricing-lib reasons are ascii-safe by construction).
  escaped_warning="$(printf '%s' "$warning" | sed 's/\\/\\\\/g; s/"/\\"/g')"

  if [ -n "$cost_usd" ] && [ -z "$warning" ]; then
    # Happy path — numeric cost, no warning field.
    # M018/P00/T01: emission_point="dispatch-interface" disambiguates from
    # build-context co-located emissions (CON-5 additive field).
    printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":%s,"pricing_version":"%s","model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s"}\n' \
      "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
      "$input_tokens" "$output_tokens" "$cost_usd" \
      "$pricing_version" "$model" "$ts" \
      >> "$log_file" 2>/dev/null || {
      printf 'dispatch-interface.sh: dispatch_usage append failed on %s\n' "$log_file" >&2
      return 0
    }
  else
    # Degradation path — cost=null JSON literal, pricing_warning present.
    # M018/P00/T01: emission_point="dispatch-interface" disambiguates from
    # build-context co-located emissions (CON-5 additive field).
    printf '{"record_type":"dispatch_usage","unitId":"%s","milestone":"%s","phase":"%s","task":"%s","backend":"%s","input_tokens_estimate":%d,"output_tokens_estimate":%d,"estimated_cost_usd":null,"pricing_version":"%s","pricing_warning":"%s","model":"%s","source":"estimate","emission_point":"dispatch-interface","timestamp":"%s"}\n' \
      "$UNIT_ID" "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" "$BACKEND" \
      "$input_tokens" "$output_tokens" \
      "$pricing_version" "$escaped_warning" "$model" "$ts" \
      >> "$log_file" 2>/dev/null || {
      printf 'dispatch-interface.sh: dispatch_usage append failed on %s\n' "$log_file" >&2
      return 0
    }
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
