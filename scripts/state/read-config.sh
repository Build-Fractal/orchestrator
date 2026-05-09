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
VALID_KEYS="default_tier verification_commands context_verbosity git_isolation dispatch_budget duration_budget budget_enforcement session_weight_limit auto_proceed efficiency_footer predictive_cost_surface anomaly_cost_multiplier anomaly_retry_threshold anomaly_pass_rate_threshold anomaly_check_enabled compression.efficiency_footer.enabled compression.regression_floor model_routing_regression.pass_rate_threshold model_routing_regression.min_class_sample display_thresholds.compression_savings_pct update_source"

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
# Dotted keys (compression.*) translate '.' to '_' for the env-var name.
upper_key=$(echo "$KEY" | tr '[:lower:]' '[:upper:]' | tr '.' '_')
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

# M018/P05/T02 — dotted compression keys are nested under the `compression:`
# block in YAML. Delegate to scripts/lib/knowledge-filter.sh helpers which
# already implement the indent-aware nested parser. The helpers resolve
# project-config (`.orchestrator/config.yml`) only; --defaults / --local
# layering does not currently apply to nested compression keys (consistent
# with the existing `compression.tier1.*` / `compression.tier2.*` pattern
# used by build-context.sh).
if [[ "$KEY" = "compression.efficiency_footer.enabled" ]] || [[ "$KEY" = "compression.regression_floor" ]]; then
  _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _PROJECT_ROOT="$(cd "$_SCRIPT_DIR/../.." && pwd)"
  # shellcheck disable=SC1091
  . "$_PROJECT_ROOT/scripts/lib/knowledge-filter.sh"
  case "$KEY" in
    compression.efficiency_footer.enabled)
      kf_get_efficiency_footer_compression_enabled "$_PROJECT_ROOT"
      ;;
    compression.regression_floor)
      kf_get_compression_regression_floor "$_PROJECT_ROOT"
      ;;
  esac
  exit 0
fi

# M030/P06/T02 — model_routing_regression.* nested keys live under the
# `model_routing_regression:` block in `.orchestrator/config.yml`. Resolve
# project-config only (mirrors the compression.* convention above). Falls
# through to "null" when the block / sub-key is absent so callers apply
# their built-in defaults.
if [[ "$KEY" = "model_routing_regression.pass_rate_threshold" ]] || [[ "$KEY" = "model_routing_regression.min_class_sample" ]]; then
  _MRR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _MRR_PROJECT_ROOT="$(cd "$_MRR_SCRIPT_DIR/../.." && pwd)"
  _MRR_CFG="$_MRR_PROJECT_ROOT/.orchestrator/config.yml"
  _mrr_val=""
  if [[ -f "$_MRR_CFG" ]]; then
    sub_key="${KEY#model_routing_regression.}"
    _mrr_val="$(awk -v sk="$sub_key" '
      BEGIN { in_block = 0 }
      /^model_routing_regression:/      { in_block = 1; next }
      in_block && /^[a-zA-Z_]/          { exit }
      in_block && /^[[:space:]]+[a-z_]+:/ {
        line = $0
        sub(/^[[:space:]]+/, "", line)
        split(line, kv, ":")
        if (kv[1] == sk) {
          val = kv[2]
          gsub(/[[:space:]]/, "", val)
          gsub(/[",]/, "", val)
          print val
          exit
        }
      }
    ' "$_MRR_CFG" 2>/dev/null || true)"
  fi
  if [[ -n "$_mrr_val" ]]; then
    echo "$_mrr_val"
  else
    echo "null"
  fi
  exit 0
fi

# M029/P03/T01 — display_thresholds.compression_savings_pct lives under
# the `display_thresholds:` block in `templates/orchestrator-config-default.yml`
# and (when an operator has overridden it) `.orchestrator/config.yml`.
# Resolve the same way as model_routing_regression.* above: nested-block
# walker against the project config; defaults file fallback; "null" when
# absent so the consumer (render-position.sh --live) applies its built-in
# 5.0 hard-coded fallback (Principle XI fail-open / AD-5).
if [[ "$KEY" = "display_thresholds.compression_savings_pct" ]]; then
  _DT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  _DT_PROJECT_ROOT="$(cd "$_DT_SCRIPT_DIR/../.." && pwd)"
  _DT_CFG="$_DT_PROJECT_ROOT/.orchestrator/config.yml"
  _DT_DEFAULTS="$_DT_PROJECT_ROOT/templates/orchestrator-config-default.yml"
  _dt_val=""
  for _dt_file in "$_DT_CFG" "$_DT_DEFAULTS"; do
    if [[ -f "$_dt_file" ]]; then
      sub_key="${KEY#display_thresholds.}"
      _dt_val="$(awk -v sk="$sub_key" '
        BEGIN { in_block = 0 }
        /^display_thresholds:/             { in_block = 1; next }
        in_block && /^[a-zA-Z_]/           { exit }
        in_block && /^[[:space:]]+[a-z_]+:/ {
          line = $0
          sub(/^[[:space:]]+/, "", line)
          split(line, kv, ":")
          if (kv[1] == sk) {
            val = kv[2]
            gsub(/[[:space:]]/, "", val)
            gsub(/[",]/, "", val)
            sub(/#.*$/, "", val)
            print val
            exit
          }
        }
      ' "$_dt_file" 2>/dev/null || true)"
      if [[ -n "$_dt_val" ]]; then
        break
      fi
    fi
  done
  if [[ -n "$_dt_val" ]]; then
    echo "$_dt_val"
  else
    echo "null"
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
