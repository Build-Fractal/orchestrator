---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P06"
milestone: "M018"
name: "Additive `tier3_compression_savings_tokens` + `tier3_invocations` fields on payload_breakdown / dispatch_usage / unit_close JSONL records (CON-5); metrics-rollup.sh `TIER3_SAVINGS` + `TIER3_INVOCS` columns; efficiency-footer.sh + check-anomalies.sh fold tier3 into existing rollup denominators"
depends_on: ["T01"]
---

## Prerequisites

- T01 has shipped `_bc_apply_tier3` writing `$TMPDIR_BUILD/_tier3_stats.txt` with the line `savings_tokens=<N> invocations=<M>` (zero on every short-circuit / failure path; non-zero only on a successful summarization).
- The P05/T01 emitter pattern is the canonical contract T02 mirrors. Re-read these blocks before authoring:

  - `scripts/dispatch/build-context.sh:_bc_emit_payload_breakdown` (lines ~1593-1754) — the existing tier1 / tier2 stats-file readers (lines ~1681-1727) and the printf line (lines ~1729-1736). T02 adds the same shape for tier3.
  - `scripts/dispatch/dispatch-interface.sh:_di_emit_dispatch_usage` — the P05 dispatch_usage emitter that rolls up the four P05 fields from in-flight `payload_breakdown` rows. T02 widens this to include the two tier3 fields under unitId-scoped match.
  - `scripts/knowledge/write-summary.sh:_ws_emit_unit_close` — the P05 unit_close emitter with granularity-aware rollup (task = M+P+T, phase = M+P, milestone = M only). T02 widens this with the two tier3 fields under the same granularity scope.
  - `scripts/diagnostics/metrics-rollup.sh` — the P05 column-projection awk pass projects four new columns at indices 13-16 (FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS). T02 appends two more (TIER3_SAVINGS / TIER3_INVOCS) at indices 17-18; columns 1-12 + 13-16 stay byte-identical for back-compat consumers.
  - `scripts/diagnostics/efficiency-footer.sh` — the P05 compression-line currently sums `filter_dropped + tier1_savings + tier2_savings` for the numerator. T02 folds `tier3_savings` into the same sum; denominator (payload_tokens) is unchanged.
  - `scripts/diagnostics/check-anomalies.sh` — the P05 compression-regression flag computes `sav_total / payload_tokens` per row; sav_total is the sum of the four P05 savings fields. T02 folds `tier3_compression_savings_tokens` into sav_total only (T2 does NOT introduce a new tier3-specific anomaly reason — the existing compression-regression flag composes additively).
- CON-5 (additive emitters): pre-P06 records remain valid JSON; downstream rollups treat absent fields as zero. T02 writes the new fields at the END of each printf line (after the existing P05 fields) so the column-index contract on rollup is preserved.
- MEM004 emitter-internal carve-out: pipes / `$()` / awk permitted inside the emitter / rollup-helper bodies. T02 changes do NOT need single-script-file shape (that rule applies to Check: lines, not script bodies).
- AD-19 / AP-009: T02's task-local extractable Check is `bash -n scripts/dispatch/build-context.sh` (the auto-loop verify parser refuses zero-Check plans). The canonical truth verifier `m018-p06-tier3-additivity.sh` ships in T04.
- Bash 3.2 (MEM001).

## Description

T02 ships:

1. `payload_breakdown` JSONL emitter widening in `_bc_emit_payload_breakdown` — read `$TMPDIR_BUILD/_tier3_stats.txt`, extract `savings_tokens` and `invocations`, append `"tier3_compression_savings_tokens":<N>,"tier3_invocations":<M>` to the record's printf line (after the existing P05 fields, before `model` / `source` / `timestamp`).
2. `dispatch_usage` JSONL emitter widening in `_di_emit_dispatch_usage` (and the co-located emitter `_bc_emit_dispatch_usage_colocated` in `build-context.sh`) — roll up `tier3_compression_savings_tokens` + `tier3_invocations` from in-flight `payload_breakdown` rows under the same unitId-scope rule the P05 fields use; emit them on the dispatch_usage record adjacent to the existing fields.
3. `unit_close` JSONL emitter widening in `_ws_emit_unit_close` — roll up the two tier3 fields under the same granularity-aware scope the P05 fields use (task = M+P+T, phase = M+P, milestone = M only).
4. `metrics-rollup.sh` column-projection widening — append `TIER3_SAVINGS` + `TIER3_INVOCS` columns at indices 17-18, after the four P05 columns at 13-16.
5. `efficiency-footer.sh` compression-line widening — fold `tier3_compression_savings_tokens` into the same numerator sum the P05 fields contribute to.
6. `check-anomalies.sh` compression-regression denominator widening — fold `tier3_compression_savings_tokens` into the per-row `sav_total` sum.

T02 does NOT ship:

- `_bc_apply_tier3` helper or prompt template (T01).
- `compression-eval.sh --tier 3` cohort logic (T03 — that READS the new field this task writes).
- Verifiers, fixtures, fixture-staging helper, P06-SUMMARY, dual-write (T04).

## Inputs

Surface contracts T02 reads from upstream files:

- `scripts/dispatch/build-context.sh:_bc_emit_payload_breakdown` (lines ~1681-1736) — the four-block tier1/tier2 stats-file reader pattern. Each block:
  1. `local fieldname=0`
  2. `local _stats_file="$TMPDIR_BUILD/_tierN_stats.txt"`
  3. `if [ -f "$_stats_file" ]; then ... awk extract ... fi`
  4. defensive `if [ -z "$fieldname" ]; then fieldname=0; fi`

  T02 adds a fifth block for `_tier3_stats.txt` extracting `savings_tokens` (named `tier3_compression_savings_tokens` on the emit) and `invocations` (named `tier3_invocations`).

- `scripts/dispatch/build-context.sh:_bc_emit_payload_breakdown` printf line (lines ~1729-1736) — single printf with format string + variadic value list. T02 widens both the format string and the value list with the two new fields, placed BEFORE the closing `model` / `source` / `timestamp` triplet.

- `scripts/dispatch/dispatch-interface.sh:_di_emit_dispatch_usage` — the P05/T01 emitter rolls up `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier1_invocations` from in-scope `payload_breakdown` records via single-pass awk over `execution-log.jsonl`. T02 extends the same awk pass to extract `tier3_compression_savings_tokens` + `tier3_invocations`.

- `scripts/knowledge/write-summary.sh:_ws_emit_unit_close` — the P05/T01 emitter rolls up the four P05 fields under granularity-aware scope. T02 extends the awk pass and the printf line with the two tier3 fields.

- `scripts/diagnostics/metrics-rollup.sh` — read for the column-projection awk pass shape: header line, scope_*[skey] map accumulator, render-loop with `defensive zero-fill`, and the `printf` that materializes each row. T02 appends the two new columns at the end.

- `scripts/diagnostics/efficiency-footer.sh` — read for the numerator-sum awk pass. T02 widens the sum.

- `scripts/diagnostics/check-anomalies.sh` — read for the per-row sav_total computation. T02 widens the sum.

## Steps

### Step 1 — Widen `_bc_emit_payload_breakdown` to read tier3 stats

In `scripts/dispatch/build-context.sh`, after the existing tier2 block (lines ~1710-1727), insert:

```bash
  # M018/P06/T02 (CON-5): additive `tier3_compression_savings_tokens` +
  # `tier3_invocations` fields. Reads $TMPDIR_BUILD/_tier3_stats.txt written
  # by _bc_apply_tier3 (T01). Defaults to 0 when tier3 was disabled, the
  # file is absent, the section did not exceed budget, MIT-08 density
  # pre-check failed, intensity gate fired, or the LLM call failed
  # (FR-9 failure-passthrough — every short-circuit path leaves the stats
  # file at savings_tokens=0 invocations=0).
  local tier3_compression_savings_tokens=0 tier3_invocations=0
  local _bc_pb_t3_stats="$TMPDIR_BUILD/_tier3_stats.txt"
  if [ -f "$_bc_pb_t3_stats" ]; then
    tier3_compression_savings_tokens="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^savings_tokens=/) {
          sub("savings_tokens=", "", $i)
          print $i
          exit
        }
      }
    }' "$_bc_pb_t3_stats")"
    tier3_invocations="$(awk '{
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^invocations=/) {
          sub("invocations=", "", $i)
          print $i
          exit
        }
      }
    }' "$_bc_pb_t3_stats")"
    if [ -z "$tier3_compression_savings_tokens" ]; then tier3_compression_savings_tokens=0; fi
    if [ -z "$tier3_invocations" ];                  then tier3_invocations=0; fi
  fi
```

### Step 2 — Widen the `_bc_emit_payload_breakdown` printf line

Replace the existing printf line (lines ~1729-1736) with:

```bash
  printf '{"record_type":"payload_breakdown","unitId":"%s/%s/%s","milestone":"%s","phase":"%s","task":"%s","payload_chars":%d,"payload_tokens_estimate":%d,"token_estimate_method":"char-quartile","section_tokens":{%s},"filter_dropped_tokens":%d,"tier1_savings_tokens":%d,"tier1_invocations":%d,"tier2_savings_tokens":%d,"tier3_compression_savings_tokens":%d,"tier3_invocations":%d,"model":"%s","source":"estimate","timestamp":"%s"}\n' \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$MILESTONE_ID" "$PHASE_ID" "$TASK_ID" \
    "$payload_chars" "$payload_tokens" \
    "$section_tokens_json" "$filter_dropped_tokens" \
    "$tier1_savings_tokens" "$tier1_invocations" \
    "$tier2_savings_tokens" \
    "$tier3_compression_savings_tokens" "$tier3_invocations" \
    "$model" "$ts" \
    >> "$log_file" 2>/dev/null || {
    printf 'build-context.sh: payload_breakdown append failed on %s\n' "$log_file" >&2
    return 0
  }
```

The two new fields are placed AFTER `tier2_savings_tokens` and BEFORE `model` — preserving every prior field's position so existing JSONL consumers see no shift.

### Step 3 — Widen `_di_emit_dispatch_usage` rollup

In `scripts/dispatch/dispatch-interface.sh`, locate the awk pass that computes the four P05 fields (rolls up `payload_breakdown` records keyed on unitId match). Extend with the two tier3 fields:

```awk
/"record_type":"payload_breakdown"/ {
  if (match($0, /"unitId":"[^"]*"/) ) {
    uid = substr($0, RSTART+10, RLENGTH-11)
    if (uid != target_uid) next
  }
  # ... existing four-field extraction ...
  if (match($0, /"tier3_compression_savings_tokens":[0-9]+/)) {
    v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t3_sav += v + 0
  }
  if (match($0, /"tier3_invocations":[0-9]+/)) {
    v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); t3_inv += v + 0
  }
}
```

The accumulators `t3_sav` / `t3_inv` are emitted in the dispatch_usage record's printf line alongside the four P05 accumulators. Find the printf line, widen the format string + value list with `"tier3_compression_savings_tokens":%d,"tier3_invocations":%d,` placed after the four P05 fields and before the `model`/`source`/`timestamp` triplet.

The same change applies to `_bc_emit_dispatch_usage_colocated` in `build-context.sh` (the co-located emitter that mirrors the dispatch-interface emit). Both emitters need the same two new fields under the same scope rule.

### Step 4 — Widen `_ws_emit_unit_close` rollup

In `scripts/knowledge/write-summary.sh`, locate the P05 awk pass that rolls up the four P05 fields under granularity-aware scope (task = M+P+T, phase = M+P, milestone = M only). Extend with the two tier3 fields under the same scope rule. The pattern mirrors Step 3 verbatim — same `match() / substr() / += accumulator` shape — but the scope filter is the granularity-aware one (read the existing block to copy its structure rather than re-deriving).

Widen the printf line for the unit_close record with the two new fields placed after the four P05 fields and before any closing fields.

### Step 5 — Append `TIER3_SAVINGS` + `TIER3_INVOCS` columns to `metrics-rollup.sh`

In `scripts/diagnostics/metrics-rollup.sh`, locate the column-projection awk pass. The P05/T02 change appended four columns at indices 13-16. T02 (this task) appends two more at indices 17-18. The accumulator pattern:

```awk
/"record_type":"payload_breakdown"/ {
  # ... existing scope_filter[skey] / scope_t1[skey] / scope_t2[skey] / scope_inv[skey] accumulators ...
  if (match($0, /"tier3_compression_savings_tokens":[0-9]+/)) {
    v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); scope_t3[skey] += v + 0
  }
  if (match($0, /"tier3_invocations":[0-9]+/)) {
    v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); scope_t3inv[skey] += v + 0
  }
}
```

(Skip the rolled-up copies on dispatch_usage / unit_close to avoid double-counting — the same restriction P05/T02 introduced for the four P05 columns. Only `payload_breakdown` rows feed savings sums.)

The render loop's printf widens with `\t%d\t%d` after the four P05 columns:

```awk
END {
  printf "scope\t...\tFILTER_DROPPED\tTIER1_SAVINGS\tTIER2_SAVINGS\tTIER1_INVOCS\tTIER3_SAVINGS\tTIER3_INVOCS\n"
  for (skey in scope_*) {
    printf "%s\t...\t%d\t%d\t%d\t%d\t%d\t%d\n", ..., scope_t3[skey] + 0, scope_t3inv[skey] + 0
  }
}
```

(Defensive `+ 0` zero-fill so absent map keys render as `0`, not empty.)

### Step 6 — Fold tier3 into `efficiency-footer.sh` compression line

The P05/T02 numerator currently sums `filter_dropped + tier1_savings + tier2_savings`. Locate that sum and widen:

```awk
/"record_type":"payload_breakdown"/ {
  # ... existing scope match ...
  if (match($0, /"tier3_compression_savings_tokens":[0-9]+/)) {
    v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); sav_t3 += v + 0
  }
}
END {
  sav_total = sav_filter + sav_t1 + sav_t2 + sav_t3
  # ... existing pct + emit ...
}
```

The denominator (sum of `payload_tokens_estimate`) is unchanged. The compression-line gating (tokens > 0 AND pct >= 0.5 AND ORCH_COMPRESSION_FOOTER not falsy) is unchanged.

### Step 7 — Fold tier3 into `check-anomalies.sh` compression-regression denominator

The P05/T02 per-row sav_total currently sums the four P05 fields. Locate the sum and widen:

```awk
/"record_type":"payload_breakdown"/ {
  # ... existing per-row state ...
  if (match($0, /"tier3_compression_savings_tokens":[0-9]+/)) {
    v = substr($0, RSTART, RLENGTH); sub(/.*:/, "", v); row_t3 = v + 0
  }
  sav_total = row_filter + row_t1 + row_t2 + row_t3
  # ... existing ratio = sav_total / payload_tokens; flag if ratio < floor && sav_total > 0 ...
}
```

The flag composition (sav_total > 0 guard, suppression matrix, configurable floor) is unchanged. T02 does NOT introduce a new tier3-specific anomaly reason — the existing compression-regression flag fires when the combined ratio is below floor, regardless of which tier(s) contributed.

### Step 8 — Self-check during development

```bash
bash -n scripts/dispatch/build-context.sh
bash -n scripts/dispatch/dispatch-interface.sh
bash -n scripts/knowledge/write-summary.sh
bash -n scripts/diagnostics/metrics-rollup.sh
bash -n scripts/diagnostics/efficiency-footer.sh
bash -n scripts/diagnostics/check-anomalies.sh
```

All exit 0. Run a known-pass dispatch under `ORCH_M019_EMIT=1` to confirm a `payload_breakdown` record appears with the two new fields at zero (T01 hasn't fired tier3 yet on this dispatch, but the additive fields should be present).

## Verification

T02 ships only production code. The canonical truth verifier (`m018-p06-tier3-additivity.sh`) ships in T04. T02's task-local extractable Check is the syntax-only self-check on the modified production-code script:

- Check: `bash -n scripts/dispatch/build-context.sh`

(One Check is sufficient per the auto-loop verify parser; the other modified scripts are exercised end-to-end by T04's `m018-p06-tier3-additivity.sh` against fixture logs.)

## Must-Haves (subset addressed by this task)

- **Truth #3**: `payload_breakdown` / `dispatch_usage` / `unit_close` carry additive `tier3_compression_savings_tokens` + `tier3_invocations` fields; pre-P06 records remain valid JSON. Wholly addressed by Steps 1-4.

T02 does not address Truths #1 (T01 — helper), #2 (T01 — prompt template), #4 (T03 — compression-eval cohort), or #5 (T04 — dual-write).

## Notes

- **CON-5 additivity audit**: T02 widens five JSONL emitters (`payload_breakdown`, `dispatch_usage` co-located, `dispatch_usage` dispatch-interface, `unit_close`, `tier3_*` event records from T01) and three diagnostic rollups (`metrics-rollup`, `efficiency-footer`, `check-anomalies`). All changes are append-only on the JSONL printf format strings and additive on the rollup sums. Every position-dependent column index and field offset stays byte-identical for pre-P06 records. The verifier `m018-p06-tier3-additivity.sh` (T04) asserts the back-compat contract end-to-end against a hand-curated pre-P06 fixture row.
- **Rollup-source restriction**: T02 carries forward the P05 invariant — `metrics-rollup.sh`, `efficiency-footer.sh`, and `check-anomalies.sh` only read `payload_breakdown` rows for savings sums, never the rolled-up copies on `dispatch_usage` / `unit_close`. The dispatch_usage / unit_close fields are the operator-facing query surface (one record per dispatch / one per unit-close); the per-row diagnostic rollups walk the ground-truth `payload_breakdown` records to avoid double-counting.
- **Granularity-aware unit_close rollup**: T02 mirrors the P05 scope rules:
  - granularity=task: match (milestone, phase, task) exactly.
  - granularity=phase: match (milestone, phase) — sums all task-rows in the phase.
  - granularity=milestone: match milestone — sums all task-rows in the milestone.
  Read the existing P05/T01 implementation in `_ws_emit_unit_close` for the canonical scope-key construction; T02 reuses it verbatim for the two tier3 fields.
- **Field placement in printf line**: `tier3_compression_savings_tokens` and `tier3_invocations` go AFTER the four P05 fields and BEFORE the `model` / `source` / `timestamp` triplet. This places them adjacent to the other tier savings fields for human readability and preserves the column-index contract (no fields move; only new ones appended).
- **MEM004 carve-out applies**: pipes / awk / `$()` permitted inside the emitter / rollup-helper bodies. The AD-19 single-script-file shape rule applies only to Check: lines, not script bodies.
- **No new doctor anomaly reason**: T02 does NOT add a `tier3-quality-regression` reason — that surface is the RISK-3 manual review at phase-close time, exercised via `compression-eval.sh --milestone M018 --tier 3`. The doctor surface composes additively (sav_total widens; flag fires whenever ratio < floor, regardless of which tier contributed).
- **Bash 3.2** (MEM001): no `declare -A`; awk inside helper bodies permitted by MEM004 carve-out. Parallel scalars / indexed accumulators only.
