---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M999"
---

# T01 — Synthetic In-flight Task Plan

Synthetic task plan used only by the SC-3 status JSON fixture. Its presence
(with no T01-SUMMARY.md sibling) drives `derive-phase.sh` to keep the
M999 milestone in the `executing` state.
