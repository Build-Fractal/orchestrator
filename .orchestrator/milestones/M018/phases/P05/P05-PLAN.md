---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M018"
goal: "Surfaces + Eval Harness — extend `dispatch_usage` and `unit_close` JSONL records with additive savings + invocation fields (FR-10), extend the M027 cost rollup engine, status efficiency footer, and doctor anomaly check to surface compression savings + flag compression regressions vs historical baseline, and ship `scripts/diagnostics/compression-eval.sh` (cohort segmentation + outcome-rate delta with confidence intervals; `--tier <N>` filter) so an operator can see what M018 saved per dispatch / per phase / per milestone without grepping JSONL"
demo_sentence: "After P05, an operator running `bash scripts/diagnostics/metrics-rollup.sh --milestone <active>` sees `FILTER_DROPPED_TOKENS`, `TIER1_SAVINGS_TOKENS`, and `TIER2_SAVINGS_TOKENS` columns alongside the existing cost/quality columns; running `bash scripts/diagnostics/efficiency-footer.sh --milestone <active>` shows a one-line compression summary appended to the footer; running `bash scripts/diagnostics/run-doctor.sh` flags any milestone whose savings ratio dropped below the SC-9 calibrated 34.7% floor against its prior baseline; running `bash scripts/diagnostics/compression-eval.sh --milestone <id> --tier 1` against a milestone with >= 30 unit_close records reports outcome-rate deltas (verification_pass_rate, retry_count, deviation_count) between compressed and uncompressed cohorts with confidence intervals or 'insufficient sample' below the floor; the new fields on `dispatch_usage` and `unit_close` are additive — pre-P05 records remain valid JSON and rollups treat absent fields as zero (CON-5)"
risk: "medium"
depends_on: ["P02", "P03", "P04"]
---

## Must-Haves

### Truths

<!-- AD-19: every Check is a single-script-file invocation. No inline
     compound bash, no plain subshells, no $(...|...). One verifier per
     truth, parked under scripts/verify/m018-p05-*.sh. -->

- `dispatch_usage` JSONL records carry additive integer fields `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, and `tier1_invocations`, populated by rolling up the matching `payload_breakdown` record(s) for the same `unitId` at emit-time; pre-P05 `dispatch_usage` records remain valid JSON; missing fields default to 0 in rollups (CON-5).
  - Check: `bash scripts/verify/m018-p05-dispatch-usage-additivity.sh`
- `unit_close` JSONL records carry additive integer fields `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, and `tier1_invocations`, computed by aggregating the per-task `payload_breakdown` records on the same milestone/phase/task scope at unit_close emit-time; pre-P05 `unit_close` records remain valid JSON; missing fields default to 0 in rollups (CON-5).
  - Check: `bash scripts/verify/m018-p05-unit-close-additivity.sh`
- `scripts/diagnostics/metrics-rollup.sh` cost rollup output includes a "Compression savings" block (or `FILTER_DROPPED_TOKENS` / `TIER1_SAVINGS_TOKENS` / `TIER2_SAVINGS_TOKENS` columns appended to the existing tabular shape) summing the additive fields across the resolved scope; absent fields contribute zero; the engine never aborts on logs predating the schema extension (CON-5 carry-forward).
  - Check: `bash scripts/verify/m018-p05-cost-rollup-savings-columns.sh`
- `scripts/diagnostics/efficiency-footer.sh` (M027/P02 helper) emits a one-line "Compressed: <pct>% reduction over baseline" tail after the existing footer body when any in-scope `payload_breakdown` record carries a non-zero savings field; suppressed under `--quiet` and under `compression.efficiency_footer.enabled: false` (FR-15 carry-forward); fixture-replay against a savings-bearing log shows the line, fixture-replay against a savings-free log omits it, byte-identity contract preserved.
  - Check: `bash scripts/verify/m018-p05-efficiency-footer-compression.sh`
- `scripts/diagnostics/check-anomalies.sh` (M027/P03 helper) flags a milestone whose moving-window savings ratio falls below the SC-9 calibrated 34.7% floor against the milestone's prior baseline; the flag is one stable line in the existing anomaly block (e.g., `FLAGGED <milestone> compression-regression savings_ratio=<pct> floor=0.347 reasons=compression-regression`), suppressed under `--no-anomaly` / `--yes` / `ORCHESTRATOR_AUTO=1` / `ORCH_ANOMALY_CHECK_ENABLED=false` per the existing suppression matrix; sample-size below floor surfaces "insufficient sample" rather than a noisy false-positive.
  - Check: `bash scripts/verify/m018-p05-doctor-compression-regression.sh`
- `scripts/diagnostics/compression-eval.sh` exists, accepts `--milestone <id>`, `--tier <N>` (1 or 2 in P05; tier 3 reserved for P06), and `--sample-floor <N>` (default 30 per cohort); reads `payload_breakdown` + `unit_close` records from `execution-log.jsonl`; segments compressed vs uncompressed cohorts (compressed = unit_close where the matching payload_breakdown carries the requested tier's savings field > 0; uncompressed = unit_close on the same milestone with the savings field absent or 0); reports per-cohort verification_pass_rate / retry_count / deviation_count plus the delta with a confidence interval; below-floor sample emits "insufficient sample" and exits 0; never aborts on degraded inputs (CON-5).
  - Check: `bash scripts/verify/m018-p05-compression-eval.sh`
- `compression-eval.sh` is a single-script-file CLI under `scripts/diagnostics/` that follows the AP-009 / AD-19 shape rules — bash 3.2 only, no `declare -A`, no plain subshells, no `$(...|...)` outside the MEM004 emitter-internal carve-out; sourceable as a library (function `compression_eval_render <milestone> <tier> <sample_floor>`) AND runnable as a CLI; emits zero JSONL records (FR-12 read-only); zero LLM tokens (FR-21 / CON-6 — bash + awk + grep only).
  - Check: `bash scripts/verify/m018-p05-compression-eval-shape.sh`
- CLAUDE.md and AGENTS.md `orchestrator:recent-changes` blocks both name "M018/P05" or "compression-eval" — phase-close dual-write via `scripts/util/dual-write-runtime-md.sh`.
  - Check: `bash scripts/verify/m018-p05-dual-write-recent.sh`

### Artifacts

- `scripts/dispatch/dispatch-interface.sh` (min 350 lines, contains "tier1_savings_tokens")
- `scripts/knowledge/write-summary.sh` (min 470 lines, contains "tier1_savings_tokens")
- `scripts/diagnostics/metrics-rollup.sh` (min 800 lines, contains "tier1_savings_tokens")
- `scripts/diagnostics/efficiency-footer.sh` (min 170 lines, contains "Compressed:")
- `scripts/diagnostics/check-anomalies.sh` (min 240 lines, contains "compression-regression")
- `scripts/diagnostics/compression-eval.sh` (min 200 lines, contains "--tier")
- `tests/fixtures/m018-p05-savings-log/execution-log.jsonl` (min 6 lines, contains "tier1_savings_tokens")
- `tests/fixtures/m018-p05-savings-log/README.md` (min 10 lines, contains "compression-eval")
- `tests/fixtures/m018-p05-no-savings-log/execution-log.jsonl` (min 4 lines, contains "payload_breakdown")
- `tests/fixtures/m018-p05-no-savings-log/README.md` (min 6 lines, contains "no savings")
- `scripts/verify/_helpers/m018-p05-build-fixture.sh` (min 30 lines, contains "P05")
- `scripts/verify/m018-p05-dispatch-usage-additivity.sh` (min 30 lines, contains "tier1_savings_tokens")
- `scripts/verify/m018-p05-unit-close-additivity.sh` (min 30 lines, contains "tier1_savings_tokens")
- `scripts/verify/m018-p05-cost-rollup-savings-columns.sh` (min 30 lines, contains "TIER1_SAVINGS_TOKENS")
- `scripts/verify/m018-p05-efficiency-footer-compression.sh` (min 30 lines, contains "Compressed:")
- `scripts/verify/m018-p05-doctor-compression-regression.sh` (min 30 lines, contains "compression-regression")
- `scripts/verify/m018-p05-compression-eval.sh` (min 30 lines, contains "compression-eval")
- `scripts/verify/m018-p05-compression-eval-shape.sh` (min 25 lines, contains "AP-009")
- `scripts/verify/m018-p05-dual-write-recent.sh` (min 20 lines, contains "recent-changes")
- `.orchestrator/milestones/M018/phases/P05/P05-SUMMARY.md` (min 50 lines, contains "compression-eval.sh")

### Key Links

- `scripts/dispatch/dispatch-interface.sh` → `scripts/dispatch/build-context.sh` (rolls up the same-unitId `payload_breakdown` record(s) for the additive savings fields on the `dispatch_usage` emit; both files write to the same `execution-log.jsonl` so the rollup is a single grep + awk pass over the in-flight log on emit)
- `scripts/knowledge/write-summary.sh` → `scripts/dispatch/build-context.sh` (aggregates the per-task `payload_breakdown` records on the unit_close scope at emit-time; same log-file pass shape as the dispatch_usage rollup but scoped to milestone/phase/task)
- `scripts/diagnostics/metrics-rollup.sh` → `scripts/dispatch/build-context.sh` (consumes the additive `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier1_invocations` fields from `payload_breakdown` records — the existing engine already opens the same log)
- `scripts/diagnostics/efficiency-footer.sh` → `scripts/diagnostics/metrics-rollup.sh` (delegates to the rollup engine for the savings aggregate; renders the one-line "Compressed:" tail)
- `scripts/diagnostics/check-anomalies.sh` → `scripts/diagnostics/metrics-rollup.sh` (consumes the per-milestone savings aggregate; flags compression-regression when below floor)
- `scripts/diagnostics/compression-eval.sh` → `scripts/dispatch/build-context.sh` (reads `payload_breakdown` records to bin compressed vs uncompressed cohorts)
- `scripts/diagnostics/compression-eval.sh` → `scripts/knowledge/write-summary.sh` (reads `unit_close` records for the outcome-rate computation: `verification_pass_rate`, `retry_count`, `deviation_count`)
- `CLAUDE.md` → `M018/P05` (recent-changes block names the phase)
- `AGENTS.md` → `M018/P05` (recent-changes block names the phase, written via `scripts/util/dual-write-runtime-md.sh`)

## Boundary Map

- **Produces**:
  - `dispatch_usage` schema extension: additive integer fields `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens`, `tier1_invocations` on the JSONL record emitted by `_di_emit_dispatch_usage` in `scripts/dispatch/dispatch-interface.sh` (FR-10, CON-5).
  - `unit_close` schema extension: same four additive integer fields on the record emitted by `_ws_emit_unit_close` in `scripts/knowledge/write-summary.sh` (FR-10, CON-5).
  - `metrics-rollup.sh` cost rollup extension: per-scope columns / "Compression savings" block summing the additive fields across the resolved scope (FR-11).
  - `efficiency-footer.sh` extension: one-line "Compressed: <pct>% reduction over baseline" tail when any in-scope record carries a non-zero savings field (FR-11).
  - `check-anomalies.sh` extension: `compression-regression` flag when the milestone's moving-window savings ratio falls below the SC-9 calibrated 34.7% floor (FR-11).
  - `scripts/diagnostics/compression-eval.sh`: new diagnostic with cohort segmentation (compressed vs uncompressed) + outcome-rate delta with confidence intervals; `--tier <N>` filter (FR-12).
- **Consumes**:
  - M019 emitter schema (DEP-3 extension point) — additive fields on existing record types; no rename, no removal, no value-vocabulary change.
  - M027 surfaces (DEP-2 extension points): `metrics-rollup.sh`, `efficiency-footer.sh`, `check-anomalies.sh` — all extended additively.
  - P02 `payload_filter` JSONL record + `filter_dropped_tokens` additive field on `payload_breakdown`.
  - P03 `tier1_savings_tokens` + `tier1_invocations` additive fields on `payload_breakdown`.
  - P04 `tier2_savings_tokens` additive field on `payload_breakdown`.
  - SC-9 calibrated 34.7% floor (P00) — used as the doctor compression-regression threshold default.

## Tasks

### T01: Schema extensions on `dispatch_usage` + `unit_close` (FR-10 additive)

(Plan in `tasks/T01-schema-extensions-PLAN.md`.)

Add the four additive integer fields to the `dispatch_usage` JSONL printf in `scripts/dispatch/dispatch-interface.sh:_di_emit_dispatch_usage` and the `unit_close` JSONL printf in `scripts/knowledge/write-summary.sh:_ws_emit_unit_close`. Each emitter rolls up the matching `payload_breakdown` records from the same milestone's `execution-log.jsonl` at emit-time (single grep + awk pass — MEM004 emitter-internal carve-out). Pre-P05 records remain valid JSON; missing fields default to 0 in downstream rollups (CON-5).

### T02: Cost rollup + efficiency footer + doctor anomaly extensions

(Plan in `tasks/T02-surface-extensions-PLAN.md`.)

Extend `scripts/diagnostics/metrics-rollup.sh` to read the additive savings fields from `payload_breakdown` (and the matching fields on `dispatch_usage` / `unit_close` that T01 added) and surface them as columns in the rollup table. Extend `scripts/diagnostics/efficiency-footer.sh` to render a "Compressed: <pct>% reduction over baseline" tail when the rollup reports non-zero savings. Extend `scripts/diagnostics/check-anomalies.sh` to flag a `compression-regression` reason when the milestone's moving-window savings ratio falls below the SC-9 calibrated 34.7% floor.

### T03: `scripts/diagnostics/compression-eval.sh` (cohort segmentation + outcome-rate delta)

(Plan in `tasks/T03-compression-eval-PLAN.md`.)

New CLI under `scripts/diagnostics/`. Reads `payload_breakdown` + `unit_close` records, segments compressed vs uncompressed cohorts, reports outcome-rate deltas (`verification_pass_rate`, `retry_count`, `deviation_count`) with confidence intervals; `--tier <N>` filter (P05 supports tier 1 + tier 2; tier 3 reserved for P06). Sourceable + runnable; AP-009 / AD-19 compliant; below-floor sample emits "insufficient sample" and exits 0.

### T04: Verifiers, fixtures, fixture-staging helper, P05-SUMMARY + dual-write

(Plan in `tasks/T04-verifiers-and-summary-PLAN.md`.)

Eight verifier scripts under `scripts/verify/m018-p05-*.sh`, two fixture trees under `tests/fixtures/m018-p05-*/`, one fixture-staging helper under `scripts/verify/_helpers/m018-p05-build-fixture.sh`, the P05-SUMMARY, and the CLAUDE.md/AGENTS.md `orchestrator:recent-changes` dual-write.

## Task Dependencies

```
T01 → T02   (T02 cost rollup reads the additive fields T01 lands on dispatch_usage / unit_close)
T01 → T03   (T03 compression-eval reads the additive fields T01 lands on unit_close for the cohort outcome-rate computation; payload_breakdown fields already exist from P02-P04)
T02 ⟂ T03   (T02 and T03 are independent extensions of the diagnostic surfaces — no shared edits)
T01 → T04   (T04 verifiers exercise T01's additive fields)
T02 → T04   (T04 verifiers exercise T02's rollup + footer + doctor extensions)
T03 → T04   (T04 verifiers exercise T03's compression-eval CLI)
```

## Files Likely Touched

- `scripts/dispatch/dispatch-interface.sh` (modify) — add the four additive integer fields to both branches of `_di_emit_dispatch_usage`'s printf (happy-path + degraded-path); add an internal helper `_di_rollup_savings_fields` (MEM004 carve-out — pipes/awk permitted) that reads the same-unitId `payload_breakdown` records from the resolved log file and emits the four integers.
- `scripts/knowledge/write-summary.sh` (modify) — add the four additive integer fields to the `_ws_emit_unit_close` printf; add an internal helper `_ws_rollup_savings_fields` that reads the per-task `payload_breakdown` records on the unit_close scope from `execution-log.jsonl` and emits the four integers.
- `scripts/diagnostics/metrics-rollup.sh` (modify) — extend the per-bucket aggregation in the awk pass to track the four savings fields on `payload_breakdown` (with the same source-precedence rule); extend the render to emit the new columns / a "Compression savings" sub-block.
- `scripts/diagnostics/efficiency-footer.sh` (modify) — append the one-line "Compressed: <pct>% reduction over baseline" tail when the rollup reports non-zero savings; honor `--quiet` and the `compression.efficiency_footer.enabled` config knob (FR-15 carry-forward).
- `scripts/diagnostics/check-anomalies.sh` (modify) — add a `compression-regression` reason in the awk pass when the milestone's savings ratio (sum savings / sum payload_tokens) falls below the SC-9 calibrated 34.7% floor against the milestone's prior baseline; respect the existing suppression matrix.
- `scripts/diagnostics/compression-eval.sh` (create) — new sourceable + CLI diagnostic.
- `tests/fixtures/m018-p05-savings-log/execution-log.jsonl` (create) — fixture with mixed compressed + uncompressed records covering tier1, tier2, and a savings-bearing dispatch_usage / unit_close pair.
- `tests/fixtures/m018-p05-savings-log/README.md` (create) — fixture description.
- `tests/fixtures/m018-p05-no-savings-log/execution-log.jsonl` (create) — fixture with payload_breakdown records carrying zero / absent savings fields, used to assert the footer/doctor surfaces stay quiet.
- `tests/fixtures/m018-p05-no-savings-log/README.md` (create) — fixture description.
- `scripts/verify/_helpers/m018-p05-build-fixture.sh` (create) — fixture-staging helper mirroring P03 / P04.
- `scripts/verify/m018-p05-dispatch-usage-additivity.sh` (create)
- `scripts/verify/m018-p05-unit-close-additivity.sh` (create)
- `scripts/verify/m018-p05-cost-rollup-savings-columns.sh` (create)
- `scripts/verify/m018-p05-efficiency-footer-compression.sh` (create)
- `scripts/verify/m018-p05-doctor-compression-regression.sh` (create)
- `scripts/verify/m018-p05-compression-eval.sh` (create)
- `scripts/verify/m018-p05-compression-eval-shape.sh` (create)
- `scripts/verify/m018-p05-dual-write-recent.sh` (create)
- `.orchestrator/milestones/M018/phases/P05/P05-SUMMARY.md` (create) — written via `bash scripts/knowledge/write-summary.sh`.
- `CLAUDE.md` (modify) — refresh `orchestrator:recent-changes` block to name M018/P05.
- `AGENTS.md` (modify) — same content (dual-write via `scripts/util/dual-write-runtime-md.sh`).
