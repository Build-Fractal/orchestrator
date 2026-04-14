---
schema_version: "1.0"
type: "dispatch-result"
status: "{{status}}"
backend: "{{backend}}"
task_id: "{{task_id}}"
phase_id: "{{phase_id}}"
milestone_id: "{{milestone_id}}"
dispatched_at: "{{dispatched_at}}"
completed_at: "{{completed_at}}"
duration_s: "{{duration_s}}"
---

# Dispatch Result

## Status

{{status}} -- {{status_explanation}}

<!--
  status values:
    success  -- task executed and produced expected artifacts
    failure  -- task executed but verification failed or artifacts missing
    retry    -- task did not complete; a retry is warranted
    timeout  -- task exceeded the configured time budget
-->

## Summary

{{summary}}

<!--
  One to three sentences describing what the task did. Written by the
  backend-adapted agent after task completion. Consumed by the
  orchestrator core and (optionally) surfaced to the developer.
-->

## Artifacts

<!--
  List each file created or modified by the task, one per bullet,
  as a relative path from the project root. Empty list is allowed
  if the task intentionally produced no files.
-->

- {{artifact_path_1}}
- {{artifact_path_2}}

## Notes

<!-- Optional. Backend-specific diagnostic information, performance
     notes, or anything else not captured by the fields above. -->

{{notes}}
