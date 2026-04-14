#!/usr/bin/env bash
# scripts/diagnostics/check-recipe.sh — Recipe conformance diagnostic
#
# Validates the structure of a context-recipe.yaml file:
#   1. Required fields — each section must have source, priority, order, filter, cache_hint
#   2. Valid source types — source must be a known type or end in .md
#   3. Valid priorities — priority must be required, compressible, or optional
#
# Usage:
#   check-recipe.sh [--root <project-root>] [--recipe <file>]
#
# Options:
#   --root    Project root directory (default: PROJECT_ROOT env or two levels up)
#   --recipe  Recipe file to validate (default: templates/context-recipe.yaml)
#
# Output: DOCTOR:RECIPE status=<ok|warn> sections=N invalid=N
#
# Bash 3.2 compatible. No jq. No associative arrays.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
_LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
RECIPE_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root) PROJECT_ROOT="$2"; shift 2 ;;
    --recipe) RECIPE_FILE="$2"; shift 2 ;;
    *) echo "check-recipe.sh: unknown option: $1" >&2; exit 1 ;;
  esac
done

# Default recipe path if not specified
if [ -z "$RECIPE_FILE" ]; then
  RECIPE_FILE="$PROJECT_ROOT/templates/context-recipe.yaml"
fi

# --- Source recipe parser ---
# shellcheck source=../lib/recipe-parser.sh
. "$_LIB_DIR/recipe-parser.sh"

# --- Optional engine integration (P02 libs) ---
if [ -n "${ORCH_RUN_ID:-}" ]; then
  # shellcheck source=../lib/errors.sh
  . "$_LIB_DIR/errors.sh"
  # shellcheck source=../lib/events.sh
  . "$_LIB_DIR/events.sh"
fi

# --- Validate recipe file exists ---
if [ ! -f "$RECIPE_FILE" ]; then
  printf 'DOCTOR:RECIPE status=warn sections=0 invalid=0\n'
  printf '  INVALID: recipe file not found: %s\n' "$RECIPE_FILE"
  if [ -n "${ORCH_RUN_ID:-}" ]; then
    emit_event VERIFY_COMPLETE check=recipe status=warn detail="recipe file not found" >&2
    emit_result error CONFIG "recipe file not found: $RECIPE_FILE" >&2
  fi
  exit 1
fi

# --- Known source types ---
KNOWN_SOURCES="computed
file
phase_summaries
phase_plan
task_plan
template
index"

# --- Known priority values ---
KNOWN_PRIORITIES="required
compressible
optional"

# --- Helper: check if value is in a newline-separated list ---
is_in_list() {
  local value="$1"
  local list="$2"
  local item
  while IFS= read -r item; do
    [ -z "$item" ] && continue
    if [ "$value" = "$item" ]; then
      return 0
    fi
  done <<LIST_EOF
$list
LIST_EOF
  return 1
}

# --- Helper: check if source is valid ---
is_valid_source() {
  local source="$1"
  # Known type
  if is_in_list "$source" "$KNOWN_SOURCES"; then
    return 0
  fi
  # File path ending in .md
  case "$source" in
    *.md) return 0 ;;
  esac
  return 1
}

# --- Helper: check if priority is valid ---
is_valid_priority() {
  local priority="$1"
  is_in_list "$priority" "$KNOWN_PRIORITIES"
}

# --- Parse recipe sections ---
sections_output=""
sections_output="$(parse_recipe_sections "$RECIPE_FILE")" || {
  printf 'DOCTOR:RECIPE status=warn sections=0 invalid=0\n'
  printf '  INVALID: failed to parse recipe file: %s\n' "$RECIPE_FILE"
  if [ -n "${ORCH_RUN_ID:-}" ]; then
    emit_event VERIFY_COMPLETE check=recipe status=warn detail="parse failure" >&2
    emit_result error CONFIG "failed to parse recipe: $RECIPE_FILE" >&2
  fi
  exit 1
}

# --- Validate each section ---
total=0
invalid=0
invalid_list=""

while IFS= read -r line; do
  [ -z "$line" ] && continue

  total=$((total + 1))

  # Format: <name>|<source>|<priority>|<order>|<filter>|<cache_hint>
  name="$(echo "$line" | cut -d'|' -f1)"
  source="$(echo "$line" | cut -d'|' -f2)"
  priority="$(echo "$line" | cut -d'|' -f3)"
  order="$(echo "$line" | cut -d'|' -f4)"
  filter="$(echo "$line" | cut -d'|' -f5)"
  cache_hint="$(echo "$line" | cut -d'|' -f6)"

  reasons=""

  # Check required fields are non-empty
  if [ -z "$source" ]; then
    reasons="${reasons}missing source; "
  fi
  if [ -z "$priority" ]; then
    reasons="${reasons}missing priority; "
  fi
  if [ -z "$order" ]; then
    reasons="${reasons}missing order; "
  fi
  if [ -z "$filter" ]; then
    reasons="${reasons}missing filter; "
  fi
  if [ -z "$cache_hint" ]; then
    reasons="${reasons}missing cache_hint; "
  fi

  # Validate source type (only if source is non-empty)
  if [ -n "$source" ] && ! is_valid_source "$source"; then
    reasons="${reasons}unknown source type '$source'; "
  fi

  # Validate priority (only if priority is non-empty)
  if [ -n "$priority" ] && ! is_valid_priority "$priority"; then
    reasons="${reasons}unknown priority '$priority'; "
  fi

  # If any issues, record as invalid
  if [ -n "$reasons" ]; then
    invalid=$((invalid + 1))
    # Trim trailing "; "
    reasons="$(echo "$reasons" | sed 's/; $//')"
    invalid_list="${invalid_list}  INVALID: ${name} -- ${reasons}
"
  fi

done <<SECTIONS_EOF
$sections_output
SECTIONS_EOF

# --- Report ---
if [ "$invalid" -eq 0 ]; then
  status="ok"
else
  status="warn"
fi

printf 'DOCTOR:RECIPE status=%s sections=%d invalid=%d\n' "$status" "$total" "$invalid"

if [ "$status" = "warn" ] && [ -n "$invalid_list" ]; then
  printf '%s' "$invalid_list"
fi

# --- Engine integration ---
if [ -n "${ORCH_RUN_ID:-}" ]; then
  if [ "$status" = "ok" ]; then
    emit_event VERIFY_COMPLETE check=recipe status=ok sections="$total" >&2
    emit_result ok "" "recipe conformance: $total sections, all valid" >&2
  else
    emit_event VERIFY_COMPLETE check=recipe status=warn sections="$total" invalid="$invalid" >&2
    emit_result error VERIFY "recipe conformance: $total sections, $invalid invalid" >&2
  fi
fi

if [ "$status" = "warn" ]; then
  exit 1
fi
exit 0
