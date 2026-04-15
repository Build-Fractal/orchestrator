---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M005"
goal: "Execution-log.jsonl entries include cost_source field (estimated/reported/unknown); aggregate-metrics.sh distinguishes unknown costs from zero costs; telemetry dashboard-ready output groups by cost accuracy."
demo_sentence: "A developer runs bash scripts/telemetry/record-telemetry.sh <log> --unit-id=M005/P02/T01 --cost=0.12 --cost-source=estimated and the JSONL entry includes a cost_source:estimated field; running bash scripts/telemetry/aggregate-metrics.sh <log> --format=json produces output with a by_cost_source breakdown showing counts and totals for estimated, reported, and unknown entries; null cost is reported as unknown (not zero), and cost 0 with cost_source=reported is reported as a zero-cost reported entry."
risk: "low"
depends_on: []
---

<!--
  P02 -- Cost Transparency
  =========================

  Context: The existing telemetry scripts record a `cost_estimated` numeric
  field but provide no provenance — the consumer cannot distinguish between
  "cost was computed from chars/4 heuristic" (estimated), "cost was returned
  by the provider API" (reported), and "no cost data was available" (unknown).
  This distinction is load-bearing for Conversus gate cost decisions (AD-2).

  Additionally, null/missing cost and zero cost are conflated: both result in
  no `cost_estimated` field in the JSONL. Downstream consumers cannot tell
  "we don't know the cost" from "it was actually free."

  Architectural decision:
    AD-2  Cost source is a closed enum with three values: `estimated`
          (chars/4 heuristic), `reported` (from provider response),
          `unknown` (no data available). `null` cost means unknown,
          `0` means actually free. This distinction is load-bearing
          for Conversus gate cost decisions.

  Cross-milestone dependencies:
    - M002 delivered the telemetry scripts (record-telemetry.sh,
      aggregate-metrics.sh).
    - M004 P02 delivered scripts/lib/errors.sh (emit_result).
    Both are committed on main.
-->

## Must-Haves

### Truths

- record-telemetry.sh accepts a `--cost-source` flag and validates it against the closed enum (estimated, reported, unknown).
  - Check: `bash scripts/verify/p02-cost-source-flag.sh`
- record-telemetry.sh writes `cost_source` field into the JSONL entry when `--cost-source` is provided.
  - Check: `bash scripts/verify/p02-cost-source-written.sh`
- record-telemetry.sh rejects invalid `--cost-source` values with a non-zero exit.
  - Check: `bash scripts/verify/p02-cost-source-validation.sh`
- aggregate-metrics.sh groups telemetry entries by `cost_source` and reports per-source counts and cost totals.
  - Check: `bash scripts/verify/p02-aggregate-groups.sh`
- aggregate-metrics.sh distinguishes null/missing cost from zero cost: null cost entries are counted as unknown, zero cost entries with a cost_source are counted under their source.
  - Check: `bash scripts/verify/p02-null-vs-zero.sh`
- references/file-formats.md documents the telemetry entry schema including cost_source enum and the null-vs-zero distinction.
  - Check: `bash scripts/verify/p02-schema-docs.sh`

### Artifacts

- scripts/telemetry/record-telemetry.sh (modify, contains "cost_source")
- scripts/telemetry/aggregate-metrics.sh (modify, contains "cost_source")
- references/file-formats.md (modify, contains "cost_source")
- scripts/verify/p02-cost-source-flag.sh (create, min 10 lines, contains "cost-source")
- scripts/verify/p02-cost-source-written.sh (create, min 10 lines, contains "cost_source")
- scripts/verify/p02-cost-source-validation.sh (create, min 10 lines, contains "cost-source")
- scripts/verify/p02-aggregate-groups.sh (create, min 10 lines, contains "cost_source")
- scripts/verify/p02-null-vs-zero.sh (create, min 10 lines, contains "cost_source")
- scripts/verify/p02-schema-docs.sh (create, min 10 lines, contains "cost_source")

### Key Links

- scripts/telemetry/record-telemetry.sh -> scripts/telemetry/aggregate-metrics.sh (record-telemetry produces entries that aggregate-metrics consumes)
- scripts/telemetry/record-telemetry.sh -> references/file-formats.md (schema documents the fields record-telemetry writes)
- scripts/telemetry/aggregate-metrics.sh -> references/file-formats.md (schema documents the aggregation output shape)

## Tasks

### T01: Add --cost-source flag to record-telemetry.sh + verification scripts

Updates `scripts/telemetry/record-telemetry.sh` to accept a `--cost-source`
flag with closed-enum validation (estimated|reported|unknown). When provided,
writes a `"cost_source":"<value>"` field into the JSONL entry. Rejects
unknown enum values with exit 1. Also creates all six verification scripts
for this phase under `scripts/verify/p02-*.sh`. Zero upstream dependencies.

Full plan: `tasks/T01-PLAN.md`

### T02: Update aggregate-metrics.sh to group by cost_source

Updates `scripts/telemetry/aggregate-metrics.sh` to read the `cost_source`
field from telemetry entries, accumulate per-source counts and cost totals,
and include a `by_cost_source` section in both text and JSON output formats.
Entries with no `cost_source` field and no `cost_estimated` field are counted
as `unknown`. Entries with `cost_estimated` of 0 and a `cost_source` field
are counted under their source (not conflated with unknown). Depends on T01
(the flag must exist so verification scripts can produce test data).

Full plan: `tasks/T02-PLAN.md`

### T03: Document telemetry entry schema in references/file-formats.md

Updates `references/file-formats.md` to add a Telemetry Entry section
documenting the record-telemetry.sh JSONL format, including the
`cost_source` enum (estimated|reported|unknown), the null-vs-zero cost
distinction (null = unknown, 0 = free), and all optional fields. Depends
on T01 (field names must be finalized).

Full plan: `tasks/T03-PLAN.md`

## Task Dependencies

```
T01 (record-telemetry.sh --cost-source + verify scripts)
  |
  +---> T02 (aggregate-metrics.sh grouping by cost_source)
  |
  +---> T03 (file-formats.md schema documentation)
```

T01 is the critical-path gate -- T02 needs the field to be written so its
verification scripts can produce test data. T03 needs finalized field names.
T02 and T03 are independent of each other and can execute in parallel.

## Files Likely Touched

- scripts/telemetry/record-telemetry.sh (modify)
- scripts/telemetry/aggregate-metrics.sh (modify)
- references/file-formats.md (modify)
- scripts/verify/p02-cost-source-flag.sh (create)
- scripts/verify/p02-cost-source-written.sh (create)
- scripts/verify/p02-cost-source-validation.sh (create)
- scripts/verify/p02-aggregate-groups.sh (create)
- scripts/verify/p02-null-vs-zero.sh (create)
- scripts/verify/p02-schema-docs.sh (create)
