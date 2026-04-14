#!/usr/bin/env bash
# scripts/engine/context-pressure.sh — Context window pressure evaluator.
# Evaluates estimated token count against configurable thresholds to prevent
# dispatching oversized payloads that degrade agent output quality.
# Part of M008 Adaptive Intensity Engine (AD-04, DC-05, OQ-03).
#
# Usage: context-pressure.sh --tokens N [--intensity Quick|Standard|Full]
#                              [--context-window N]
#   --tokens:         estimated token count
#   --intensity:      current intensity level (default: Standard)
#   --context-window: context window size (default: $CONTEXT_WINDOW_TOKENS or 200000)
#
# Environment overrides:
#   CONTEXT_WINDOW_TOKENS   — context window size (default: 200000)
#   PRESSURE_WARN_PCT       — warn threshold % (default: 60)
#   PRESSURE_DECOMPOSE_PCT  — decompose threshold % (default: 75)
#   PRESSURE_REFUSE_PCT     — refuse threshold % (default: 85)
#
# Output (stdout, key=value):
#   pressure=low|medium|high|critical
#   action=proceed|warn|decompose|refuse
#   utilization_pct=<0-100>
#   threshold_warn=<token count>
#   threshold_decompose=<token count>
#   threshold_refuse=<token count>
#
# Exit: 0 always (pressure evaluation never fails).
# Bash 3.2 compatible (NFR-200).

set -euo pipefail

# --- Defaults ---
TOKENS=0
INTENSITY="Standard"
CONTEXT_WINDOW="${CONTEXT_WINDOW_TOKENS:-200000}"
WARN_PCT="${PRESSURE_WARN_PCT:-60}"
DECOMPOSE_PCT="${PRESSURE_DECOMPOSE_PCT:-75}"
REFUSE_PCT="${PRESSURE_REFUSE_PCT:-85}"

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tokens)
      TOKENS="$2"; shift 2 ;;
    --intensity)
      INTENSITY="$2"; shift 2 ;;
    --context-window)
      CONTEXT_WINDOW="$2"; shift 2 ;;
    *)
      shift ;;
  esac
done

# --- Validate numeric inputs ---
# Default to safe values if inputs are not numeric
case "$TOKENS" in
  ''|*[!0-9]*) TOKENS=0 ;;
esac
case "$CONTEXT_WINDOW" in
  ''|*[!0-9]*) CONTEXT_WINDOW=200000 ;;
esac
case "$WARN_PCT" in
  ''|*[!0-9]*) WARN_PCT=60 ;;
esac
case "$DECOMPOSE_PCT" in
  ''|*[!0-9]*) DECOMPOSE_PCT=75 ;;
esac
case "$REFUSE_PCT" in
  ''|*[!0-9]*) REFUSE_PCT=85 ;;
esac

# --- Intensity-aware threshold adjustment ---
case "$INTENSITY" in
  Quick)
    # 10% tighter thresholds for Quick (stay fast, small payloads)
    WARN_PCT=$((WARN_PCT - 10))
    DECOMPOSE_PCT=$((DECOMPOSE_PCT - 10))
    REFUSE_PCT=$((REFUSE_PCT - 10))
    ;;
  Full)
    # 5% looser thresholds for Full (richer payloads acceptable)
    WARN_PCT=$((WARN_PCT + 5))
    DECOMPOSE_PCT=$((DECOMPOSE_PCT + 5))
    REFUSE_PCT=$((REFUSE_PCT + 5))
    ;;
  Standard|*)
    # Default thresholds, no adjustment
    ;;
esac

# Clamp percentages to valid range
if [[ "$WARN_PCT" -lt 10 ]]; then WARN_PCT=10; fi
if [[ "$WARN_PCT" -gt 95 ]]; then WARN_PCT=95; fi
if [[ "$DECOMPOSE_PCT" -lt 20 ]]; then DECOMPOSE_PCT=20; fi
if [[ "$DECOMPOSE_PCT" -gt 95 ]]; then DECOMPOSE_PCT=95; fi
if [[ "$REFUSE_PCT" -lt 30 ]]; then REFUSE_PCT=30; fi
if [[ "$REFUSE_PCT" -gt 99 ]]; then REFUSE_PCT=99; fi

# --- Calculate thresholds as token counts ---
threshold_warn=$((CONTEXT_WINDOW * WARN_PCT / 100))
threshold_decompose=$((CONTEXT_WINDOW * DECOMPOSE_PCT / 100))
threshold_refuse=$((CONTEXT_WINDOW * REFUSE_PCT / 100))

# --- Calculate utilization ---
if [[ "$CONTEXT_WINDOW" -gt 0 ]]; then
  utilization_pct=$((TOKENS * 100 / CONTEXT_WINDOW))
else
  utilization_pct=0
fi

# Clamp to 0-100
if [[ "$utilization_pct" -gt 100 ]]; then utilization_pct=100; fi
if [[ "$utilization_pct" -lt 0 ]]; then utilization_pct=0; fi

# --- Determine pressure level and action ---
pressure="low"
action="proceed"

if [[ "$TOKENS" -ge "$threshold_refuse" ]]; then
  pressure="critical"
  action="refuse"
elif [[ "$TOKENS" -ge "$threshold_decompose" ]]; then
  pressure="high"
  action="decompose"
elif [[ "$TOKENS" -ge "$threshold_warn" ]]; then
  pressure="medium"
  action="warn"
fi

# --- Output ---
echo "pressure=$pressure"
echo "action=$action"
echo "utilization_pct=$utilization_pct"
echo "threshold_warn=$threshold_warn"
echo "threshold_decompose=$threshold_decompose"
echo "threshold_refuse=$threshold_refuse"
