---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P05"
milestone: "M018"
name: "scripts/diagnostics/compression-eval.sh — sourceable + CLI cohort segmentation diagnostic that reports outcome-rate deltas (verification_pass_rate, retry_count, deviation_count) between compressed and uncompressed cohorts with confidence intervals; --tier <N> filter; below-floor sample emits 'insufficient sample' and exits 0"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped the four additive savings fields on `unit_close` JSONL records (`filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier1_invocations`). T03's cohort segmentation reads these fields plus the existing `verification_pass_rate`, `retry_count`, `deviation_count` fields from `unit_close` records.
- T03 also reads `payload_breakdown` records to identify which units' dispatches actually fired the requested tier — the savings field on `unit_close` rolls up across the whole unit; the `payload_breakdown` record is the per-dispatch ground truth.
- The execution-log.jsonl path resolution mirrors the existing `metrics-rollup.sh` path: under a milestone directory, `<milestone-dir>/execution-log.jsonl`. T03 uses `scripts/state/find-active-milestone.sh` to resolve the active milestone when `--milestone` is omitted.
- The "compressed" vs "uncompressed" cohort definition for tier N (where N is 1 or 2 in P05; tier 3 is reserved for P06):
  - **Compressed cohort**: `unit_close` records where the matching scope's aggregated `payload_breakdown` records carry `tier<N>_savings_tokens > 0`.
  - **Uncompressed cohort**: `unit_close` records on the same milestone where the same scope's aggregated `payload_breakdown` records carry `tier<N>_savings_tokens == 0` OR the field is absent.
  The cohort match is on (milestone, phase, task) for task-granularity unit_close records; phase-granularity and milestone-granularity records are excluded from the cohort split (they are aggregations, not per-task observations).
- The outcome-rate metrics:
  - `verification_pass_rate` (real number 0.0–1.0 or `"unknown"`; treat unknown as missing and exclude from the cohort metric)
  - `retry_count` (non-negative integer)
  - `deviation_count` (non-negative integer)
- The confidence interval method:
  - For `verification_pass_rate` (a proportion): Wilson 95% CI per cohort; cohort delta CI via the standard normal-approximation pooled formula.
  - For `retry_count` / `deviation_count` (count metrics, possibly heavy-tailed): per-cohort mean + standard error of the mean (SEM); cohort delta CI via the t-test approximation.
  Implemented in awk (no python, no jq) using closed-form arithmetic. Bash 3.2 — no associative arrays in the awk pass beyond the standard awk indexed maps.
- Sample-size floor: default 30 per cohort (`--sample-floor 30`). When either cohort is below the floor, emit `"insufficient sample (compressed=N1 uncompressed=N2 floor=F)"` and exit 0 — no noisy false-positives.
- AP-009 + AD-19: `compression-eval.sh` IS a Check: command target (T04 wires it up). The CLI script's own body uses MEM004 carve-out for awk + pipes; T04's verifier `m018-p05-compression-eval.sh` invokes it as a single-script-file `Check:`. The script CLI itself MAY use compound chains internally per the existing `metrics-rollup.sh` precedent; T04's `m018-p05-compression-eval-shape.sh` verifier asserts compliance with the documented shape rules.
- Bash 3.2 — no `declare -A`, no process substitution, no merged stdout-stderr shorthand.

## Description

Ship a new sourceable + CLI diagnostic at `scripts/diagnostics/compression-eval.sh`. The diagnostic answers the question "did the dispatches that fired tier N produce different outcomes than the dispatches on the same milestone that did not fire tier N?" by segmenting `unit_close` records into compressed vs uncompressed cohorts and reporting the per-cohort + delta means with confidence intervals.

After T03:

1. `bash scripts/diagnostics/compression-eval.sh --milestone M018 --tier 1` against a fixture log with mixed compressed + uncompressed dispatches reports:

   ```
   # compression-eval — milestone=M018 tier=1
   COHORT       N    PASS_RATE         RETRY_COUNT       DEVIATION_COUNT
   compressed   42   0.952 [0.84,0.99]  0.43 ± 0.12       0.07 ± 0.04
   uncompressed 48   0.917 [0.80,0.97]  0.52 ± 0.14       0.10 ± 0.05
   delta              +0.035 [-0.06,+0.13]  -0.09 [-0.27,+0.09]  -0.03 [-0.10,+0.04]
   regression_flag: none
   ```

2. `bash scripts/diagnostics/compression-eval.sh --milestone M018 --tier 1 --sample-floor 100` against the same log emits:

   ```
   # compression-eval — milestone=M018 tier=1
   insufficient sample (compressed=42 uncompressed=48 floor=100)
   ```

   Exit 0.

3. `bash scripts/diagnostics/compression-eval.sh --milestone <id> --tier 3` (P05 era) emits a one-line "tier 3 reserved for P06; not yet supported" advisory and exits 0. T03 ships the `--tier 3` path as a recognized-but-no-op stub so the CLI surface is stable for P06.

4. The diagnostic is sourceable: `source scripts/diagnostics/compression-eval.sh` and call `compression_eval_render <milestone> <tier> <sample_floor>`. The function returns 0 always; degraded inputs surface as text on stdout.

5. The diagnostic emits zero JSONL records (FR-12 read-only).
6. Token cost: zero (bash + awk + grep only — FR-21).

T03 ships ONLY:

- `scripts/diagnostics/compression-eval.sh` — the new diagnostic.

T03 does NOT ship:

- Verifiers, fixtures, fixture-staging helper, P05-SUMMARY, dual-write (T04).
- T01's emitter extensions or T02's surface extensions.

## Inputs

- `scripts/dispatch/build-context.sh:_bc_emit_payload_breakdown` — read for the JSONL field shape so T03's cohort detector extracts the right fields. Field names: `record_type`, `unitId`, `milestone`, `phase`, `task`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier1_invocations`, `filter_dropped_tokens`. (Tier 3 fields land in P06.)
- `scripts/knowledge/write-summary.sh:_ws_emit_unit_close` — read for the unit_close JSONL field shape after T01: `record_type`, `granularity`, `unitId`, `milestone`, `phase`, `task`, `verification_pass_rate`, `deviation_count`, `retry_count`, plus the four T01-additive savings fields.
- `scripts/diagnostics/metrics-rollup.sh` — read for shape conventions: header at top, sourceable guard, project-root resolution, MEM004 carve-out comments, CLI argv parser. T03 mirrors the same structural skeleton.
- `scripts/diagnostics/efficiency-footer.sh` and `check-anomalies.sh` — same shape skeleton.
- `scripts/state/find-active-milestone.sh` — resolves the active milestone for the no-`--milestone` case.

## Steps

### Step 1 — Author the script header + sourceable guard

```bash
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
#   --tier <N>             Required. 1 or 2 in P05; 3 emits an advisory stub for P06.
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
```

### Step 2 — Author `compression_eval_render`

The render function takes three arguments: `<milestone>`, `<tier>`, `<sample_floor>`. Body:

```bash
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
    1|2) ;;
    3)
      printf 'tier 3 reserved for P06; not yet supported\n'
      return 0
      ;;
    *)
      printf 'unsupported tier=%s (must be 1, 2, or 3)\n' "$tier"
      return 0
      ;;
  esac

  local log_file="$_CE_PROJECT_ROOT/.orchestrator/milestones/$milestone/execution-log.jsonl"
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
  # Two passes via awk -f / piped invocation — single command, single stdin.
  # Compute per-cohort mean + variance + n. Emit cohort + delta block with CIs.
  # Below-floor: emit "insufficient sample" and exit.

  local awk_out
  awk_out="$(awk -v tier="$tier" -v floor="$floor" '
    function tonum(x) { return (x == "" || x == "null") ? 0 : x + 0 }
    function field_num(line, key,    re, m, v) {
      re = "\"" key "\":[0-9]+"
      if (match(line, re)) {
        v = substr(line, RSTART, RLENGTH); sub(/.*:/, "", v); return v + 0
      }
      return 0
    }
    function field_str(line, key,    re, m, v) {
      re = "\"" key "\":\"[^\"]*\""
      if (match(line, re)) {
        v = substr(line, RSTART, RLENGTH); sub(/^"[^"]*":"/, "", v); sub(/"$/, "", v); return v
      }
      return ""
    }
    function field_real(line, key,    re, m, v) {
      re = "\"" key "\":(-?[0-9]+(\\.[0-9]+)?)"
      if (match(line, re)) {
        v = substr(line, RSTART, RLENGTH); sub(/.*:/, "", v); return v + 0
      }
      return -1.0
    }
    /"record_type":"payload_breakdown"/ {
      m = field_str($0, "milestone")
      p = field_str($0, "phase")
      t = field_str($0, "task")
      key = m "/" p "/" t
      if (tier == "1") {
        v = field_num($0, "tier1_savings_tokens")
      } else {
        v = field_num($0, "tier2_savings_tokens")
      }
      if (v > 0) tier_fired[key] = 1
      else if (!(key in tier_fired)) tier_fired[key] = 0
    }
    /"record_type":"unit_close"/ {
      g = field_str($0, "granularity")
      if (g != "task") next
      m = field_str($0, "milestone")
      p = field_str($0, "phase")
      t = field_str($0, "task")
      key = m "/" p "/" t
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
      # Wilson 95% CI for pass-rate proportion.
      function wilson_lo(p, nn,    z, denom, center, half) {
        if (nn <= 0 || p < 0) return -1
        z = 1.96; denom = 1 + z*z/nn
        center = (p + z*z/(2*nn)) / denom
        half = (z/denom) * sqrt(p*(1-p)/nn + z*z/(4*nn*nn))
        v = center - half; if (v < 0) v = 0
        return v
      }
      function wilson_hi(p, nn,    z, denom, center, half) {
        if (nn <= 0 || p < 0) return -1
        z = 1.96; denom = 1 + z*z/nn
        center = (p + z*z/(2*nn)) / denom
        half = (z/denom) * sqrt(p*(1-p)/nn + z*z/(4*nn*nn))
        v = center + half; if (v > 1) v = 1
        return v
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
      if (delta_pr > -50) {
        pp = (pr_sum["compressed"] + pr_sum["uncompressed"]) / (pr_n["compressed"] + pr_n["uncompressed"])
        se_pr = sqrt(pp * (1 - pp) * (1.0/pr_n["compressed"] + 1.0/pr_n["uncompressed"]))
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
      # Regression flag (advisory): pass-rate delta < -0.05 AND CI does not cross 0.
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
```

### Step 3 — Author the CLI block

```bash
# CLI entry point — only when invoked as a script (not sourced).
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  MILESTONE=""
  TIER=""
  FLOOR_OVERRIDE=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --milestone)     MILESTONE="$2"; shift 2 ;;
      --tier)          TIER="$2"; shift 2 ;;
      --sample-floor)  FLOOR_OVERRIDE="$2"; shift 2 ;;
      --help|-h)
        printf '%s\n' "Usage: compression-eval.sh --milestone <Mxxx> --tier <N> [--sample-floor <N>]"
        printf '%s\n' "  --milestone <Mxxx>     Required (or auto-resolved)."
        printf '%s\n' "  --tier <N>             Required. 1 or 2 in P05; 3 reserved for P06."
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
```

### Step 4 — Make the script executable

`chmod +x scripts/diagnostics/compression-eval.sh` so the verifier can invoke it as a single bash script. (The phase-close verifier `m018-p05-compression-eval.sh` will assert this.)

### Step 5 — Self-test during development

Run `bash scripts/diagnostics/compression-eval.sh --help` and confirm the usage block. Run against the active M018 log (which already has tier1 + tier2 records by P05): `bash scripts/diagnostics/compression-eval.sh --milestone M018 --tier 1 --sample-floor 5`. Expect a small-sample report or "insufficient sample" depending on actual log volume.

## Verification

T03 produces no verifier scripts (those are T04). T03's production code is exercised by:

- `m018-p05-compression-eval.sh` (T04) — exercises the cohort segmentation + outcome-rate delta against a fixture log.
- `m018-p05-compression-eval-shape.sh` (T04) — asserts the script is sourceable AND CLI-runnable, has the AP-009/AD-19 carve-out comments, exits 0 in all paths, emits zero JSONL, and zero LLM tokens.

Mechanical self-check (T03-local; AD-19 single-script-file shape; no T04 dependency):

- Check: `bash -n scripts/diagnostics/compression-eval.sh`

## Must-Haves (subset addressed by this task)

- **Truth #6**: compression-eval cohort segmentation. Wholly addressed by Steps 1–4.
- **Truth #7**: compression-eval shape contract. Wholly addressed by Steps 1, 4 (sourceable guard, CLI duality, MEM004 carve-out doc-comment, executable bit).

T03 does not address Truths #1–#5 (T01, T02) or #8 (T04).

## Notes

- The Wilson 95% CI for proportions is the textbook formula; closed-form, no iteration; bash-3.2-friendly via awk arithmetic.
- The pooled SE for proportion deltas uses the normal approximation; this is acceptable for the "advisory" flag at the n>=30/n>=30 boundary. Below the floor, the diagnostic refuses to flag — it emits "insufficient sample" instead.
- `delta_pr <= -0.05 AND CI excludes 0` is the advisory regression threshold (5pp pass-rate drop with statistical confidence). T03 surfaces this as a one-line `regression_flag:` field; T02's doctor anomaly extension flags compression-regression at the savings-ratio level (not the outcome-rate level — that's T03's job exclusively).
- Tier 3 stub: emits "tier 3 reserved for P06; not yet supported" and exits 0. P06 will replace the stub with the same cohort logic against `tier3_savings_tokens` / `tier3_invocations`.
- The script explicitly does not invoke `metrics-rollup.sh` — T03 walks the JSONL directly to maintain the field-extraction granularity needed for the cohort split. This is the same pattern `check-anomalies.sh` uses (delegation to the rollup engine for table data + secondary awk pass for per-row analysis).
- AGENTS.md / CLAUDE.md `orchestrator:recent-changes` dual-write is T04, not T03.
- Bash 3.2: parallel scalars (`MILESTONE`, `TIER`, `FLOOR_OVERRIDE`); awk inside the helper (MEM004 carve-out); no `declare -A`; no process substitution; no merged stdout-stderr.
