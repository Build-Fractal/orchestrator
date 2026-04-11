#!/usr/bin/env bash
# scripts/lib/events.sh — Structured event emission for engine-managed scripts.
[ -n "${_EVENTS_SOURCED:-}" ] && return 0
_EVENTS_SOURCED=1

# Source this file to get:
#   - emit_event <TYPE> [key=value ...]  — prints a single EVENT: line
#   - ORCH_EVENT_TYPES                    — newline-separated canonical registry
#   - orch_is_event_type <type>           — validates a type against the registry
#
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.
#
# Constitution:
#   Principle II (amended): engine-managed scripts MUST emit structured events.
#   Principle IX: timestamps derive from $ORCH_STARTED_AT when set, so events
#   from the same run share the same frozen session timestamp.

# --- Canonical event type registry (FR-221) ---
# Engine lifecycle events correlate to the dispatch pipeline stages.
# Safety/hook events correspond to guard and hook outcomes.
# Dispatch events are emitted by the P03 engine and P06 scripts.
ORCH_EVENT_TYPES="SESSION_START
SESSION_END
PHASE_START
PHASE_COMPLETE
TASK_START
TASK_COMPLETE
DISPATCH_START
DISPATCH_FALLBACK
VERIFY_START
VERIFY_COMPLETE
GUARD_BLOCKED
GUARD_WARNING
SAFETY_WARNING
HOOK_START
HOOK_COMPLETE
HOOK_BLOCKED
HOOK_VIOLATION
CHECKPOINT_WRITE
CHECKPOINT_RESUME"

export ORCH_EVENT_TYPES

# orch_is_event_type <type>
# Returns 0 if <type> is in the canonical registry, 1 otherwise. This is a
# warning-level check: emit_event still prints unknown types but also emits a
# SAFETY_WARNING so the drift is observable.
orch_is_event_type() {
  local t="$1"
  [ -z "$t" ] && return 1
  case "$t" in
    SESSION_START|SESSION_END|PHASE_START|PHASE_COMPLETE|TASK_START|TASK_COMPLETE) return 0 ;;
    DISPATCH_START|DISPATCH_FALLBACK|VERIFY_START|VERIFY_COMPLETE) return 0 ;;
    GUARD_BLOCKED|GUARD_WARNING|SAFETY_WARNING) return 0 ;;
    HOOK_START|HOOK_COMPLETE|HOOK_BLOCKED|HOOK_VIOLATION) return 0 ;;
    CHECKPOINT_WRITE|CHECKPOINT_RESUME) return 0 ;;
    *) return 1 ;;
  esac
}

# _orch_events_timestamp
# Returns an ISO-8601 UTC timestamp. Prefers $ORCH_STARTED_AT (set by
# init_run_context in run-context.sh) for determinism. Falls back to a single
# date call when run-context is not loaded.
_orch_events_timestamp() {
  if [ -n "${ORCH_STARTED_AT:-}" ]; then
    printf '%s' "$ORCH_STARTED_AT"
  else
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}

# _orch_events_quote <string>
# Shell-safe quoting for event values: if the value contains whitespace, wrap
# it in double quotes and escape internal double quotes. Otherwise emit as-is.
_orch_events_quote() {
  local s="$1"
  case "$s" in
    *[[:space:]]*|*'"'*)
      s="$(printf '%s' "$s" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
      printf '"%s"' "$s"
      ;;
    *)
      printf '%s' "$s"
      ;;
  esac
}

# emit_event <TYPE> [key=value ...]
# Prints a single EVENT: line to stdout. TYPE is uppercase from the canonical
# registry (unknown types trigger a SAFETY_WARNING companion event). Remaining
# args are key=value pairs; values containing whitespace are shell-quoted.
#
# Examples:
#   emit_event SESSION_START run_id="$ORCH_RUN_ID" milestone=M004
#   emit_event TASK_START task=T02 phase=P02
#   emit_event GUARD_BLOCKED guard=payload_sanity reason="empty payload"
emit_event() {
  local type="$1"
  shift || true

  if [ -z "$type" ]; then
    type="SAFETY_WARNING"
    set -- "reason=emit_event_missing_type" "$@"
  fi

  if ! orch_is_event_type "$type"; then
    # Emit the original event first (callers extending the registry), then a
    # companion SAFETY_WARNING so the drift is observable in the event stream.
    _orch_events_print "$type" "$@"
    _orch_events_print "SAFETY_WARNING" "reason=unknown_event_type" "original_type=$type"
    return 0
  fi

  _orch_events_print "$type" "$@"
}

# Internal: format and print one EVENT: line.
_orch_events_print() {
  local type="$1"
  shift || true

  local ts run_id out
  ts="$(_orch_events_timestamp)"
  run_id="${ORCH_RUN_ID:-unset}"
  out="EVENT:${type} timestamp=${ts} run_id=${run_id}"

  local kv key val
  for kv in "$@"; do
    case "$kv" in
      *=*)
        key="${kv%%=*}"
        val="${kv#*=}"
        val="$(_orch_events_quote "$val")"
        out="${out} ${key}=${val}"
        ;;
      *)
        out="${out} ${kv}"
        ;;
    esac
  done

  printf '%s\n' "$out"
}
