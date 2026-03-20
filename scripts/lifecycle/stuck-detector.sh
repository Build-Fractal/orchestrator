#!/usr/bin/env bash
# scripts/lifecycle/stuck-detector.sh — Detect stuck dispatch loops
# Reads the JSONL execution log and determines if a unit has been dispatched
# multiple times without producing a completion artifact (summary file).
#
# Usage: stuck-detector.sh <execution-log> <unit-id>
#
# Stuck condition: unit dispatched ≥2 times AND no success outcome recorded.
#
# Structured output (stdout):
#   STUCK:YES unit=<unit-id> dispatches=<N> expected=<artifact>
#   STUCK:NO unit=<unit-id> dispatches=<N>
#   STUCK:NO dispatches=0 (No dispatches found)
#
# Always exits 0 (stuck is an observation, not an error).
# Exits 1 only for invalid arguments.

set -euo pipefail

# --- Argument validation ---
if [[ $# -lt 2 ]]; then
  echo "stuck-detector.sh: requires <execution-log> <unit-id>" >&2
  echo "Usage: stuck-detector.sh <execution-log> <unit-id>" >&2
  exit 1
fi

EXECUTION_LOG="$1"
UNIT_ID="$2"

# --- Handle missing or empty log ---
if [[ ! -f "$EXECUTION_LOG" ]] || [[ ! -s "$EXECUTION_LOG" ]]; then
  echo "STUCK:NO dispatches=0 (No dispatches found)"
  exit 0
fi

# --- Count dispatches for this unit ---
# Each JSONL entry has "unitId" or "unit_id" field — match the unit ID
dispatch_count=0
has_success=false

while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  # Check if this line references our unit ID
  if echo "$line" | grep -qE '"unitId"[[:space:]]*:[[:space:]]*"'"$UNIT_ID"'"'; then
    # Check if this is a dispatch event
    if echo "$line" | grep -q '"dispatch"'; then
      dispatch_count=$((dispatch_count + 1))
    fi
    # Check if this is a success outcome
    if echo "$line" | grep -q '"success"'; then
      has_success=true
    fi
  fi
done < "$EXECUTION_LOG"

# --- Handle no dispatches ---
if [[ $dispatch_count -eq 0 ]]; then
  echo "STUCK:NO dispatches=0 (No dispatches found)"
  exit 0
fi

# --- Determine stuck status ---
if [[ $dispatch_count -ge 2 ]] && [[ "$has_success" = "false" ]]; then
  # Derive expected artifact from unit ID (e.g., M001/P01/T01 → T01-SUMMARY.md)
  expected_artifact=""
  task_part="${UNIT_ID##*/}"
  if [[ "$task_part" =~ ^T[0-9]+ ]]; then
    expected_artifact="${task_part}-SUMMARY.md"
  elif [[ "$task_part" =~ ^P[0-9]+ ]]; then
    expected_artifact="${task_part}-SUMMARY.md"
  else
    expected_artifact="SUMMARY.md"
  fi
  echo "STUCK:YES unit=$UNIT_ID dispatches=$dispatch_count expected=$expected_artifact"
else
  echo "STUCK:NO unit=$UNIT_ID dispatches=$dispatch_count"
fi

exit 0
