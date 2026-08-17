---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "MFIX"
name: "Trivial fixture task (P01)"
depends_on: []
---

## Description

Trivial fixture task for the M046/P01/T02 cost-cadence probe. No real work:
the dispatch stub (drive-segment.sh) stands in for the agent runtime and
writes T01-SUMMARY.md via the real write-summary.sh.

## Verification

```bash
true
```
