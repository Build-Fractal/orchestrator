---
schema_version: "1.0"
type: milestone-summary
id: "{{milestone_id}}"
parent: null
milestone: "{{milestone_id}}"
provides:
  - "{{provides_entry}}"
requires:
  - from: "{{requires_from}}"
    what: "{{requires_what}}"
affects:
  - "{{affected_milestone_id}}"
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

## Milestone Rollup

{{milestone_rollup}}

## Phase Summaries

{{phase_summaries_compressed}}

## Key Decisions

{{key_decisions_detail}}

## Patterns Established

{{patterns_established_detail}}

## Knowledge Captured

{{knowledge_entries}}
