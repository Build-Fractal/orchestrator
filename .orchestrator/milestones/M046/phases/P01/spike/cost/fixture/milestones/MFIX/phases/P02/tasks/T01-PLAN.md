---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "MFIX"
name: "Trivial fixture task (P02)"
depends_on: []
---

## Description

Trivial fixture task for the M046/P01/T02 cost-cadence probe. Same shape as
P01/T01, but the stub seeds one SYNTHETIC dispatch_usage record (labeled
`emission_point: cadence-probe-stub`, `pricing_version: synthetic-fixture`)
before writing the summary, so the unit_close estimated_cost_usd aggregation
path is exercised without any LLM spend.

## Verification

```bash
true
```
