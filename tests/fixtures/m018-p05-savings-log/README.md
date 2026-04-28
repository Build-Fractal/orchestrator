# m018-p05-savings-log

Hand-crafted execution-log.jsonl fixture for the M018/P05 verifiers
(`m018-p05-cost-rollup-savings-columns`, `m018-p05-efficiency-footer-compression`,
`m018-p05-doctor-compression-regression`, `m018-p05-compression-eval`,
`m018-p05-dispatch-usage-additivity`, `m018-p05-unit-close-additivity`).

## Record mix (12 records)

`payload_breakdown` rows (5):

- T01: tier1=200 fdrop=100 tier2=0 t1i=1 tokens=1000 → savings_ratio=0.300
  (BELOW SC-9 0.347 floor + savings>0 → exercises the
  `compression-regression` flag in `check-anomalies.sh`).
- T02: tier1=600 fdrop=300 tier2=100 t1i=2 tokens=2000 → ratio=0.500.
- T03: zero savings (uncompressed cohort representative).
- T04: tier1=800 fdrop=200 tier2=200 t1i=3 tokens=2000 → ratio=0.600.
- T05: zero savings (uncompressed cohort).

`unit_close` rows at granularity=task (5) — match the payload_breakdown
keys above so `compression-eval.sh` can segment cohorts. Three rows fall
into the compressed cohort (T01/T02/T04) and two into the uncompressed
cohort (T03/T05) — exactly above the `--sample-floor 2` threshold the
verifier uses.

Pre-P05 back-compat rows (2):

- One `unit_close` task record on M018F/P04/T99 WITHOUT the four
  additive savings fields — exercises CON-5 absent-as-zero.
- One `dispatch_usage` record on M018F/P04/T99 WITHOUT the four
  additive savings fields — exercises CON-5 absent-as-zero.

## Use via fixture-staging helper

`bash scripts/verify/_helpers/m018-p05-build-fixture.sh <root> savings`
copies this log to `<root>/milestones/M018F/execution-log.jsonl` and
emits `M018F` on stdout. Verifiers then point
`ORCHESTRATOR_ROOT=<root>` at the M018F milestone via
`metrics-rollup.sh` / `efficiency-footer.sh` / `check-anomalies.sh` /
`compression-eval.sh --milestone M018F`.

Verifier→exercise map:

- `m018-p05-cost-rollup-savings-columns.sh` — header carries
  `FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS`
  columns; data row sums payload_breakdown savings.
- `m018-p05-efficiency-footer-compression.sh` — emits the
  `compression: <pct>%` reduction line because some payload_breakdown
  records carry non-zero savings.
- `m018-p05-doctor-compression-regression.sh` — flags T01 as
  `compression-regression` because its ratio is below 0.347 with
  savings>0.
- `m018-p05-compression-eval.sh` — segments 3 compressed (T01/T02/T04)
  vs 2 uncompressed (T03/T05) cohorts; reports per-cohort and delta
  pass-rate / retry / deviation means with confidence intervals.
- `m018-p05-dispatch-usage-additivity.sh` — pre-P05 dispatch_usage
  on T99 is valid JSON (back-compat).
- `m018-p05-unit-close-additivity.sh` — pre-P05 unit_close on T99
  is valid JSON (back-compat).
