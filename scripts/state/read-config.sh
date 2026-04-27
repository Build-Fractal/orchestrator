#!/usr/bin/env bash
# scripts/state/read-config.sh — Multi-layer config resolution
# Resolves a config key from 4 precedence layers (highest to lowest):
#   1. Environment variable SPECKIT_ORCHESTRATOR_<UPPER_KEY>
#   2. Local config file (--local)
#   3. Project config file (--project)
#   4. Extension defaults file (--defaults)
#
# Usage: read-config.sh <key> [--defaults <file>] [--project <file>] [--local <file>]
#        read-config.sh --key <name> [--defaults <file>] [--project <file>] [--local <file>]
#
# Outputs resolved value to stdout. Exits 1 for unknown keys.

set -euo pipefail

# Valid config keys
VALID_KEYS="default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement session_weight_limit auto_proceed efficiency_footer predictive_cost_surface anomaly_cost_multiplier anomaly_retry_threshold anomaly_pass_rate_threshold anomaly_check_enabled"

# Defaults for file paths
DEFAULTS_FILE=""
PROJECT_FILE=""
LOCAL_FILE=""
KEY=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --key)
      KEY="$2"; shift 2 ;;
    --defaults)
      DEFAULTS_FILE="$2"; shift 2 ;;
    --project)
      PROJECT_FILE="$2"; shift 2 ;;
    --local)
      LOCAL_FILE="$2"; shift 2 ;;
    --project-root)
      # Accept but use --project/--local/--defaults for explicit file paths
      shift 2 ;;
    --extension-dir)
      shift 2 ;;
    -*)
      echo "read-config.sh: unknown option '$1'" >&2; exit 1 ;;
    *)
      # Positional argument = key
      if [[ -z "$KEY" ]]; then
        KEY="$1"
      fi
      shift ;;
  esac
done

# Validate key was provided
if [[ -z "$KEY" ]]; then
  echo "read-config.sh: missing config key argument" >&2
  echo "Usage: read-config.sh <key> [--defaults <file>] [--project <file>] [--local <file>]" >&2
  exit 1
fi

# Validate key is in the valid list
key_valid=false
for valid_key in $VALID_KEYS; do
  if [[ "$valid_key" = "$KEY" ]]; then
    key_valid=true
    break
  fi
done

if [[ "$key_valid" = "false" ]]; then
  echo "read-config.sh: unknown config key '$KEY'" >&2
  echo "Valid keys: $VALID_KEYS" >&2
  exit 1
fi

# Read a value from a YAML file for a given key
# Returns empty string if not found or file doesn't exist
read_yaml_value() {
  local file="$1"
  local key="$2"

  if [[ ! -f "$file" ]]; then
    return
  fi

  # Match "key: value" at the start of a line
  # Handle arrays: key: [] should return []
  local line
  line=$(grep "^${key}:" "$file" 2>/dev/null | head -1) || true

  if [[ -z "$line" ]]; then
    return
  fi

  # Extract value after "key: " — trim leading/trailing whitespace and quotes
  local value
  value=$(echo "$line" | sed "s/^${key}:[[:space:]]*//" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

  # Strip inline comments (but not inside quotes)
  # Simple approach: strip everything after # preceded by whitespace
  value=$(echo "$value" | sed 's/[[:space:]]*#.*$//')

  # Strip surrounding quotes if present
  value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")

  echo "$value"
}

# Layer 1: Environment variable (highest precedence)
upper_key=$(echo "$KEY" | tr '[:lower:]' '[:upper:]')
env_var="SPECKIT_ORCHESTRATOR_${upper_key}"
env_value="${!env_var:-}"

if [[ -n "$env_value" ]]; then
  if [[ "$KEY" = "verification_commands" ]]; then
    # Split comma-separated values into lines
    echo "$env_value" | tr ',' '\n'
  else
    echo "$env_value"
  fi
  exit 0
fi

# Layer 2: Local config (second precedence)
if [[ -n "$LOCAL_FILE" ]]; then
  value=$(read_yaml_value "$LOCAL_FILE" "$KEY")
  if [[ -n "$value" ]]; then
    echo "$value"
    exit 0
  fi
fi

# Layer 3: Project config (third precedence)
if [[ -n "$PROJECT_FILE" ]]; then
  value=$(read_yaml_value "$PROJECT_FILE" "$KEY")
  if [[ -n "$value" ]]; then
    echo "$value"
    exit 0
  fi
fi

# Layer 4: Extension defaults (lowest precedence)
if [[ -n "$DEFAULTS_FILE" ]]; then
  value=$(read_yaml_value "$DEFAULTS_FILE" "$KEY")
  if [[ -n "$value" ]]; then
    echo "$value"
    exit 0
  fi
fi

# No value found at any layer
echo "null"
