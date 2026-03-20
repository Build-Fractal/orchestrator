#!/usr/bin/env bash
# scripts/lifecycle/budget-checker.sh — Budget enforcement for autonomous dispatch
# Reads the execution log and checks dispatch count and cumulative duration
# against configured budget limits. Used by auto.md as a gate before each dispatch.
#
# Usage: budget-checker.sh <execution-log> [--dispatch-budget N] [--duration-budget T]
#
# Arguments:
#   <execution-log>        Path to the JSONL execution log
#   --dispatch-budget N    Maximum number of dispatches allowed (integer)
#   --duration-budget T    Maximum cumulative duration in seconds (integer)
#
# Structured output (stdout):
#   BUDGET:EXCEEDED type=dispatch current=<N> limit=<N>
#   BUDGET:EXCEEDED type=duration current=<T> limit=<T>
#   BUDGET:OK dispatches=<N>/<limit> duration=<T>/<limit>
#   BUDGET:OK (no limits configured)
#   BUDGET:OK dispatches=0 duration=0s (no log)
#
# Always exits 0 (budget status is informational).
# Exits 1 only for invalid arguments.

set -euo pipefail

# --- Argument parsing ---
if [[ $# -lt 1 ]]; then
  echo "budget-checker.sh: requires <execution-log> [options]" >&2
  echo "Usage: budget-checker.sh <execution-log> [--dispatch-budget N] [--duration-budget T]" >&2
  exit 1
fi

EXECUTION_LOG="$1"
shift

DISPATCH_BUDGET=""
DURATION_BUDGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dispatch-budget)
      if [[ $# -lt 2 ]]; then
        echo "budget-checker.sh: --dispatch-budget requires a value" >&2
        exit 1
      fi
      DISPATCH_BUDGET="$2"
      shift 2
      ;;
    --duration-budget)
      if [[ $# -lt 2 ]]; then
        echo "budget-checker.sh: --duration-budget requires a value" >&2
        exit 1
      fi
      DURATION_BUDGET="$2"
      shift 2
      ;;
    *)
      echo "budget-checker.sh: unknown option '$1'" >&2
      echo "Usage: budget-checker.sh <execution-log> [--dispatch-budget N] [--duration-budget T]" >&2
      exit 1
      ;;
  esac
done

# --- Handle missing or empty log ---
if [[ ! -f "$EXECUTION_LOG" ]] || [[ ! -s "$EXECUTION_LOG" ]]; then
  echo "BUDGET:OK dispatches=0 duration=0s (no log)"
  exit 0
fi

# --- No budgets configured ---
if [[ -z "$DISPATCH_BUDGET" ]] && [[ -z "$DURATION_BUDGET" ]]; then
  echo "BUDGET:OK (no limits configured)"
  exit 0
fi

# --- Count dispatches and sum duration ---
dispatch_count=0
duration_total=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  # Count dispatch events
  if echo "$line" | grep -q '"dispatch"'; then
    dispatch_count=$((dispatch_count + 1))
  fi

  # Sum duration values (look for "duration": N or "duration_s": N)
  duration_val=""
  duration_val=$(echo "$line" | grep -oE '"duration_s?"[[:space:]]*:[[:space:]]*[0-9]+' \
    | head -1 \
    | grep -oE '[0-9]+$' || true)
  if [[ -n "$duration_val" ]]; then
    duration_total=$((duration_total + duration_val))
  fi
done < "$EXECUTION_LOG"

# --- Check dispatch budget ---
if [[ -n "$DISPATCH_BUDGET" ]] && [[ $dispatch_count -ge $DISPATCH_BUDGET ]]; then
  echo "BUDGET:EXCEEDED type=dispatch current=$dispatch_count limit=$DISPATCH_BUDGET"
  exit 0
fi

# --- Check duration budget ---
if [[ -n "$DURATION_BUDGET" ]] && [[ $duration_total -ge $DURATION_BUDGET ]]; then
  echo "BUDGET:EXCEEDED type=duration current=${duration_total}s limit=${DURATION_BUDGET}s"
  exit 0
fi

# --- Within budget ---
dispatch_display="${dispatch_count}"
if [[ -n "$DISPATCH_BUDGET" ]]; then
  dispatch_display="${dispatch_count}/${DISPATCH_BUDGET}"
fi

duration_display="${duration_total}s"
if [[ -n "$DURATION_BUDGET" ]]; then
  duration_display="${duration_total}s/${DURATION_BUDGET}s"
fi

echo "BUDGET:OK dispatches=$dispatch_display duration=$duration_display"
exit 0
