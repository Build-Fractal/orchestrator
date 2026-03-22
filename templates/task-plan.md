---
schema_version: "1.0"
type: task-plan
task: "{{task_id}}"
phase: "{{phase_id}}"
milestone: "{{milestone_id}}"
name: "{{task_name}}"
depends_on: [{{upstream_task_ids}}]
---

## Description

{{description}}

## Steps

{{steps}}

## Must-Haves

{{must_haves}}

## Verification

{{verification_criteria}}

## Inputs

### From Previous Tasks
<!-- For each upstream file this task reads or imports: -->
- `{{file_path}}` (from {{task_id}})
  - Key API: `{{method signatures this task calls}}`
  - Key types: `{{types/interfaces this task uses}}`

### From Disk (Pre-existing)
<!-- Files that exist before any phase tasks run -->
- `{{file_path}}` — {{what this task uses from it}}

## Expected Output

{{expected_output}}

<!-- Task plans must fit in one context window (FR-005).
     Plans assume zero prior context — include all paths, commands, and expected output (FR-011, FR-012).
     All dynamic values use placeholder syntax. No hardcoded IDs. -->
