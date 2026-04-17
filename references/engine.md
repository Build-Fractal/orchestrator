# Engine Reference

> Progressive disclosure reference for the speckit-orchestrator engine.
> Self-contained — read this document to understand how to invoke the engine,
> what it does at each lifecycle stage, and how crash recovery works without
> reading source code.

> Audience: extenders, contributors

## Overview

The engine (`scripts/engine/run.sh`) is the mechanical pipeline coordinator for the speckit-orchestrator. It accepts a milestone and phase, discovers pending tasks, and runs each task through a 7-stage pipeline: Init, Hook, Build, Compress, Dispatch, Verify, Record. The engine is stateless between sessions — all progress is derived from file presence on disk and from an optional checkpoint file written after each task boundary.

The engine does not make decisions about what to build or how to verify results. It is a sequencer: it assembles payloads, enforces safety guards, dispatches to a model, runs verification, and records outcomes. Higher-level commands (`auto`, `dispatch`, `plan-phase`) invoke the engine or replicate parts of its pipeline; the engine itself is concerned only with the mechanical loop.

All timestamps within a single engine session are frozen at init time. Every event, checkpoint, and log entry shares the same `ORCH_STARTED_AT` value, making post-hoc correlation trivial and ensuring deterministic replay when seeded.

---

## Usage

```
scripts/engine/run.sh [--dry-run] [--force] <milestone> <phase>
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<milestone>` | Yes | Milestone ID (e.g., `M004`). Must correspond to an existing directory under `.orchestrator/milestones/`. |
| `<phase>` | Yes | Phase ID (e.g., `P03`). Must correspond to an existing subdirectory under the milestone's `phases/` directory, containing a `tasks/` directory with one or more `T##-PLAN.md` files. |
| `--dry-run` | No | Execute the full pipeline except actual agent dispatch. Events are emitted and guards run, but no payload is sent to a model. Pre-dispatch guards (`payload_sanity`) and verification are skipped with audit warnings. |
| `--force` | No | Downgrade guard blocks to `GUARD_WARNING` (operator override). Allows the pipeline to continue past payload sanity, budget, output sanity, and phase-complete guards. Hook tampering detection (`HOOK_VIOLATION`) is never overridable, even with `--force`. |
| `-h`, `--help` | No | Print usage and exit. |

### Environment Variables

| Variable | Effect |
|----------|--------|
| `ORCH_RUN_SEED` | When set, produces a deterministic `ORCH_RUN_ID` and `ORCH_STARTED_AT` derived from the seed value via `cksum`. Useful for reproducible test runs. |
| `ORCH_DRY_RUN=1` | Equivalent to `--dry-run`. If both the flag and the variable are set, the flag is redundant — the variable is merged in after argument parsing. |
| `ORCH_FORCE=1` | Equivalent to `--force`. Same merge behavior as `ORCH_DRY_RUN`. |
| `ORCH_ENGINE_STOP_AFTER_TASK` | Debug hook: the engine breaks out of the task loop immediately after completing the named task (e.g., `T03`). Used for simulated-crash testing of the checkpoint/resume path. |

---

## Run Context

Every engine session begins by calling `init_run_context` from `scripts/lib/run-context.sh`. This establishes the following exported variables used by every downstream library:

| Variable | Value |
|----------|-------|
| `ORCH_RUN_ID` | Unique session identifier. Format is `run-<ISO-timestamp>-<8-char-nonce>` in normal mode, or `run-seed-<cksum-hash>` when `ORCH_RUN_SEED` is set. |
| `ORCH_STARTED_AT` | Frozen ISO-8601 UTC timestamp (`YYYY-MM-DDTHH:MM:SSZ`). In seeded mode, derived deterministically from the seed hash; otherwise, captured once at init and never updated. |
| `ORCH_RUN_MILESTONE` | The milestone ID passed to the engine. |
| `ORCH_RUN_PHASE` | The phase ID passed to the engine. |
| `ORCH_FORCE` | `"1"` if `--force` or `ORCH_FORCE=1` was set, empty otherwise. |
| `ORCH_DRY_RUN` | `"1"` if `--dry-run` or `ORCH_DRY_RUN=1` was set, empty otherwise. |

The `orch_now` function always returns `ORCH_STARTED_AT` when it is set, ensuring that all timestamps within a session are identical. This supports Constitution Principle IX (Reproducibility) — no inline `date` calls after the run context is initialized.

When `ORCH_RUN_SEED` is set, the seed is hashed via `cksum` and the resulting integer is used both as the run ID suffix and as an offset from a fixed epoch anchor to compute the frozen timestamp. Two runs with the same seed produce the same run ID and timestamp, enabling deterministic test replay.

---

## Lifecycle Stages

The engine runs each pending task through a 7-stage pipeline. A task is pending when its `T##-PLAN.md` exists in the phase's `tasks/` directory but no sibling `T##-SUMMARY.md` is present.

```
  +----------+   +-----------+   +----------+   +-----------+
  |  1 Init  |-->|  2 Hook   |-->|  3 Build |-->| 4 Compress|
  +----------+   +-----------+   +----------+   +-----------+
                                                      |
  +----------+   +-----------+   +-----------+        |
  | 7 Record |<--| 6 Verify  |<--| 5 Dispatch|<------+
  +----------+   +-----------+   +-----------+
```

### Stage 1 — Init

Performed once per session, before the task loop begins.

1. **Argument parsing** — Reads `--dry-run`, `--force`, `-h`, and positional `<milestone>` `<phase>` arguments. Unknown flags cause an immediate exit with code 2.
2. **Run context** — Calls `init_run_context` to establish `ORCH_RUN_ID`, `ORCH_STARTED_AT`, and the mode flags.
3. **Directory resolution** — Locates the phase directory at `.orchestrator/milestones/<milestone>/phases/<phase>/` and its `tasks/` subdirectory. Missing directories cause exit code 3.
4. **Task discovery** — Scans for `T*-PLAN.md` files without matching `T*-SUMMARY.md` siblings. Pending task IDs are written to a temp file for the loop to consume.
5. **Model selection** — Calls `scripts/dispatch/select-model.sh standard` against `templates/routing.yaml` to resolve the model ID and context budget for the "standard" complexity tier. Falls back to `claude-sonnet-4-6` with a 150,000 token budget if selection fails.
6. **Checkpoint detection** — Checks for a prior checkpoint via `checkpoint_detect`. If found, reads the `last_task` field and emits `CHECKPOINT_RESUME`. Tasks up to and including the checkpoint boundary are skipped during the loop (see Checkpointing and Crash Recovery below).
7. **Session events** — Emits `SESSION_START` and `PHASE_START` events with milestone, phase, pending task count, and mode flags.

### Stage 2 — Hook (PRE_DISPATCH)

Fires the `PRE_DISPATCH` lifecycle hook via `run_hooks` from `scripts/lib/hooks.sh`. The hook receives a frozen, read-only snapshot of the phase directory (via `ORCH_HOOK_SNAPSHOT`, set to `chmod 444`). Hooks are killed after the configured timeout (default 30 seconds).

- If the hook returns non-zero, the task is skipped with outcome `blocked` and reason `hook_pre_dispatch`. The engine increments the blocked counter and moves to the next task.
- If the hook modifies the snapshot, a `HOOK_VIOLATION` event is emitted. This violation is unconditional — `--force` does not suppress it.

### Stage 3 — Build

Assembles the dispatch payload by calling `scripts/dispatch/build-context.sh` with the orchestrator root, milestone, phase, and task IDs. The build script reads a context recipe (`templates/context-recipe.yaml` or an override) and dispatches each section to a handler. The output is a structured markdown document with YAML frontmatter, a manifest table (section names, line ranges, token estimates, priorities), and section bodies ordered for cache efficiency.

If context building fails, the task is marked as failed with reason `build_context`, the blocked counter increments, and the engine continues to the next task.

### Stage 4 — Compress

Calls `scripts/dispatch/compress-payload.sh` with the model's context budget and the built payload. Compression applies graduated steps — dropping optional sections, summarizing subsections, and removing low-confidence knowledge entries — until the token count fits within the budget. The task plan section is never truncated.

After compression, the payload file is swapped: the original build output is removed and the compressed file takes its place. The engine computes the final payload size in bytes and an estimated token count (bytes / 4) for downstream events.

If compression fails, the task is marked as failed with reason `compress`.

### Stage 5 — Dispatch

This stage runs safety guards and then dispatches the payload to a model.

1. **Payload sanity guard** — `guard_payload_sanity` checks that the payload file exists and meets the minimum character threshold (default 100 characters, configurable via `ORCH_GUARD_MIN_PAYLOAD_CHARS`). In dry-run mode, this guard is skipped with a `SAFETY_WARNING` audit marker. With `--force`, a block is downgraded to `GUARD_WARNING`.
2. **Budget guard** — `guard_budget` checks cumulative cost and duration against configured caps. Caps of 0 disable enforcement (default). Runs in both dry-run and real mode.
3. **DISPATCH_START event** — Emits the model name, estimated token count, payload byte size, and dry-run flag.
4. **Dispatch execution** — In dry-run mode, writes a stub line to the output file. In real mode, writes a stub placeholder (actual agent invocation is deferred to a future milestone). Both paths produce a non-empty output file for the verification stage.

If either guard blocks, the task is skipped with outcome `blocked` and the relevant reason (`payload_sanity` or `budget`).

### Stage 6 — Verify

Verifies that the dispatch produced valid output and that the phase's must-have criteria are met.

1. **Output sanity guard** — `guard_output_sanity` checks that the output file is non-empty and meets the minimum character threshold (default 100 characters, configurable via `ORCH_GUARD_MIN_OUTPUT_CHARS`). Skipped in dry-run mode with an audit marker.
2. **Must-have verification** — Calls `scripts/verify/check-must-haves.sh` against the phase directory. This is a 3-category static check: Truths (grep patterns), Artifacts (file existence with optional constraints), and Key Links (cross-file references). In dry-run mode, verification is skipped because the phase summary does not exist yet.
3. **VERIFY_COMPLETE event** — Emits the verification result (`pass`, `fail`, or `skipped`).
4. **POST_VERIFY hooks** — Fires `POST_VERIFY` lifecycle hooks. If a hook blocks, the task is skipped with outcome `blocked` and reason `hook_post_verify`.

### Stage 7 — Record

Records the task outcome and writes a checkpoint for crash recovery.

1. **Execution log** — Appends a structured JSON line to `.orchestrator/milestones/<milestone>/execution-log.jsonl` via `scripts/lifecycle/record-result.sh`. The entry includes milestone, phase, task, outcome (success or failure based on verification), verification result, model, payload bytes, dispatch method (`engine`), and run ID.
2. **POST_DISPATCH hooks** — Fires `POST_DISPATCH` lifecycle hooks. Unlike `PRE_DISPATCH`, failure here is non-blocking — a `SAFETY_WARNING` is emitted but the task is not marked as blocked.
3. **Checkpoint write** — Calls `checkpoint_write` with the milestone, phase, task ID, and outcome. This creates the crash-recovery anchor for this task boundary.
4. **TASK_COMPLETE event** — Emits the final task outcome with model name, verification result, and estimated token count.

After the task loop completes, the engine runs a post-loop sequence:

1. **PRE_ADVANCE hooks** — Last chance for hooks to gate the phase transition. If blocked, the engine exits with code 6.
2. **Phase-complete guard** — `guard_phase_complete` checks that all tasks have summaries. In dry-run mode, a failure is downgraded to a warning. In real mode with `--force`, the block becomes a warning. Otherwise, the engine exits with code 5.
3. **PHASE_COMPLETE event** — Emits completed and blocked task counts.
4. **Checkpoint clear** — If no tasks were blocked, the checkpoint file is removed.
5. **SESSION_END event** — Emits final session summary.

---

## Dry-Run Mode

Dry-run mode (`--dry-run` or `ORCH_DRY_RUN=1`) executes the full pipeline skeleton without performing real dispatch or verification. Its purpose is to validate the pipeline wiring, guard configuration, and event emission without consuming model tokens.

In dry-run mode:

- **Events are emitted normally.** `SESSION_START`, `PHASE_START`, `TASK_START`, `DISPATCH_START`, and all other lifecycle events fire with their full payloads. The `DISPATCH_START` event includes `dry_run=1`.
- **Context build and compress run normally.** The payload is assembled and compressed as in a real run, exercising the recipe and section handlers.
- **Pre-dispatch guards are skipped.** `guard_payload_sanity` is bypassed with a `SAFETY_WARNING reason=dry_run_guard_skipped guard=payload_sanity` audit marker. The budget guard still runs (it is always enabled).
- **Dispatch writes a stub.** The output file contains `dry-run: <milestone> <phase> <task_id>` instead of agent output.
- **Output sanity is skipped.** `guard_output_sanity` is bypassed with an audit marker.
- **Must-have verification is skipped.** Because no real output is produced, `check-must-haves.sh` is not invoked. The verification result is `skipped`.
- **Phase-complete guard downgrades.** A failure is treated as a warning rather than an exit, since summaries will not exist.

Dry-run mode is designed for pipeline validation, hook testing, and observability instrumentation without side effects on the project's state files.

---

## Checkpointing and Crash Recovery

The engine writes a checkpoint file after each completed task so that a crashed or interrupted session can resume without re-executing already-completed work.

### Checkpoint File

Checkpoints are stored at `.orchestrator/milestones/<milestone>/engine-checkpoint.json`. The file is a JSON object with 6 fields:

```json
{
  "run_id": "run-2026-04-13T10:00:00Z-abc12345",
  "milestone": "M004",
  "phase": "P03",
  "last_task": "T02",
  "outcome": "success",
  "timestamp": "2026-04-13T10:00:00Z"
}
```

Writes are atomic: a temp file is built and then moved into place via `mv`, so a crash during write leaves either the old checkpoint or the new one — never a partial file.

### Checkpoint Functions

The checkpoint library (`scripts/engine/checkpoint.sh`) provides 5 functions:

| Function | Purpose |
|----------|---------|
| `checkpoint_path <milestone>` | Returns the path to the checkpoint file. |
| `checkpoint_write <milestone> <phase> <task> <outcome>` | Atomically writes a new checkpoint. Emits `CHECKPOINT_WRITE`. |
| `checkpoint_read <milestone> <field>` | Reads a single field from the checkpoint (one of: `run_id`, `milestone`, `phase`, `last_task`, `outcome`, `timestamp`). Returns 1 if the checkpoint or field is missing. |
| `checkpoint_detect <milestone>` | Returns 0 if a non-empty checkpoint file exists, 1 otherwise. |
| `checkpoint_clear <milestone>` | Removes the checkpoint file. Called on successful phase completion when no tasks were blocked. |

### Resume Behavior

When the engine starts and detects a prior checkpoint via `checkpoint_detect`:

1. It reads the `last_task` field from the checkpoint.
2. It emits a `CHECKPOINT_RESUME` event with the milestone, phase, and last completed task.
3. During the task loop, it skips every task up to and including the `last_task` boundary. Each skipped task emits `SAFETY_WARNING reason=resume_skip`.
4. When the boundary task is reached, it emits `SAFETY_WARNING reason=resume_boundary_reached` and clears the skip flag. All subsequent tasks execute normally.

This design means the engine never re-dispatches a task that already completed before the crash. The cost is that the boundary task itself is skipped on resume — it was the last task that completed successfully, so it does not need to run again.

### Debug Stop-After Hook

The `ORCH_ENGINE_STOP_AFTER_TASK` environment variable simulates a crash for testing. When set to a task ID (e.g., `T02`), the engine breaks out of the task loop after completing that task, writing a checkpoint but not completing the phase. A subsequent engine invocation for the same milestone and phase will detect the checkpoint and resume from the next task.

---

## Exit Codes

| Code | Meaning | Error Kind |
|------|---------|------------|
| 0 | Phase completed successfully. All tasks dispatched, verified, and recorded. | — |
| 2 | Configuration error: unknown flag, missing required positional arguments. | `CONFIG` |
| 3 | State error: phase directory or tasks directory not found. | `STATE` |
| 4 | Phase ended with one or more blocked tasks. At least one task was skipped due to a guard block, hook block, or build/compress failure. | `STATE` |
| 5 | Phase-complete guard blocked the advance. Not all tasks have summaries and `--force` was not set. | `VERIFY` |
| 6 | `PRE_ADVANCE` hook blocked phase completion. A lifecycle hook vetoed the transition. | `STATE` |

Every non-zero exit is preceded by an `emit_result error` call with the corresponding error kind, making the failure reason available in structured output.

---

## Agent-Facing Marker Convention

The anti-pattern linter (`scripts/verify/anti-pattern-lint.sh`) enforces shape
rules against markdown files a subagent may read as authoritative. By default
it scans:

- `commands/**/*.md`
- `templates/**/*.md`
- `scripts/dispatch/lib/**/*.sh`
- `.orchestrator/milestones/**/tasks/*-PAYLOAD.md`

Files under `specs/`, `references/`, and `docs/` are **excluded by default** —
they often contain illustrative bash for human readers that would trip the
shape heuristics without cause.

To opt a specific file under `specs/`, `references/`, or `docs/` into linter
scanning, place the literal HTML comment marker anywhere before the first
fenced code block:

```
<!-- agent-facing -->
```

Once the marker is present, the linter sweeps that file on every run. Without
the marker, the linter skips it even if other files in the same directory are
opted in.

### When to add the marker

Add the marker to a specs/references/docs file when:

- The file contains a canonical bash recipe that a subagent is expected to
  copy verbatim into a Bash tool call (e.g., a migration guide with exact
  commands).
- The file is referenced from a dispatch payload or task plan as
  "follow the steps in `docs/<file>.md`".

Leave the marker off when the file is human-facing documentation, conceptual
prose, or contains bash only to illustrate what *not* to do.

### Example

````markdown
# My Runbook

<!-- agent-facing -->

Run these steps in order:

```bash
bash scripts/verify/run-suite.sh m999 P01
```
````

With the marker, the fenced bash above is subject to the same Class A +
Class B detectors that guard `commands/` and `templates/`. Without it, the
same file is invisible to the linter.

See `ANTIPATTERNS.md#AP-004` (Class A) and `AP-005` through `AP-009` (Class B)
for the full pattern catalog and remediation wrappers.

---

## Cross-References

- [Architecture](architecture.md) — System architecture overview including the engine pipeline in broader context
- [Events](events.md) — Complete event type registry for all lifecycle events emitted by the engine
- [Errors](errors.md) — Error taxonomy, emit_result protocol, and RESULT line format
- [Hooks](hooks.md) — Hook lifecycle points, verdict protocol, and snapshot isolation
- [State Machine](state-machine.md) — 10-state lifecycle and file-presence derivation rules
- [Verification Ladder](verification-ladder.md) — 4-tier verification protocol used by Stage 6
- [File Formats](file-formats.md) — Format contracts for execution logs, checkpoints, and other state files
- [Tier Definitions](tier-definitions.md) — Tier A/B/C classification and model routing
- [Provider Convention](provider-convention.md) — Agent provider integration protocol for Stage 5 dispatch
