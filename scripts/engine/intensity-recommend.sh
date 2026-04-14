#!/usr/bin/env bash
# scripts/engine/intensity-recommend.sh — Intensity recommendation engine.
# Combines scope analysis (intensity-analyze.sh) + capability profile
# (detect-capabilities.sh --profile) into a final intensity recommendation
# with confidence and reasoning. Part of M008 Adaptive Intensity Engine
# (FR-001, FR-005, FR-025).
#
# Usage: intensity-recommend.sh [--analyze-output "text"] [--profile-output "text"]
#                                [--description "text"]
#   --analyze-output: pre-computed output from intensity-analyze.sh
#   --profile-output: pre-computed output from detect-capabilities.sh --profile
#   --description:    task description (runs intensity-analyze.sh internally)
#   If no flags given, reads description from stdin and runs both scripts.
#
# Output (stdout, key=value):
#   intensity=Quick|Standard|Full
#   confidence=high|medium|low
#   reasoning=<explanation>
#   scope=<from analyze>
#   risk_level=<from analyze>
#   complexity=<from analyze>
#   risk_signals=<from analyze>
#   cap_score=<from profile>
#
# Exit: 0 success, 1 error.
# Bash 3.2 compatible (NFR-200).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ANALYZE_OUTPUT=""
PROFILE_OUTPUT=""
DESCRIPTION=""

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --analyze-output)
      ANALYZE_OUTPUT="$2"; shift 2 ;;
    --profile-output)
      PROFILE_OUTPUT="$2"; shift 2 ;;
    --description)
      DESCRIPTION="$2"; shift 2 ;;
    *)
      shift ;;
  esac
done

# If --analyze-output value is an existing file path, read its contents.
# Otherwise treat the value as inline text (as used by verification scripts).
if [[ -n "$ANALYZE_OUTPUT" ]] && [[ -f "$ANALYZE_OUTPUT" ]]; then
  ANALYZE_OUTPUT="$(cat "$ANALYZE_OUTPUT")"
fi
if [[ -n "$PROFILE_OUTPUT" ]] && [[ -f "$PROFILE_OUTPUT" ]]; then
  PROFILE_OUTPUT="$(cat "$PROFILE_OUTPUT")"
fi

# If no analyze output provided, run intensity-analyze.sh
if [[ -z "$ANALYZE_OUTPUT" ]]; then
  if [[ -z "$DESCRIPTION" ]]; then
    if [[ -t 0 ]]; then
      echo "ERROR: no description or analyze output provided." >&2
      exit 1
    fi
    DESCRIPTION="$(cat)"
  fi
  ANALYZE_OUTPUT="$(echo "$DESCRIPTION" | bash "$SCRIPT_DIR/intensity-analyze.sh" 2>/dev/null)"
fi

# If no profile output provided, run detect-capabilities.sh --profile
if [[ -z "$PROFILE_OUTPUT" ]]; then
  PROFILE_OUTPUT="$(bash "$REPO_ROOT/scripts/dispatch/detect-capabilities.sh" --profile 2>/dev/null)"
fi

# --- Parse analyze output ---
# Extract values using grep + cut (no associative arrays)
scope="$(echo "$ANALYZE_OUTPUT" | grep "^scope=" | head -1 | cut -d= -f2)"
risk_level="$(echo "$ANALYZE_OUTPUT" | grep "^risk_level=" | head -1 | cut -d= -f2)"
complexity="$(echo "$ANALYZE_OUTPUT" | grep "^complexity=" | head -1 | cut -d= -f2)"
risk_signals="$(echo "$ANALYZE_OUTPUT" | grep "^risk_signals=" | head -1 | cut -d= -f2-)"
base_intensity="$(echo "$ANALYZE_OUTPUT" | grep "^recommended_intensity=" | head -1 | cut -d= -f2)"

# --- Parse capability profile ---
cap_score="$(echo "$PROFILE_OUTPUT" | grep "^cap_score=" | head -1 | cut -d= -f2)"
cap_score="${cap_score:-0}"

# --- Apply decision matrix ---
intensity="$base_intensity"
confidence="high"

# Risk escalation: risk overrides convenience
if [[ "$risk_level" = "high" ]] && [[ "$intensity" = "Quick" ]]; then
  intensity="Standard"
fi

# Risk + complexity double-escalation
if [[ "$risk_level" = "high" ]] && [[ "$complexity" = "complex" ]]; then
  intensity="Full"
fi

# Specific risk signal escalation (migration, security, auth -> at least Standard)
if [[ "$risk_signals" != "none" ]]; then
  for escalation_signal in "migration" "security" "auth"; do
    if echo "$risk_signals" | grep -qF "$escalation_signal"; then
      if [[ "$intensity" = "Quick" ]]; then
        intensity="Standard"
      fi
      break
    fi
  done
fi

# Confidence adjustment based on capability score
if [[ "$intensity" = "Full" ]] && [[ "$cap_score" -le 1 ]]; then
  confidence="medium"
fi

# --- Build reasoning ---
signal_clause=""
if [[ "$risk_signals" != "none" ]]; then
  signal_clause=" with signals: $risk_signals"
fi

reasoning="${intensity} recommended: scope is ${scope}, risk is ${risk_level}${signal_clause}, complexity is ${complexity}, environment has ${cap_score}/5 capabilities."

# --- Output ---
echo "intensity=$intensity"
echo "confidence=$confidence"
echo "reasoning=$reasoning"
echo "scope=$scope"
echo "risk_level=$risk_level"
echo "complexity=$complexity"
echo "risk_signals=$risk_signals"
echo "cap_score=$cap_score"
