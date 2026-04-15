---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M008"
name: "Create dispatch-result.md and dispatch-error.md templates"
depends_on: []
---

## Prerequisites

- `templates/` directory exists (contains many existing templates like `task-plan.md`, `phase-plan.md`, `intensity-metadata.md`).
- Per MEM013, all templates use YAML frontmatter with `schema_version` + `type` fields and `{{placeholder}}` syntax in the body.

## Description

Create two template files that define the canonical schemas emitted by all backend adapters:

1. **`templates/dispatch-result.md`** — success result envelope. Emitted by a backend adapter when a dispatched task completes (regardless of whether the task's internal logic succeeded or failed — that is tracked by the `status` field). Downstream consumers (the orchestrator core, verification scripts, the knowledge system) parse this schema to learn completion status and which artifacts were produced.

2. **`templates/dispatch-error.md`** — structured-error envelope. Emitted by `dispatch-interface.sh` (and optionally by adapters themselves) when a dispatch *attempt* fails (backend unavailable, adapter crashed, timeout, malformed input). Distinguished from `dispatch-result.md` with `status: failure` — error.md is for *dispatch infrastructure* failures, whereas result.md with `status: failure` is for *task execution* failures.

Both files are markdown templates (not executable). No scripts import them; adapters emit text matching the schema. Verification scripts check the template files' structural fields are present.

## Steps

### Step 1 — Create templates/dispatch-result.md

Write the following content verbatim to `templates/dispatch-result.md`:

```markdown
---
schema_version: "1.0"
type: dispatch-result
status: "{{status}}"
backend: "{{backend}}"
task_id: "{{task_id}}"
phase_id: "{{phase_id}}"
milestone_id: "{{milestone_id}}"
dispatched_at: "{{dispatched_at}}"
completed_at: "{{completed_at}}"
duration_s: "{{duration_s}}"
---

# Dispatch Result

## Status

{{status}} -- {{status_explanation}}

<!--
  status values:
    success  -- task executed and produced expected artifacts
    failure  -- task executed but verification failed or artifacts missing
    retry    -- task did not complete; a retry is warranted
    timeout  -- task exceeded the configured time budget
-->

## Summary

{{summary}}

<!--
  One to three sentences describing what the task did. Written by the
  backend-adapted agent after task completion. Consumed by the
  orchestrator core and (optionally) surfaced to the developer.
-->

## Artifacts

<!--
  List each file created or modified by the task, one per bullet,
  as a relative path from the project root. Empty list is allowed
  if the task intentionally produced no files.
-->

- {{artifact_path_1}}
- {{artifact_path_2}}

## Notes

<!-- Optional. Backend-specific diagnostic information, performance
     notes, or anything else not captured by the fields above. -->

{{notes}}
```

### Step 2 — Create templates/dispatch-error.md

Write the following content verbatim to `templates/dispatch-error.md`:

```markdown
---
schema_version: "1.0"
type: dispatch-error
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
```

### Step 3 — Create scripts/verify/m008-p02-result-template.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies templates/dispatch-result.md defines the success result schema.
set -eu

f="templates/dispatch-result.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# YAML frontmatter fields
for field in schema_version type status backend task_id dispatched_at completed_at duration_s; do
  grep -q "^${field}:" "$f" || { echo "FAIL: $f missing frontmatter field '${field}'"; exit 1; }
done

# Type value
grep -q '^type: "dispatch-result"' "$f" || { echo "FAIL: $f type must be dispatch-result"; exit 1; }

# Body sections
grep -q '^# Dispatch Result' "$f" || { echo "FAIL: $f missing '# Dispatch Result' heading"; exit 1; }
grep -q '^## Status' "$f" || { echo "FAIL: $f missing '## Status' section"; exit 1; }
grep -q '^## Summary' "$f" || { echo "FAIL: $f missing '## Summary' section"; exit 1; }
grep -q '^## Artifacts' "$f" || { echo "FAIL: $f missing '## Artifacts' section"; exit 1; }

# Comment block enumerating status values
grep -q 'success' "$f" || { echo "FAIL: $f missing 'success' status value documentation"; exit 1; }
grep -q 'failure' "$f" || { echo "FAIL: $f missing 'failure' status value documentation"; exit 1; }
grep -q 'retry' "$f" || { echo "FAIL: $f missing 'retry' status value documentation"; exit 1; }
grep -q 'timeout' "$f" || { echo "FAIL: $f missing 'timeout' status value documentation"; exit 1; }

echo "PASS: templates/dispatch-result.md defines the success result schema"
```

### Step 4 — Create scripts/verify/m008-p02-error-template.sh

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# Verifies templates/dispatch-error.md defines the structured-error schema.
set -eu

f="templates/dispatch-error.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }

# YAML frontmatter fields
for field in schema_version type error_type retry_eligible escalation backend occurred_at; do
  grep -q "^${field}:" "$f" || { echo "FAIL: $f missing frontmatter field '${field}'"; exit 1; }
done

# Type value
grep -q '^type: "dispatch-error"' "$f" || { echo "FAIL: $f type must be dispatch-error"; exit 1; }

# Body sections
grep -q '^# Dispatch Error' "$f" || { echo "FAIL: $f missing '# Dispatch Error' heading"; exit 1; }
grep -q '^## Error Type' "$f" || { echo "FAIL: $f missing '## Error Type' section"; exit 1; }
grep -q '^## Retry Eligibility' "$f" || { echo "FAIL: $f missing '## Retry Eligibility' section"; exit 1; }
grep -q '^## Escalation' "$f" || { echo "FAIL: $f missing '## Escalation' section"; exit 1; }
grep -q '^## Error Message' "$f" || { echo "FAIL: $f missing '## Error Message' section"; exit 1; }
grep -q '^## Suggested Action' "$f" || { echo "FAIL: $f missing '## Suggested Action' section"; exit 1; }

# Enumerated error_type values
for et in backend_unavailable backend_crashed backend_malformed input_invalid timeout registry_error; do
  grep -q "$et" "$f" || { echo "FAIL: $f missing error_type value '$et' documentation"; exit 1; }
done

# Escalation values
for ev in "none" "developer" "abort"; do
  grep -q "$ev" "$f" || { echo "FAIL: $f missing escalation value '$ev' documentation"; exit 1; }
done

echo "PASS: templates/dispatch-error.md defines the structured-error schema"
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: "templates/dispatch-result.md defines the success result schema..." and "templates/dispatch-error.md defines the failure error schema..."
- **Artifacts**: `templates/dispatch-result.md`, `templates/dispatch-error.md`, `scripts/verify/m008-p02-result-template.sh`, `scripts/verify/m008-p02-error-template.sh`.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/m008-p02-result-template.sh
bash scripts/verify/m008-p02-error-template.sh
```

Both should print `PASS:` lines and exit 0.

### Files Touched By This Task

- `templates/dispatch-result.md` (create)
- `templates/dispatch-error.md` (create)
- `scripts/verify/m008-p02-result-template.sh` (create)
- `scripts/verify/m008-p02-error-template.sh` (create)

## Inputs

### From Previous Tasks

None — T01 is the first task in P02.

### From Disk (Pre-existing)

- `templates/task-plan.md`, `templates/intensity-metadata.md`, `templates/phase-plan.md` — existing templates demonstrating the `schema_version`/`type`/placeholder convention (MEM013).

## Constraints

- Templates are markdown only — no executable code.
- Follow MEM013: YAML frontmatter with `schema_version` + `type` fields; body uses `{{placeholder}}` syntax; no hardcoded IDs.
- `type` field value must exactly match `dispatch-result` and `dispatch-error` respectively (verification scripts grep for the exact string).
- HTML comments (`<!-- ... -->`) document field enumerations inline; they must include every enumerated value since verification scripts grep for each.

## Expected Output

After completing this task:

1. `templates/dispatch-result.md` exists with YAML frontmatter (8 fields including `status`, `backend`, `task_id`, timestamps, `duration_s`), and body sections: Status, Summary, Artifacts, Notes.
2. `templates/dispatch-error.md` exists with YAML frontmatter (7 fields including `error_type`, `retry_eligible`, `escalation`, `backend`, `task_id`, `occurred_at`), and body sections: Error Type, Retry Eligibility, Escalation, Error Message, Context, Suggested Action.
3. `bash scripts/verify/m008-p02-result-template.sh` prints `PASS`.
4. `bash scripts/verify/m008-p02-error-template.sh` prints `PASS`.
5. `git status` shows 4 new files.
