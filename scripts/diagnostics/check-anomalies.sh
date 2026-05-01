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

# check_anomalies_render <milestone-or-empty> <suppress-flag> <multiplier> <retry-thresh> <pass-rate-thresh> <sample-floor> [compression-floor]
#   When <suppress-flag> = 1, emits zero stdout (and returns 0).
#   When <milestone-or-empty> = empty, falls back to project-granularity rollup.
#   compression-floor (M018/P05/T02) defaults to 0.347 (SC-9 P00-calibrated)
#     when the seventh arg is empty/absent. Below this savings-ratio per task,
#     the row carries a `compression-regression` reason composed with the
#     existing cost-spike / retry-spike / low-pass-rate reasons.
#   Always returns exit 0 (never aborts; degraded inputs surface as text).
check_anomalies_render() {
  local milestone="$1"
  local suppress="$2"
  local mult="$3"
  local retry_thresh="$4"
  local pass_thresh="$5"
  local floor="$6"
  local compression_floor="${7:-0.347}"
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
  awk_out="$(printf '%s\n' "$rollup_out" | awk -v mult_s="$mult" -v rt_s="$retry_thresh" -v pt_s="$pass_thresh" -v cf_s="$compression_floor" '
    BEGIN { mult = mult_s + 0; rt = rt_s + 0; pt = pt_s + 0; cfloor = cf_s + 0; }
    /^task[[:space:]]/ {
      n++;
      scope=$2;
      # Detect "(N missing)" pattern in the EST_COST_USD column.
      # M018/P05/T02 — the four new savings columns are appended AFTER the
      # existing 12, so they shift by the same +2 when the cost cell carries
      # the "(N missing)" annotation. TOKENS_EST is col 5 normally / col 7
      # when shifted; FILTER_DROPPED is col 13 / col 15; TIER1_SAVINGS col
      # 14 / 16; TIER2_SAVINGS col 15 / 17.
      if ($5 ~ /^\(/) {
        cost_unavail[n]=1;
        cost[n]=0;
        # Columns 5-6 are the "(N missing)" tokens, so shift by 2.
        pass_rate[n]=$10+0;
        retries[n]=$12+0;
        tokens[n]=$7+0;
        fdrop[n]=$15+0;
        t1s[n]=$16+0;
        t2s[n]=$17+0;
        # M018/P06/T02 — tier3_savings at col 19 (shifted) / col 17 (normal).
        t3s[n]=$19+0;
      } else {
        cost_unavail[n]=0;
        cost[n]=$4+0;
        pass_rate[n]=$8+0;
        retries[n]=$10+0;
        tokens[n]=$5+0;
        fdrop[n]=$13+0;
        t1s[n]=$14+0;
        t2s[n]=$15+0;
        # M018/P06/T02 — tier3_savings at col 17 (normal layout).
        t3s[n]=$17+0;
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
        # M018/P05/T02 — compression-regression reason. Composes additively
        # with the existing reasons. Guarded against div-by-zero (degraded
        # tokens=0 path → no flag fires); guarded against pre-P05 records
        # (savings cols all zero → ratio 0 < cfloor → would flag every row,
        # so we ALSO require that at least ONE savings token is non-zero
        # OR that any record in scope advertised the new fields. The
        # simpler invariant: skip the compression flag when ALL THREE
        # savings sums are zero — that distinguishes "compression ran and
        # underperformed" from "compression did not run at all", which is
        # the operational signal we want).
        sav_ratio = -1;
        if (tokens[i] > 0) {
          # M018/P06/T02 — fold tier3_savings into sav_total. The
          # compression-regression flag composes additively (no new reason).
          sav_total = fdrop[i] + t1s[i] + t2s[i] + t3s[i];
          sav_ratio = sav_total / tokens[i];
          if (sav_total > 0 && sav_ratio < cfloor) {
            reasons = reasons " compression-regression";
          }
        }
        if (reasons != "") {
          flagged++;
          if (shown < cap) {
            if (cost_unavail[i] == 1 || median == 0) {
              cost_token = "cost=(unavailable; fallback=duration)";
            } else {
              cost_token = sprintf("cost=%.4f", cost[i]);
            }
            if (reasons ~ /compression-regression/ && sav_ratio >= 0) {
              printf "FLAGGED %s %s pass_rate=%.2f retry_count=%d savings_ratio=%.3f reasons=%s\n", scopes[i], cost_token, pass_rate[i], retries[i], sav_ratio, reasons;
            } else {
              printf "FLAGGED %s %s pass_rate=%.2f retry_count=%d reasons=%s\n", scopes[i], cost_token, pass_rate[i], retries[i], reasons;
            }
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

# M030/P06/T02 — model_routing_regression check (FR-18).
#
# Reads the milestone's execution-log.jsonl for shadow-on dispatch_usage
# records carrying the additive `character` field (introduced by
# dispatch-interface.sh under M030/P06/T02). Groups by character class.
# Computes per-class pass-rate as:
#   pass_rate = pass_count / sample_count
#     pass_count   = records with escalation_count=0 AND escalation_reason=""
#     sample_count = records with character=<C>
# When sample_count >= min_class_sample AND pass_rate < pass_rate_thresh,
# emits a `FLAGGED model_routing_regression class=<C> ...` line to stdout
# AND appends a JSONL anomaly record to the configured emit path.
#
# Invariants:
# - Idempotent stdout per input (timestamp lives on the JSONL append only).
# - Read-only on execution-log.jsonl. Append-only on anomalies.jsonl.
# - Exit 0 always (CON-5 never-abort, mirrors check_anomalies_render).
# - Bash 3.2 compatible: parallel scalars, awk for parsing, no `declare -A`.
# - MEM004 emitter-internal carve-out: pipes / $(...) / awk permitted.
#
# Args:
#   $1 milestone-or-empty
#   $2 pass-rate threshold (e.g. "0.5")
#   $3 min-class-sample floor (e.g. "10")
#   $4 jsonl emit path
_ca_model_routing_regression_check() {
  local milestone="$1"
  local pass_rate_thresh="$2"
  local min_class_sample="$3"
  local jsonl_path="$4"
  local log_path

  local orch_root="${ORCHESTRATOR_ROOT:-$_CA_PROJECT_ROOT/.orchestrator}"
  if [ -n "$milestone" ]; then
    log_path="$orch_root/milestones/$milestone/execution-log.jsonl"
  else
    log_path="$orch_root/execution-log.jsonl"
  fi

  if [ ! -f "$log_path" ]; then
    return 0
  fi

  local mech_total=0; local mech_pass=0
  local std_total=0; local std_pass=0
  local nov_total=0; local nov_pass=0

  # Single-pass awk: per-class counters, full-quoted-token regex anchors to
  # avoid cross-class substring leakage (e.g. "standard" containing "stand").
  local awk_out
  awk_out="$(awk '
    BEGIN { mt=0; mp=0; st=0; sp=0; nt=0; np=0; }
    /"record_type":"dispatch_usage"/ {
      ch = "";
      if (match($0, /"character":"mechanical"/)) ch = "mechanical";
      else if (match($0, /"character":"standard"/)) ch = "standard";
      else if (match($0, /"character":"novel"/)) ch = "novel";
      else next;
      pass = 0;
      if (match($0, /"escalation_count":0/) && match($0, /"escalation_reason":""/)) pass = 1;
      if (ch == "mechanical") { mt++; if (pass) mp++; }
      if (ch == "standard")   { st++; if (pass) sp++; }
      if (ch == "novel")      { nt++; if (pass) np++; }
    }
    END { printf "%d %d %d %d %d %d", mt, mp, st, sp, nt, np; }
  ' "$log_path")"

  set -- $awk_out
  mech_total="$1"; mech_pass="$2"
  std_total="$3"; std_pass="$4"
  nov_total="$5"; nov_pass="$6"

  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  _ca_emit_class_regression() {
    local class="$1"
    local total="$2"
    local pass_count="$3"
    if [ "$total" -lt "$min_class_sample" ]; then
      return 0
    fi
    local pass_rate
    pass_rate="$(awk -v p="$pass_count" -v t="$total" 'BEGIN { if (t == 0) { printf "0.00" } else { printf "%.2f", p / t } }')"
    local below
    below="$(awk -v r="$pass_rate" -v th="$pass_rate_thresh" 'BEGIN { if (r + 0 < th + 0) print "1"; else print "0" }')"
    if [ "$below" != "1" ]; then
      return 0
    fi
    local thresh_fmt
    thresh_fmt="$(awk -v th="$pass_rate_thresh" 'BEGIN { printf "%.2f", th + 0 }')"
    printf 'FLAGGED model_routing_regression class=%s class_pass_rate=%s sample=%d threshold=%s\n' \
      "$class" "$pass_rate" "$total" "$thresh_fmt"
    if [ -n "$jsonl_path" ]; then
      mkdir -p "$(dirname "$jsonl_path")" 2>/dev/null || true
      printf '{"record_type":"anomaly","kind":"model_routing_regression","class":"%s","class_pass_rate":%s,"class_sample":%d,"threshold":%s,"milestone":"%s","timestamp":"%s"}\n' \
        "$class" "$pass_rate" "$total" "$thresh_fmt" "${milestone:-}" "$now" \
        >> "$jsonl_path" 2>/dev/null || true
    fi
  }

  _ca_emit_class_regression "mechanical" "$mech_total" "$mech_pass"
  _ca_emit_class_regression "standard"   "$std_total"  "$std_pass"
  _ca_emit_class_regression "novel"      "$nov_total"  "$nov_pass"

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
  PASS_RATE_THRESH_OVERRIDE=""
  MIN_CLASS_SAMPLE_OVERRIDE=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --milestone)            MILESTONE="$2"; shift 2 ;;
      --project)              PROJECT_FALLBACK=1; shift ;;
      --no-anomaly)           NO_ANOMALY=1; shift ;;
      --yes)                  YES=1; shift ;;
      --threshold)            MULT_OVERRIDE="$2"; shift 2 ;;
      --sample-floor)         FLOOR_OVERRIDE="$2"; shift 2 ;;
      --threshold-pass-rate)  PASS_RATE_THRESH_OVERRIDE="$2"; shift 2 ;;
      --min-class-sample)     MIN_CLASS_SAMPLE_OVERRIDE="$2"; shift 2 ;;
      --config-defaults)      CONFIG_DEFAULTS="$2"; shift 2 ;;
      --help|-h)
        printf '%s\n' "Usage: check-anomalies.sh [--milestone <Mxxx>] [--project] [--no-anomaly] [--yes] [--threshold <multiplier>] [--sample-floor <N>] [--threshold-pass-rate <float>] [--min-class-sample <N>] [--config-defaults <path>]"
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

  # M018/P05/T02 — compression-regression floor (savings ratio). Resolves
  # via read-config.sh `compression.regression_floor` (which delegates to
  # kf_get_compression_regression_floor). Defaults to 0.347 — SC-9 P00
  # calibration. Mirror of the MULT / RETRY_THRESH / PASS_THRESH shape above.
  COMPRESSION_FLOOR=""
  if [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
    COMPRESSION_FLOOR="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" compression.regression_floor 2>/dev/null || true)"
  fi
  if [ -z "$COMPRESSION_FLOOR" ] || [ "$COMPRESSION_FLOOR" = "null" ]; then COMPRESSION_FLOOR="0.347"; fi

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

  check_anomalies_render "$MILESTONE" "$SUPPRESS" "$MULT" "$RETRY_THRESH" "$PASS_THRESH" "$FLOOR" "$COMPRESSION_FLOOR"

  # M030/P06/T02 — model_routing_regression check (FR-18). Additive: emits
  # zero stdout AND zero JSONL when no class crosses the threshold; the
  # legacy anomaly block above is byte-untouched. Threshold defaults:
  # pass-rate 0.50 floor + 10 min class sample (#Q-4 plan-phase decision).
  # Suppressed alongside the legacy block when SUPPRESS=1 (--no-anomaly /
  # --yes / ORCHESTRATOR_AUTO=1 / anomaly_check_enabled=false).
  if [ "$SUPPRESS" -eq 0 ]; then
    PASS_RATE_THRESH="$PASS_RATE_THRESH_OVERRIDE"
    if [ -z "$PASS_RATE_THRESH" ] && [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
      PASS_RATE_THRESH="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" model_routing_regression.pass_rate_threshold 2>/dev/null || true)"
    fi
    if [ -z "$PASS_RATE_THRESH" ] || [ "$PASS_RATE_THRESH" = "null" ]; then PASS_RATE_THRESH="0.5"; fi

    MIN_CLASS_SAMPLE="$MIN_CLASS_SAMPLE_OVERRIDE"
    if [ -z "$MIN_CLASS_SAMPLE" ] && [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
      MIN_CLASS_SAMPLE="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" model_routing_regression.min_class_sample 2>/dev/null || true)"
    fi
    if [ -z "$MIN_CLASS_SAMPLE" ] || [ "$MIN_CLASS_SAMPLE" = "null" ]; then MIN_CLASS_SAMPLE="10"; fi

    ANOMALIES_JSONL_PATH="${M030_ANOMALIES_JSONL_PATH:-${ORCHESTRATOR_ROOT:-$_CA_PROJECT_ROOT/.orchestrator}/anomalies.jsonl}"

    _ca_model_routing_regression_check "$MILESTONE" "$PASS_RATE_THRESH" "$MIN_CLASS_SAMPLE" "$ANOMALIES_JSONL_PATH"
  fi

  exit 0
fi
