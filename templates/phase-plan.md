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
