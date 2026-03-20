---
schema_version: "1.0"
type: phase-summary
id: "{{phase_id}}"
parent: "{{milestone_id}}"
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
observability_surfaces:
  - "{{observability_surface}}"
---

{{one_line_summary}}

## Phase Rollup

{{phase_rollup}}

## Task Summaries

{{task_summaries_compressed}}

## Decisions Made

{{decisions_made}}

## Patterns Established

{{patterns_established_detail}}
