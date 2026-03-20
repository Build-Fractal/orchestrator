---
schema_version: "1.0"
type: task-plan
task: "{{task_id}}"
phase: "{{phase_id}}"
milestone: "{{milestone_id}}"
name: "{{task_name}}"
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

{{inputs}}

## Expected Output

{{expected_output}}

<!-- Task plans must fit in one context window (FR-005).
     Plans assume zero prior context — include all paths, commands, and expected output (FR-011, FR-012).
     All dynamic values use placeholder syntax. No hardcoded IDs. -->
