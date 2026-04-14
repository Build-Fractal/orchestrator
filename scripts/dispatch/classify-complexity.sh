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

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_LIB_DIR="$(cd "$_SCRIPT_DIR/../lib" && pwd)"
. "$_LIB_DIR/errors.sh"
. "$_LIB_DIR/events.sh"

_CC_RESULT_EMITTED=0
_cc_final_result() {
  local rc=$?
  if [ "$_CC_RESULT_EMITTED" -eq 0 ] && [ -n "${ORCH_RUN_ID:-}" ]; then
    if [ "$rc" -eq 0 ]; then
      emit_result ok "" "complexity classified" >&2
    else
      emit_result error DISPATCH "classify-complexity failed rc=$rc" >&2
    fi
    _CC_RESULT_EMITTED=1
  fi
}
trap _cc_final_result EXIT

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

if [ -n "${ORCH_RUN_ID:-}" ]; then
  emit_event DISPATCH_START stage=classify_complexity task_plan="$(basename "$TASK_PLAN")" >&2
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

# --- Custom classification keywords from routing config (if provided) ---
_use_custom=0
if [ -n "$ROUTING_CONFIG" ] && [ -f "$ROUTING_CONFIG" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
  # shellcheck source=/dev/null
  . "$PROJECT_ROOT/scripts/lib/recipe-parser.sh"

  _heavy_patterns="$(read_recipe_field "$ROUTING_CONFIG" "classification.heavy.patterns" 2>/dev/null || true)"
  _standard_patterns="$(read_recipe_field "$ROUTING_CONFIG" "classification.standard.patterns" 2>/dev/null || true)"
  _light_patterns="$(read_recipe_field "$ROUTING_CONFIG" "classification.light.patterns" 2>/dev/null || true)"

  if [ -n "$_heavy_patterns" ] || [ -n "$_standard_patterns" ] || [ -n "$_light_patterns" ]; then
    _use_custom=1

    # Count matches for each tier's custom patterns (comma-separated)
    for tier_label in heavy standard light; do
      case "$tier_label" in
        heavy)    _patterns="$_heavy_patterns" ;;
        standard) _patterns="$_standard_patterns" ;;
        light)    _patterns="$_light_patterns" ;;
      esac
      [ -z "$_patterns" ] && continue
      _OLDIFS="$IFS"
      IFS=','
      # shellcheck disable=SC2086
      set -- $_patterns
      IFS="$_OLDIFS"
      for _kw in "$@"; do
        # Trim leading/trailing whitespace
        _kw="$(echo "$_kw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')"
        [ -z "$_kw" ] && continue
        if printf '%s' "$content" | grep -q "$_kw"; then
          case "$tier_label" in
            heavy)    heavy_count=$((heavy_count + 1)) ;;
            standard) standard_count=$((standard_count + 1)) ;;
            light)    light_count=$((light_count + 1)) ;;
          esac
        fi
      done
    done
  fi
fi

# --- Built-in keyword signal matching (used when no custom patterns) ---
if [ "$_use_custom" -eq 0 ]; then

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

fi  # end built-in fallback

# --- Pick the tier with most signals ---
if [ "$heavy_count" -gt "$standard_count" ] && [ "$heavy_count" -gt "$light_count" ]; then
  echo "heavy"
elif [ "$light_count" -gt "$standard_count" ] && [ "$light_count" -ge "$heavy_count" ]; then
  echo "light"
else
  echo "standard"
fi
