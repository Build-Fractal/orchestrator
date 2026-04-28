---
schema_version: "1.0"
type: phase-summary
id: "P05"
parent: "M018"
milestone: "M018"
provides:
  - "additive integer fields filter_dropped_tokens / tier1_savings_tokens / tier2_savings_tokens / tier1_invocations on dispatch_usage (scripts/dispatch/dispatch-interface.sh:_di_emit_dispatch_usage) and unit_close (scripts/knowledge/write-summary.sh:_ws_emit_unit_close) JSONL records — rolled up from in-scope payload_breakdown records at emit-time (CON-5); cost-rollup column extension (FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS appended after existing 12 columns); efficiency-footer 'compression: <pct>% reduction over baseline' tail line (configurable via compression.efficiency_footer.enabled); doctor anomaly compression-regression reason (configurable via compression.regression_floor, default 0.347 per SC-9 P00 calibration); scripts/diagnostics/compression-eval.sh sourceable+CLI cohort-segmentation diagnostic with --tier <N> filter (1 and 2 supported in P05; tier 3 stub for P06); eight P05-private truth verifiers under scripts/verify/m018-p05-*.sh; two fixture trees under tests/fixtures/m018-p05-{savings-log,no-savings-log}/; scripts/verify/_helpers/m018-p05-build-fixture.sh fixture-staging helper; CLAUDE.md/AGENTS.md recent-changes refresh"
requires:
  - "P02 payload_filter + filter_dropped_tokens additive field on payload_breakdown; P03 tier1_savings_tokens + tier1_invocations additive fields on payload_breakdown; P04 tier2_savings_tokens additive field on payload_breakdown; SC-9 calibrated 34.7% floor (P00); M027 metrics-rollup.sh + efficiency-footer.sh + check-anomalies.sh as extension targets (DEP-2)"
affects:
  - "P06 (Tier 3 auto-compact — extends compression-eval.sh tier=3 stub to a real cohort against tier3_savings_tokens; extends dispatch_usage / unit_close additive fields with tier3_compression_savings_tokens and tier3_invocations; reuses the rollup-helper shape T01 established for the dispatch-internal emitter side; doctor compression-regression flag composes with tier3-quality regression once tier3 ships); M027 future surfaces consume the additive fields with no further changes required (rollup column-index contract is now pinned)"
key_files:
  - "scripts/dispatch/dispatch-interface.sh;scripts/knowledge/write-summary.sh;scripts/diagnostics/metrics-rollup.sh;scripts/diagnostics/efficiency-footer.sh;scripts/diagnostics/check-anomalies.sh;scripts/diagnostics/compression-eval.sh;tests/fixtures/m018-p05-savings-log/execution-log.jsonl;tests/fixtures/m018-p05-savings-log/README.md;tests/fixtures/m018-p05-no-savings-log/execution-log.jsonl;tests/fixtures/m018-p05-no-savings-log/README.md;scripts/verify/_helpers/m018-p05-build-fixture.sh;scripts/verify/m018-p05-dispatch-usage-additivity.sh;scripts/verify/m018-p05-unit-close-additivity.sh;scripts/verify/m018-p05-cost-rollup-savings-columns.sh;scripts/verify/m018-p05-efficiency-footer-compression.sh;scripts/verify/m018-p05-doctor-compression-regression.sh;scripts/verify/m018-p05-compression-eval.sh;scripts/verify/m018-p05-compression-eval-shape.sh;scripts/verify/m018-p05-dual-write-recent.sh"
key_decisions:
  - "MEM004 emitter-internal carve-out applies to JSONL-record-rollup helpers (single-pass awk in helper bodies; pipes/sed permitted); rollup-helper scope-precedence: dispatch_usage = unitId match; unit_close = granularity-aware (task M+P+T / phase M+P / milestone M); rollup-source restriction: metrics-rollup.sh accumulator skips rolled-up copies on dispatch_usage / unit_close to avoid double-counting (only payload_breakdown rows feed savings sums); savings columns appended AFTER existing 12 to preserve rollup column-index contract (CON-5); efficiency-footer compression line gated by tokens > 0 AND pct >= 0.5 AND ORCH_COMPRESSION_FOOTER not falsy; doctor compression-regression gated by sav_total > 0 AND ratio < floor (distinguishes 'compression ran and underperformed' from 'compression did not run at all'); compression-eval cohort definition: (milestone, phase, task)-keyed; compressed = tier<N>_savings_tokens > 0 from payload_breakdown ground truth (NOT the rolled-up unit_close field); --tier 3 ships as recognized-but-no-op stub for P06 forward-compat; sample-floor default 30 prevents false positives at low N; compression-eval honors ORCHESTRATOR_ROOT for fixture-based verifier runs (T04 patch)"
patterns_established:
  - "MEM004 dispatch-internal carve-out extends to JSONL-record-rollup helpers — single-pass awk + sed -n line read with defensive [-n] || var=0 floor; granularity-aware scope match for unit_close mirrors awk index() pattern from existing verification_pass_rate aggregation (parallel-scalar, no declare -A); metrics-rollup.sh additive column extension pattern — append at projection END (cols 13+), accumulate in scope_*[skey] map, defensive zero-fill in render loop; cohort-segmentation diagnostic shape: single awk pass over execution-log.jsonl with per-record-type branches (payload_breakdown classifies, unit_close measures); Wilson 95% CI + pooled-SE delta in pure awk (closed-form, single-pass); always-exit-0 contract on diagnostic CLIs surfaces degraded inputs as text; shim-style verifier pattern from P03/P04 extends to write-summary.sh + dispatch-interface.sh CLI scripts (awk function-extraction shim isolates the unit-under-test from the host CLI body)"
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P05/tasks/T01-schema-extensions-SUMMARY.md;.orchestrator/milestones/M018/phases/P05/tasks/T02-surface-extensions-SUMMARY.md;.orchestrator/milestones/M018/phases/P05/tasks/T03-compression-eval-SUMMARY.md;.orchestrator/milestones/M018/phases/P05/tasks/T04-verifiers-and-summary-SUMMARY.md"
duration: "~5h"
verification_result: "pass"
completed_at: "2026-04-28T05:30:00Z"
observability_surfaces:
  - "execution-log.jsonl: dispatch_usage.filter_dropped_tokens / .tier1_savings_tokens / .tier2_savings_tokens / .tier1_invocations additive integer fields; unit_close.{filter_dropped_tokens,tier1_savings_tokens,tier2_savings_tokens,tier1_invocations} additive integer fields; metrics-rollup.sh stdout: FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS columns; efficiency-footer.sh stdout: compression: <pct>% reduction over baseline tail; check-anomalies.sh stdout: FLAGGED <task> ... savings_ratio=<pct> ... reasons=... compression-regression; compression-eval.sh stdout: cohort + delta block with 95% CIs and regression_flag"
---

P05 lands the **observability tier** of the M018 compression pipeline:
schema extensions on the dispatch_usage / unit_close JSONL records,
M027 surface extensions (cost rollup column extension, efficiency-footer
compression line, doctor compression-regression flag), and a new
sourceable + CLI cohort-segmentation diagnostic (compression-eval.sh).
After P05, an operator can answer two questions without grepping JSONL:

1. "How much did compression save on this milestone / phase / task?"
   — `metrics-rollup.sh --milestone <M>` shows the four savings columns;
   `efficiency-footer.sh --milestone <M>` shows the one-line compression
   reduction tail.
2. "Did the dispatches that fired tier N produce different verification
   outcomes than the dispatches that did not?" — `compression-eval.sh
   --milestone <M> --tier <N>` reports per-cohort + delta means with
   95% CIs for verification_pass_rate / retry_count / deviation_count.

The phase ships:

- **dispatch_usage / unit_close schema extensions** (T01) — four additive
  integer fields (filter_dropped_tokens / tier1_savings_tokens /
  tier2_savings_tokens / tier1_invocations) on both record types. Each
  emitter rolls up the matching payload_breakdown records from the
  in-flight execution-log.jsonl at emit-time. dispatch_usage rollup is
  unitId-scoped; unit_close rollup is granularity-aware (task = M+P+T,
  phase = M+P, milestone = M only). MEM004 emitter-internal carve-out
  applies — single-pass awk in helper bodies. Pre-P05 records remain
  valid JSON; absent fields default to 0 in downstream rollups (CON-5).

- **Cost rollup column extension** (T02) — `metrics-rollup.sh` projects
  the four savings fields at columns 13-16, accumulates per-scope sums
  from payload_breakdown rows ONLY (skipping the rolled-up copies T01
  added to dispatch_usage / unit_close — avoids double-counting), and
  appends FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS
  columns AFTER the existing 12. Column indices 1-12 remain byte-identical
  for back-compat consumers (CON-5 carry-forward to the rollup
  column-index contract).

- **Efficiency-footer compression line** (T02) — `efficiency-footer.sh`
  emits a `compression: <pct>% reduction over baseline (filter+tier1+tier2
  / payload_tokens)` tail when in-scope payload_breakdown records carry
  non-zero savings. Suppressed under `--quiet`,
  `compression.efficiency_footer.enabled: false`, or
  `ORCH_COMPRESSION_FOOTER=false` (FR-15 carry-forward).

- **Doctor compression-regression flag** (T02) — `check-anomalies.sh`
  composes a `compression-regression` reason additively with cost-spike
  / retry-spike / low-pass-rate when a task's per-row savings ratio
  (sav_total / payload_tokens) falls below the SC-9 calibrated 34.7%
  floor AND sav_total > 0 (the latter guard distinguishes "compression
  ran and underperformed" from "compression did not run at all"). Floor
  configurable via `compression.regression_floor`. Suppression matrix
  preserved (`--no-anomaly`, `--yes`, `ORCHESTRATOR_AUTO=1`,
  `ORCH_ANOMALY_CHECK_ENABLED=false`).

- **scripts/diagnostics/compression-eval.sh** (T03) — sourceable + CLI
  cohort-segmentation diagnostic. Single awk pass walks
  execution-log.jsonl: payload_breakdown classifies each
  (milestone, phase, task) into compressed (tier<N>_savings_tokens > 0)
  or uncompressed cohorts; task-granularity unit_close records measure
  pass_rate / retry / deviation. END block enforces sample floor
  (default 30 per cohort), computes Wilson 95% CI for proportions and
  pooled-SE deltas, emits a regression_flag when delta_pass_rate <= -0.05
  AND CI excludes 0. CLI: `--milestone <Mxxx>`, `--tier <N>` (1 or 2 in
  P05; 3 reserved for P06 stub), `--sample-floor <N>`. Always exits 0
  (FR-12 / CON-5 — degraded inputs surface as text). Honors
  `ORCHESTRATOR_ROOT` env override.

- **Eight P05-private truth verifiers** under `scripts/verify/m018-p05-*.sh`
  exercise all four production-code surfaces end-to-end against
  hand-crafted fixture logs (savings-bearing + no-savings legacy).
  Verifier shape mirrors the P03/P04 pattern: pass()/fail() helpers,
  shim-style awk function extraction where dispatch-interface.sh /
  write-summary.sh CLI bodies prevent direct sourcing, single-script-file
  Check: shape (AD-19 / AP-009).

- **Two fixture trees** under `tests/fixtures/m018-p05-{savings,no-savings}-log/`
  provide the hermetic input. The savings fixture mixes 3 compressed
  (T01/T02/T04) + 2 uncompressed (T03/T05) tasks; T01 has tokens=1000
  with savings=300 → ratio=0.300 (below 0.347 floor, savings > 0) so
  the doctor compression-regression flag fires. The legacy fixture
  carries zero savings fields so the surfaces stay quiet (CON-5
  absent-as-zero).

- **`scripts/verify/_helpers/m018-p05-build-fixture.sh`** — fixture-staging
  helper mirroring the P03 / P04 shape. Stages a hermetic
  `.orchestrator/`-style root with `milestones/<id>/execution-log.jsonl`
  copied from the chosen slug (savings / no-savings) and a minimal
  `config.yml` so `read-config.sh` resolves cleanly under
  `ORCHESTRATOR_ROOT=<root>`.

## Risk-mitigation traceability

- **CON-5 (additive emitters)** — the four new fields on dispatch_usage
  and unit_close are additive. Pre-P05 records (the T99 row in the
  savings fixture, every record in the no-savings fixture, and every
  pre-P05 row in the live `.orchestrator/milestones/M018/execution-log.jsonl`)
  remain valid JSON; downstream consumers (rollup, footer, doctor,
  compression-eval) treat absent fields as zero. Verified by the
  back-compat assertions in `m018-p05-dispatch-usage-additivity.sh` and
  `m018-p05-unit-close-additivity.sh`.

- **SC-9 (34.7% calibrated floor)** — surfaced in `check-anomalies.sh`
  as the default `compression.regression_floor` and in
  `compression-eval.sh` as the regression flag pass-rate delta.
  Configurable via `compression.regression_floor` config knob.

- **FR-12 (read-only diagnostic surfaces)** — `compression-eval.sh`
  never appends to or rewrites JSONL; always exits 0. Verified by the
  malformed-arg-combo assertions in `m018-p05-compression-eval-shape.sh`.

- **AD-19 / AP-009 single-script-file Check shape** — every truth's
  Check: line is a single bash invocation. Verifier scripts use
  pass()/fail() per MEM002 and printf-prefixed lines per MEM001.

## Followups for downstream phases

- **P06 (tier3 auto-compact)** — extends the `--tier 3` stub in
  `compression-eval.sh` to a real cohort against `tier3_savings_tokens`;
  extends dispatch_usage / unit_close additive fields with
  `tier3_compression_savings_tokens` and `tier3_invocations` per the
  same MEM004 carve-out pattern T01 established. The doctor
  compression-regression flag composes with tier3-quality regression
  once tier3 ships. The cohort-segmentation diagnostic is the gate the
  P06 LLM trust boundary (MIT-08) is verified against.

- **M027 future surfaces** — consume the additive savings fields with
  no further changes required. The rollup column-index contract is
  pinned (1-12 stable; 13-16 are the M018 savings columns).

- **M019 future surfaces** — the four additive fields on dispatch_usage
  and unit_close are the contract the M019 cost+token transparency
  surfaces (M027 extension target) read.

## Verification result

All P05 truths PASS via
`bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P05/`.
All artifacts present at required line counts with required substrings;
all key links resolve; all eight private verifiers green:

- `m018-p05-dispatch-usage-additivity.sh` — PASS (14 assertions:
  emitter source carries the four additive fields; live emit produces
  expected sums against fixture; pre-P05 record back-compat).
- `m018-p05-unit-close-additivity.sh` — PASS (18 assertions: rollup
  helper sums correctly across phase scope; live emit through
  `write-summary.sh phase` carries the four fields; pre-P05 record
  back-compat).
- `m018-p05-cost-rollup-savings-columns.sh` — PASS (12 assertions:
  header carries the four new columns; data row sums correctly;
  legacy log columns default to 0).
- `m018-p05-efficiency-footer-compression.sh` — PASS (4 assertions:
  savings-bearing fixture emits compression: line; --quiet zero
  stdout; no-savings fixture omits the line; ORCH_COMPRESSION_FOOTER
  override suppresses).
- `m018-p05-doctor-compression-regression.sh` — PASS (5 assertions:
  T01 row flagged with savings_ratio token; ORCHESTRATOR_AUTO=1 zero
  stdout; --no-anomaly zero stdout; legacy log NOT flagged).
- `m018-p05-compression-eval.sh` — PASS (13 assertions: cohort + delta
  block emitted; high floor → insufficient sample; --tier 3 stub;
  missing-log degraded text; --tier 2 cohort).
- `m018-p05-compression-eval-shape.sh` — PASS (10 assertions: file
  readable; sourceable guard present; BASH_SOURCE CLI block; MEM004
  carve-out; --help exits 0; malformed-arg combos all exit 0; bash -n;
  no declare -A; sourceable function).
- `m018-p05-dual-write-recent.sh` — PASS (CLAUDE.md + AGENTS.md
  recent-changes blocks both name M018/P05 / compression-eval).

P05 closed. M018 advances to P06 (tier3 auto-compact).
