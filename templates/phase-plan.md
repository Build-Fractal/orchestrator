---
schema_version: "1.0"
type: phase-plan
phase: "{{phase_id}}"
milestone: "{{milestone_id}}"
goal: "{{goal}}"
demo_sentence: "{{demo_sentence}}"
risk: "{{risk}}"
depends_on: {{depends_on}}
---

## Must-Haves

### Truths

- {{truth}}

### Artifacts

- {{artifact_path}} (min {{min_lines}} lines{{contains_note}})

### Key Links

- {{from_path}} → {{to_path}} ({{link_description}})

## Tasks

### {{task_id}}: {{task_name}}

{{task_plan}}

<!-- Repeat the task block above for each task in the phase (1-7 tasks per phase).
     Each task plan must be self-contained: exact file paths, code, commands, expected output.
     Plans assume zero prior context (FR-011). -->

## Task Dependencies

<!-- Show the dependency graph between tasks in this phase.
     Linear chain example:    T01 → T02 → T03 → T04
     Parallel example:        T01 → T02
                              T01 → T03  (T02 and T03 can run in parallel)
                              T02 + T03 → T04
     Used by dispatch to determine execution order and parallelism opportunities. -->

## Files Likely Touched

- {{file_path}} ({{create|modify}})

<!-- List every file any task in this phase will create or modify.
     Used by scripts/verify/check-scope.sh for scope enforcement. -->
