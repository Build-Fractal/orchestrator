#!/usr/bin/env bash
# scripts/diagnostics/compression-eval.sh — M018/P05/T03 cohort-segmentation
# diagnostic for the M018 compression pipeline.
#
# Sourceable as a library (function compression_eval_render) AND runnable
# as a CLI. Reads payload_breakdown + unit_close records from a milestone's
# execution-log.jsonl, segments compressed vs uncompressed cohorts on the
# requested tier, and reports per-cohort + delta means for verification_
# pass_rate, retry_count, and deviation_count with confidence intervals.
#
# Reads payload_breakdown records emitted by scripts/dispatch/build-context.sh
# (cohort classifier) and unit_close records emitted by
# scripts/knowledge/write-summary.sh (cohort outcome measure).
# Read-only (FR-12 / CON-1): never appends to or rewrites JSONL.
# Zero-LLM-token (FR-21 / CON-6): bash + awk + grep only.
# Bash 3.2 (CON-7): parallel scalars, no associative arrays beyond awk
#   indexed maps, no process substitution, no merged stdout-stderr.
# MEM004 emitter-internal carve-out: pipes / $() / awk permitted inside
# this diagnostic body; the AD-19 single-script-file shape rule applies
# only to Check: commands at task / phase plan level (T04 wires this
# script as a single Check: invocation per truth).
#
# Usage:
#   bash scripts/diagnostics/compression-eval.sh --milestone <Mxxx> --tier <N> [--sample-floor <N>]
#   --milestone <Mxxx>     Required (or auto-resolved via find-active-milestone.sh).
#   --tier <N>             Required. 1, 2, or 3 (tier 3 cohort logic shipped in P06/T03).
#   --sample-floor <N>     Default 30. Both cohorts must be at or above the floor.
#   --help / -h
#
# Exit codes: always 0 (FR-12 / CON-5 — degraded inputs surface as text).

set -u

if [ -n "${_COMPRESSION_EVAL_SH_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
_COMPRESSION_EVAL_SH_SOURCED=1

_CE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CE_PROJECT_ROOT="$(cd "$_CE_SCRIPT_DIR/../.." && pwd)"

# compression_eval_render <milestone> <tier> <sample-floor>
# Always returns 0. Emits the report on stdout.
compression_eval_render() {
  local milestone="$1"
  local tier="$2"
  local floor="$3"

  printf '# compression-eval — milestone=%s tier=%s\n' "$milestone" "$tier"

  if [ -z "$milestone" ]; then
    printf 'no milestone resolved (pass --milestone <Mxxx> or run inside an active milestone)\n'
    return 0
  fi

  case "$tier" in
    1|2|3) ;;
    *)
      printf 'unsupported tier=%s (must be 1, 2, or 3)\n' "$tier"
      return 0
      ;;
  esac

  # M018/P05/T04: honor ORCHESTRATOR_ROOT for fixture-based verifier runs.
  # Falls back to the project's `.orchestrator/` when the env override is
  # absent. CON-5 carry-forward — no abort on degraded inputs.
  local _ce_orch_root
  _ce_orch_root="${ORCHESTRATOR_ROOT:-$_CE_PROJECT_ROOT/.orchestrator}"
  local log_file="$_ce_orch_root/milestones/$milestone/execution-log.jsonl"
  if [ ! -f "$log_file" ]; then
    printf 'log file missing: %s\n' "$log_file"
    return 0
  fi

  # The cohort-build awk pass:
  #   1. Walk the log; for every payload_breakdown record, record whether
  #      tier<N>_savings_tokens > 0 keyed on (milestone, phase, task).
  #   2. Walk the log again; for every unit_close record at granularity=task,
  #      emit (cohort, pass_rate, retry_count, deviation_count) keyed on the
  #      same (milestone, phase, task).
  # Single awk invocation, single input file. Compute per-cohort mean +
  # variance + n. Emit cohort + delta block with CIs.
  # Below-floor: emit "insufficient sample" and exit.

  local awk_out
  awk_out="$(awk -v tier="$tier" -v floor="$floor" '
    function tonum(x) { return (x == "" || x == "null") ? 0 : x + 0 }
    function field_num(line, key,    re, v) {
      re = "\"" key "\":[0-9]+"
      if (match(line, re)) {
        v = substr(line, RSTART, RLENGTH); sub(/.*:/, "", v); return v + 0
      }
      return 0
    }
    function field_str(line, key,    re, v) {
      re = "\"" key "\":\"[^\"]*\""
      if (match(line, re)) {
        v = substr(line, RSTART, RLENGTH); sub(/^"[^"]*":"/, "", v); sub(/"$/, "", v); return v
      }
      return ""
    }
    function field_real(line, key,    re, v) {
      re = "\"" key "\":(-?[0-9]+(\\.[0-9]+)?)"
      if (match(line, re)) {
        v = substr(line, RSTART, RLENGTH); sub(/.*:/, "", v); return v + 0
      }
      return -1.0
    }
    function wilson_lo(p, nn,    z, denom, center, half, vv) {
      if (nn <= 0 || p < 0) return -1
      z = 1.96; denom = 1 + z*z/nn
      center = (p + z*z/(2*nn)) / denom
      half = (z/denom) * sqrt(p*(1-p)/nn + z*z/(4*nn*nn))
      vv = center - half; if (vv < 0) vv = 0
      return vv
    }
    function wilson_hi(p, nn,    z, denom, center, half, vv) {
      if (nn <= 0 || p < 0) return -1
      z = 1.96; denom = 1 + z*z/nn
      center = (p + z*z/(2*nn)) / denom
      half = (z/denom) * sqrt(p*(1-p)/nn + z*z/(4*nn*nn))
      vv = center + half; if (vv > 1) vv = 1
      return vv
    }
    /"record_type":"payload_breakdown"/ {
      mm = field_str($0, "milestone")
      pp = field_str($0, "phase")
      tt = field_str($0, "task")
      key = mm "/" pp "/" tt
      if (tier == "1") {
        v = field_num($0, "tier1_savings_tokens")
      } else if (tier == "2") {
        v = field_num($0, "tier2_savings_tokens")
      } else if (tier == "3") {
        v = field_num($0, "tier3_compression_savings_tokens")
      } else {
        v = 0
      }
      if (v > 0) tier_fired[key] = 1
      else if (!(key in tier_fired)) tier_fired[key] = 0
      next
    }
    /"record_type":"unit_close"/ {
      g = field_str($0, "granularity")
      if (g != "task") next
      mm = field_str($0, "milestone")
      pp = field_str($0, "phase")
      tt = field_str($0, "task")
      key = mm "/" pp "/" tt
      pr = field_real($0, "verification_pass_rate")
      rt = field_num($0, "retry_count")
      dv = field_num($0, "deviation_count")
      cohort = (key in tier_fired && tier_fired[key] == 1) ? "compressed" : "uncompressed"
      n[cohort]++
      if (pr >= 0) {
        # Pass rate is a proportion in [0,1]; treat -1 as "unknown" and skip.
        pr_sum[cohort] += pr; pr_n[cohort]++
        pr_sumsq[cohort] += pr * pr
      }
      rt_sum[cohort] += rt; rt_sumsq[cohort] += rt * rt
      dv_sum[cohort] += dv; dv_sumsq[cohort] += dv * dv
    }
    END {
      nc = n["compressed"] + 0
      nu = n["uncompressed"] + 0
      if (nc < floor || nu < floor) {
        printf "insufficient sample (compressed=%d uncompressed=%d floor=%d)\n", nc, nu, floor
        exit
      }
      # Per-cohort means.
      for (c in n) {
        pr_mean[c] = (pr_n[c] > 0) ? pr_sum[c] / pr_n[c] : -1
        rt_mean[c] = rt_sum[c] / n[c]
        dv_mean[c] = dv_sum[c] / n[c]
        # Variance for retry / deviation (population variance is fine for the SEM).
        rt_var[c]  = rt_sumsq[c] / n[c] - rt_mean[c] * rt_mean[c]
        dv_var[c]  = dv_sumsq[c] / n[c] - dv_mean[c] * dv_mean[c]
        if (rt_var[c] < 0) rt_var[c] = 0
        if (dv_var[c] < 0) dv_var[c] = 0
      }
      printf "COHORT       N    PASS_RATE              RETRY_COUNT        DEVIATION_COUNT\n"
      for (i = 0; i < 2; i++) {
        c = (i == 0) ? "compressed" : "uncompressed"
        if (pr_n[c] > 0 && pr_mean[c] >= 0) {
          pr_lo = wilson_lo(pr_mean[c], pr_n[c]); pr_hi = wilson_hi(pr_mean[c], pr_n[c])
          pr_str = sprintf("%.3f [%.2f,%.2f]", pr_mean[c], pr_lo, pr_hi)
        } else {
          pr_str = "unknown"
        }
        rt_sem = (n[c] > 1) ? sqrt(rt_var[c] / n[c]) : 0
        dv_sem = (n[c] > 1) ? sqrt(dv_var[c] / n[c]) : 0
        printf "%-12s %-4d %-22s %.2f +/- %.2f      %.2f +/- %.2f\n", \
          c, n[c], pr_str, rt_mean[c], rt_sem, dv_mean[c], dv_sem
      }
      # Delta block.
      delta_pr = (pr_mean["compressed"] >= 0 && pr_mean["uncompressed"] >= 0) \
        ? pr_mean["compressed"] - pr_mean["uncompressed"] : -99
      delta_rt = rt_mean["compressed"] - rt_mean["uncompressed"]
      delta_dv = dv_mean["compressed"] - dv_mean["uncompressed"]
      # Pooled SE for proportion delta (normal approx).
      pr_d_hi = 0
      if (delta_pr > -50) {
        pp_pool = (pr_sum["compressed"] + pr_sum["uncompressed"]) / (pr_n["compressed"] + pr_n["uncompressed"])
        se_pr = sqrt(pp_pool * (1 - pp_pool) * (1.0/pr_n["compressed"] + 1.0/pr_n["uncompressed"]))
        z95 = 1.96
        pr_d_lo = delta_pr - z95 * se_pr; pr_d_hi = delta_pr + z95 * se_pr
        delta_pr_str = sprintf("%+.3f [%+.2f,%+.2f]", delta_pr, pr_d_lo, pr_d_hi)
      } else {
        delta_pr_str = "unknown"
      }
      se_rt = sqrt(rt_var["compressed"]/n["compressed"] + rt_var["uncompressed"]/n["uncompressed"])
      se_dv = sqrt(dv_var["compressed"]/n["compressed"] + dv_var["uncompressed"]/n["uncompressed"])
      delta_rt_str = sprintf("%+.2f [%+.2f,%+.2f]", delta_rt, delta_rt - 1.96*se_rt, delta_rt + 1.96*se_rt)
      delta_dv_str = sprintf("%+.2f [%+.2f,%+.2f]", delta_dv, delta_dv - 1.96*se_dv, delta_dv + 1.96*se_dv)
      printf "delta              %s  %s  %s\n", delta_pr_str, delta_rt_str, delta_dv_str
      # Regression flag (advisory): pass-rate delta <= -0.05 AND CI does not cross 0.
      if (delta_pr > -50 && delta_pr <= -0.05 && pr_d_hi < 0) {
        printf "regression_flag: pass-rate regression (delta=%.3f CI excludes 0)\n", delta_pr
      } else {
        printf "regression_flag: none\n"
      }
    }
  ' "$log_file" 2>/dev/null || true)"

  if [ -z "$awk_out" ]; then
    printf 'no records to evaluate\n'
    return 0
  fi
  printf '%s\n' "$awk_out"
  return 0
}

# CLI entry point — only when invoked as a script (not sourced).
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  MILESTONE=""
  TIER=""
  FLOOR_OVERRIDE=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --milestone)
        # Defensive: missing trailing value must not crash under set -u
        # (FR-12 / CON-5 never-abort).
        if [ $# -ge 2 ]; then MILESTONE="$2"; shift 2; else shift; fi
        ;;
      --tier)
        if [ $# -ge 2 ]; then TIER="$2"; shift 2; else shift; fi
        ;;
      --sample-floor)
        if [ $# -ge 2 ]; then FLOOR_OVERRIDE="$2"; shift 2; else shift; fi
        ;;
      --help|-h)
        printf '%s\n' "Usage: compression-eval.sh --milestone <Mxxx> --tier <N> [--sample-floor <N>]"
        printf '%s\n' "  --milestone <Mxxx>     Required (or auto-resolved)."
        printf '%s\n' "  --tier <N>             Required. 1, 2, or 3."
        printf '%s\n' "  --sample-floor <N>     Default 30."
        printf '%s\n' "  --help, -h             Show this help and exit 0."
        exit 0 ;;
      *) shift ;;
    esac
  done

  if [ -z "$MILESTONE" ]; then
    if [ -x "$_CE_PROJECT_ROOT/scripts/state/find-active-milestone.sh" ]; then
      _ce_active="$(bash "$_CE_PROJECT_ROOT/scripts/state/find-active-milestone.sh" "$_CE_PROJECT_ROOT/.orchestrator" 2>/dev/null || true)"
      MILESTONE="$(printf '%s\n' "$_ce_active" | awk 'NR==1 { print $1 }')"
    fi
  fi

  if [ -z "$TIER" ]; then
    printf '%s\n' "compression-eval: --tier <N> is required" >&2
    exit 0   # FR-12 / CON-5 — never abort.
  fi

  FLOOR="$FLOOR_OVERRIDE"
  if [ -z "$FLOOR" ]; then FLOOR="30"; fi

  compression_eval_render "$MILESTONE" "$TIER" "$FLOOR"
  exit 0
fi
