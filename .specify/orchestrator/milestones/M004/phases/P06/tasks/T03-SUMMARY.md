---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P06"
milestone: "M004"
provides:
  - "Engine integration for record-telemetry.sh (run_id in JSONL, EVENT+RESULT on stderr) and aggregate-metrics.sh (error_kind grouping in text+JSON output, EVENT+RESULT via chained EXIT trap)"
requires:
  - "from:P02 what:lib/errors.sh and lib/events.sh"
affects:
  - "P07 (conformance checks)"
key_files:
  - "scripts/telemetry/record-telemetry.sh, scripts/telemetry/aggregate-metrics.sh"
key_decisions:
  - "Chained _am_final_result into existing EXIT trap rather than adding separate trap to avoid overwriting temp-dir cleanup; error_kind tracking uses same tmpdir-per-value pattern as model and milestone tracking for Bash 3.2 compatibility"
patterns_established:
  - "EXIT trap chaining pattern for scripts with pre-existing cleanup traps; error_kind aggregation via tmpdir files"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P06/tasks/T03-PLAN.md"
duration: "8m"
verification_result: "pass"
completed_at: "2026-04-13T20:45:20Z"
---

Integrated engine lifecycle hooks into both telemetry scripts. record-telemetry.sh now sources lib/errors.sh and lib/events.sh, includes run_id in JSONL entries when ORCH_RUN_ID is set, emits TASK_COMPLETE event and RESULT on stderr via EXIT trap. aggregate-metrics.sh now sources the same libs, tracks error_kind from dispatch entries using tmpdir files (Bash 3.2 safe), outputs a By Error Kind section in text format and by_error_kind object in JSON format, emits TASK_COMPLETE event and RESULT via chained EXIT trap that preserves existing temp-dir cleanup. All changes are guarded by ORCH_RUN_ID checks per NFR-204. Verified in both standalone and engine modes.
