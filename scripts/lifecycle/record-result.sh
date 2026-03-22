#!/usr/bin/env bash
# scripts/lifecycle/record-result.sh — Append structured result to execution log
# Validates required fields, generates timestamp and unitId, appends one JSON line.
# Replaces inline echo commands in auto.md Step G with a proper script.
#
# Usage: record-result.sh <execution-log> --milestone=M### --phase=P## --task=T## --outcome=<success|failure|retry> [options]
#
# Required:
#   <execution-log>              Path to the JSONL execution log file
#   --milestone=<M###>           Milestone ID
#   --phase=<P##>                Phase ID
#   --task=<T##>                 Task ID
#   --outcome=<value>            One of: success, failure, retry, blocked, timeout, stuck
#
# Optional:
#   --tier=<A|B|C>               Execution tier (default: C)
#   --dispatch_method=<value>    One of: subagent, sequential (default: sequential)
#   --verification_result=<val>  One of: pass, fail, pass_with_concerns, skipped
#   --attempt=<N>                Dispatch attempt number (default: 1)
#   --duration_s=<N>             Duration in seconds
#   --payload_bytes=<N>          Payload size in bytes
#   --concerns=<text>            Concern notes (optional)
#
# Structured output (stdout):
#   RECORD:APPENDED <log-file>
#
# Exits 0 on success, 1 on missing required fields or invalid arguments.

set -euo pipefail

# --- Argument parsing ---
if [[ $# -lt 1 ]]; then
  echo "record-result.sh: requires <execution-log> --milestone=... --phase=... --task=... --outcome=..." >&2
  echo "Usage: record-result.sh <execution-log> --milestone=M### --phase=P## --task=T## --outcome=<success|failure|retry>" >&2
  exit 1
fi

EXECUTION_LOG="$1"
shift

MILESTONE=""
PHASE=""
TASK=""
OUTCOME=""
TIER="C"
DISPATCH_METHOD="sequential"
VERIFICATION_RESULT=""
ATTEMPT="1"
DURATION_S=""
PAYLOAD_BYTES=""
CONCERNS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --milestone=*) MILESTONE="${1#--milestone=}" ;;
    --phase=*)     PHASE="${1#--phase=}" ;;
    --task=*)      TASK="${1#--task=}" ;;
    --outcome=*)   OUTCOME="${1#--outcome=}" ;;
    --tier=*)      TIER="${1#--tier=}" ;;
    --dispatch_method=*) DISPATCH_METHOD="${1#--dispatch_method=}" ;;
    --verification_result=*) VERIFICATION_RESULT="${1#--verification_result=}" ;;
    --attempt=*)   ATTEMPT="${1#--attempt=}" ;;
    --duration_s=*) DURATION_S="${1#--duration_s=}" ;;
    --payload_bytes=*) PAYLOAD_BYTES="${1#--payload_bytes=}" ;;
    --concerns=*)  CONCERNS="${1#--concerns=}" ;;
    *)
      echo "record-result.sh: unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# --- Validate required fields ---
missing=""
if [[ -z "$MILESTONE" ]]; then missing="${missing} milestone"; fi
if [[ -z "$PHASE" ]]; then missing="${missing} phase"; fi
if [[ -z "$TASK" ]]; then missing="${missing} task"; fi
if [[ -z "$OUTCOME" ]]; then missing="${missing} outcome"; fi

if [[ -n "$missing" ]]; then
  echo "record-result.sh: missing required fields:${missing}" >&2
  exit 1
fi

# --- Validate outcome value ---
case "$OUTCOME" in
  success|failure|retry|blocked|timeout|stuck) ;;
  *)
    echo "record-result.sh: invalid outcome: $OUTCOME (expected: success|failure|retry|blocked|timeout|stuck)" >&2
    exit 1
    ;;
esac

# --- Generate timestamp and unitId ---
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
UNIT_ID="${MILESTONE}/${PHASE}/${TASK}"

# --- Build JSON entry ---
# Use printf to avoid issues with special characters in concerns field
json="{"
json="${json}\"timestamp\":\"${TIMESTAMP}\""
json="${json},\"unitId\":\"${UNIT_ID}\""
json="${json},\"milestone\":\"${MILESTONE}\""
json="${json},\"phase\":\"${PHASE}\""
json="${json},\"task\":\"${TASK}\""
json="${json},\"tier\":\"${TIER}\""
json="${json},\"outcome\":\"${OUTCOME}\""
json="${json},\"dispatch_method\":\"${DISPATCH_METHOD}\""
json="${json},\"attempt\":${ATTEMPT}"

if [[ -n "$VERIFICATION_RESULT" ]]; then
  json="${json},\"verification_result\":\"${VERIFICATION_RESULT}\""
fi

if [[ -n "$DURATION_S" ]]; then
  json="${json},\"duration_s\":${DURATION_S}"
fi

if [[ -n "$PAYLOAD_BYTES" ]]; then
  json="${json},\"payload_bytes\":${PAYLOAD_BYTES}"
fi

if [[ -n "$CONCERNS" ]]; then
  # Escape double quotes in concerns text
  escaped_concerns=$(printf '%s' "$CONCERNS" | sed 's/"/\\"/g')
  json="${json},\"concerns\":\"${escaped_concerns}\""
fi

json="${json}}"

# --- Create log file directory if needed ---
log_dir=$(dirname "$EXECUTION_LOG")
if [[ ! -d "$log_dir" ]]; then
  mkdir -p "$log_dir"
fi

# --- Append to log ---
echo "$json" >> "$EXECUTION_LOG"

echo "RECORD:APPENDED $EXECUTION_LOG"
