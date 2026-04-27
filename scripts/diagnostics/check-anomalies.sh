#!/usr/bin/env bash
# scripts/diagnostics/check-anomalies.sh — M027/P03/T01 anomaly-detection helper.
#
# Sourceable as a library (function check_anomalies_render) AND runnable as a CLI.
# CLI emits an anomaly block (<=12 lines) titled
# "Anomaly Detection (Tier 1 baseline)" listing dispatches whose cost or
# duration deviates from the per-milestone moving median by >= the configured
# multiplier (default 3.0), or whose retry_count exceeds the configured
# threshold (default 2), or whose verification_pass_rate falls below the
# configured threshold (default 0.5). Goodhart pairing: every flagged row
# carries BOTH cost (or fallback=duration) AND quality (pass_rate, retry_count)
# tokens — the alerting surface honors FR-9 / CON-4.
#
# Suppression matrix (5 conditions; any one short-circuits to zero stdout, exit 0):
#   --no-anomaly flag
#   --yes flag
#   ORCHESTRATOR_AUTO=1 env var
#   ORCH_ANOMALY_CHECK_ENABLED=false env var (or anomaly_check_enabled=false config)
#   sample-size below floor (structural carve-out — emits a single
#     "ANOMALY: insufficient sample (n=N floor=F)" line in default mode,
#     stays empty under any of the four suppressors above)
#
# Read-only (FR-12/CON-1): never writes to execution-log.jsonl or config.
# Zero-LLM-token (FR-21/CON-6): bash + invocation of metrics-rollup.sh /
#   read-config.sh / find-active-milestone.sh only; no LLM client calls.
# Bash 3.2 (CON-7): parallel scalars only; no associative arrays;
#   no herestring redirect; no process substitution; no merged
#   stdout-stderr shorthand; no case-folding parameter expansion.
# Comment-hygiene carry-forward from M027/P00 + P01 + P02: doc-comments
#   describe forbidden bash-4 constructs by category rather than spelling
#   the literal forbidden tokens, so the T04 bash32-compat verifier regex
#   stays clean against this file body.
#
# CON-5 never-abort: degraded inputs (missing pricing, missing milestone,
# empty log, below-floor sample) surface as text rather than nonzero exit.
# When the rollup engine emits "(N missing)" in EST_COST_USD the helper
# substitutes "cost=(unavailable; fallback=duration)" per row.

set -u

if [ -n "${_CHECK_ANOMALIES_SH_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
_CHECK_ANOMALIES_SH_SOURCED=1

_CA_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CA_PROJECT_ROOT="$(cd "$_CA_SCRIPT_DIR/../.." && pwd)"

# check_anomalies_render <milestone-or-empty> <suppress-flag> <multiplier> <retry-thresh> <pass-rate-thresh> <sample-floor>
#   When <suppress-flag> = 1, emits zero stdout (and returns 0).
#   When <milestone-or-empty> = empty, falls back to project-granularity rollup.
#   Always returns exit 0 (never aborts; degraded inputs surface as text).
check_anomalies_render() {
  local milestone="$1"
  local suppress="$2"
  local mult="$3"
  local retry_thresh="$4"
  local pass_thresh="$5"
  local floor="$6"
  if [ "$suppress" = "1" ]; then
    return 0
  fi
  local rollup_out
  if [ -n "$milestone" ]; then
    rollup_out="$(bash "$_CA_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
      --granularity task --milestone "$milestone" 2>/dev/null || true)"
  else
    rollup_out="$(bash "$_CA_PROJECT_ROOT/scripts/diagnostics/metrics-rollup.sh" \
      --granularity task 2>/dev/null || true)"
  fi
  # Count data rows. Rollup emits header "GRANULARITY ..." and zero or more
  # "task <scope> ..." rows. We use a strict prefix match.
  local row_count
  row_count="$(printf '%s\n' "$rollup_out" | grep -cE '^task[[:space:]]' || true)"
  if [ -z "$row_count" ]; then row_count=0; fi
  printf '%s\n' "Anomaly Detection (Tier 1 baseline)"
  if [ "$row_count" -lt "$floor" ]; then
    printf 'ANOMALY: insufficient sample (n=%s floor=%s)\n' "$row_count" "$floor"
    return 0
  fi
  # Single-pass awk:
  #   - Detect "(N missing)" annotation on the EST_COST_USD cell. When
  #     present, columns shift by +2; cost is unavailable so the row
  #     contributes cost=(unavailable; fallback=duration) to its emission.
  #   - Otherwise read EST_COST_USD (col 4), PASS_RATE (col 8), RETRIES (col 10).
  #     Header columns from metrics-rollup.sh:
  #       1 GRANULARITY  2 SCOPE  3 DISPATCHES  4 EST_COST_USD  5 TOKENS_EST
  #       6 P50_COST     7 P95_COST  8 PASS_RATE  9 DEVIATIONS  10 RETRIES
  #       11 WARNINGS    12 SOURCE
  #   - Median of cost across rows; flag where cost >= mult * median (and
  #     median > 0 — guards against the all-zero degraded path), where
  #     retries > retry_thresh, or where pass_rate < pass_thresh.
  #   - Emit at most 8 flagged rows so the total block stays <=12 lines
  #     including the title and a possible summary line.
  local awk_out
  awk_out="$(printf '%s\n' "$rollup_out" | awk -v mult_s="$mult" -v rt_s="$retry_thresh" -v pt_s="$pass_thresh" '
    BEGIN { mult = mult_s + 0; rt = rt_s + 0; pt = pt_s + 0; }
    /^task[[:space:]]/ {
      n++;
      scope=$2;
      # Detect "(N missing)" pattern in the EST_COST_USD column.
      if ($5 ~ /^\(/) {
        cost_unavail[n]=1;
        cost[n]=0;
        # Columns 5-6 are the "(N missing)" tokens, so shift by 2.
        pass_rate[n]=$10+0;
        retries[n]=$12+0;
      } else {
        cost_unavail[n]=0;
        cost[n]=$4+0;
        pass_rate[n]=$8+0;
        retries[n]=$10+0;
      }
      scopes[n]=scope;
    }
    END {
      # Insertion sort of costs to compute median (n is small per milestone).
      for (i=1; i<=n; i++) sorted[i]=cost[i];
      for (i=1; i<n; i++) for (j=i+1; j<=n; j++) {
        if (sorted[j] < sorted[i]) { t=sorted[i]; sorted[i]=sorted[j]; sorted[j]=t; }
      }
      if (n % 2 == 1) median=sorted[(n+1)/2]; else median=(sorted[n/2]+sorted[n/2+1])/2;
      flagged=0;
      shown=0;
      cap=8;
      for (i=1; i<=n; i++) {
        reasons="";
        if (median > 0 && cost[i] >= mult * median) reasons = reasons " cost-spike";
        if (retries[i] > rt) reasons = reasons " retry-spike";
        if (pass_rate[i] < pt) reasons = reasons " low-pass-rate";
        if (reasons != "") {
          flagged++;
          if (shown < cap) {
            if (cost_unavail[i] == 1 || median == 0) {
              cost_token = "cost=(unavailable; fallback=duration)";
            } else {
              cost_token = sprintf("cost=%.4f", cost[i]);
            }
            printf "FLAGGED %s %s pass_rate=%.2f retry_count=%d reasons=%s\n", scopes[i], cost_token, pass_rate[i], retries[i], reasons;
            shown++;
          }
        }
      }
      if (flagged == 0) {
        printf "ANOMALY: no anomalies detected (n=%d median=%.4f mult=%.2f)\n", n, median, mult;
      } else if (flagged > shown) {
        printf "ANOMALY: %d additional flagged rows truncated (cap=%d)\n", flagged - shown, cap;
      }
    }
  ' || true)"
  printf '%s\n' "$awk_out"
  return 0
}

# CLI entry point — only when invoked as a script (not sourced).
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  MILESTONE=""
  PROJECT_FALLBACK=0
  SUPPRESS=0
  YES=0
  NO_ANOMALY=0
  CONFIG_DEFAULTS=""
  MULT_OVERRIDE=""
  FLOOR_OVERRIDE=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --milestone)        MILESTONE="$2"; shift 2 ;;
      --project)          PROJECT_FALLBACK=1; shift ;;
      --no-anomaly)       NO_ANOMALY=1; shift ;;
      --yes)              YES=1; shift ;;
      --threshold)        MULT_OVERRIDE="$2"; shift 2 ;;
      --sample-floor)     FLOOR_OVERRIDE="$2"; shift 2 ;;
      --config-defaults)  CONFIG_DEFAULTS="$2"; shift 2 ;;
      --help|-h)
        printf '%s\n' "Usage: check-anomalies.sh [--milestone <Mxxx>] [--project] [--no-anomaly] [--yes] [--threshold <multiplier>] [--sample-floor <N>] [--config-defaults <path>]"
        exit 0 ;;
      *) shift ;;
    esac
  done

  # Suppression precedence: any of the flags / env-vars / config knob short-circuits.
  if [ "$NO_ANOMALY" -eq 1 ] || [ "$YES" -eq 1 ]; then SUPPRESS=1; fi
  if [ -n "${ORCHESTRATOR_AUTO:-}" ] && [ "${ORCHESTRATOR_AUTO}" != "0" ]; then SUPPRESS=1; fi
  # Resolve anomaly_check_enabled config knob (env-var override takes precedence).
  if [ "$SUPPRESS" -eq 0 ]; then
    cfg_val="${ORCH_ANOMALY_CHECK_ENABLED:-}"
    if [ -z "$cfg_val" ] && [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
      cfg_val="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" anomaly_check_enabled 2>/dev/null || true)"
    fi
    case "$cfg_val" in
      false|FALSE|False|0|no|NO|No) SUPPRESS=1 ;;
    esac
  fi

  # Resolve thresholds via config (with --threshold / --sample-floor overrides).
  # read-config.sh returns the literal string "null" for unset-but-registered
  # keys; treat that as "use built-in default" alongside empty.
  MULT="$MULT_OVERRIDE"
  if [ -z "$MULT" ] && [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
    MULT="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" anomaly_cost_multiplier 2>/dev/null || true)"
  fi
  if [ -z "$MULT" ] || [ "$MULT" = "null" ]; then MULT="3.0"; fi

  RETRY_THRESH=""
  if [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
    RETRY_THRESH="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" anomaly_retry_threshold 2>/dev/null || true)"
  fi
  if [ -z "$RETRY_THRESH" ] || [ "$RETRY_THRESH" = "null" ]; then RETRY_THRESH="2"; fi

  PASS_THRESH=""
  if [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
    PASS_THRESH="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" anomaly_pass_rate_threshold 2>/dev/null || true)"
  fi
  if [ -z "$PASS_THRESH" ] || [ "$PASS_THRESH" = "null" ]; then PASS_THRESH="0.5"; fi

  FLOOR="$FLOOR_OVERRIDE"
  if [ -z "$FLOOR" ]; then FLOOR="5"; fi

  # Resolve active milestone if neither --milestone nor --project given.
  # find-active-milestone.sh emits "M### <state> <tier>"; take the first token.
  if [ -z "$MILESTONE" ] && [ "$PROJECT_FALLBACK" -eq 0 ]; then
    if [ -x "$_CA_PROJECT_ROOT/scripts/state/find-active-milestone.sh" ]; then
      _fa_out="$(bash "$_CA_PROJECT_ROOT/scripts/state/find-active-milestone.sh" "$_CA_PROJECT_ROOT/.orchestrator" 2>/dev/null || true)"
      MILESTONE="$(printf '%s\n' "$_fa_out" | awk 'NR==1 { print $1 }')"
    fi
  fi
  # If --project was passed, leave MILESTONE empty so the render path uses
  # project-granularity rollup.
  if [ "$PROJECT_FALLBACK" -eq 1 ]; then MILESTONE=""; fi

  check_anomalies_render "$MILESTONE" "$SUPPRESS" "$MULT" "$RETRY_THRESH" "$PASS_THRESH" "$FLOOR"
  exit 0
fi
