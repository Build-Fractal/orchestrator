#!/usr/bin/env bash
# scripts/telemetry/record-telemetry.sh — Record execution telemetry
# Appends a telemetry-typed JSON line to the execution log, distinct from
# dispatch result entries written by record-result.sh.
#
# Usage: record-telemetry.sh <execution-log> --unit-id=... [--model=...] [--tokens-input=N] ...
#
# Required:
#   <execution-log>              Path to the JSONL execution log file
#   --unit-id=<M###/P##/T##>     Unit identifier
#
# Optional:
#   --model=<model-id>           Model used for the dispatch
#   --tokens-input=<N>           Input token count
#   --tokens-output=<N>          Output token count
#   --tokens-cache-read=<N>      Cache-read token count
#   --cost=<amount>              Estimated cost in dollars
#   --cache-hit-rate=<rate>      Cache hit rate (0.0-1.0)
#   --payload-bytes=<N>          Payload size in bytes
#
# Structured output (stdout):
#   TELEMETRY:RECORDED <log-file>
#
# Exits 0 on success, 1 on missing required fields or invalid arguments.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: record-telemetry.sh <execution-log> --unit-id=... [--model=...] [--tokens-input=N] ..." >&2
  exit 1
fi

EXECUTION_LOG="$1"
shift

UNIT_ID=""
MODEL_USED=""
TOKENS_INPUT=""
TOKENS_OUTPUT=""
TOKENS_CACHE_READ=""
COST_ESTIMATED=""
CACHE_HIT_RATE=""
PAYLOAD_BYTES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --unit-id=*) UNIT_ID="${1#--unit-id=}" ;;
    --model=*) MODEL_USED="${1#--model=}" ;;
    --tokens-input=*) TOKENS_INPUT="${1#--tokens-input=}" ;;
    --tokens-output=*) TOKENS_OUTPUT="${1#--tokens-output=}" ;;
    --tokens-cache-read=*) TOKENS_CACHE_READ="${1#--tokens-cache-read=}" ;;
    --cost=*) COST_ESTIMATED="${1#--cost=}" ;;
    --cache-hit-rate=*) CACHE_HIT_RATE="${1#--cache-hit-rate=}" ;;
    --payload-bytes=*) PAYLOAD_BYTES="${1#--payload-bytes=}" ;;
    *) echo "record-telemetry.sh: unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

# Validate required
if [ -z "$UNIT_ID" ]; then
  echo "record-telemetry.sh: --unit-id is required" >&2
  exit 1
fi

TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# Build JSON
json="{\"timestamp\":\"${TIMESTAMP}\",\"type\":\"telemetry\",\"unitId\":\"${UNIT_ID}\""
[ -n "$MODEL_USED" ] && json="${json},\"model_used\":\"${MODEL_USED}\""
[ -n "$TOKENS_INPUT" ] && json="${json},\"tokens_input\":${TOKENS_INPUT}"
[ -n "$TOKENS_OUTPUT" ] && json="${json},\"tokens_output\":${TOKENS_OUTPUT}"
[ -n "$TOKENS_CACHE_READ" ] && json="${json},\"tokens_cache_read\":${TOKENS_CACHE_READ}"
[ -n "$COST_ESTIMATED" ] && json="${json},\"cost_estimated\":${COST_ESTIMATED}"
[ -n "$CACHE_HIT_RATE" ] && json="${json},\"cache_hit_rate\":${CACHE_HIT_RATE}"
[ -n "$PAYLOAD_BYTES" ] && json="${json},\"payload_bytes\":${PAYLOAD_BYTES}"
json="${json}}"

mkdir -p "$(dirname "$EXECUTION_LOG")"
echo "$json" >> "$EXECUTION_LOG"
echo "TELEMETRY:RECORDED $EXECUTION_LOG"
