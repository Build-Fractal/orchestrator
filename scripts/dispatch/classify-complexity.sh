#!/usr/bin/env bash
# scripts/dispatch/classify-complexity.sh — Classify task complexity
# Analyzes a task plan and outputs its complexity tier (heavy, standard, light).
#
# Usage: classify-complexity.sh <task-plan-file> [--routing-config <routing.yaml>]
#
# Classification priority:
#   1. Explicit `complexity:` in YAML frontmatter (override)
#   2. Custom classification keywords from routing.yaml (if provided)
#   3. Built-in signal keyword matching
#   4. Default: "standard"
#
# Output: one of "heavy", "standard", "light" to stdout
# Exit 0 on success, 1 on missing arguments.
#
# Bash 3.2 compatible — no jq/yq dependency.

set -euo pipefail

TASK_PLAN="${1:?Usage: classify-complexity.sh <task-plan-file> [--routing-config <file>]}"
ROUTING_CONFIG=""

shift
while [ $# -gt 0 ]; do
  case "$1" in
    --routing-config) ROUTING_CONFIG="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ ! -f "$TASK_PLAN" ]; then
  echo "Error: task plan not found: $TASK_PLAN" >&2
  exit 1
fi

# --- Check for explicit complexity in YAML frontmatter ---
explicit=$(sed -n '/^---$/,/^---$/p' "$TASK_PLAN" | grep '^complexity:' | head -1 | sed 's/complexity:[[:space:]]*//' | sed 's/[[:space:]]*$//' || true)
if [ -n "$explicit" ]; then
  case "$explicit" in
    heavy|standard|light) echo "$explicit"; exit 0 ;;
  esac
fi

# --- Read the full task plan content (lowercase for matching) ---
content="$(tr '[:upper:]' '[:lower:]' < "$TASK_PLAN")"

# --- Count signals for each tier ---
heavy_count=0
standard_count=0
light_count=0

# Heavy signals
for keyword in "new subsystem" "rewrite" "architect" "from scratch" "high risk" "complex" "foundation"; do
  if printf '%s' "$content" | grep -q "$keyword"; then
    heavy_count=$((heavy_count + 1))
  fi
done

# Standard signals
for keyword in "implement" "feature" "modify" "extend" "update" "enhance" "integrate"; do
  if printf '%s' "$content" | grep -q "$keyword"; then
    standard_count=$((standard_count + 1))
  fi
done

# Light signals
for keyword in "config" "test" "document" "single file" "rename" "typo" "template" "wrapper" "thin"; do
  if printf '%s' "$content" | grep -q "$keyword"; then
    light_count=$((light_count + 1))
  fi
done

# --- Pick the tier with most signals ---
if [ "$heavy_count" -gt "$standard_count" ] && [ "$heavy_count" -gt "$light_count" ]; then
  echo "heavy"
elif [ "$light_count" -gt "$standard_count" ] && [ "$light_count" -ge "$heavy_count" ]; then
  echo "light"
else
  echo "standard"
fi
