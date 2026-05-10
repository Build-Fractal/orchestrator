---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M018"
name: "Cost rollup + efficiency footer + doctor anomaly extensions — surface compression savings columns, the one-line 'Compressed: <pct>% reduction over baseline' tail, and the compression-regression flag against the SC-9 calibrated 34.7% floor"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped the four additive integer fields (`filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier1_invocations`) on `dispatch_usage` and `unit_close` JSONL records. T02 EXTENDS the existing M027/P00–P03 surfaces to read these fields PLUS the same-named fields on `payload_breakdown` (which P02/P03/P04 already shipped). All four fields are integer-valued; missing fields are treated as 0 in rollups (CON-5).
- `scripts/diagnostics/metrics-rollup.sh` is the M027/P00 rollup engine. Read once for shape:
  - The aggregation awk pass at lines ~340–530 buckets records by (scope, source, granularity) and tracks per-bucket sums. T02 extends the awk pass to track four additional sums: `bk_filter_dropped[bucket]`, `bk_tier1_savings[bucket]`, `bk_tier2_savings[bucket]`, `bk_tier1_invocs[bucket]`.
  - The render function `metrics_rollup_render` at lines ~534–590 emits the tabular output with a fixed-width header. T02 extends the header and the data row format with four new columns: `FILTER_DROPPED  TIER1_SAVINGS  TIER2_SAVINGS  TIER1_INVOCS`. Per FR-4 / CON-4 (Goodhart pairing), the savings columns appear adjacent to the existing cost columns so a row carrying savings carries cost on the same row.
  - The tabular shape is consumed by `efficiency-footer.sh` (column-by-column awk extraction) and `check-anomalies.sh` (column-by-column awk extraction); T02's column additions go AFTER the existing columns so the existing column indices for cost/quality/retries are preserved (CON-5 carry-forward applied to the rollup column-index contract).
- `scripts/diagnostics/efficiency-footer.sh` is the M027/P02 footer helper. Read once for shape:
  - `efficiency_footer_render` at lines ~44–102 invokes the rollup, extracts a small set of columns, and emits the footer block (≤ 6 lines). T02 extends the render to APPEND a single line: `"  compression: <pct>% reduction over baseline (filter+tier1+tier2 / payload_tokens)"` when any in-scope record carries non-zero savings; the line is omitted when all savings are zero.
  - The `--quiet` short-circuit at line 47 carries forward unchanged.
  - A new config knob `compression.efficiency_footer.enabled` (default true) suppresses the compression line independently of the parent footer's `efficiency_footer` knob; T02 wires this via `scripts/state/read-config.sh` mirroring the existing `efficiency_footer` resolution at lines ~143–152.
- `scripts/diagnostics/check-anomalies.sh` is the M027/P03 anomaly helper. Read once for shape:
  - `check_anomalies_render` at lines ~53–153 invokes the rollup at task granularity, extracts cost/pass_rate/retries by column, and emits flagged rows. T02 extends the awk pass to compute the SAVINGS RATIO per row (sum_savings / sum_payload_tokens — sum_savings = filter_dropped + tier1_savings + tier2_savings; sum_payload_tokens = the existing TOKENS_EST column at index 5) and to flag rows where the ratio falls below the SC-9 calibrated 34.7% floor.
  - The reasons string at lines ~127–130 already concatenates `cost-spike`, `retry-spike`, `low-pass-rate`. T02 adds a fourth reason: ` compression-regression` when `savings_ratio < 0.347` AND `sum_payload_tokens > 0` (guard against div-by-zero degraded path).
  - The new threshold knob `compression_regression_floor` defaults to `0.347` and is configurable via `scripts/state/read-config.sh` mirroring the existing `anomaly_*` knobs at lines ~199–217.
- AP-009 (`scripts/hooks/pre-bash-shape-guard.sh`) bans: compound chains > 2; plain subshells; `$(...|...)` shell forms. Bash 3.2 — no `declare -A`. T02 follows MEM004's emitter-internal carve-out: pipes/awk/$() permitted INSIDE these diagnostic helpers because they are explicitly documented as MEM004-carve-out files (see header comments in metrics-rollup.sh + check-anomalies.sh).
- T01 has shipped (this task depends on T01). T02 does NOT modify dispatch-interface.sh or write-summary.sh.

## Description

Extend the three [M027](../../../../../milestones/M027/index.md) diagnostic surfaces to read the additive savings fields and surface them to the operator. After T02:

1. `bash scripts/diagnostics/metrics-rollup.sh --milestone <id>` emits four new columns appended to the existing tabular shape: `FILTER_DROPPED`, `TIER1_SAVINGS`, `TIER2_SAVINGS`, `TIER1_INVOCS`. Each column is an integer sum across the resolved scope. Pre-P05 records (no savings fields) contribute 0. Existing column indices for cost/quality/retries are preserved.
2. `bash scripts/diagnostics/efficiency-footer.sh --milestone <id>` appends one line to the existing footer when any in-scope record carries a non-zero savings field: `compression: <pct>% reduction over baseline (filter+tier1+tier2 / payload_tokens)`. The line is suppressed under `--quiet` and under `compression.efficiency_footer.enabled: false`. When all savings are zero, the line is omitted entirely.
3. `bash scripts/diagnostics/check-anomalies.sh --milestone <id>` (or `bash scripts/diagnostics/run-doctor.sh`) flags a `compression-regression` reason in the existing anomaly block when the milestone's savings ratio (sum_savings / sum_payload_tokens) falls below the SC-9 calibrated 34.7% floor. The reason composes with the existing `cost-spike`, `retry-spike`, `low-pass-rate` reasons. The flag is suppressed by the existing suppression matrix (`--no-anomaly`, `--yes`, `ORCHESTRATOR_AUTO=1`, `ORCH_ANOMALY_CHECK_ENABLED=false`, sample-floor undershoot).

T02 does NOT ship verifiers, fixtures, or the P05-SUMMARY (T04). T02 ships ONLY the production code that T04's verifiers exercise, plus the corresponding config-knob registrations.

## Inputs

- `scripts/diagnostics/metrics-rollup.sh` — read existing aggregation + render. The awk pass at lines ~340–530 reads tab-pipe normalized rows from the previous `metrics_rollup_normalize` step. Field 7 = cost; 8 = tokens (TOKENS_EST); 9 = pass_rate; 10 = deviations; 11 = retries; 12 = pricing_warning. T02 extends `metrics_rollup_normalize` (around line 230, awk pass) to project four additional fields from each `payload_breakdown` JSONL line (`filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier1_invocations`) AND from each `dispatch_usage` and `unit_close` line (the same fields T01 added — see T01 plan). The four fields project as positions 13, 14, 15, 16 in the normalized stream.
- `scripts/diagnostics/efficiency-footer.sh` — read `efficiency_footer_render`. The rollup output is captured in `rollup_out`; T02 adds a small awk pass to extract the four new columns and compute the savings ratio.
- `scripts/diagnostics/check-anomalies.sh` — read `check_anomalies_render`. The awk pass at lines ~96–151 buckets per-task data; T02 extends the data extraction to capture the four new columns and the existing TOKENS_EST column, then computes the savings ratio per task and per milestone for the regression flag.
- `scripts/state/read-config.sh` — register the two new config knobs:
  - `compression.efficiency_footer.enabled` (default `true`)
  - `compression.regression_floor` (default `0.347` — pinned to SC-9 P00 calibration)
  Both knobs follow the existing `efficiency_footer` / `anomaly_*` resolution shape.
- `templates/orchestrator-config-default.yml` — add the two new keys under the existing `compression:` block so freshly-installed projects inherit the defaults.

## Steps

### Step 1 — Extend `scripts/diagnostics/metrics-rollup.sh` normalization

Inside `metrics_rollup_normalize` (around line 230), the inner awk pass projects each JSONL record onto a normalized tab-pipe row. Add four field extractions, applied to `payload_breakdown`, `dispatch_usage`, and `unit_close` records uniformly:

```awk
# Existing extraction shape (fields 1–12) is preserved; T02 appends four.
fdrop = ""; t1s = ""; t2s = ""; t1i = "";
if (match($0, /"filter_dropped_tokens":[0-9]+/)) {
  v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); fdrop = v;
}
if (match($0, /"tier1_savings_tokens":[0-9]+/)) {
  v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t1s = v;
}
if (match($0, /"tier2_savings_tokens":[0-9]+/)) {
  v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t2s = v;
}
if (match($0, /"tier1_invocations":[0-9]+/)) {
  v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t1i = v;
}
# Append to the existing tab-pipe printf at columns 13–16.
```

Update the printf to emit 16 fields per normalized row (12 existing + 4 new), tab-pipe separated. The exact printf tail becomes `\t%s\t%s\t%s\t%s` for the four new columns.

### Step 2 — Extend `metrics_rollup_aggregate` bucketing

Inside the awk aggregation pass at lines ~340–530, after the existing per-bucket sum bindings (`bk_disp[bucket] += 1`, `bk_cost[bucket] += ...`, etc., around lines 450–467), add four parallel sums:

```awk
if (isnumset(fdrop)) bk_filter_dropped[bucket] += tonum(fdrop);
if (isnumset(t1s))   bk_tier1_savings[bucket] += tonum(t1s);
if (isnumset(t2s))   bk_tier2_savings[bucket] += tonum(t2s);
if (isnumset(t1i))   bk_tier1_invocs[bucket] += tonum(t1i);
```

Initialize the four bucket arrays in the bucket-creation block (around line 446) to 0 alongside the existing `bk_disp[bucket] = 0` initializers.

The savings fields are sourced PRIMARILY from `payload_breakdown` records (which P02/P03/P04 already populate). T01 also writes the same fields onto `dispatch_usage` + `unit_close` — but we project from `payload_breakdown` to avoid double-counting. The aggregate should sum the field across all `payload_breakdown` records in scope, ignoring the rolled-up copies on `dispatch_usage` / `unit_close`. Implement this by scoping the four new field accumulators to rows where `rt == "payload_breakdown"` ONLY (mirror the existing `tokens_aux` scoping at lines ~386–397).

### Step 3 — Extend the per-scope output emit

Inside the END block at lines ~475–528, the per-scope output printf at line 523 emits 12 pipe-separated fields. Extend the output to 16 fields:

```awk
printf "%s|%s|%d|%.8f|%d|%.8f|%.8f|%s|%d|%d|%d|%s|%d|%d|%d|%d\n",
  f_gran, skey, bk_disp[bk], cost_cell, bk_toks[bk],
  p50, p95,
  (pass_rate < 0 ? "unknown" : sprintf("%.4f", pass_rate)),
  bk_dev[bk], bk_retry[bk], warn_n, bk_source[bk],
  bk_filter_dropped[bk], bk_tier1_savings[bk], bk_tier2_savings[bk], bk_tier1_invocs[bk];
```

But the four new sums need to be looked up across all buckets sharing the same scope key (since the savings come from `payload_breakdown` records, not from the chosen bucket which is keyed off `unit_close` / `dispatch_usage`). The cleanest path: track per-scope (not per-bucket) sums in a separate map accumulated at row-read time, and look them up by `skey` in the END emit. Implement:

```awk
# In the row-read block, in addition to per-bucket bookkeeping:
if (rt == "payload_breakdown") {
  scope_filter_dropped[key] += tonum(fdrop);
  scope_tier1_savings[key]  += tonum(t1s);
  scope_tier2_savings[key]  += tonum(t2s);
  scope_tier1_invocs[key]   += tonum(t1i);
}
# In the END emit, replace bk_filter_dropped[bk] with scope_filter_dropped[skey], etc.
```

### Step 4 — Extend `metrics_rollup_render` header + data formatting

In `metrics_rollup_render` at lines ~540–590:

- Header line at line ~541: append `  FILTER_DROPPED  TIER1_SAVINGS  TIER2_SAVINGS  TIER1_INVOCS` to the existing header.
- Data-row read at line ~545: extend the `IFS='|' read -r ...` to bind the four new fields:
  ```bash
  while IFS='|' read -r gran scope disp cost tokens p50 p95 pass dev retry warn src \
      filter_dropped tier1_savings tier2_savings tier1_invocs; do
  ```
- Data-row printf: extend the existing format with four right-padded integer columns:
  ```bash
  # ... existing printf ... append:
  #   "  %14d  %13d  %13d  %12d\n"  filter_dropped tier1_savings tier2_savings tier1_invocs
  ```
  Use the same defensive defaulting pattern as `cost_disp`: when a value is empty, render as `0`.

### Step 5 — Extend `scripts/diagnostics/efficiency-footer.sh`

Inside `efficiency_footer_render` at lines ~44–102, after the existing per-line emits (`scope_text`, `cost_text`, `qual_text`, `count_text`, `warn_text` — lines ~96–100), add a new compression-line block:

```bash
  # M018/P05/T02: compression savings line.
  # Read the four new columns from the same data_line; compute pct = sum_savings / tokens * 100.
  # Suppress when all four are zero OR when the new config knob is false.
  local cfg_compression_footer="${ORCH_COMPRESSION_FOOTER:-}"
  if [ -z "$cfg_compression_footer" ] && [ -x "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
    cfg_compression_footer="$(bash "$_EFF_PROJECT_ROOT/scripts/state/read-config.sh" compression.efficiency_footer.enabled 2>/dev/null || true)"
  fi
  case "$cfg_compression_footer" in
    false|FALSE|False|0|no|NO|No) ;; # suppressed
    *)
      local _eff_savings_line
      _eff_savings_line="$(printf '%s\n' "$data_line" | awk '
        {
          # Columns 13–16 = filter_dropped, tier1_savings, tier2_savings, tier1_invocs.
          # Column 5 = TOKENS_EST.
          fdrop = $13 + 0; t1s = $14 + 0; t2s = $15 + 0;
          tokens = $5 + 0;
          if (tokens > 0) {
            pct = (fdrop + t1s + t2s) * 100.0 / tokens;
            if (pct >= 0.5) {
              printf "compression: %.1f%% reduction over baseline (filter+tier1+tier2 / payload_tokens)", pct;
            }
          }
        }
      ' || true)"
      if [ -n "$_eff_savings_line" ]; then
        printf '  %s\n' "$_eff_savings_line"
      fi
      ;;
  esac
```

The 0.5% threshold guards against rounding noise — sub-1% reductions are not meaningful.

### Step 6 — Extend `scripts/diagnostics/check-anomalies.sh`

Inside `check_anomalies_render` at lines ~96–151, the awk pass extracts cost/pass_rate/retries by column. Extend the column extraction to also read the savings columns and TOKENS_EST, then compute the savings ratio:

```awk
# Inside the per-task accumulator block:
tokens[n] = $5 + 0;                       # TOKENS_EST (existing column 5).
fdrop[n]  = $13 + 0;
t1s[n]    = $14 + 0;
t2s[n]    = $15 + 0;
# Existing extractions for cost/pass/retries unchanged.

# In the per-task flag-evaluation loop, add:
if (tokens[i] > 0) {
  ratio = (fdrop[i] + t1s[i] + t2s[i]) / tokens[i];
  if (ratio < floor) reasons = reasons " compression-regression";
}
```

Pass the floor as an awk variable: `-v floor_s="$COMPRESSION_FLOOR"` and `BEGIN { floor = floor_s + 0 }`. Resolve `COMPRESSION_FLOOR` in the CLI block at lines ~199–217 mirroring the existing `MULT` resolution:

```bash
COMPRESSION_FLOOR=""
if [ -x "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" ]; then
  COMPRESSION_FLOOR="$(bash "$_CA_PROJECT_ROOT/scripts/state/read-config.sh" compression.regression_floor 2>/dev/null || true)"
fi
if [ -z "$COMPRESSION_FLOOR" ] || [ "$COMPRESSION_FLOOR" = "null" ]; then COMPRESSION_FLOOR="0.347"; fi
```

The flagged-row printf (line ~139) extends to include the savings ratio when compression-regression fired:

```awk
if (reasons ~ /compression-regression/) {
  printf "FLAGGED %s %s pass_rate=%.2f retry_count=%d savings_ratio=%.3f reasons=%s\n",
    scopes[i], cost_token, pass_rate[i], retries[i], ratio, reasons;
} else {
  # Existing format.
  printf "FLAGGED %s %s pass_rate=%.2f retry_count=%d reasons=%s\n",
    scopes[i], cost_token, pass_rate[i], retries[i], reasons;
}
```

### Step 7 — Register config knobs

Edit `templates/orchestrator-config-default.yml` to add under the existing `compression:` block:

```yaml
  efficiency_footer:
    enabled: true     # M018/P05/T02 — compression line in efficiency footer.
  regression_floor: 0.347   # M018/P05/T02 — SC-9 P00-calibrated.
```

The `read-config.sh` resolver consumes flat dotted keys (`compression.efficiency_footer.enabled`, `compression.regression_floor`); confirm the existing knowledge-filter / tier1 / tier2 keys parse the same way and mirror the shape.

Edit `.orchestrator/config.yml` to add the same keys (this repo's local override).

### Step 8 — Defensive backward-compatibility

For each of the three extended scripts, the new code paths default to zero / suppressed when:

- The log file lacks the new fields entirely (pre-P02 records) — extraction returns empty / 0; no flag fires.
- `tokens_est == 0` for a scope (degraded log) — savings ratio is undefined; no flag fires; no compression line in footer.
- Config knob is absent — `read-config.sh` returns "null" or empty; the script falls back to its built-in default (true for footer; 0.347 for floor).

These match the M027 carry-forward "never abort on degraded inputs" posture (CON-5) — the rollup engine, footer, and doctor anomaly block already operate this way; T02 extends the posture to the four new fields.

## Verification

T02 produces no verifier scripts (those are T04). T02's production code is exercised by:

- `m018-p05-cost-rollup-savings-columns.sh` (T04) — Step 1–4.
- `m018-p05-efficiency-footer-compression.sh` (T04) — Step 5.
- `m018-p05-doctor-compression-regression.sh` (T04) — Step 6.

Mechanical self-checks (syntax-only — production-code lint):

- Check: `bash -n scripts/diagnostics/metrics-rollup.sh`
- Check: `bash -n scripts/diagnostics/efficiency-footer.sh`
- Check: `bash -n scripts/diagnostics/check-anomalies.sh`
- Check: `bash -n scripts/lib/knowledge-filter.sh`
- Check: `bash -n scripts/state/read-config.sh`

## Must-Haves (subset addressed by this task)

- **Truth #3**: cost rollup savings columns. Wholly addressed by Steps 1–4.
- **Truth #4**: efficiency footer compression line. Wholly addressed by Step 5.
- **Truth #5**: doctor compression-regression flag. Wholly addressed by Step 6.

T02 does not address:

- Truth #1, #2 (T01).
- Truth #6, #7 (T03 — `compression-eval.sh`).
- Truth #8 (T04 — dual-write recent-changes).

## Notes

- The four new columns appear AT THE END of the rollup output to preserve column-index back-compat for any external consumer (referenced in M027/P00–P03 verifiers; the existing column indices for SCOPE / DISPATCHES / EST_COST_USD / TOKENS_EST / P50_COST / P95_COST / PASS_RATE / DEVIATIONS / RETRIES / WARNINGS / SOURCE remain at indices 1–12).
- The compression line in `efficiency-footer.sh` is appended to the existing block, not replacing the existing pricing/cost/quality lines — the footer's ≤ 6-line contract becomes ≤ 7 lines for the post-P05 case. This is a documented additive extension of the M027/P02 footer contract; T04's verifier asserts the line is present-or-absent, not a fixed line count.
- The `compression-regression` reason composes additively with the existing four reasons. A row may carry multiple reasons (e.g., `cost-spike compression-regression`) — the existing reasons concatenation logic carries forward.
- The SC-9 calibrated 34.7% floor is the milestone-summary's officially-pinned threshold (per spec.md SC-9, archived at `.orchestrator/scratch/m018-section-distribution-output.{json,txt}`). T02 wires the floor as a configurable knob so future calibration updates do not require code changes.
- Bash 3.2: parallel scalars throughout; awk inside the helpers (MEM004 carve-out); no `declare -A`.
