---
schema_version: "1.0"
type: task-plan
task: "{{task_id}}"
phase: "{{phase_id}}"
milestone: "{{milestone_id}}"
name: "{{task_name}}"
depends_on: [{{upstream_task_ids}}]
---

## Prerequisites

<!-- Upstream dependencies and pre-existing state this task requires. -->
{{prerequisites}}

## Description

{{description}}

## Steps

{{steps}}

## Must-Haves

{{must_haves}}

## Verification

<!-- Verification commands MUST use single-script-file shape per AD-19.
     The harness safety heuristic layer sits above the allow list and
     cannot be configured away. Inline compound bash, plain subshells,
     $() containing pipes, and process substitution all trigger the
     heuristic and interrupt unattended auto mode execution.

     See commands/plan-phase.md "Truth Check: command shape" for the
     full forbidden-shape enumeration and rationale (AD-19).

     Required form:
       bash scripts/verify/<phase>-<task>-<name>.sh
       bash scripts/verify/check-must-haves.sh <phase-dir>

     Forbidden forms:
       ( . scripts/lib/errors.sh && fn arg )
       result=$(bash cmd | grep -c 'RESULT')
       diff <(cmd1) <(cmd2)
-->
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

## Constraints

<!-- Scope boundaries, budget limits, or invariants this task must respect. -->
{{constraints}}

## Expected Output

{{expected_output}}

<!-- Task plans must fit in one context window (FR-005).
     Plans assume zero prior context — include all paths, commands, and expected output (FR-011, FR-012).
     All dynamic values use placeholder syntax. No hardcoded IDs. -->
