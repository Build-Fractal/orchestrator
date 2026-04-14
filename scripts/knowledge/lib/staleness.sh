#!/usr/bin/env bash
# scripts/knowledge/lib/staleness.sh — Staleness decay helper library
# Source this file to use compute_effective_confidence().
#
# Formula (AD-5, FR-105):
#   effective_confidence = confidence * max(0.5, 1.0 - (days_since_verified / 180))
#
# The floor of 0.5 prevents entries from decaying to zero.
# The 180-day window is the default staleness horizon.
#
# Bash 3.2 compatible — uses only POSIX arithmetic and bc for floating point.

# Compute days between two ISO dates (YYYY-MM-DD format).
# Usage: days_since <past_date> [<reference_date>]
# If reference_date is omitted, uses today.
# Returns integer days to stdout.
days_since() {
  local past_date="$1"
  local ref_date="${2:-$(date +%Y-%m-%d)}"

  # Convert dates to epoch seconds
  # macOS date (BSD) uses -j -f, Linux date uses -d
  local past_epoch ref_epoch
  if date -j -f "%Y-%m-%d" "$past_date" "+%s" >/dev/null 2>&1; then
    # BSD/macOS date
    past_epoch=$(date -j -f "%Y-%m-%d" "$past_date" "+%s" 2>/dev/null)
    ref_epoch=$(date -j -f "%Y-%m-%d" "$ref_date" "+%s" 2>/dev/null)
  else
    # GNU/Linux date
    past_epoch=$(date -d "$past_date" "+%s" 2>/dev/null)
    ref_epoch=$(date -d "$ref_date" "+%s" 2>/dev/null)
  fi

  if [ -z "$past_epoch" ] || [ -z "$ref_epoch" ]; then
    echo "0"
    return 1
  fi

  local diff_seconds=$(( ref_epoch - past_epoch ))
  local diff_days=$(( diff_seconds / 86400 ))
  # Ensure non-negative
  if [ "$diff_days" -lt 0 ]; then
    diff_days=0
  fi
  echo "$diff_days"
}

# Compute effective confidence after staleness decay.
# Usage: compute_effective_confidence <confidence> <last_verified_date> [<reference_date>]
# confidence: float 0.0 to 1.0 (e.g., 0.90)
# last_verified_date: YYYY-MM-DD format
# reference_date: optional, defaults to today
#
# Output: float effective confidence to stdout (e.g., 0.72)
# Uses bc if available, falls back to awk for floating-point math.
compute_effective_confidence() {
  local confidence="$1"
  local last_verified="$2"
  local ref_date="${3:-$(date +%Y-%m-%d)}"

  local days
  days=$(days_since "$last_verified" "$ref_date")

  # decay_factor = max(0.5, 1.0 - (days / 180))
  # effective_confidence = confidence * decay_factor
  if command -v bc >/dev/null 2>&1; then
    echo "$confidence $days" | awk '{
      days = $2
      conf = $1
      decay = 1.0 - (days / 180.0)
      if (decay < 0.5) decay = 0.5
      printf "%.2f\n", conf * decay
    }'
  else
    # awk-only fallback (always available)
    echo "$confidence $days" | awk '{
      days = $2
      conf = $1
      decay = 1.0 - (days / 180.0)
      if (decay < 0.5) decay = 0.5
      printf "%.2f\n", conf * decay
    }'
  fi
}
