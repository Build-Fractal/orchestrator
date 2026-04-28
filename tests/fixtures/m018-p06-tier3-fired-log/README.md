# m018-p06-tier3-fired-log

Hand-crafted execution-log.jsonl fixture for the M018/P06 verifiers
(`m018-p06-tier3-additivity`, `m018-p06-compression-eval-tier3`).

## Record mix (12 records)

Pre-P06 back-compat (1):

- One `payload_breakdown` row on `M018F/P04/T99` carrying ONLY the four
  P05 fields (`filter_dropped_tokens`, `tier1_savings_tokens`,
  `tier2_savings_tokens`, `tier1_invocations`) and NONE of the P06 tier3
  fields. Exercises the CON-5 absent-as-zero contract — downstream
  consumers (rollup, footer, doctor, compression-eval) treat the absent
  tier3 fields as zero.

`payload_breakdown` rows on M018F/P06 (5):

- T01: `tier3_compression_savings_tokens=400 tier3_invocations=1
  payload_tokens_estimate=2000` — compressed cohort.
- T02: `tier3_compression_savings_tokens=600 tier3_invocations=1
  payload_tokens_estimate=3000` — compressed cohort.
- T03: `tier3_compression_savings_tokens=0 tier3_invocations=0
  payload_tokens_estimate=2500` — uncompressed cohort representative.
- T04: `tier3_compression_savings_tokens=800 tier3_invocations=1
  payload_tokens_estimate=3500` — compressed cohort (high savings).
- T05: `tier3_compression_savings_tokens=0 tier3_invocations=0
  payload_tokens_estimate=2200` — uncompressed cohort representative.

Each row also carries small P05 fields (filter=100 / tier1=50 / tier2=50
/ t1i=1 on the compressed rows; zeros on the uncompressed rows) so
`efficiency-footer.sh` can demonstrate the tier3 fold widens the
compression-line numerator beyond the P05 sum.

`unit_close` rows at granularity=task (5) — match the payload_breakdown
keys above so `compression-eval.sh --tier 3` can segment cohorts.
Compressed cohort: T01/T02/T04 (tier3 fired). Uncompressed cohort:
T03/T05. All five carry `verification_pass_rate=1.0 retry_count=0
deviation_count=0`, so the regression flag will be `none` (the diagnostic
is operational; no statistically significant outcome-rate difference).

`tier3_skipped` event (1):

- One `tier3_skipped` record naming `reason=density-floor` — exercises
  the helper's MIT-08 short-circuit emit shape.

## Use via fixture-staging helper

`bash scripts/verify/_helpers/m018-p06-build-fixture.sh <root> tier3-fired`
copies this log to `<root>/milestones/M018F/execution-log.jsonl` and
emits `M018F` on stdout. Verifiers then point
`ORCHESTRATOR_ROOT=<root>` at the M018F milestone via
`metrics-rollup.sh` / `efficiency-footer.sh` / `check-anomalies.sh` /
`compression-eval.sh --milestone M018F --tier 3`.
