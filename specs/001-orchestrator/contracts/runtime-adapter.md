# Contract: Runtime Adapter Interface

**Version**: 1.0 | **Date**: 2026-03-19
**Spec References**: FR-067, FR-068, FR-069

## Overview

The runtime adapter is the boundary between the orchestrator's core logic and platform-specific execution. The orchestrator programs against this interface; adapters implement it using platform-native primitives.

## Adapter Lifecycle: Hydrate-Execute-Persist

Every adapter invocation follows a mandatory three-phase sequence:

1. **Hydrate** — Restore `.specify/orchestrator/` state from durable storage into the working tree. For local adapters, this is a no-op (files persist naturally). For CI adapters, this pulls from repo-memory or artifact storage.
2. **Execute** — All operations target the working tree. `.specify/orchestrator/` is the canonical source of truth during this phase. All core operations (dispatch, verify, collect) happen here.
3. **Persist** — Commit working tree state back to durable storage. For local adapters, this is a no-op. For CI adapters, this pushes to repo-memory and/or commits to the branch.

This contract resolves the working-tree vs. repo-memory tension: the working tree is always canonical during execution; durable storage is a sync mechanism.

## Core Operations (Required — All Adapters)

### 1. `dispatch-task`

**Input**:
```yaml
task_id: "M001/P01/T02"
payload: |
  # Task: T02 — Implement dispatch table
  ## Task Plan
  ...
  ## Phase Context
  ...
  ## Verification Criteria
  ...
timeout: "30m"  # optional, from duration_budget
```

**Output**:
```yaml
dispatch_id: "d-20260319-001"  # unique dispatch identifier
status: dispatched             # enum: dispatched | failed
error: null                    # set if status=failed
```

**Behavior**: Send the payload to a fresh agent context for execution. The adapter determines HOW (subagent, subprocess, in-session, CI job). The orchestrator never knows or cares about the mechanism.

### 2. `await-completion`

**Input**:
```yaml
dispatch_id: "d-20260319-001"
poll_interval: "30s"           # optional, adapter may ignore
```

**Output**:
```yaml
status: done | done_with_concerns | blocked | needs_context | failed | timeout
duration: "12m"
```

**Behavior**: Block or poll until the dispatched task signals completion. For local-sequential adapters, this returns immediately (execution is synchronous). For subprocess/CI adapters, this polls or waits.

### 3. `collect-result`

**Input**:
```yaml
dispatch_id: "d-20260319-001"
```

**Output**:
```yaml
status: done | done_with_concerns | blocked | needs_context | failed
artifacts:                     # files created/modified by the task
  - path: scripts/state/derive-phase.sh
    action: created
  - path: extension.yml
    action: modified
summary: |
  Implemented state derivation script with 9-state logic...
concerns: []                   # populated if status=done_with_concerns
blocker: null                  # populated if status=blocked
needed_context: null           # populated if status=needs_context
```

**Behavior**: Retrieve the output from a completed dispatch. For local adapters, this reads from the working directory. For CI adapters, this may pull from artifacts or commit diffs.

### 4. `signal-failure`

**Input**:
```yaml
dispatch_id: "d-20260319-001"
diagnostic: |
  Task T02 failed verification: scripts/state/derive-phase.sh exists but
  does not handle the 'replanning' state. Expected output includes 'replanning'
  but grep found no match.
retry: true                    # should the adapter attempt retry?
```

**Output**:
```yaml
acknowledged: true
retry_dispatch_id: "d-20260319-002"  # null if retry=false
```

**Behavior**: Report failure with diagnostic context. If `retry=true`, the adapter dispatches a new attempt with the diagnostic injected as additional context.

### 5. `inject-context`

**Input**:
```yaml
dispatch_id: "d-20260319-001"   # may be null for "next dispatch" injection
context: |
  DECISION INJECTED: D005 — Use POSIX sh instead of bash for all state scripts.
  Rationale: macOS ships zsh, not bash 4+. POSIX sh is the safe portability target.
target: next_dispatch           # enum: active | next_dispatch
```

**Output**:
```yaml
injected: true
effective_at: "next_dispatch"   # or "active" if adapter supports mid-task injection
```

**Behavior**: Provide additional context to a running or queued task. Most adapters only support `next_dispatch` (context picked up at next phase boundary). CI adapters with long-running jobs may support `active` injection.

## Adapter-Internal Optimizations

Adapters MAY implement internal optimizations that are invisible to the orchestrator's core dispatch loop. The 5-operation interface is fixed — there is no capability negotiation, no `AdapterCapabilities` type, and no conditional branches in core logic.

**Example**: The gh-aw adapter may internally batch independent tasks (detected from the roadmap's dependency graph) into parallel GitHub Actions jobs. The orchestrator calls `dispatch-task` sequentially; the adapter buffers and fans out internally. The orchestrator calls `await-completion` and gets results — it never knows parallelism occurred.

This satisfies FR-068 (no conditional branches based on runtime identity) by eliminating the negotiation that would require them.

*Per arbitration resolution (2026-03-19): capability negotiation removed from FR-069. The five core operations are the complete interface contract.*

## Lock File Operations

Adapters MUST implement lock acquisition and release:

### `acquire_lock`
Write `orchestrator.lock` with adapter-appropriate fields:
- Local: `{ "runtime": "local", "pid": $$, ... }`
- CI: `{ "runtime": "ci-github", "run_id": "$GITHUB_RUN_ID", ... }`

### `release_lock`
Delete `orchestrator.lock` on clean completion. On crash, the lock remains for detection by `check-lock.sh`.

The `runtime` field is self-describing — `derive-phase.sh` reads it to determine the liveness check strategy without adapter code.

## Planned Adapters

### `local-sequential` (Default)

Executes tasks in the current agent session with explicit context separation. No subprocess, no subagent.

| Operation | Implementation |
|-----------|---------------|
| dispatch-task | Print payload as instructions for the agent to follow inline |
| await-completion | Synchronous — returns when agent finishes the task |
| collect-result | Read modified files from working directory |
| signal-failure | Print diagnostic, prompt agent to retry |
| inject-context | Append to next dispatch payload |

**Used when**: Agent runtime has no subagent support (Cursor, Gemini CLI, basic setups).

### `local-subprocess`

Dispatches tasks to fresh agent sessions via the Agent tool or CLI subprocess (e.g., `claude --print`).

| Operation | Implementation |
|-----------|---------------|
| dispatch-task | Invoke Agent tool / subprocess with payload |
| await-completion | Wait for subprocess exit / Agent tool return |
| collect-result | Parse agent output + scan working directory for changes |
| signal-failure | Re-invoke with diagnostic context appended |
| inject-context | Write to injection file, read by next dispatch's build-context |

**Used when**: Agent supports subagent dispatch (Claude Code Agent tool).

### `gh-aw-ci` (Future — US-7)

Dispatches tasks as GitHub Actions workflow jobs.

| Operation | Implementation |
|-----------|---------------|
| dispatch-task | Create workflow dispatch event or issue comment |
| await-completion | Poll workflow run status via GitHub API |
| collect-result | Read commit diff + workflow artifacts |
| signal-failure | Post failure comment on tracking issue |
| inject-context | Post context as issue comment, picked up by next job |
| internal_optimizations | Parallel fan-out of independent tasks, repo-memory persistence |

**Dispatch Mode**: `step` — advances one unit per workflow run. Cannot drive a full milestone due to CI timeout caps. Re-enters via `schedule` or `repository_dispatch`.

**Concurrency Requirement**: All task dispatch workflows MUST include:
```yaml
concurrency:
  group: orchestrator-${{ inputs.task_id }}
  cancel-in-progress: false
```
This prevents fan-out cancellations (dispatching T02 would otherwise cancel T01).

**Used when**: Running in GitHub Actions with Agentic Workflows configured.

## Adapter Selection

`detect-capabilities.sh` determines the active adapter:

1. Check `GITHUB_ACTIONS` env var → `gh-aw-ci`
2. Check if Agent tool is available (agent runtime detection) → `local-subprocess`
3. Default → `local-sequential`

The developer can override via config: `SPECKIT_ORCHESTRATOR_ADAPTER=local-subprocess`