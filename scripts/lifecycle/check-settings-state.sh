#!/usr/bin/env bash
# scripts/lifecycle/check-settings-state.sh — Permission pre-flight for auto mode
# Detects .claude/settings.json state and conditionally runs the permission
# pipeline (generate → write → drift check). Replaces inline conditional
# logic in auto mode that triggers harness safety heuristics.
#
# Usage: check-settings-state.sh <project-root>
#
# Output: Structured SETTINGS: lines.
#   SETTINGS:MISSING        — no settings.json, generated fresh
#   SETTINGS:ORCHESTRATOR   — orchestrator-generated, regenerated for drift
#   SETTINGS:USER_AUTHORED  — user-authored, merged orchestrator patterns
#   SETTINGS:EXISTS         — settings.json present (fallback when pipeline unavailable)
#   SETTINGS:ERROR          — pipeline failed
#
# Exit: 0 on success, 1 on error.
#
# Bash 3.2 compatible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${1:-.}"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"
GENERATE_SCRIPT="$SCRIPT_DIR/generate-permissions.sh"
WRITE_SCRIPT="$SCRIPT_DIR/write-permissions.sh"
CHECK_SCRIPT="$SCRIPT_DIR/../diagnostics/check-permissions.sh"
TEMPLATE="$SCRIPT_DIR/../../templates/claude-settings.json"

# Detect state
if [[ ! -f "$SETTINGS_FILE" ]]; then
  state="MISSING"
elif grep -q '"_generated_by": "speckit-orchestrator"' "$SETTINGS_FILE" 2>/dev/null; then
  state="ORCHESTRATOR"
else
  state="USER_AUTHORED"
fi

# Check if permission pipeline scripts exist
has_pipeline=true
if [[ ! -x "$GENERATE_SCRIPT" ]] || [[ ! -x "$WRITE_SCRIPT" ]]; then
  has_pipeline=false
fi

case "$state" in
  MISSING)
    if [[ "$has_pipeline" = "true" ]]; then
      # Generate from project introspection
      gen_output=$(bash "$GENERATE_SCRIPT" "$PROJECT_ROOT" 2>&1) || {
        # Fallback to template
        if [[ -f "$TEMPLATE" ]]; then
          mkdir -p "$PROJECT_ROOT/.claude"
          cp "$TEMPLATE" "$SETTINGS_FILE"
          echo "SETTINGS:MISSING — generated from template (pipeline failed)"
          exit 0
        fi
        echo "SETTINGS:ERROR — generate-permissions.sh failed and no template available" >&2
        exit 1
      }
      echo "$gen_output" | bash "$WRITE_SCRIPT" "$PROJECT_ROOT" 2>&1 || {
        echo "SETTINGS:ERROR — write-permissions.sh failed" >&2
        exit 1
      }
      echo "SETTINGS:MISSING — generated from project introspection"
    elif [[ -f "$TEMPLATE" ]]; then
      mkdir -p "$PROJECT_ROOT/.claude"
      cp "$TEMPLATE" "$SETTINGS_FILE"
      echo "SETTINGS:MISSING — generated from template"
    else
      echo "SETTINGS:ERROR — no settings.json, no pipeline, no template" >&2
      exit 1
    fi
    ;;

  ORCHESTRATOR)
    if [[ "$has_pipeline" = "true" ]]; then
      # Regenerate to catch toolchain changes
      gen_output=$(bash "$GENERATE_SCRIPT" "$PROJECT_ROOT" 2>&1) || {
        echo "SETTINGS:ORCHESTRATOR — regeneration failed, keeping existing"
        exit 0
      }
      echo "$gen_output" | bash "$WRITE_SCRIPT" "$PROJECT_ROOT" 2>&1 || {
        echo "SETTINGS:ORCHESTRATOR — write failed, keeping existing"
        exit 0
      }
      echo "SETTINGS:ORCHESTRATOR — regenerated"
    else
      echo "SETTINGS:ORCHESTRATOR — pipeline unavailable, keeping existing"
    fi
    ;;

  USER_AUTHORED)
    if [[ "$has_pipeline" = "true" ]]; then
      # Merge orchestrator patterns into existing
      gen_output=$(bash "$GENERATE_SCRIPT" "$PROJECT_ROOT" 2>&1) || {
        echo "SETTINGS:USER_AUTHORED — generation failed, keeping existing"
        exit 0
      }
      echo "$gen_output" | bash "$WRITE_SCRIPT" "$PROJECT_ROOT" --merge 2>&1 || {
        echo "SETTINGS:USER_AUTHORED — merge failed, keeping existing"
        exit 0
      }
      echo "SETTINGS:USER_AUTHORED — merged orchestrator patterns"
    else
      echo "SETTINGS:USER_AUTHORED — pipeline unavailable, keeping existing"
    fi
    ;;
esac

# Run drift check if available
if [[ -x "$CHECK_SCRIPT" ]]; then
  drift_output=$(bash "$CHECK_SCRIPT" "$PROJECT_ROOT" 2>&1) || true
  echo "$drift_output"
fi

exit 0
