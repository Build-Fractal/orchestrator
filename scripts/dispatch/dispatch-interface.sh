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

TASK_PLAN=""
PAYLOAD=""
INTENSITY_METADATA=""
BACKEND=""

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
  exit 5
fi

# Minimal conformance check: adapter output must contain schema_version
# and type: "dispatch-result" frontmatter.
if ! echo "$adapter_output" | grep -q '^schema_version:'; then
  emit_error "backend_malformed" "false" "developer" "${BACKEND}" \
    "Adapter output missing schema_version frontmatter" \
    "Adapter: ${ADAPTER}" \
    "Adapter must emit a dispatch-result.md conforming document. See templates/dispatch-result.md."
  exit 6
fi
if ! echo "$adapter_output" | grep -q '^type: "dispatch-result"'; then
  emit_error "backend_malformed" "false" "developer" "${BACKEND}" \
    "Adapter output missing type: dispatch-result frontmatter" \
    "Adapter: ${ADAPTER}" \
    "Adapter must emit a dispatch-result.md conforming document. See templates/dispatch-result.md."
  exit 6
fi

# --- Emit adapter output unchanged ---
echo "$adapter_output"
exit 0
