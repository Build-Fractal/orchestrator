---
schema_version: "1.0"
type: recovery-briefing
milestone: "{{milestone_id}}"
recovered_at: "{{recovered_at}}"
crash_detected_at: "{{crash_detected_at}}"
---

## Crash State

- **Last Active Unit**: {{unit_type}} — {{unit_id}}
- **Last Known State**: {{last_known_state}}
- **Lock File**: {{lock_file_status}}
- **PID**: {{pid}} ({{pid_status}})
- **Runtime**: {{runtime}}
- **Started At**: {{started_at}}
- **Unit Started At**: {{unit_started_at}}

## Completed Work

<!-- Units that completed before the crash, verified by summary files on disk. -->

{{completed_units}}

## Incomplete Work

<!-- The unit that was in progress when the crash occurred.
     Check for partial output files, modified timestamps, git diff. -->

{{incomplete_work}}

## Recovery Plan

<!-- Recommended actions to resume from the crash point. -->

{{recovery_plan}}
