---
schema_version: "1.0"
type: continue-file
milestone: "{{milestone_id}}"
phase: "{{phase_id}}"
task: "{{task_id}}"
step: {{step}}
total_steps: {{total_steps}}
saved_at: "{{saved_at}}"
reason: "{{reason}}"
---

## Completed Work

{{completed_work}}

## Remaining Work

{{remaining_work}}

## Decisions Made

{{decisions_made}}

## Context

<!-- Key context the resuming agent needs to pick up where this session left off.
     Include any state that is not on disk but was in the paused session's memory. -->

{{context}}

## Next Action

{{next_action}}
