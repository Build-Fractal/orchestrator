---
schema_version: "1.0"
type: "dispatch-error"
error_type: "{{error_type}}"
retry_eligible: "{{retry_eligible}}"
escalation: "{{escalation}}"
backend: "{{backend}}"
task_id: "{{task_id}}"
occurred_at: "{{occurred_at}}"
---

# Dispatch Error

## Error Type

{{error_type}}

<!--
  error_type values:
    backend_unavailable   -- no adapter probed as available
    backend_crashed        -- adapter subprocess exited non-zero without emitting a result
    backend_malformed      -- adapter output did not conform to dispatch-result schema
    input_invalid          -- task plan or payload path missing/unreadable
    timeout                -- dispatch exceeded configured time budget
    registry_error         -- backend-registry.sh could not enumerate adapters
-->

## Retry Eligibility

retry_eligible: {{retry_eligible}}

<!--
  retry_eligible values:
    true   -- orchestrator may safely re-dispatch without intervention
    false  -- re-dispatching will fail in the same way; escalation required
-->

## Escalation

escalation: {{escalation}}

<!--
  escalation values:
    none       -- handled in-band; retry or skip
    developer  -- pause the loop and surface to the developer
    abort      -- terminate the current autonomous run immediately
-->

## Error Message

{{error_message}}

## Context

<!-- Captured context at time of failure: which adapter was attempted,
     which backend resolved, what inputs were provided, what stderr
     lines the adapter emitted. Used by the developer and by crash-
     recovery briefing generators. -->

{{error_context}}

## Suggested Action

<!-- Concrete next step. Examples:
       "Install the codex CLI and re-run."
       "Retry with --backend local-agent."
       "Review the task payload for malformed YAML frontmatter."
-->

{{suggested_action}}
