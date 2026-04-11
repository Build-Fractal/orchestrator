#!/usr/bin/env bash
# scripts/lib/run-context.sh — Deterministic per-session run context.
[ -n "${_RUN_CONTEXT_SOURCED:-}" ] && return 0
_RUN_CONTEXT_SOURCED=1

# Source this file to get:
#   - init_run_context [milestone] [phase]  — initialize and export run context
#   - orch_now                                — frozen timestamp (Principle IX)
#   - orch_is_forced                          — returns 0 if ORCH_FORCE is set
#   - orch_is_dry_run                         — returns 0 if ORCH_DRY_RUN is set
#
# Exported environment variables (after init_run_context):
#   ORCH_RUN_ID         Unique ID for the current session (deterministic when seeded)
#   ORCH_STARTED_AT     Frozen ISO-8601 UTC timestamp for the session
#   ORCH_FORCE          "1" to bypass safety rails, empty/unset otherwise
#   ORCH_DRY_RUN        "1" to skip real dispatch, empty/unset otherwise
#   ORCH_RUN_MILESTONE  Optional: milestone id for this session
#   ORCH_RUN_PHASE      Optional: phase id for this session
#
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.
# Constitution: Principle IX (Reproducibility) — no inline `date` calls after
# this library is loaded. Use orch_now instead.

# init_run_context [milestone] [phase]
init_run_context() {
  local milestone="${1:-${ORCH_RUN_MILESTONE:-}}"
  local phase="${2:-${ORCH_RUN_PHASE:-}}"

  local seed="${ORCH_RUN_SEED:-}"
  local run_id started_at

  if [ -n "$seed" ]; then
    local hash
    hash="$(printf '%s' "$seed" | cksum | awk '{print $1}')"
    run_id="run-seed-${hash}"
    local offset anchor
    anchor=1767225600
    offset=$(( hash % 31536000 ))
    local total=$(( anchor + offset ))
    if date -u -d "@${total}" +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
      started_at="$(date -u -d "@${total}" +%Y-%m-%dT%H:%M:%SZ)"
    else
      started_at="$(date -u -r "${total}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
    fi
  else
    started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    local nonce
    nonce="$(_orch_run_nonce)"
    run_id="run-${started_at}-${nonce}"
  fi

  ORCH_RUN_ID="$run_id"
  ORCH_STARTED_AT="$started_at"
  ORCH_FORCE="${ORCH_FORCE:-}"
  ORCH_DRY_RUN="${ORCH_DRY_RUN:-}"
  ORCH_RUN_MILESTONE="$milestone"
  ORCH_RUN_PHASE="$phase"

  export ORCH_RUN_ID ORCH_STARTED_AT ORCH_FORCE ORCH_DRY_RUN ORCH_RUN_MILESTONE ORCH_RUN_PHASE
}

_orch_run_nonce() {
  if [ -r /dev/urandom ]; then
    LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 8
  else
    printf '%s%s' "$$" "${RANDOM:-0}" | cksum | awk '{printf "%08x\n", $1}' | head -c 8
  fi
}

orch_now() {
  if [ -n "${ORCH_STARTED_AT:-}" ]; then
    printf '%s\n' "$ORCH_STARTED_AT"
  else
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}

orch_is_forced() {
  case "${ORCH_FORCE:-}" in
    1|true|TRUE|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

orch_is_dry_run() {
  case "${ORCH_DRY_RUN:-}" in
    1|true|TRUE|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}
