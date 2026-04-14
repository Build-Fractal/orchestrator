# Errors Reference

> Progressive disclosure reference for the speckit-orchestrator error system.
> Self-contained — read this document to understand error kinds, the emit_result
> protocol, and error handling patterns without reading source code.

> Audience: extenders, contributors

## Overview

The orchestrator uses a **closed error taxonomy** with structured result reporting. Every script must emit exactly one `RESULT:` line before exiting. This is not optional — a script that completes without a RESULT line is a silent failure (Constitution Principle II: Evidence Before Claims).

The system has three layers:

1. **Error kinds** — a closed set of 6 categories that classify every failure.
2. **The `emit_result` protocol** — a function that prints a single structured `RESULT:` JSON line to stdout.
3. **Error propagation** — how RESULT lines flow into the execution log and drive the stuck detector.

All error handling code lives in `scripts/lib/errors.sh`, which every engine-managed script sources via its double-sourcing guard.

---

## Error Kinds

The orchestrator defines exactly 6 error kinds. This is a **closed set** (FR-220) — no new kinds can be added without updating the taxonomy in `scripts/lib/errors.sh`. The `orch_is_error_kind` function validates any value against this set.

### CONFIG

**Description**: Configuration or argument errors. The inputs to a script are invalid, missing, or malformed.

**When it occurs**:
- Missing required CLI arguments or flags
- Invalid flag values passed to a script
- A required configuration file (e.g., `routing.yaml`, `autonomy-defaults.yaml`) is missing or unparseable
- A recipe file cannot be parsed
- An unknown error_kind value is passed to `emit_result` (self-heals by reclassifying as CONFIG)

**Example scenario**: The engine is invoked without positional arguments for milestone and phase.

**Example RESULT line**:
```
RESULT:{"status":"error","error_kind":"CONFIG","detail":"missing required positional args: <milestone> <phase>"}
```

### STATE

**Description**: State-related errors. The on-disk orchestrator state is not in the expected condition for the requested operation.

**When it occurs**:
- A phase directory or tasks directory does not exist when the engine tries to run
- A hook blocks a lifecycle transition (e.g., PRE_ADVANCE hook rejects phase completion)
- The phase ends with blocked tasks, indicating incomplete execution
- A phase transition cannot proceed because prerequisites are unmet

**Example scenario**: The engine tries to run phase P03 but the directory `.specify/orchestrator/milestones/M001/phases/P03` does not exist.

**Example RESULT line**:
```
RESULT:{"status":"error","error_kind":"STATE","detail":"phase directory not found: .specify/orchestrator/milestones/M001/phases/P03"}
```

### DISPATCH

**Description**: Dispatch pipeline errors. Something went wrong during model selection, complexity classification, or agent invocation.

**When it occurs**:
- Model selection fails (all models in the fallback chain are exhausted)
- Complexity classification fails
- The permissions check detects that `generate-permissions.sh` failed
- A pluggable host stub is invoked that has no real implementation yet

**Example scenario**: The `select-model.sh` script cannot find a valid model for the requested tier in `routing.yaml`.

**Example RESULT line**:
```
RESULT:{"status":"error","error_kind":"DISPATCH","detail":"all models in fallback chain exhausted"}
```

### VERIFY

**Description**: Verification errors. A completed task or phase failed its verification checks.

**When it occurs**:
- `check-must-haves.sh` detects that required artifacts are missing or incomplete
- The `phase_complete` guard blocks phase advancement because not all tasks have summaries
- Recipe conformance checks find invalid sections
- Resume E2E test assertions fail

**Example scenario**: The engine finishes executing all tasks in P02 but the phase-completeness guard finds tasks without summary files.

**Example RESULT line**:
```
RESULT:{"status":"error","error_kind":"VERIFY","detail":"phase_complete guard blocked advance for .specify/orchestrator/milestones/M001/phases/P02"}
```

### BUDGET

**Description**: Budget or resource limit errors. The session has exceeded its configured cost or duration caps.

**When it occurs**:
- The cumulative cost of dispatches exceeds the configured maximum cost cap
- The cumulative duration of dispatches exceeds the configured maximum duration cap
- The `guard_budget` function in the engine task loop rejects further dispatches

**Example scenario**: A long-running autonomous session has dispatched 15 tasks and the cumulative estimated cost exceeds the configured $5.00 budget cap.

**Example RESULT line**:
```
RESULT:{"status":"error","error_kind":"BUDGET","detail":"cumulative cost 512 cents exceeds cap 500 cents"}
```

### IO

**Description**: Input/output and file system errors. A file could not be read, written, or an external process failed unexpectedly.

**When it occurs**:
- `record-result.sh` fails to append to the execution log
- `record-telemetry.sh` fails during telemetry recording
- `aggregate-metrics.sh` encounters a file system error
- `write-permissions.sh` receives an empty input file or encounters unsupported fields
- Any EXIT trap detects a nonzero return code from an engine-managed script

**Example scenario**: The `record-result.sh` script fails to write to the execution log because the target directory does not exist and cannot be created.

**Example RESULT line**:
```
RESULT:{"status":"error","error_kind":"IO","detail":"record-result failed rc=1"}
```

---

## The emit_result Protocol

### Function Signature

```bash
emit_result <status> [error_kind] [detail]
```

| Parameter    | Required | Values           | Description                                      |
|--------------|----------|------------------|--------------------------------------------------|
| `status`     | Yes      | `ok`, `error`    | Whether the script succeeded or failed            |
| `error_kind` | No*      | One of the 6 kinds | Category of failure. Required when status=error  |
| `detail`     | No       | Free-form string | Human-readable description of what happened       |

*When `status` is `error`, `error_kind` SHOULD be provided. If omitted, the RESULT line will have an empty `error_kind` field.

### Protocol Rules

1. **Exactly once**: Every script must call `emit_result` exactly once, at completion. Multiple calls produce multiple RESULT lines and violate the protocol.

2. **Status validation**: If `status` is anything other than `ok` or `error`, the function self-corrects to `error` with kind `CONFIG` and prepends "invalid status passed to emit_result" to the detail.

3. **Error kind validation**: If `error_kind` is not in the closed taxonomy, the function reclassifies it as `CONFIG` and rewrites the detail to include the original invalid kind. This prevents taxonomy drift.

4. **JSON escaping**: The `detail` field is escaped for JSON safety — backslashes, double quotes, newlines, tabs, and carriage returns are all sanitized.

5. **Output target**: RESULT lines go to **stdout** by default. Scripts running under the engine (when `ORCH_RUN_ID` is set) may redirect their own RESULT lines to **stderr** via EXIT traps so they do not interfere with the script's primary stdout output.

### Usage Examples

Success:
```bash
emit_result ok "" "phase advanced to P03"
emit_result ok "" "engine completed M001/P02 (dry_run=0, completed=4)"
```

Error with kind:
```bash
emit_result error CONFIG "routing.yaml missing required field models.heavy.id"
emit_result error STATE "phase directory not found: $PHASE_DIR"
emit_result error DISPATCH "all models in fallback chain exhausted"
emit_result error VERIFY "check-must-haves failed rc=1"
emit_result error BUDGET "cumulative cost exceeds cap"
emit_result error IO "record-result failed rc=1"
```

---

## RESULT Line Format

Every RESULT line is a single line on stdout with the prefix `RESULT:` followed by a JSON object:

```
RESULT:{"status":"<ok|error>","error_kind":"<kind>","detail":"<message>"}
```

### Field Schema

| Field        | Type   | Always Present | Description                                       |
|--------------|--------|----------------|---------------------------------------------------|
| `status`     | string | Yes            | `"ok"` or `"error"`                                |
| `error_kind` | string | Yes            | One of the 6 taxonomy values, or `""` for ok status |
| `detail`     | string | Yes            | Human-readable description, JSON-escaped            |

### Parsing

RESULT lines are designed to be grep-friendly:

```bash
# Extract all RESULT lines from engine output
grep '^RESULT:' engine-output.log

# Extract the JSON payload
grep '^RESULT:' engine-output.log | sed 's/^RESULT://'

# Check if the final result was an error
grep '^RESULT:' engine-output.log | grep '"status":"error"'
```

### Relationship to Exit Codes

RESULT lines and exit codes serve complementary purposes:

| Exit Code | Meaning                        | Typical error_kind |
|-----------|--------------------------------|--------------------|
| 0         | Success                        | (none — status=ok) |
| 1         | General error / invalid args   | CONFIG or IO       |
| 2         | CLI argument validation failure| CONFIG             |
| 3         | State precondition failure     | STATE              |
| 4         | Phase ended with blocked tasks | STATE              |
| 5         | Phase-completeness guard block | VERIFY             |
| 6         | Hook blocked lifecycle advance | STATE              |

The RESULT line is always emitted **before** the exit, so consumers can parse the structured detail even when only an exit code is available.

---

## Error Propagation

Errors flow through a four-stage pipeline from script execution to autonomous loop decisions.

### Stage 1: Script Emission

A script calls `emit_result error <kind> <detail>`, which prints the RESULT line to stdout. The script then exits with a nonzero code. Scripts that use EXIT traps (e.g., `record-result.sh`, `aggregate-metrics.sh`) emit their RESULT line in the trap handler so it fires even on unexpected failures.

### Stage 2: Engine Capture

The engine (`scripts/engine/run.sh`) runs scripts as subprocesses and observes their exit codes. When a subprocess fails:

- The engine emits a `SAFETY_WARNING` event noting the failure
- The engine increments its `_blocked` counter
- The engine emits a `TASK_COMPLETE` event with `outcome="blocked"` or `outcome="failed"`
- If the failure is fatal (e.g., missing phase directory), the engine emits its own RESULT line and exits

### Stage 3: Execution Log Recording

The `record-result.sh` script appends a JSON entry to the execution log (`execution-log.jsonl`). When the `--error_kind=<KIND>` flag is passed, the entry includes an `error_kind` field:

```json
{
  "timestamp": "2026-04-13T10:15:00Z",
  "unitId": "M001/P02/T03",
  "milestone": "M001",
  "phase": "P02",
  "task": "T03",
  "tier": "C",
  "outcome": "failure",
  "dispatch_method": "sequential",
  "attempt": 1,
  "error_kind": "VERIFY"
}
```

The `error_kind` field is validated by `orch_is_error_kind` before recording. Invalid values are rejected with exit code 1.

### Stage 4: Stuck Detection and Telemetry

Two downstream consumers read `error_kind` from the execution log:

**Stuck detector** (`scripts/lifecycle/stuck-detector.sh`): Scans the execution log for a given unit ID. If a unit has been dispatched 2 or more times without a `success` outcome, it reports `STUCK:YES`. The auto-loop (`scripts/lifecycle/auto-loop.sh`) calls the stuck detector at Step C and exits with code 3 if stuck is detected. This halts autonomous execution and surfaces the problem for human intervention.

**Aggregate metrics** (`scripts/telemetry/aggregate-metrics.sh`): Groups failures by `error_kind` and reports counts in the `by_error_kind` section of its output. This provides a dashboard-level view of which error categories dominate:

```json
{
  "by_error_kind": {
    "CONFIG": 2,
    "VERIFY": 5,
    "IO": 1
  }
}
```

### Flow Diagram

```
Script failure
  |
  v
emit_result error <KIND> <detail>    --> RESULT: line on stdout
  |
  v
Engine observes nonzero exit code    --> SAFETY_WARNING event
  |                                  --> TASK_COMPLETE event (blocked/failed)
  v
record-result.sh --error_kind=KIND   --> execution-log.jsonl entry
  |
  +---> stuck-detector.sh            --> STUCK:YES/NO (gates auto-loop)
  +---> aggregate-metrics.sh         --> by_error_kind counts (telemetry)
```

---

## Cross-References

- [File Formats Reference](./file-formats.md) — execution log JSONL schema, all state file formats
- [Events Reference](./events.md) — EVENT: line format, SAFETY_WARNING and lifecycle events
- [Engine Reference](./engine.md) — engine run pipeline, guard functions, task loop
- [State Machine Reference](./state-machine.md) — phase states and transitions
- [Verification Ladder Reference](./verification-ladder.md) — 4-tier verification that produces VERIFY errors
- Source: [`scripts/lib/errors.sh`](../scripts/lib/errors.sh) — error taxonomy and emit_result implementation
- Source: [`scripts/engine/run.sh`](../scripts/engine/run.sh) — engine error handling and exit codes
- Source: [`scripts/lifecycle/record-result.sh`](../scripts/lifecycle/record-result.sh) — execution log recording
- Source: [`scripts/lifecycle/stuck-detector.sh`](../scripts/lifecycle/stuck-detector.sh) — stuck detection from log entries
- Source: [`scripts/telemetry/aggregate-metrics.sh`](../scripts/telemetry/aggregate-metrics.sh) — error_kind aggregation
