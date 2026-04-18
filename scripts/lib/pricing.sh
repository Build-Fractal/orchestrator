#!/usr/bin/env bash
# scripts/lib/pricing.sh — M019/P01 pricing + token-estimate helpers.
#
# Sourceable library (no load-time output). All functions are idempotent
# and side-effect-free except for stderr warnings on degradation paths.
#
# Resolver contract:
#   pricing_file_path           -> prints resolved path (ORCH_PRICING_FILE override
#                                  wins, else .orchestrator/config/pricing.yml)
#   pricing_file_present        -> exit 0 if resolvable + readable, 1 otherwise
#   pricing_last_updated        -> prints "YYYY-MM-DD" from last_updated, empty on miss
#   pricing_stale_days          -> prints integer days since last_updated, or "" if N/A
#   pricing_is_stale            -> exit 0 if file missing or age>90 days, 1 otherwise
#   pricing_lookup_rates MODEL  -> prints "INPUT_USD_PER_M OUTPUT_USD_PER_M" or "" on miss
#   pricing_resolve_alias MODEL -> prints concrete model id (resolves aliases.* -> models.*)
#   pricing_estimate_cost_usd INPUT_TOKENS OUTPUT_TOKENS MODEL
#                               -> prints numeric dollar estimate (8-decimal precision)
#                                  OR prints empty string and exits 0 on pricing miss
#   chars_to_tokens_quartile CHARCOUNT
#                               -> prints int(chars/4), AD-1 token estimate method
#                                  (token_estimate_method: "char-quartile")
#   pricing_warning_reason      -> prints "missing" | "stale:<N>d" | "no-rate:<MODEL>"
#                                  after a failed pricing_estimate_cost_usd; empty otherwise
#
# Bash 3.2 compatible. No declare -A. Parallel indexed-array lookups.
# Emitter-internal (MEM004 carve-out): pipes/$()/awk permitted.

[ -n "${_PRICING_SH_SOURCED:-}" ] && return 0
_PRICING_SH_SOURCED=1

# Module-scoped warning channel. Set by pricing_estimate_cost_usd on degradation,
# read by pricing_warning_reason. Plain top-level assignment (bash 3.2 safe).
_PRICING_WARNING_REASON=""

# Compute project root if caller has not exported PROJECT_ROOT.
_pricing_project_root() {
  if [ -n "${PROJECT_ROOT:-}" ]; then
    printf '%s\n' "$PROJECT_ROOT"
    return 0
  fi
  local src="${BASH_SOURCE[0]}"
  local dir
  dir="$(cd "$(dirname "$src")/../.." && pwd)"
  printf '%s\n' "$dir"
}

pricing_file_path() {
  if [ -n "${ORCH_PRICING_FILE:-}" ]; then
    printf '%s\n' "$ORCH_PRICING_FILE"
    return 0
  fi
  local root
  root="$(_pricing_project_root)"
  printf '%s\n' "$root/.orchestrator/config/pricing.yml"
}

pricing_file_present() {
  local f
  f="$(pricing_file_path)"
  [ -n "$f" ] && [ -r "$f" ]
}

pricing_last_updated() {
  local f
  f="$(pricing_file_path)"
  [ -r "$f" ] || return 0
  grep -E '^last_updated:' "$f" | head -n 1 | sed -E 's/^last_updated:[[:space:]]*"?([^"[:space:]]*)"?.*$/\1/'
}

# Convert YYYY-MM-DD to epoch seconds. BSD date (macOS) with GNU fallback.
_pricing_date_to_epoch() {
  local d="$1"
  local e=""
  e="$(date -u -j -f "%Y-%m-%d" "$d" +%s 2>/dev/null || true)"
  if [ -z "$e" ]; then
    e="$(date -u -d "$d" +%s 2>/dev/null || true)"
  fi
  printf '%s\n' "$e"
}

pricing_stale_days() {
  local lu
  lu="$(pricing_last_updated)"
  [ -n "$lu" ] || return 0
  local lu_epoch now_epoch
  lu_epoch="$(_pricing_date_to_epoch "$lu")"
  [ -n "$lu_epoch" ] || return 0
  now_epoch="$(date -u +%s)"
  printf '%d\n' $(( (now_epoch - lu_epoch) / 86400 ))
}

pricing_is_stale() {
  if ! pricing_file_present; then
    return 0
  fi
  local days
  days="$(pricing_stale_days)"
  if [ -z "$days" ]; then
    return 0
  fi
  if [ "$days" -gt 90 ]; then
    return 0
  fi
  return 1
}

pricing_resolve_alias() {
  local model="$1"
  [ -n "$model" ] || return 0
  local f
  f="$(pricing_file_path)"
  if [ ! -r "$f" ]; then
    printf '%s\n' "$model"
    return 0
  fi
  # Walk only the aliases: block. One-level indented keys are alias -> target.
  local resolved
  resolved="$(awk -v m="$model" '
    /^aliases:[[:space:]]*$/ { in_alias=1; next }
    /^[^[:space:]#]/ { in_alias=0 }
    in_alias && /^[[:space:]]+[^[:space:]#][^:]*:[[:space:]]*/ {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      key=line
      sub(/:.*/, "", key)
      val=line
      sub(/^[^:]*:[[:space:]]*/, "", val)
      gsub(/^"|"$/, "", val)
      gsub(/[[:space:]]+$/, "", val)
      if (key == m) { print val; exit 0 }
    }
  ' "$f")"
  if [ -n "$resolved" ]; then
    printf '%s\n' "$resolved"
  else
    printf '%s\n' "$model"
  fi
}

pricing_lookup_rates() {
  local model="$1"
  [ -n "$model" ] || return 0
  local f
  f="$(pricing_file_path)"
  [ -r "$f" ] || return 0
  awk -v m="$model" '
    /^models:[[:space:]]*$/ { in_models=1; next }
    /^[^[:space:]#]/ { in_models=0; cur="" }
    in_models && /^[[:space:]]{2}[^[:space:]#][^:]*:[[:space:]]*$/ {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/:.*$/, "", line)
      cur=line
      in_val=0
      next
    }
    in_models && cur == m && /input_per_million_usd:/ {
      val=$0
      sub(/^[^:]*:[[:space:]]*/, "", val)
      gsub(/[[:space:]]+$/, "", val)
      ival=val
    }
    in_models && cur == m && /output_per_million_usd:/ {
      val=$0
      sub(/^[^:]*:[[:space:]]*/, "", val)
      gsub(/[[:space:]]+$/, "", val)
      oval=val
    }
    END {
      if (ival != "" && oval != "") {
        print ival " " oval
      }
    }
  ' "$f"
}

pricing_estimate_cost_usd() {
  local in_tok="${1:-0}"
  local out_tok="${2:-0}"
  local model="${3:-}"

  _PRICING_WARNING_REASON=""

  if ! pricing_file_present; then
    _PRICING_WARNING_REASON="missing"
    return 0
  fi

  if pricing_is_stale; then
    local days
    days="$(pricing_stale_days)"
    if [ -n "$days" ]; then
      _PRICING_WARNING_REASON="stale:${days}d"
    else
      _PRICING_WARNING_REASON="missing"
    fi
    return 0
  fi

  local resolved rates in_rate out_rate
  resolved="$(pricing_resolve_alias "$model")"
  rates="$(pricing_lookup_rates "$resolved")"
  if [ -z "$rates" ]; then
    _PRICING_WARNING_REASON="no-rate:${model}"
    return 0
  fi

  in_rate="${rates%% *}"
  out_rate="${rates##* }"

  awk -v i="$in_tok" -v o="$out_tok" -v ir="$in_rate" -v or="$out_rate" \
    'BEGIN { printf "%.8f\n", (i * ir + o * or) / 1000000 }'
}

chars_to_tokens_quartile() {
  local c="${1:-0}"
  printf '%d\n' $(( c / 4 ))
}

pricing_warning_reason() {
  printf '%s\n' "${_PRICING_WARNING_REASON:-}"
}
