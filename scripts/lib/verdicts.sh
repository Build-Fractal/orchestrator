#!/usr/bin/env bash
# scripts/lib/verdicts.sh — Gate verdict protocol for hook scripts.
# Provides structured verdict emission and parsing.
#
# Source this file to get:
#   - Closed verdict set: ORCH_VERDICT_PASS, ORCH_VERDICT_BLOCK,
#     ORCH_VERDICT_WARN, ORCH_VERDICT_NEEDS_REVIEW
#   - emit_verdict <verdict> <reason>  — prints a single VERDICT: line
#   - parse_verdict <line>             — extracts verdict and reason
#   - orch_is_verdict <value>          — validates against the verdict set
#
# Verdict line format:
#   VERDICT:<verdict> reason="<reason>"
#
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.
# AD-3: verdict schema is provider-agnostic.

# --- Double-sourcing guard ---
[ -n "${_VERDICTS_SOURCED:-}" ] && return 0
_VERDICTS_SOURCED=1

# --- Verdict constants (closed set, AD-3) ---
ORCH_VERDICT_PASS="PASS"
ORCH_VERDICT_BLOCK="BLOCK"
ORCH_VERDICT_WARN="WARN"
ORCH_VERDICT_NEEDS_REVIEW="NEEDS_REVIEW"

ORCH_VERDICT_KINDS="PASS
BLOCK
WARN
NEEDS_REVIEW"

export ORCH_VERDICT_PASS ORCH_VERDICT_BLOCK ORCH_VERDICT_WARN ORCH_VERDICT_NEEDS_REVIEW ORCH_VERDICT_KINDS

# orch_is_verdict <value>
# Returns 0 if <value> is in the closed verdict set, 1 otherwise.
orch_is_verdict() {
  local v="$1"
  [ -z "$v" ] && return 1
  case "$v" in
    PASS|BLOCK|WARN|NEEDS_REVIEW) return 0 ;;
    *) return 1 ;;
  esac
}

# _verdicts_quote <string>
# Shell-safe quoting for verdict reason values: if the value contains
# whitespace or double quotes, wrap in double quotes and escape internal
# quotes. Follows the events.sh _orch_events_quote pattern.
_verdicts_quote() {
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

# emit_verdict <verdict> <reason>
# Prints a single VERDICT: line to stdout. Validates that <verdict> is
# in the closed set. If invalid, downgrades to WARN and includes the
# original verdict in the reason.
emit_verdict() {
  local verdict="${1:-}"
  local reason="${2:-}"

  if [ -z "$verdict" ]; then
    verdict="WARN"
    reason="emit_verdict called without verdict: ${reason}"
  elif ! orch_is_verdict "$verdict"; then
    reason="unknown verdict '${verdict}': ${reason}"
    verdict="WARN"
  fi

  local quoted_reason
  quoted_reason="$(_verdicts_quote "$reason")"

  printf 'VERDICT:%s reason=%s\n' "$verdict" "$quoted_reason"
}

# parse_verdict <line>
# Parses a VERDICT: line and outputs tab-separated fields:
#   verdict<TAB>reason
# Returns 0 on successful parse, 1 if the line is not a valid VERDICT line.
#
# Handles both quoted and unquoted reason values:
#   VERDICT:PASS reason="all checks passed"
#   VERDICT:PASS reason=ok
parse_verdict() {
  local line="$1"

  # Must start with VERDICT:
  case "$line" in
    VERDICT:*) ;;
    *) return 1 ;;
  esac

  # Extract verdict (between VERDICT: and first space)
  local after_prefix="${line#VERDICT:}"
  local verdict="${after_prefix%% *}"

  # Validate verdict
  if ! orch_is_verdict "$verdict"; then
    return 1
  fi

  # Extract reason value
  local reason=""
  case "$after_prefix" in
    *reason=\"*)
      # Quoted reason: extract between first =" and last "
      reason="${after_prefix#*reason=\"}"
      reason="${reason%\"}"
      ;;
    *reason=*)
      # Unquoted reason: everything after reason=
      reason="${after_prefix#*reason=}"
      ;;
  esac

  printf '%s\t%s\n' "$verdict" "$reason"
  return 0
}
