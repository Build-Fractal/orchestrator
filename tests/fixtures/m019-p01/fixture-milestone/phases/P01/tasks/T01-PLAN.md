---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M999"
name: "Fixture task"
depends_on: []
---

## Prerequisites

None. Hermetic fixture.

## Description

Fixture task used by scripts/verify/m019-p01-emitter-presence.sh to exercise
build-context.sh + dispatch-interface.sh + write-summary.sh end-to-end.

## Must-Haves

### Truths

- The emitter writes exactly one `payload_breakdown` record after payload assembly.
  - Check: `grep -c '"record_type":"payload_breakdown"' tests/fixtures/m019-p01/fixture-milestone/execution-log.jsonl`

## Constraints

- Hermetic: writes land in the fixture tree only.

## Expected Output

- One JSONL record appended per emitter invocation.
