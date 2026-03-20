---
schema_version: "1.0"
type: task-summary
id: "{{task_id}}"
parent: "{{phase_id}}"
milestone: "{{milestone_id}}"
provides:
  - "{{provides_entry}}"
requires:
  - from: "{{requires_from}}"
    what: "{{requires_what}}"
affects:
  - "{{affected_phase_id}}"
key_files:
  - "{{key_file_path}}"
key_decisions:
  - "{{decision_ref}}"
patterns_established:
  - "{{pattern_description}}"
drill_down_paths:
  - "{{drill_down_path}}"
duration: "{{duration}}"
verification_result: "{{result}}"
completed_at: "{{completed_at}}"
---

{{one_line_summary}}

## What Happened

{{what_happened}}

## Deviations

{{deviations}}

## Files Created/Modified

- `{{file_path}}` — {{file_description}}
