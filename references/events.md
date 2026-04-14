# Events Reference

> Progressive disclosure reference for the speckit-orchestrator event system.
> Self-contained — read this document to understand every event type, its fields,
> and the structured EVENT: line format without reading source code.

> Audience: extenders, contributors

## Overview

The orchestrator emits **structured events** at every lifecycle boundary. Events provide a machine-parseable observability stream that hooks, diagnostics, and telemetry consumers can process without understanding engine internals.

Events are emitted by the `emit_event` function defined in `scripts/lib/events.sh`. Every engine-managed script is required to emit at least one event (Constitution Principle II). Events appear on stdout as single-line `EVENT:` records and are designed to be grep-friendly and append-only.

The canonical event type registry is defined in the `ORCH_EVENT_TYPES` variable. Emitting an unregistered type still produces the event line but also triggers a companion `SAFETY_WARNING` so the drift is observable.

---

## Event Line Format

Every event is a single line with the following structure:

```
EVENT:<TYPE> timestamp=<ISO-8601> run_id=<run_id> [key=value ...]
```

### Fixed Fields (always present)

| Field       | Description                                                                 |
|-------------|-----------------------------------------------------------------------------|
| `TYPE`      | Uppercase event type from the canonical registry (appended directly after `EVENT:` with no space). |
| `timestamp` | ISO-8601 UTC timestamp. Uses `$ORCH_STARTED_AT` when set (frozen per-session for determinism), otherwise falls back to `date -u`. |
| `run_id`    | The current run identifier from `$ORCH_RUN_ID`. Defaults to `unset` if run context has not been initialized. |

### Value Quoting

Values containing whitespace or double quotes are automatically wrapped in double quotes with internal quotes and backslashes escaped. Values without whitespace are emitted bare.

### Examples

```
EVENT:SESSION_START timestamp=2026-04-10T14:00:00Z run_id=abc123 milestone=M004 phase=P03 pending_tasks=5
EVENT:GUARD_BLOCKED timestamp=2026-04-10T14:01:00Z run_id=abc123 guard=payload_sanity reason="payload too small: 42 < 100 chars"
EVENT:TASK_COMPLETE timestamp=2026-04-10T14:02:00Z run_id=abc123 task=T02 outcome=success model=claude-sonnet-4-6 verify=pass
```

---

## Event Types

The canonical registry contains 20 event types organized into four categories: session/lifecycle events, dispatch pipeline events, safety/guard events, and hook events.

---

### SESSION_START

Marks the beginning of an engine session.

**Emitted by**: `scripts/engine/run.sh` (session open), `scripts/lifecycle/generate-permissions.sh` (permission generation sessions)

**When**: At the start of `run.sh` after run context initialization and pending-task discovery. Also emitted by standalone scripts that manage their own sessions.

**Fields**:

| Field           | Type   | Description                              |
|-----------------|--------|------------------------------------------|
| `milestone`     | string | Milestone ID (e.g., `M004`)             |
| `phase`         | string | Phase ID (e.g., `P03`)                  |
| `pending_tasks` | int    | Count of tasks without a SUMMARY.md     |
| `dry_run`       | 0/1    | Whether this is a dry-run session       |
| `forced`        | 0/1    | Whether `--force` override is active    |

**Example**:
```
EVENT:SESSION_START timestamp=2026-04-10T14:00:00Z run_id=abc123 milestone=M004 phase=P03 pending_tasks=5 dry_run=0 forced=0
```

---

### SESSION_END

Marks the end of an engine session.

**Emitted by**: `scripts/engine/run.sh`

**When**: After all tasks have been processed and PRE_ADVANCE hooks have run.

**Fields**:

| Field       | Type   | Description                                |
|-------------|--------|--------------------------------------------|
| `milestone` | string | Milestone ID                               |
| `phase`     | string | Phase ID                                   |
| `completed` | int    | Number of tasks completed this session     |
| `blocked`   | int    | Number of tasks blocked by guards or hooks |
| `dry_run`   | 0/1    | Whether this was a dry-run session         |

**Example**:
```
EVENT:SESSION_END timestamp=2026-04-10T15:00:00Z run_id=abc123 milestone=M004 phase=P03 completed=4 blocked=1 dry_run=0
```

---

### PHASE_START

Marks the beginning of phase processing.

**Emitted by**: `scripts/engine/run.sh`, `scripts/lifecycle/phase-transition.sh`

**When**: After session start and crash-recovery detection, before the task loop begins. Also emitted by `phase-transition.sh` when transitioning into a phase.

**Fields**:

| Field           | Type   | Description                             |
|-----------------|--------|-----------------------------------------|
| `milestone`     | string | Milestone ID                            |
| `phase`         | string | Phase ID                                |
| `pending_tasks` | int    | Count of pending tasks (engine context) |
| `stage`         | string | `transition` when emitted by phase-transition.sh |

**Example**:
```
EVENT:PHASE_START timestamp=2026-04-10T14:00:05Z run_id=abc123 milestone=M004 phase=P03 pending_tasks=5
```

---

### PHASE_COMPLETE

Marks successful completion of all tasks in a phase.

**Emitted by**: `scripts/engine/run.sh`, `scripts/lifecycle/phase-transition.sh`

**When**: After the task loop finishes and PRE_ADVANCE hooks pass. Emitted before the checkpoint is cleared.

**Fields**:

| Field        | Type   | Description                                |
|--------------|--------|--------------------------------------------|
| `milestone`  | string | Milestone ID                               |
| `phase`      | string | Phase ID                                   |
| `completed`  | int    | Number of tasks completed                  |
| `blocked`    | int    | Number of tasks blocked                    |
| `task_count` | int    | Total task count (phase-transition context) |
| `stage`      | string | `transition` when emitted by phase-transition.sh |

**Example**:
```
EVENT:PHASE_COMPLETE timestamp=2026-04-10T15:00:00Z run_id=abc123 milestone=M004 phase=P03 completed=5 blocked=0
```

---

### TASK_START

Marks the beginning of processing for a single task.

**Emitted by**: `scripts/engine/run.sh`

**When**: At the top of the task loop, before PRE_DISPATCH hooks run.

**Fields**:

| Field       | Type   | Description            |
|-------------|--------|------------------------|
| `task`      | string | Task ID (e.g., `T02`)  |
| `milestone` | string | Milestone ID           |
| `phase`     | string | Phase ID               |

**Example**:
```
EVENT:TASK_START timestamp=2026-04-10T14:01:00Z run_id=abc123 task=T02 milestone=M004 phase=P03
```

---

### TASK_COMPLETE

Marks the end of processing for a single task.

**Emitted by**: `scripts/engine/run.sh`, `scripts/lifecycle/record-result.sh`, `scripts/telemetry/record-telemetry.sh`, `scripts/telemetry/aggregate-metrics.sh`

**When**: After verification and result recording, or immediately when a guard/hook blocks the task. Also emitted by telemetry and record scripts to signal their own completion.

**Fields** (engine context):

| Field              | Type   | Description                                               |
|--------------------|--------|-----------------------------------------------------------|
| `task`             | string | Task ID                                                   |
| `outcome`          | string | `success`, `failure`, `blocked`, or `failed`              |
| `reason`           | string | Block reason when outcome is `blocked` (e.g., `budget`, `payload_sanity`, `hook_pre_dispatch`) |
| `model`            | string | Model used for dispatch (on success/failure)              |
| `verify`           | string | Verification result: `pass`, `fail`, `skipped`           |
| `tokens_estimated` | int    | Estimated token count of the compressed payload           |

**Fields** (telemetry/record context):

| Field   | Type   | Description                                    |
|---------|--------|------------------------------------------------|
| `stage` | string | Script stage (e.g., `record_result`, `record_telemetry`, `aggregate_metrics`) |
| `unit`  | string | Unit path (e.g., `M004/P03/T02`)               |

**Example**:
```
EVENT:TASK_COMPLETE timestamp=2026-04-10T14:05:00Z run_id=abc123 task=T02 outcome=success model=claude-sonnet-4-6 verify=pass tokens_estimated=12500
EVENT:TASK_COMPLETE timestamp=2026-04-10T14:05:01Z run_id=abc123 task=T02 outcome=blocked reason=payload_sanity
```

---

### DISPATCH_START

Marks the beginning of a dispatch operation (context build, model selection, or agent invocation).

**Emitted by**: `scripts/engine/run.sh`, `scripts/dispatch/build-context.sh`, `scripts/dispatch/compress-payload.sh`, `scripts/dispatch/classify-complexity.sh`, `scripts/dispatch/select-model.sh`

**When**: After pre-dispatch guards pass, before the agent call. Also emitted by individual dispatch pipeline scripts to mark their own stages.

**Fields** (engine context):

| Field              | Type   | Description                                |
|--------------------|--------|--------------------------------------------|
| `task`             | string | Task ID                                    |
| `model`            | string | Selected model identifier                  |
| `tokens_estimated` | int    | Estimated token count of payload           |
| `payload_bytes`    | int    | Raw byte size of compressed payload        |
| `dry_run`          | 0/1    | Present (set to `1`) only in dry-run mode  |

**Fields** (pipeline stage context):

| Field       | Type   | Description                                     |
|-------------|--------|-------------------------------------------------|
| `stage`     | string | Pipeline stage: `build_context`, `compress`, `classify_complexity`, `select_model`, `recipe_resolved` |
| `milestone` | string | Milestone ID (build-context)                    |
| `phase`     | string | Phase ID (build-context)                        |
| `task`      | string | Task ID (build-context)                         |
| `budget`    | int    | Token budget (compress)                         |
| `task_plan` | string | Plan filename (classify-complexity)             |
| `tier`      | string | Complexity tier (select-model)                  |
| `mode`      | string | Selection mode (select-model)                   |
| `recipe`    | string | Resolved recipe path (build-context)            |

**Example**:
```
EVENT:DISPATCH_START timestamp=2026-04-10T14:03:00Z run_id=abc123 task=T02 model=claude-sonnet-4-6 tokens_estimated=12500 payload_bytes=50000
EVENT:DISPATCH_START timestamp=2026-04-10T14:02:50Z run_id=abc123 stage=build_context milestone=M004 phase=P03 task=T02
```

---

### DISPATCH_FALLBACK

Signals a model fallback in the dispatch chain.

**Emitted by**: `scripts/dispatch/select-model.sh`

**When**: When the current model is not suitable and the system falls back to the next model in the routing chain, or when the chain is exhausted.

**Fields**:

| Field       | Type   | Description                                      |
|-------------|--------|--------------------------------------------------|
| `tier`      | string | Complexity tier being routed                     |
| `from`      | string | Current model being replaced                     |
| `to`        | string | Next model in the chain (empty if exhausted)     |
| `exhausted` | 0/1    | `1` if no more models available in the chain     |

**Example**:
```
EVENT:DISPATCH_FALLBACK timestamp=2026-04-10T14:03:05Z run_id=abc123 tier=standard from=claude-sonnet-4-6 to=claude-haiku-4 exhausted=0
EVENT:DISPATCH_FALLBACK timestamp=2026-04-10T14:03:05Z run_id=abc123 tier=heavy from=claude-haiku-4 to="" exhausted=1
```

---

### VERIFY_START

Marks the beginning of a verification stage.

**Emitted by**: `scripts/engine/run.sh`, `scripts/verify/check-must-haves.sh`, `scripts/diagnostics/check-recipe.sh`

**When**: Before `check-must-haves.sh` runs against the phase directory.

**Fields**:

| Field   | Type   | Description                                           |
|---------|--------|-------------------------------------------------------|
| `task`  | string | Task ID being verified (engine context)               |
| `phase` | string | Phase ID (engine context)                             |
| `stage` | string | `check_must_haves` (verify script context)            |
| `plan`  | string | Plan filename (verify script context)                 |
| `check` | string | Check name, e.g. `recipe` (diagnostics context)      |

**Example**:
```
EVENT:VERIFY_START timestamp=2026-04-10T14:04:00Z run_id=abc123 task=T02 phase=P03
EVENT:VERIFY_START timestamp=2026-04-10T14:04:00Z run_id=abc123 stage=check_must_haves plan=T02-PLAN.md
```

---

### VERIFY_COMPLETE

Marks the end of a verification stage.

**Emitted by**: `scripts/engine/run.sh`, `scripts/verify/check-must-haves.sh`, `scripts/diagnostics/check-recipe.sh`

**When**: After verification finishes, with the result.

**Fields**:

| Field      | Type   | Description                                        |
|------------|--------|----------------------------------------------------|
| `task`     | string | Task ID (engine context)                           |
| `result`   | string | `pass`, `fail`, or `skipped` (engine context)      |
| `stage`    | string | `check_must_haves` (verify script context)         |
| `failures` | int    | Count of must-have failures (verify script context)|
| `check`    | string | Check name (diagnostics context)                   |
| `status`   | string | `ok` or `warn` (diagnostics context)               |
| `sections` | int    | Total sections checked (diagnostics context)       |
| `invalid`  | int    | Invalid section count (diagnostics context)        |
| `detail`   | string | Human-readable detail (diagnostics context)        |

**Example**:
```
EVENT:VERIFY_COMPLETE timestamp=2026-04-10T14:04:30Z run_id=abc123 task=T02 result=pass
EVENT:VERIFY_COMPLETE timestamp=2026-04-10T14:04:30Z run_id=abc123 stage=check_must_haves failures=0
```

---

### GUARD_BLOCKED

A safety guard has blocked execution.

**Emitted by**: `scripts/lib/guards.sh` (via `_guard_block`)

**When**: A guard check fails and `ORCH_FORCE` is NOT set. The calling pipeline stage should stop processing the current unit.

**Fields**:

| Field    | Type   | Description                                             |
|----------|--------|---------------------------------------------------------|
| `guard`  | string | Guard name: `payload_sanity`, `output_sanity`, `budget`, `phase_complete` |
| `reason` | string | Human-readable explanation of the block                 |

**Example**:
```
EVENT:GUARD_BLOCKED timestamp=2026-04-10T14:02:00Z run_id=abc123 guard=payload_sanity reason="payload too small: 42 < 100 chars"
EVENT:GUARD_BLOCKED timestamp=2026-04-10T14:02:00Z run_id=abc123 guard=budget reason="cost 550 exceeds cap 500 (cents)"
```

---

### GUARD_WARNING

A safety guard would have blocked, but `ORCH_FORCE` is set so execution continues.

**Emitted by**: `scripts/lib/guards.sh` (via `_guard_block` when forced)

**When**: A guard check fails but `ORCH_FORCE=1` downgrades the block to a warning. The pipeline continues past the guard.

**Fields**:

| Field    | Type   | Description                                        |
|----------|--------|----------------------------------------------------|
| `guard`  | string | Guard name (same values as GUARD_BLOCKED)          |
| `reason` | string | Human-readable explanation                         |
| `forced` | 1      | Always `1` — indicates force-override was applied  |

**Example**:
```
EVENT:GUARD_WARNING timestamp=2026-04-10T14:02:00Z run_id=abc123 guard=payload_sanity reason="payload too small: 42 < 100 chars" forced=1
```

---

### SAFETY_WARNING

A non-blocking warning about unexpected or degraded conditions.

**Emitted by**: Multiple scripts across the engine, guards, hooks, dispatch, and diagnostics subsystems.

**When**: Various situations including: unknown event types emitted, missing files, fallback behavior triggered, dry-run guard skips, recipe parsing failures, snapshot issues, and other degraded-mode operations.

**Fields**:

| Field           | Type   | Description                                              |
|-----------------|--------|----------------------------------------------------------|
| `reason`        | string | Machine-readable reason code (always present). See table below. |
| *(varies)*      |        | Additional context fields depending on the reason code.  |

**Common reason codes**:

| Reason Code                    | Source Script             | Additional Fields                |
|--------------------------------|---------------------------|----------------------------------|
| `unknown_event_type`           | `lib/events.sh`           | `original_type`                  |
| `emit_event_missing_type`      | `lib/events.sh`           | *(none)*                         |
| `phase_dir_missing`            | `engine/run.sh`           | `phase_dir`                      |
| `tasks_dir_missing`            | `engine/run.sh`           | `tasks_dir`                      |
| `select_model_fallback`        | `engine/run.sh`           | `tier`                           |
| `model_selected`               | `engine/run.sh`           | `model`, `budget`                |
| `resume_boundary_reached`      | `engine/run.sh`           | `task`                           |
| `resume_skip`                  | `engine/run.sh`           | `task`                           |
| `build_context_failed`         | `engine/run.sh`           | `task`                           |
| `compress_failed`              | `engine/run.sh`           | `task`                           |
| `dry_run_guard_skipped`        | `engine/run.sh`           | `guard`, `task`                  |
| `dispatch_skipped_dry_run`     | `engine/run.sh`           | `task`                           |
| `dispatch_stub`                | `engine/run.sh`           | `task`                           |
| `verify_skipped_dry_run`       | `engine/run.sh`           | `task`                           |
| `record_result_failed`         | `engine/run.sh`           | `task`                           |
| `hook_post_dispatch_warning`   | `engine/run.sh`           | `task`                           |
| `debug_stop_after_task`        | `engine/run.sh`           | `task`                           |
| `dry_run_phase_incomplete`     | `engine/run.sh`           | `phase_dir`                      |
| `checkpoint_write_missing_args`| `engine/checkpoint.sh`    | `milestone`, `phase`, `task`     |
| `checkpoint_mkdir_failed`      | `engine/checkpoint.sh`    | `path`                           |
| `checkpoint_write_failed`      | `engine/checkpoint.sh`    | `path`                           |
| `checkpoint_mv_failed`         | `engine/checkpoint.sh`    | `path`                           |
| `unknown_lifecycle_point`      | `lib/hooks.sh`            | `lifecycle`                      |
| `recipe_parser_unavailable`    | `lib/hooks.sh`            | `lifecycle`                      |
| `hooks_yaml_missing`           | `lib/hooks.sh`            | `path`                           |
| `hook_script_missing`          | `lib/hooks.sh`            | `hook`, `script`                 |
| `recipe_not_found`             | `dispatch/compress-payload.sh` | `path`                      |
| `recipe_compression_empty`     | `dispatch/compress-payload.sh` | `path`                      |
| `unknown_compression_step_type`| `dispatch/compress-payload.sh` | `original_type`             |
| `handler_failed`               | `dispatch/build-context.sh`    | `section`, `source`         |
| `current_model_not_in_chain`   | `dispatch/select-model.sh`     | `current`, `tier`           |

**Example**:
```
EVENT:SAFETY_WARNING timestamp=2026-04-10T14:01:00Z run_id=abc123 reason=phase_dir_missing phase_dir=".specify/orchestrator/milestones/M004/phases/P99"
EVENT:SAFETY_WARNING timestamp=2026-04-10T14:01:00Z run_id=abc123 reason=dry_run_guard_skipped guard=payload_sanity task=T02
```

---

### HOOK_START

A hook script is about to execute.

**Emitted by**: `scripts/lib/hooks.sh`

**When**: After the frozen state snapshot is created and before the hook script runs under timeout.

**Fields**:

| Field       | Type   | Description                                     |
|-------------|--------|-------------------------------------------------|
| `hook`      | string | Hook key from hooks.yaml                        |
| `lifecycle` | string | Lifecycle point: `PRE_DISPATCH`, `POST_DISPATCH`, `POST_VERIFY`, `PRE_ADVANCE` |
| `script`    | string | Path to the hook script being executed          |

**Example**:
```
EVENT:HOOK_START timestamp=2026-04-10T14:01:30Z run_id=abc123 hook=validate_payload lifecycle=PRE_DISPATCH script=hooks/validate.sh
```

---

### HOOK_COMPLETE

A hook script finished successfully.

**Emitted by**: `scripts/lib/hooks.sh`, `scripts/lifecycle/write-permissions.sh`

**When**: After a hook exits with code 0 (or emits a PASS/NEEDS_REVIEW verdict), and the frozen snapshot was not tampered with.

**Fields**:

| Field       | Type   | Description                                     |
|-------------|--------|-------------------------------------------------|
| `hook`      | string | Hook key                                        |
| `lifecycle` | string | Lifecycle point                                 |
| `exit_code` | int    | Hook process exit code (typically `0`)          |
| `verdict`   | string | Verdict value if the hook used the verdict protocol (`PASS`, `NEEDS_REVIEW`) |
| `reason`    | string | Verdict reason text (if verdict protocol used)  |
| `script`    | string | Script path (write-permissions context)         |
| `mode`      | string | Permission write mode (write-permissions context) |
| `host`      | string | Host identifier (write-permissions context)     |
| `target`    | string | Target path (write-permissions context)         |

**Example**:
```
EVENT:HOOK_COMPLETE timestamp=2026-04-10T14:01:35Z run_id=abc123 hook=validate_payload lifecycle=PRE_DISPATCH exit_code=0
EVENT:HOOK_COMPLETE timestamp=2026-04-10T14:01:35Z run_id=abc123 hook=lint_check lifecycle=POST_VERIFY exit_code=0 verdict=PASS reason="all checks passed"
```

---

### HOOK_BLOCKED

A hook has blocked execution.

**Emitted by**: `scripts/lib/hooks.sh`

**When**: A hook exits with a non-zero code (with `block: true` in hooks.yaml) or emits a `BLOCK` verdict, and `ORCH_FORCE` is NOT set. Also emitted when snapshot creation fails.

**Fields**:

| Field       | Type   | Description                                        |
|-------------|--------|----------------------------------------------------|
| `hook`      | string | Hook key                                           |
| `lifecycle` | string | Lifecycle point (absent for snapshot failures)     |
| `exit_code` | int    | Hook process exit code (absent for verdict blocks) |
| `verdict`   | string | `BLOCK` (if using verdict protocol)                |
| `reason`    | string | Block reason (verdict text or `snapshot_create_failed`) |

**Example**:
```
EVENT:HOOK_BLOCKED timestamp=2026-04-10T14:01:35Z run_id=abc123 hook=security_scan lifecycle=PRE_DISPATCH exit_code=1
EVENT:HOOK_BLOCKED timestamp=2026-04-10T14:01:35Z run_id=abc123 hook=security_scan lifecycle=PRE_DISPATCH verdict=BLOCK reason="CVE detected"
EVENT:HOOK_BLOCKED timestamp=2026-04-10T14:01:35Z run_id=abc123 hook=security_scan reason=snapshot_create_failed
```

---

### HOOK_VIOLATION

A hook tampered with its frozen state snapshot. This event is **never downgradeable** -- it fires unconditionally regardless of `ORCH_FORCE`.

**Emitted by**: `scripts/lib/hooks.sh`

**When**: After a hook finishes, if the chmod-444 snapshot file was modified (mtime changed or write permission restored). This is the strongest safety signal in the hook system.

**Fields**:

| Field    | Type   | Description                                |
|----------|--------|--------------------------------------------|
| `hook`   | string | Hook key that violated isolation           |
| `reason` | string | Always `snapshot_modified`                 |
| `script` | string | Path to the violating hook script          |

**Example**:
```
EVENT:HOOK_VIOLATION timestamp=2026-04-10T14:01:36Z run_id=abc123 hook=rogue_hook reason=snapshot_modified script=hooks/rogue.sh
```

---

### CHECKPOINT_WRITE

A crash-recovery checkpoint was persisted to disk.

**Emitted by**: `scripts/engine/checkpoint.sh`

**When**: After a task boundary, when `checkpoint_write` successfully atomically writes (tmp + mv) the checkpoint JSON file.

**Fields**:

| Field       | Type   | Description                                   |
|-------------|--------|-----------------------------------------------|
| `milestone` | string | Milestone ID                                  |
| `phase`     | string | Phase ID                                      |
| `last_task` | string | Task ID of the most recently completed task   |
| `outcome`   | string | Task outcome: `success` or `failure`          |
| `path`      | string | Filesystem path to the checkpoint JSON file   |

**Example**:
```
EVENT:CHECKPOINT_WRITE timestamp=2026-04-10T14:05:00Z run_id=abc123 milestone=M004 phase=P03 last_task=T02 outcome=success path=.specify/orchestrator/milestones/M004/engine-checkpoint.json
```

---

### CHECKPOINT_RESUME

A prior crash-recovery checkpoint was detected and the engine is resuming.

**Emitted by**: `scripts/engine/run.sh`

**When**: At session startup, if `checkpoint_detect` finds an existing checkpoint for the milestone. The engine will skip tasks up to and including `last_task`.

**Fields**:

| Field       | Type   | Description                                    |
|-------------|--------|-------------------------------------------------|
| `milestone` | string | Milestone ID                                   |
| `phase`     | string | Phase ID                                       |
| `last_task` | string | Task ID from the checkpoint (resume boundary)  |

**Example**:
```
EVENT:CHECKPOINT_RESUME timestamp=2026-04-10T14:00:01Z run_id=def456 milestone=M004 phase=P03 last_task=T02
```

---

## Non-Registry Events

The following event types are emitted by scripts but are **not** in the canonical `ORCH_EVENT_TYPES` registry. When emitted, they trigger a companion `SAFETY_WARNING` with `reason=unknown_event_type` so the drift is observable.

### HOOK_WARNING

Emitted by `scripts/lib/hooks.sh` when a hook fails but the failure is non-blocking (either `block: false` in hooks.yaml, or `ORCH_FORCE` is set).

**Fields**: `hook`, `lifecycle`, `exit_code` or `verdict`/`reason`, optionally `forced=1`.

> Note: `HOOK_WARNING` is functionally used but not yet added to the canonical registry. Each emission produces a companion `SAFETY_WARNING` event.

---

## Cross-References

- **Event emission function**: [`scripts/lib/events.sh`](../scripts/lib/events.sh) -- `emit_event`, `ORCH_EVENT_TYPES`, `orch_is_event_type`
- **Guard events**: [`scripts/lib/guards.sh`](../scripts/lib/guards.sh) -- `GUARD_BLOCKED`, `GUARD_WARNING`
- **Hook events**: [`scripts/lib/hooks.sh`](../scripts/lib/hooks.sh) -- `HOOK_START`, `HOOK_COMPLETE`, `HOOK_BLOCKED`, `HOOK_VIOLATION`
- **Engine lifecycle**: [`scripts/engine/run.sh`](../scripts/engine/run.sh) -- `SESSION_START/END`, `PHASE_START/COMPLETE`, `TASK_START/COMPLETE`
- **Checkpoint events**: [`scripts/engine/checkpoint.sh`](../scripts/engine/checkpoint.sh) -- `CHECKPOINT_WRITE`, `CHECKPOINT_RESUME`
- **Dispatch pipeline**: [`scripts/dispatch/`](../scripts/dispatch/) -- `DISPATCH_START`, `DISPATCH_FALLBACK`
- **Verification**: [`scripts/verify/check-must-haves.sh`](../scripts/verify/check-must-haves.sh) -- `VERIFY_START`, `VERIFY_COMPLETE`
- **Engine reference**: [engine.md](engine.md) -- engine lifecycle stages that emit events
- **Error reference**: [errors.md](errors.md) -- error taxonomy and emit_result protocol (complements events)
- **Hooks reference**: [hooks.md](hooks.md) -- hook lifecycle points and verdict events
- **State machine**: [state-machine.md](state-machine.md) -- lifecycle states that drive event emission
- **File formats**: [file-formats.md](file-formats.md) -- checkpoint JSON format, execution log JSONL format
- **Diagnostics**: [`scripts/diagnostics/check-events.sh`](../scripts/diagnostics/check-events.sh) -- verifies all engine scripts emit at least one event
