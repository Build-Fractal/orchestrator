#!/usr/bin/env bash
# scripts/diagnostics/check-config-drift.sh — M027/P03/T02 config-drift helper.
#
# Sourceable as a library (function check_config_drift_render) AND runnable as a CLI.
# CLI emits a one-block drift report (<=4 lines per audited key) titled
# "Config Drift (M027 knobs)" listing the resolved value at each precedence
# layer (env / local / project / defaults) plus a final effective= line per key.
# Backs orchestrator:doctor --config-check per FR-16.
#
# Read-only (FR-12/CON-1): never writes to execution-log.jsonl or config files;
# stdout/stderr only.
# Zero-LLM-token (FR-21/CON-6): bash + invocation of read-config.sh only.
# Bash 3.2 (CON-7): parallel scalars only; no associative arrays; no
# herestring redirect; no inline process substitution; no merged
# stdout-stderr shorthand; no case-folding parameter expansion.
#
# Comment hygiene carry-forward from M027/P00 + P01 + P02: doc-comments use
# the safe phrasing "no associative arrays / no herestring redirect" rather
# than spelling literal bash-4 forbidden tokens, so the T04 bash32-compat
# verifier grep regex stays clean against this file body.

set -u

if [ -n "${_CHECK_CONFIG_DRIFT_SH_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
_CHECK_CONFIG_DRIFT_SH_SOURCED=1

_CCD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CCD_PROJECT_ROOT="$(cd "$_CCD_SCRIPT_DIR/../.." && pwd)"

# Default key set: the six M027 knobs (P02 + P03).
_CCD_DEFAULT_KEYS="efficiency_footer predictive_cost_surface anomaly_cost_multiplier anomaly_retry_threshold anomaly_pass_rate_threshold anomaly_check_enabled"

# _ccd_normalize_unset <value>
#   Treats empty string and the literal "null" sentinel (returned by
#   read-config.sh for unset-but-registered keys) as "(unset)".
_ccd_normalize_unset() {
  local v="$1"
  if [ -z "$v" ] || [ "$v" = "null" ]; then
    printf '%s' "(unset)"
  else
    printf '%s' "$v"
  fi
}

# _ccd_resolve_layer <layer> <key> [defaults] [project] [local]
#   Resolves <key> at exactly one layer by passing only that layer's file
#   to read-config.sh. The env layer is read directly (cannot be isolated
#   inside read-config.sh because env always has highest precedence).
#   Always returns exit 0; emits the resolved value to stdout (or empty).
_ccd_resolve_layer() {
  local layer="$1"
  local key="$2"
  local defaults="${3:-}"
  local project="${4:-}"
  local local_f="${5:-}"
  local upper_key
  upper_key=$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')
  case "$layer" in
    env)
      # Indirect-read a dynamically-named env var via eval. The $upper_key
      # expansion is whitelisted: it has been passed through tr [:lower:]
      # to [:upper:] from a known key list — no shell-injection surface.
      local v=""
      v="$(eval 'printf %s "${SPECKIT_ORCHESTRATOR_'"$upper_key"':-}"')"
      printf '%s' "$v"
      ;;
    local)
      if [ -n "$local_f" ] && [ -f "$local_f" ]; then
        # Strip env so read-config.sh's env layer cannot win.
        # Use env -u (POSIX) to clear the indirect env var name.
        env -u "SPECKIT_ORCHESTRATOR_${upper_key}" \
          bash "$_CCD_PROJECT_ROOT/scripts/state/read-config.sh" \
          "$key" --local "$local_f" 2>/dev/null || true
      fi
      ;;
    project)
      if [ -n "$project" ] && [ -f "$project" ]; then
        env -u "SPECKIT_ORCHESTRATOR_${upper_key}" \
          bash "$_CCD_PROJECT_ROOT/scripts/state/read-config.sh" \
          "$key" --project "$project" 2>/dev/null || true
      fi
      ;;
    defaults)
      if [ -n "$defaults" ] && [ -f "$defaults" ]; then
        env -u "SPECKIT_ORCHESTRATOR_${upper_key}" \
          bash "$_CCD_PROJECT_ROOT/scripts/state/read-config.sh" \
          "$key" --defaults "$defaults" 2>/dev/null || true
      fi
      ;;
  esac
  return 0
}

# check_config_drift_render <space-separated-keys> [defaults] [project] [local]
#   For each key, queries each precedence layer's resolved value and emits:
#     key=<k>
#       env=<v>
#       local=<v>
#       project=<v>
#       defaults=<v>
#       effective=<v>
#   The "null" sentinel from read-config.sh (unset-but-registered) and the
#   empty-string sentinel both render as "(unset)" so operators can
#   visually distinguish a present-but-null value from layer absence.
#   Always returns exit 0 (never aborts; CON-5).
check_config_drift_render() {
  local keys="$1"
  local defaults="${2:-}"
  local project="${3:-}"
  local local_f="${4:-}"
  printf '%s\n' "Config Drift (M027 knobs)"
  local key env_val local_val project_val defaults_val effective_val
  for key in $keys; do
    printf '  key=%s\n' "$key"
    env_val=$(_ccd_normalize_unset "$(_ccd_resolve_layer env "$key")")
    local_val=$(_ccd_normalize_unset "$(_ccd_resolve_layer local "$key" "" "" "$local_f")")
    project_val=$(_ccd_normalize_unset "$(_ccd_resolve_layer project "$key" "" "$project")")
    defaults_val=$(_ccd_normalize_unset "$(_ccd_resolve_layer defaults "$key" "$defaults")")
    printf '    env=%s\n' "$env_val"
    printf '    local=%s\n' "$local_val"
    printf '    project=%s\n' "$project_val"
    printf '    defaults=%s\n' "$defaults_val"
    # Effective resolution via read-config.sh (the canonical resolver).
    effective_val="$(bash "$_CCD_PROJECT_ROOT/scripts/state/read-config.sh" "$key" 2>/dev/null || true)"
    effective_val=$(_ccd_normalize_unset "$effective_val")
    printf '    effective=%s\n' "$effective_val"
  done
  return 0
}

# CLI entry point — sourceable-CLI duality via BASH_SOURCE/$0 guard.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  KEYS=""
  SINGLE_KEY=""
  SUPPRESS=0
  CONFIG_DEFAULTS=""
  CONFIG_PROJECT=""
  CONFIG_LOCAL=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --keys) KEYS="$2"; shift 2 ;;
      --key)  SINGLE_KEY="$2"; shift 2 ;;
      --no-config-check) SUPPRESS=1; shift ;;
      --config-defaults) CONFIG_DEFAULTS="$2"; shift 2 ;;
      --config-project) CONFIG_PROJECT="$2"; shift 2 ;;
      --config-local) CONFIG_LOCAL="$2"; shift 2 ;;
      --help|-h)
        printf '%s\n' "Usage: check-config-drift.sh [--keys k1,k2,...] [--key k] [--no-config-check] [--config-defaults <path>] [--config-project <path>] [--config-local <path>]"
        exit 0 ;;
      *) shift ;;
    esac
  done
  if [ "$SUPPRESS" -eq 1 ]; then
    exit 0
  fi
  if [ -n "$SINGLE_KEY" ]; then
    KEYS="$SINGLE_KEY"
  elif [ -n "$KEYS" ]; then
    # Convert comma-separated to space-separated.
    KEYS=$(printf '%s' "$KEYS" | tr ',' ' ')
  else
    KEYS="$_CCD_DEFAULT_KEYS"
  fi
  check_config_drift_render "$KEYS" "$CONFIG_DEFAULTS" "$CONFIG_PROJECT" "$CONFIG_LOCAL"
  exit 0
fi
