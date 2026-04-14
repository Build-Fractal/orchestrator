# Hooks Reference

> Progressive disclosure reference for the speckit-orchestrator hook lifecycle system.
> Self-contained — read this document to understand hook lifecycle points, the
> verdict protocol, snapshot isolation, and how to write custom hooks without
> reading source code.

> Audience: extenders, contributors

## Overview

The orchestrator engine fires **hooks** at four lifecycle points during task dispatch. Hooks are external scripts that observe engine state, enforce gates, or emit structured verdicts — without modifying engine state.

Key guarantees:

- **Isolation**: every hook receives a read-only frozen snapshot of the phase directory (`chmod 444`). If a hook modifies the snapshot, the engine emits a `HOOK_VIOLATION` event and the hook is treated as failed. This violation is never downgraded, even under `ORCH_FORCE`.
- **Timeout**: hooks are killed after a configurable timeout (default 30 seconds). A watchdog process sends `SIGTERM`, waits 1 second, then sends `SIGKILL`.
- **Graceful degradation**: if the recipe parser or hooks.yaml file is missing, the engine emits a `SAFETY_WARNING` and continues without running hooks. No hook failure ever silently passes.

Hooks are configured in a `hooks.yaml` file and registered under one of the four lifecycle points. The engine calls `run_hooks` at each point, iterating over all enabled hooks in declaration order.

---

## Lifecycle Points

The engine fires hooks at four points in the task dispatch pipeline. Each point has different data availability and different blocking behavior.

### PRE_DISPATCH

**When it fires**: After context assembly completes, before the agent dispatch begins. Fires once per task, including during dry-run sessions.

**State source**: The phase directory (`$PHASE_DIR`). The frozen snapshot contains the full phase directory tree at the moment context assembly finishes.

**Blocking behavior**: If any PRE_DISPATCH hook returns non-zero (or emits `VERDICT:BLOCK`), the task is skipped. The engine increments the blocked counter, emits `TASK_COMPLETE` with `outcome="blocked" reason="hook_pre_dispatch"`, and moves to the next task. The phase continues.

**Use cases**: payload validation, budget pre-checks, external approval gates.

### POST_DISPATCH

**When it fires**: After the agent returns output and the result has been recorded to the execution log. Despite the name, it fires *after* `record-result.sh` so that hooks can observe the final recorded outcome.

**State source**: The phase directory, which now includes the recorded result.

**Blocking behavior**: POST_DISPATCH is **non-blocking**. If a hook fails, the engine emits `SAFETY_WARNING reason="hook_post_dispatch_warning"` but does not block the task or the phase. The task continues to checkpoint and completion.

**Use cases**: output quality reporting, notification triggers, telemetry collection.

### POST_VERIFY

**When it fires**: After the verification stage (`check-must-haves.sh`) completes, before the result is recorded.

**State source**: The phase directory. The verification result is available in the engine's internal state but not yet written to the execution log.

**Blocking behavior**: If any POST_VERIFY hook returns non-zero (or emits `VERDICT:BLOCK`), the task is blocked. The engine increments the blocked counter, emits `TASK_COMPLETE` with `outcome="blocked" reason="hook_post_verify"`, and moves to the next task.

**Use cases**: phase completeness checks, summary quality gates, cross-task consistency validation.

### PRE_ADVANCE

**When it fires**: After all tasks in a phase have been processed, before the engine advances the phase/task state. This is the last opportunity to prevent a phase transition.

**State source**: The phase directory with all task results recorded.

**Blocking behavior**: If any PRE_ADVANCE hook fails, the engine calls `emit_result error STATE "PRE_ADVANCE hook blocked phase completion"` and exits with code 6. This is a **hard stop** — the engine does not continue to phase advancement. The checkpoint from the last completed task is preserved on disk, enabling crash recovery on the next run.

**Use cases**: final budget enforcement, knowledge consolidation triggers, external approval gates for phase transitions.

---

## Hooks Configuration (hooks.yaml)

Hooks are declared in a YAML file with a fixed two-level structure. The default configuration lives at `templates/hooks.yaml`. Override it by placing a `hooks.yaml` in a milestone or phase directory, or by setting the `ORCH_HOOKS_YAML_DEFAULT` environment variable.

### Format

```yaml
# Global defaults applied to all hooks unless overridden per-hook.
hook_defaults:
  timeout: 30
  block_on_fail: true

# One top-level key per lifecycle point.
PRE_DISPATCH:
  hook_key:
    name: Human-Readable Name
    script: path/to/script.sh
    enabled: true
    block_on_fail: true
    description: What this hook checks
```

### Fields

| Field | Scope | Required | Default | Description |
|-------|-------|----------|---------|-------------|
| `hook_defaults.timeout` | global | no | `30` | Seconds before a hook is killed |
| `hook_defaults.block_on_fail` | global | no | `true` | Whether a non-zero exit blocks the pipeline |
| `name` | per-hook | yes | — | Human-readable label for events and logs |
| `script` | per-hook | yes | — | Path to the hook script (relative to repo root) |
| `enabled` | per-hook | no | `true` | Set to `false`, `FALSE`, `0`, or `no` to skip |
| `block_on_fail` | per-hook | no | inherits global | Overrides the global default for this hook |
| `description` | per-hook | no | — | Documents the hook's purpose |

### Resolution Order

The engine resolves hooks.yaml in this order:

1. Explicit path passed as the third argument to `run_hooks`
2. `ORCH_HOOKS_YAML_DEFAULT` environment variable
3. `templates/hooks.yaml` (built-in default)

Only one hooks.yaml file is used per invocation — there is no merging across levels.

### Parsing

The hooks.yaml is parsed by `scripts/lib/recipe-parser.sh` using grep/sed/awk only (no jq required, per NFR-202). The parser outputs one pipe-delimited line per hook:

```
hook_key|name|script|enabled|block_on_fail|description
```

---

## Frozen Snapshot

Every hook invocation receives a **frozen snapshot** of the state source (typically the phase directory). The snapshot enforces Principle XII (Hook Isolation): hooks can read engine state but cannot modify it.

### How It Is Built

1. The engine calls `_hooks_snapshot_create` with the state source path.
2. If the source is a **file**, it is copied to a temporary file.
3. If the source is a **directory**, it is packed into a tar archive in a temporary file.
4. If the source **does not exist**, the snapshot contains the literal string `no-state`.
5. The temporary file is set to `chmod 444` (read-only for all, writable by none).

### How Hooks Access It

The snapshot path is exported as the `ORCH_HOOK_SNAPSHOT` environment variable before the hook script executes. Hooks read this variable to locate the snapshot.

```bash
# Inside a hook script:
snapshot="$ORCH_HOOK_SNAPSHOT"
# For a directory source, the snapshot is a tar archive:
tar -tf "$snapshot"    # list contents
tar -xf "$snapshot" -C /tmp/inspect  # extract for inspection
```

### Integrity Check

After the hook completes, the engine verifies the snapshot was not modified:

1. The modification timestamp (`mtime`) is compared against the value captured before hook execution.
2. The file is checked for write permission — if it is writable, the check fails.

If either check fails, the engine emits a `HOOK_VIOLATION` event with `reason="snapshot_modified"`. This violation is **never downgraded**, even when `ORCH_FORCE` is set. The hook is treated as failed and the overall `run_hooks` call returns non-zero.

---

## Verdict Protocol

Hooks communicate structured outcomes to the engine via **verdict lines** printed to stdout. The verdict protocol is defined in `scripts/lib/verdicts.sh`.

### Verdict Line Format

```
VERDICT:<verdict> reason=<reason>
```

The reason value may be quoted or unquoted:

```
VERDICT:PASS reason=ok
VERDICT:BLOCK reason="budget exceeded by 150 cents"
```

If a hook emits multiple `VERDICT:` lines, the engine uses the **most severe** verdict (BLOCK > NEEDS_REVIEW > WARN > PASS).

### PASS

**Severity**: 0 (lowest)

**Meaning**: The hook's checks succeeded. No action required.

**Engine behavior**: Emits `HOOK_COMPLETE` event with the verdict and reason. The pipeline continues.

**Example output**:
```
VERDICT:PASS reason="all payload checks passed"
```

### WARN

**Severity**: 1

**Meaning**: The hook detected a non-critical issue. The pipeline should continue, but the issue is logged for visibility.

**Engine behavior**: Emits `HOOK_WARNING` event with the verdict and reason. The pipeline continues regardless of the `block_on_fail` setting — WARN verdicts never block.

**Example output**:
```
VERDICT:WARN reason="payload is under 500 chars, may lack context"
```

### NEEDS_REVIEW

**Severity**: 2

**Meaning**: The hook detected something that warrants human attention but does not require blocking. Typically used for quality signals that should be reviewed after the run completes.

**Engine behavior**: Emits `HOOK_COMPLETE` event with the verdict and reason. The pipeline continues.

**Example output**:
```
VERDICT:NEEDS_REVIEW reason="summary section missing expected headings"
```

### BLOCK

**Severity**: 3 (highest)

**Meaning**: The hook detected a critical issue. The pipeline must not continue past this point.

**Engine behavior**: If `ORCH_FORCE` is set, the block is downgraded to a `HOOK_WARNING` with `forced=1` and the pipeline continues. Otherwise, emits `HOOK_BLOCKED` event and the `run_hooks` call returns non-zero, triggering the lifecycle point's blocking behavior.

**Example output**:
```
VERDICT:BLOCK reason="cumulative cost exceeds budget ceiling"
```

### No Verdict Lines

If a hook does not print any `VERDICT:` lines, the engine falls back to the exit code:

- Exit 0: treated as success (equivalent to PASS).
- Non-zero exit with `block_on_fail: true`: treated as a blocking failure.
- Non-zero exit with `block_on_fail: false`: emits `HOOK_WARNING`, pipeline continues.

---

## Timeout Behavior

Every hook execution is wrapped in a timeout watchdog to prevent runaway scripts from stalling the engine.

### Default Timeout

The default timeout is **30 seconds**, set by the `ORCH_HOOK_TIMEOUT_SEC` environment variable. The global default can also be configured via the `hook_defaults.timeout` field in hooks.yaml.

### Per-Hook Override

Set `ORCH_HOOK_TIMEOUT_SEC` before calling `run_hooks` to change the timeout for all hooks in that invocation. Per-hook timeout fields in hooks.yaml are parsed but the current implementation uses the global value.

### What Happens on Timeout

1. After `$ORCH_HOOK_TIMEOUT_SEC` seconds, the watchdog sends `SIGTERM` to the hook process.
2. After 1 additional second, if the hook is still running, the watchdog sends `SIGKILL`.
3. The hook's exit code will be non-zero (reflecting the signal termination).
4. The engine processes the non-zero exit code through the normal `block_on_fail` logic.
5. The frozen snapshot integrity check still runs — a timed-out hook that managed to modify the snapshot will trigger a `HOOK_VIOLATION`.

---

## Writing a Custom Hook

This walkthrough creates a hook that blocks dispatch if the task payload exceeds a maximum token estimate.

### Step 1: Create the Hook Script

Create a new file at `scripts/verify/guards/check-token-limit.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/guards/check-token-limit.sh
# Block dispatch if estimated tokens exceed a threshold.

set -euo pipefail

MAX_TOKENS="${ORCH_MAX_TOKENS:-50000}"
SNAPSHOT="$ORCH_HOOK_SNAPSHOT"

# Read the snapshot (phase directory tar archive)
tmp_dir="$(mktemp -d)"
tar -xf "$SNAPSHOT" -C "$tmp_dir" 2>/dev/null || true

# Find the most recent payload file
payload="$(find "$tmp_dir" -name '*-PAYLOAD.md' -type f | head -1)"
if [ -z "$payload" ]; then
  printf 'VERDICT:PASS reason="no payload found, skipping token check"\n'
  rm -rf "$tmp_dir"
  exit 0
fi

byte_count="$(wc -c < "$payload" | tr -d ' ')"
token_est=$(( byte_count / 4 ))

rm -rf "$tmp_dir"

if [ "$token_est" -gt "$MAX_TOKENS" ]; then
  printf 'VERDICT:BLOCK reason="estimated %d tokens exceeds limit of %d"\n' \
    "$token_est" "$MAX_TOKENS"
  exit 0
fi

printf 'VERDICT:PASS reason="estimated %d tokens within limit"\n' "$token_est"
exit 0
```

Make it executable:

```bash
chmod +x scripts/verify/guards/check-token-limit.sh
```

### Step 2: Register in hooks.yaml

Add the hook under the appropriate lifecycle point in `templates/hooks.yaml` (or a milestone/phase-level override):

```yaml
PRE_DISPATCH:
  token_limit:
    name: Token Limit Check
    script: scripts/verify/guards/check-token-limit.sh
    enabled: true
    block_on_fail: true
    description: Block dispatch if estimated tokens exceed ORCH_MAX_TOKENS
```

### Step 3: Test the Hook

Run the engine in dry-run mode to verify the hook fires:

```bash
ORCH_DRY_RUN=1 bash scripts/engine/run.sh M001 P01
```

Look for `HOOK_START hook="token_limit"` and `HOOK_COMPLETE` (or `HOOK_BLOCKED`) events in the output. Verify:

1. The hook receives the snapshot via `$ORCH_HOOK_SNAPSHOT`.
2. The verdict line appears in stdout and is parsed correctly.
3. The snapshot is not modified (no `HOOK_VIOLATION` event).
4. If the hook exceeds 30 seconds, it is killed and the timeout is logged.

### Key Rules for Hook Authors

- **Never modify `$ORCH_HOOK_SNAPSHOT`**. The engine checks for modifications and will emit a `HOOK_VIOLATION` that is never downgraded.
- **Never write to the phase directory or engine state**. Hooks are observers, not actors.
- **Always emit a `VERDICT:` line** if you want structured reporting. Without one, the engine falls back to exit-code-only semantics.
- **Keep execution under 30 seconds** (or the configured timeout). Long-running hooks block the entire dispatch pipeline.
- **Use `emit_verdict` from `scripts/lib/verdicts.sh`** if you source the library — it handles quoting and validates the verdict value.

---

## Cross-References

- [State Machine Reference](state-machine.md) — phase and task state transitions that hooks can gate
- [Verification Ladder Reference](verification-ladder.md) — the 4-tier verification system that POST_VERIFY hooks extend
- [File Formats Reference](file-formats.md) — structure of execution logs, phase plans, and other files hooks may inspect
- [Engine Reference](engine.md) — the dispatch engine that calls `run_hooks` at each lifecycle point
- [Events Reference](events.md) — HOOK_START, HOOK_COMPLETE, HOOK_BLOCKED, HOOK_VIOLATION, HOOK_WARNING event definitions
- Source: `scripts/lib/hooks.sh` — `run_hooks` implementation
- Source: `scripts/lib/verdicts.sh` — verdict protocol implementation
- Source: `templates/hooks.yaml` — default hook configuration
