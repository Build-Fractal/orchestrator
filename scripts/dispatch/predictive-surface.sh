#!/usr/bin/env bash
# scripts/dispatch/predictive-surface.sh -- M027/P02/T03 dispatch-time predictive surface helper.
#
# Sourceable as a library (function predictive_surface_render) AND runnable as a CLI.
# Default mode (interactive, intensity in {standard,full}, none of the suppression
# conditions met) renders a one-block predictive surface -- recommended tier
# highlighted, per-tier cost+quality table, one-line override prompt.
# Suppressed mode (any of: --yes, ORCHESTRATOR_AUTO=1, --no-predict,
# config.predictive_cost_surface=false, intensity=quick) emits zero stdout,
# exit 0 -- load-bearing CON-3/SC-17 byte-identity contract.
#
# Read-only (FR-12/CON-1): never writes to execution-log.jsonl or config.
# Zero-LLM-token (FR-21/CON-6): bash + invocation of intensity-recommend.sh only.
# Bash 3.2 (CON-7): parallel scalars only; no associative arrays; no herestring redirect.
# CON-10 (operator-override preserved): one-line override prompt on last line.
#
# Comment hygiene (M027/P00 + P01 carry-forward): doc-comments do not list
# bash-4 forbidden constructs literally -- "no herestring redirect" is the safe
# phrasing; the literal forbidden tokens do NOT appear in this file body.

set -u

if [ -n "${_PREDICTIVE_SURFACE_SH_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
_PREDICTIVE_SURFACE_SH_SOURCED=1

_PS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PS_PROJECT_ROOT="$(cd "$_PS_SCRIPT_DIR/../.." && pwd)"

# predictive_surface_render <description> <intensity> <suppress-flag>
#   When <suppress-flag> = 1, emits zero stdout (and returns 0).
#   When <intensity> = quick, emits zero stdout (suppression by tier).
#   Else emits the one-block predictive surface to stdout; returns 0.
predictive_surface_render() {
  local description="$1"
  local intensity="$2"
  local suppress="$3"
  if [ "$suppress" = "1" ]; then
    return 0
  fi
  case "$intensity" in
    standard|full) ;;
    *) return 0 ;;
  esac
  # Pre-set the recommendation slot + fast-path env so the inner
  # intensity-recommend re-fork is short-circuited.
  export INTENSITY_RECOMMEND_FAST_PATH=1
  _CE_RECOMMENDED="$intensity"
  export _CE_RECOMMENDED
  # Invoke the P01 cost-annotation hook (text mode). Pass deterministic
  # --analyze-output and --profile-output strings so the inner
  # intensity-analyze.sh + detect-capabilities.sh forks are bypassed
  # (latency optimization; mirrors the P01/T04 verifier pattern).
  # The capitalized intensity matches intensity-recommend.sh's expected
  # recommended_intensity values (Quick|Standard|Full).
  local cap_intensity
  case "$intensity" in
    standard) cap_intensity="Standard" ;;
    full)     cap_intensity="Full" ;;
    *)        cap_intensity="Standard" ;;
  esac
  local analyze_block profile_block
  analyze_block="scope=moderate
risk_level=medium
complexity=moderate
risk_signals=none
recommended_intensity=$cap_intensity"
  profile_block="cap_score=3"
  local hook_out
  hook_out="$(bash "$_PS_PROJECT_ROOT/scripts/engine/intensity-recommend.sh" \
    --description "$description" \
    --format text \
    --analyze-output "$analyze_block" \
    --profile-output "$profile_block" \
    2>/dev/null || true)"
  if [ -z "$hook_out" ]; then
    # Degraded -- emit a minimal one-line surface with a pricing-warning hint.
    printf '%s\n' "predictive_cost_surface: estimate unavailable; recommended=$intensity (override: --no-predict to skip)"
    return 0
  fi
  # Render the surface block.
  printf '%s\n' "predictive_cost_surface (M027/P02)"
  printf '%s\n' "  recommended: $intensity"
  # Stream the cost-annotation block (lines starting with cost_ or the
  # '# cost estimates' header) verbatim. Goodhart pairing (CON-4/SC-18)
  # is inherited from the P01 cost-annotation hook -- every cost_*_usd
  # line is paired with a cost_*_quality line on adjacent rows.
  printf '%s\n' "$hook_out" | grep -E '^cost_|^# cost estimates' || true
  printf '%s\n' "  override: press 1=quick 2=standard 3=full, or Enter to accept recommended (or pass --no-predict to skip)"
  return 0
}

# CLI entry point -- only when invoked as a script (not sourced).
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  DESCRIPTION=""
  INTENSITY=""
  NO_PREDICT=0
  YES_FLAG=0
  CONFIG_DEFAULTS=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --description) DESCRIPTION="$2"; shift 2 ;;
      --intensity)   INTENSITY="$2"; shift 2 ;;
      --no-predict)  NO_PREDICT=1; shift ;;
      --yes)         YES_FLAG=1; shift ;;
      --config-defaults) CONFIG_DEFAULTS="$2"; shift 2 ;;
      --help|-h)
        printf '%s\n' "Usage: predictive-surface.sh --description <text> --intensity quick|standard|full [--no-predict] [--yes] [--config-defaults <path>]"
        exit 0 ;;
      *) shift ;;
    esac
  done
  if [ -z "$DESCRIPTION" ] || [ -z "$INTENSITY" ]; then
    printf '%s\n' "ERROR: --description and --intensity are required" >&2
    exit 2
  fi

  # Resolve suppression conditions.
  SUPPRESS=0
  if [ "$NO_PREDICT" -eq 1 ]; then SUPPRESS=1; fi
  if [ "$YES_FLAG" -eq 1 ]; then SUPPRESS=1; fi
  if [ -n "${ORCHESTRATOR_AUTO:-}" ] && [ "$ORCHESTRATOR_AUTO" != "0" ]; then
    SUPPRESS=1
  fi

  # Resolve config knob -- env var ORCH_PREDICTIVE_COST_SURFACE overrides;
  # then read-config. When config resolves to "false", force suppress.
  if [ "$SUPPRESS" -eq 0 ]; then
    cfg_val="${ORCH_PREDICTIVE_COST_SURFACE:-}"
    if [ -z "$cfg_val" ] && [ -r "$_PS_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
      if [ -n "$CONFIG_DEFAULTS" ]; then
        cfg_val="$(bash "$_PS_PROJECT_ROOT/scripts/state/read-config.sh" predictive_cost_surface "$CONFIG_DEFAULTS" 2>/dev/null || true)"
      else
        cfg_val="$(bash "$_PS_PROJECT_ROOT/scripts/state/read-config.sh" predictive_cost_surface 2>/dev/null || true)"
      fi
    fi
    case "$cfg_val" in
      false|FALSE|False|0|no|NO) SUPPRESS=1 ;;
    esac
  fi

  predictive_surface_render "$DESCRIPTION" "$INTENSITY" "$SUPPRESS"
  exit 0
fi
