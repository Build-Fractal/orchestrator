#!/usr/bin/env bash
# scripts/lib/guards.sh — Safety rail functions.
[ -n "${_GUARDS_SOURCED:-}" ] && return 0
_GUARDS_SOURCED=1

# Source this file to get:
#   - guard_payload_sanity <payload_file>
#   - guard_budget <cum_cost_cents> <max_cost_cents> [cum_dur_sec] [max_dur_sec]
#   - guard_output_sanity <output_file>
#   - guard_phase_complete <phase_dir>
#
# Every guard returns 0 on pass (or force-override) and non-zero on block.
# Every guard emits GUARD_BLOCKED or GUARD_WARNING on failure. When
# ORCH_FORCE is set (via orch_is_forced), a would-be block becomes a warning.
# Bash 3.2 compatible (NFR-200). Double-sourcing guard (NFR-203 / AP-003).
# Constitution: Principle II (structured events), Principle IX (orch_now).

# Source required sibling libraries relative to this file's location.
_guards_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
. "${_guards_dir}/errors.sh"
# shellcheck disable=SC1090
. "${_guards_dir}/events.sh"
# shellcheck disable=SC1090
. "${_guards_dir}/run-context.sh"

# --- Configuration ---
ORCH_GUARD_MIN_PAYLOAD_CHARS="${ORCH_GUARD_MIN_PAYLOAD_CHARS:-100}"
ORCH_GUARD_MIN_OUTPUT_CHARS="${ORCH_GUARD_MIN_OUTPUT_CHARS:-100}"

# _guard_block <name> <reason>
# Internal: emit GUARD_BLOCKED (or GUARD_WARNING if forced), return the status.
_guard_block() {
  local name="$1"
  local reason="$2"
  if orch_is_forced; then
    emit_event GUARD_WARNING guard="$name" reason="$reason" forced=1
    return 0
  fi
  emit_event GUARD_BLOCKED guard="$name" reason="$reason"
  return 1
}

# guard_payload_sanity <payload_file>
guard_payload_sanity() {
  local f="$1"
  if [ -z "$f" ]; then
    _guard_block payload_sanity "no payload path provided"
    return $?
  fi
  if [ ! -f "$f" ]; then
    _guard_block payload_sanity "payload file not found: $f"
    return $?
  fi
  local size
  size="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
  if [ -z "$size" ]; then
    _guard_block payload_sanity "unable to stat payload: $f"
    return $?
  fi
  if [ "$size" -lt "$ORCH_GUARD_MIN_PAYLOAD_CHARS" ]; then
    _guard_block payload_sanity "payload too small: ${size} < ${ORCH_GUARD_MIN_PAYLOAD_CHARS} chars ($f)"
    return $?
  fi
  return 0
}

# guard_budget <cum_cost_cents> <max_cost_cents> [cum_dur_sec] [max_dur_sec]
guard_budget() {
  local cum_cost="${1:-0}"
  local max_cost="${2:-0}"
  local cum_dur="${3:-0}"
  local max_dur="${4:-0}"
  case "$cum_cost" in ''|*[!0-9]*) cum_cost=0 ;; esac
  case "$max_cost" in ''|*[!0-9]*) max_cost=0 ;; esac
  case "$cum_dur"  in ''|*[!0-9]*) cum_dur=0 ;; esac
  case "$max_dur"  in ''|*[!0-9]*) max_dur=0 ;; esac
  if [ "$max_cost" -gt 0 ] && [ "$cum_cost" -gt "$max_cost" ]; then
    _guard_block budget "cost ${cum_cost} exceeds cap ${max_cost} (cents)"
    return $?
  fi
  if [ "$max_dur" -gt 0 ] && [ "$cum_dur" -gt "$max_dur" ]; then
    _guard_block budget "duration ${cum_dur}s exceeds cap ${max_dur}s"
    return $?
  fi
  return 0
}

# guard_output_sanity <output_file>
guard_output_sanity() {
  local f="$1"
  if [ -z "$f" ]; then
    _guard_block output_sanity "no output path provided"
    return $?
  fi
  if [ ! -f "$f" ]; then
    _guard_block output_sanity "output file not found: $f"
    return $?
  fi
  local size
  size="$(wc -c < "$f" 2>/dev/null | tr -d ' ')"
  if [ -z "$size" ] || [ "$size" -lt "$ORCH_GUARD_MIN_OUTPUT_CHARS" ]; then
    _guard_block output_sanity "output too small: ${size:-0} < ${ORCH_GUARD_MIN_OUTPUT_CHARS} chars"
    return $?
  fi
  return 0
}

# guard_phase_complete <phase_dir>
guard_phase_complete() {
  local phase_dir="$1"
  if [ -z "$phase_dir" ] || [ ! -d "$phase_dir" ]; then
    _guard_block phase_complete "phase dir not found: ${phase_dir:-<empty>}"
    return $?
  fi
  local summary
  summary="$(ls "$phase_dir"/P*-SUMMARY.md 2>/dev/null | head -1)"
  if [ -z "$summary" ] && [ -f "${phase_dir}/SUMMARY.md" ]; then
    summary="${phase_dir}/SUMMARY.md"
  fi
  if [ -z "$summary" ]; then
    _guard_block phase_complete "no SUMMARY.md in ${phase_dir}"
    return $?
  fi
  if ! grep -q '^## ' "$summary"; then
    _guard_block phase_complete "SUMMARY.md has no content sections: $summary"
    return $?
  fi
  return 0
}
