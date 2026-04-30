---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M001"
name: "M030/P02 round-trip stage plan"
depends_on: []
---

# Round-trip stage plan (M030/P02/T01 verifier input)

This file is a fixture input for `tools/verify/p02-additive-schema.sh`. The
path encodes `M001/P01/T01` so `dispatch-interface.sh` regex-extracts those
identifiers when emitting the round-trip `dispatch_usage` record. Do NOT edit
the embedded `M001`/`P01`/`T01` markers — they are load-bearing for the
byte-equality contract.
