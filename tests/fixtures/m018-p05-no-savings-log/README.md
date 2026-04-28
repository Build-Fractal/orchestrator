# m018-p05-no-savings-log

Hand-crafted execution-log.jsonl fixture asserting that the M018/P05
diagnostic surfaces stay quiet on legacy logs that pre-date the
schema extension.

This fixture exercises CON-5 absent-as-zero: NO savings fields on
ANY record. It is "what an old log looks like" — pre-P02
`payload_breakdown` records with no `filter_dropped_tokens` /
`tier1_savings_tokens` / `tier2_savings_tokens` / `tier1_invocations`
fields, and pre-T01 `unit_close` records with no rollup of the
same fields.

## Record mix (6 records)

- 3 `payload_breakdown` rows on milestone M018L (legacy) — zero
  savings fields. They MUST still be valid JSON when parsed.
- 3 `unit_close` task records on the same tasks — also zero
  savings fields.

## Expected behavior of the M018/P05 surfaces

- `metrics-rollup.sh --milestone M018L` — emits the four new
  columns with integer 0 (CON-5 absent-as-zero). No engine abort
  on missing fields.
- `efficiency-footer.sh --milestone M018L` — emits NO
  `compression:` line (the gate fires only when tokens > 0 AND
  pct >= 0.5; absent fields render as zero so pct = 0).
- `check-anomalies.sh --milestone M018L --sample-floor 1` — emits
  NO `compression-regression` flag (the awk gate requires
  sav_total > 0).
- `compression-eval.sh --milestone M018L --tier 1 --sample-floor 1` —
  emits cohort report; all three tasks classify as the uncompressed
  cohort (tier1_savings_tokens absent or 0); the compressed cohort
  is empty so the diagnostic emits "insufficient sample" gracefully
  on the 0-vs-3 split (CON-5 never-aborts).

This fixture is the back-compat regression contract for the four
P05 surfaces: every diagnostic must remain quiet (no savings
output emitted) when the in-scope records carry no savings fields.

## Use via fixture-staging helper

`bash scripts/verify/_helpers/m018-p05-build-fixture.sh <root> no-savings`
copies this log to `<root>/milestones/M018F/execution-log.jsonl`.
