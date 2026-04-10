#!/usr/bin/env bash
# scripts/dispatch/select-model.sh — Select model from routing config
# Maps a complexity tier to a model ID and context budget using routing.yaml.
#
# Usage: select-model.sh <complexity-tier> [--routing-config <routing.yaml>]
#
# Arguments:
#   complexity-tier: one of "heavy", "standard", "light"
#   --routing-config: path to routing.yaml (optional)
#
# Output: "<model-id> <context-budget>" to stdout
#         e.g. "claude-sonnet-4-6 150000"
#
# When no routing config is provided or the file is missing, returns defaults:
#   heavy    → claude-opus-4-6 200000
#   standard → claude-sonnet-4-6 150000
#   light    → claude-haiku-4-5 80000
#
# Exit 0 on success, 1 on missing arguments.
#
# Bash 3.2 compatible — parses YAML with grep/sed (no jq/yq dependency).
#
# NOTE: Routing optimization suggestions (e.g., "light tasks could use a cheaper
# model") are planned for when historical execution data is available. This will
# integrate with aggregate-metrics.sh to compare model usage against success rates.

set -euo pipefail

COMPLEXITY="${1:?Usage: select-model.sh <complexity-tier> [--routing-config <file>]}"
ROUTING_CONFIG=""

shift
while [ $# -gt 0 ]; do
  case "$1" in
    --routing-config) ROUTING_CONFIG="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# --- Validate complexity tier ---
case "$COMPLEXITY" in
  heavy|standard|light) ;;
  *) echo "Error: invalid complexity tier: $COMPLEXITY (expected heavy, standard, or light)" >&2; exit 1 ;;
esac

# --- Built-in defaults ---
default_model_for() {
  case "$1" in
    heavy)    echo "claude-opus-4-6 200000" ;;
    standard) echo "claude-sonnet-4-6 150000" ;;
    light)    echo "claude-haiku-4-5 80000" ;;
  esac
}

# --- If no routing config, return defaults ---
if [ -z "$ROUTING_CONFIG" ] || [ ! -f "$ROUTING_CONFIG" ]; then
  default_model_for "$COMPLEXITY"
  exit 0
fi

# --- Parse YAML routing config ---
# Strategy: find the tier section under models:, then extract id and context_budget
in_section=false
model_id=""
budget=""

while IFS= read -r line; do
  # Detect tier section start (e.g., "  heavy:")
  if echo "$line" | grep -qE "^[[:space:]]+${COMPLEXITY}:"; then
    in_section=true
    continue
  fi

  # If inside the target section, look for id and context_budget
  if [ "$in_section" = true ]; then
    # Detect next section at same or lesser indent (another tier or top-level key)
    if echo "$line" | grep -qE '^[[:space:]]{2}[a-z]+:' && ! echo "$line" | grep -qE '^[[:space:]]{4}'; then
      break
    fi
    if echo "$line" | grep -qE '^[a-z]'; then
      break
    fi

    # Extract id
    if echo "$line" | grep -q 'id:'; then
      model_id="$(echo "$line" | sed 's/.*id:[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '"' | tr -d "'")"
    fi
    # Extract context_budget
    if echo "$line" | grep -q 'context_budget:'; then
      budget="$(echo "$line" | sed 's/.*context_budget:[[:space:]]*//' | sed 's/[[:space:]]*$//')"
    fi
  fi
done < "$ROUTING_CONFIG"

# --- Fallback to defaults if parsing found nothing ---
if [ -z "$model_id" ] || [ -z "$budget" ]; then
  default_model_for "$COMPLEXITY"
  exit 0
fi

echo "$model_id $budget"
