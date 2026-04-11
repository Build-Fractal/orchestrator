#!/usr/bin/env bash
# scripts/lib/errors.sh — Orchestrator error taxonomy and result emitter.
# --- Double-sourcing guard (NFR-203 / AP-003) ---
[ -n "${_ERRORS_SOURCED:-}" ] && return 0
_ERRORS_SOURCED=1

# Source this file to get:
#   - Closed error taxonomy: ORCH_ERR_CONFIG, ORCH_ERR_STATE, ORCH_ERR_DISPATCH,
#     ORCH_ERR_VERIFY, ORCH_ERR_BUDGET, ORCH_ERR_IO
#   - emit_result <status> [error_kind] [detail]  — prints a single RESULT: line
#   - orch_is_error_kind <value>                  — validates a value against the taxonomy
#
# Bash 3.2 compatible (NFR-200). Does not use associative arrays or any of the
# Bash 4-only array-reading builtins. No process substitution as redirect target.
#
# Constitution: Principle II (Evidence Before Claims) — structured results are
# mandatory. A script that runs without emitting a final RESULT: line is a silent
# failure.

# --- Error taxonomy (closed set, FR-220) ---
ORCH_ERR_CONFIG="CONFIG"
ORCH_ERR_STATE="STATE"
ORCH_ERR_DISPATCH="DISPATCH"
ORCH_ERR_VERIFY="VERIFY"
ORCH_ERR_BUDGET="BUDGET"
ORCH_ERR_IO="IO"

# Newline-separated for iteration without associative arrays.
ORCH_ERR_KINDS="CONFIG
STATE
DISPATCH
VERIFY
BUDGET
IO"

export ORCH_ERR_CONFIG ORCH_ERR_STATE ORCH_ERR_DISPATCH ORCH_ERR_VERIFY ORCH_ERR_BUDGET ORCH_ERR_IO ORCH_ERR_KINDS

# orch_is_error_kind <value>
# Returns 0 if <value> is in the closed taxonomy, 1 otherwise.
orch_is_error_kind() {
  local v="$1"
  [ -z "$v" ] && return 1
  case "$v" in
    CONFIG|STATE|DISPATCH|VERIFY|BUDGET|IO) return 0 ;;
    *) return 1 ;;
  esac
}

# _orch_errors_escape <string>
# Minimal JSON string escaping for the detail field: escapes backslash, double
# quote, and control characters (newline, tab, carriage return). Internal.
_orch_errors_escape() {
  local s="$1"
  # Order matters: backslashes first.
  s="$(printf '%s' "$s" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
  # Convert newlines and tabs to escaped form.
  s="$(printf '%s' "$s" | tr '\n' ' ' | tr '\r' ' ' | tr '\t' ' ')"
  printf '%s' "$s"
}

# emit_result <status> [error_kind] [detail]
# Prints a single-line RESULT: entry to stdout. Called exactly once per script
# at completion. <status> is "ok" or "error". For "error", error_kind MUST be a
# taxonomy value. detail is a free-form human-readable description.
#
# Examples:
#   emit_result ok "" "phase advanced to P03"
#   emit_result error CONFIG "routing.yaml missing required field models.heavy.id"
#   emit_result error DISPATCH "all models in fallback chain exhausted"
emit_result() {
  local status="${1:-error}"
  local kind="${2:-}"
  local detail="${3:-}"

  case "$status" in
    ok|error) ;;
    *)
      status="error"
      kind="${kind:-CONFIG}"
      detail="invalid status passed to emit_result: $detail"
      ;;
  esac

  if [ "$status" = "error" ] && [ -n "$kind" ] && ! orch_is_error_kind "$kind"; then
    detail="unknown error_kind '$kind' (caller: $detail)"
    kind="CONFIG"
  fi

  local escaped_detail
  escaped_detail="$(_orch_errors_escape "$detail")"

  printf 'RESULT:{"status":"%s","error_kind":"%s","detail":"%s"}\n' \
    "$status" "$kind" "$escaped_detail"
}
