---
description: "Use when resuming after a crash or pause. Detects whether the interruption was a graceful pause (continue file present) or a crash (stale lock), then follows the appropriate recovery path — consuming the continue file for pauses, or breaking the lock and synthesizing a recovery briefing for crashes."
---

# orchestrator:resume

Resume orchestrator execution after an interruption. This command detects whether the session was paused gracefully (FR-048) or crashed unexpectedly (FR-021/FR-023), then follows the appropriate recovery path to restore execution.

## Prerequisites

### 1. Derive Current State

```bash
bash scripts/state/derive-phase.sh <milestone-dir>
```

Resume is valid in any state except:
- `complete` — there is nothing to resume. Report "Nothing to resume — milestone is complete." and exit.
- `pre-planning` — there is nothing to recover from. Report "Milestone has not started execution — nothing to resume." and exit.

### 2. Locate Recovery Artifacts

Check for the two key artifacts that indicate the type of interruption:

- **Continue file**: `<milestone-dir>/continue.md` — written by a graceful pause (FR-047/FR-048)
- **Lock file**: `.orchestrator/orchestrator.lock` — left behind by a crash

## Recovery Type Detection (FR-049)

Distinguish between recovery paths by checking which artifacts exist:

### Graceful Pause

Detected when:
- A continue file exists at `<milestone-dir>/continue.md`
- AND no stale lock file exists (or the lock has already been cleaned)

→ Follow **Path A** below.

### Crash Recovery

Detected when:
- The lock file `.orchestrator/orchestrator.lock` exists, AND
- No continue file exists at `<milestone-dir>/continue.md`

```bash
bash scripts/lifecycle/lock-manager.sh status .orchestrator/orchestrator.lock
```

The status verdict varies by runtime:
- `LOCK:STALE` — non-Claude-Code runtime confirmed the holder PID is dead.
- `LOCK:ACTIVE` under `CLAUDECODE=1` — the CC runtime cannot prove the
  lock is orphaned, because each Bash tool call spawns a fresh shell
  with a fresh PID. The lock file's recorded PID belongs to a per-call
  shell that has already exited; status falls back to "file exists =
  active." See `scripts/lifecycle/lock-manager.sh` `is_claude_code()`.

In either case, → Follow **Path B** below. B1 distinguishes the two
verdicts and applies different break-safety logic.

### Mixed State

Detected when:
- Both a continue file AND a lock file exist

This indicates the pause may not have completed cleanly. Treat as **crash recovery** (Path B), but also read the continue file for additional context about what the pausing session intended as the next action. Include that context in the recovery briefing output.

## Path A — Resume from Pause (FR-048)

Follow these steps to resume from a graceful pause:

### A1. Read the Continue File

Read `<milestone-dir>/continue.md`. This file follows the `templates/continue-file.md` format and contains:
- **Completed Work** — what was finished before the pause
- **Remaining Work** — what still needs to be done
- **Decisions Made** — decisions from the paused session's context
- **Context** — key state that was in the paused session's memory but not on disk
- **Next Action** — the exact instruction for what to do next

### A2. Extract the Next Action

The `## Next Action` section contains the specific command or step to execute immediately. This is the authoritative instruction — execute it as described.

### A3. Delete the Continue File

The continue file is consumed on resume, not permanent (per FR-048):

```bash
rm <milestone-dir>/continue.md
```

### A4. Execute the Next Action

Perform the action described in the Next Action section. This is typically one of:
- Dispatch the next task via `/orchestrator-dispatch`
- Run verification on a completed task via `/orchestrator-verify`
- Generate a phase summary
- Finalize a specific step that was in progress

### A5. Suggest Continuation

After executing the immediate next action, if the user wants to continue in autonomous mode, suggest:

> "Immediate action complete. To resume autonomous execution, run `/orchestrator-auto`."

## Path B — Crash Recovery (FR-021, FR-023)

Follow these steps to recover from a crash:

### B1. Check and Break the Lock

Verify the lock state, then decide whether to break it:

```bash
bash scripts/lifecycle/lock-manager.sh status .orchestrator/orchestrator.lock
```

Three cases:

**`LOCK:STALE`** (any runtime) — the holder PID is dead. Break the lock:

```bash
bash scripts/lifecycle/lock-manager.sh break .orchestrator/orchestrator.lock
```

**`LOCK:ACTIVE` outside Claude Code** (`CLAUDECODE` unset) — the holder
PID is alive on this machine. The previous session is still running.
Do NOT break. Report: "Lock is still active (PID {pid}). Cannot resume
while another session is running." and exit.

**`LOCK:ACTIVE` under Claude Code** (`CLAUDECODE=1`) — the verdict is
ambiguous: the recorded PID is a per-tool-call shell that always exits
immediately, so this output cannot distinguish "live concurrent CC
session" from "interrupted previous session that left the lock behind."
Resume is the user's explicit recovery action — surface the ambiguity
and require confirmation:

> "A previous orchestrator-auto session may have been interrupted, but
> Claude Code cannot tell that apart from a concurrent session on this
> project. Confirm no other Claude session is currently running
> orchestrator-auto here. Proceed with breaking the lock? [y/N]"

On `y`, break the lock with the same `lock-manager.sh break` command
above. On `n` or anything else, exit without modifying the lock.

### B2. Synthesize Recovery Briefing

Generate a structured recovery briefing from surviving disk artifacts:

```bash
bash scripts/lifecycle/recovery-briefing.sh <milestone-dir>
```

This produces a briefing following the `templates/recovery-briefing.md` format with:
- **Crash State** — last active unit, PID, timestamps, lock file status
- **Completed Work** — units verified complete on disk (summary files present)
- **Incomplete Work** — the unit that was in progress when the crash occurred
- **Recovery Plan** — recommended actions to resume

Present the full recovery briefing to the user/agent.

### B3. Check for Stuck Condition

Before automatically retrying the incomplete unit, check if it is stuck:

```bash
bash scripts/lifecycle/stuck-detector.sh <milestone-dir>/execution-log.jsonl <last-active-unit-id>
```

- If `STUCK:YES` — the task has been dispatched multiple times without completion. Report: "Unit {unit_id} is stuck (dispatched {N} times without success). Manual intervention required — do NOT automatically retry." and exit. The user should investigate the task, adjust the plan, or manually mark it as blocked.
- If `STUCK:NO` — the task failed due to the crash, not a recurring issue. Safe to re-dispatch.

### B4. Resume Execution

If the unit is not stuck, re-dispatch the task that was in progress:
- Use `/orchestrator-dispatch` to re-execute the incomplete task
- The dispatch command's idempotency check will detect if the task actually completed before the crash (summary file exists) and skip re-execution

If the user wants to continue in autonomous mode after recovery, suggest running `/orchestrator-auto`.

## Idempotency (FR-066)

Resume is designed to be safely re-callable:

- **No lock file, no continue file, state is `executing`**: Report current state and suggest: "No crash or pause detected. Use `/orchestrator-dispatch` to execute the next task, or `/orchestrator-auto` for autonomous mode."
- **Milestone is `complete`**: Report "Nothing to resume — milestone is complete."
- **Running resume twice after a pause**: The first resume deletes the continue file. The second resume finds no continue file and no stale lock, so it falls through to the "no recovery needed" case above.
- **Running resume twice after a crash**: The first resume breaks the lock and re-dispatches. The second resume finds no stale lock and no continue file, so it falls through to the "no recovery needed" case.

## Error Handling

- **Malformed continue file** (missing required sections like `## Next Action`): Warn "Continue file is malformed — missing Next Action section. Falling back to crash recovery path." Then follow Path B (minus lock breaking if no stale lock exists) to determine the next action from disk state instead.
- **Recovery briefing script fails** (exit code non-zero): Warn "Recovery briefing generation failed." Fall back to reporting raw state:
  - Output of `bash scripts/state/derive-phase.sh <milestone-dir>`
  - Contents of the lock file (if readable) for manual inspection
  - Suggest running `/orchestrator-status` for a full state report.
- **Lock file cannot be broken** (lock-manager.sh break returns non-zero): Report "Failed to break stale lock at .orchestrator/orchestrator.lock. Manual removal may be required." and exit 1.
- **Both recovery paths fail**: If neither the continue file nor the recovery briefing provides actionable information, report: "Unable to determine recovery path. Run `/orchestrator-status` for current state." and exit 1.

## Gotchas

- **Continue file is consumed (deleted) on resume**: The same pause cannot be resumed twice. A second resume invocation finds no continue file and falls through to the "no recovery needed" case.
- **Mixed state (continue file + stale lock) is treated as crash recovery**: The continue file is read for context, but Path B (crash recovery) takes precedence — the lock is broken and a recovery briefing is synthesized.
- **Stuck tasks are not auto-retried**: If `stuck-detector.sh` reports `STUCK:YES`, the command exits and requires manual intervention. The developer must investigate, adjust the task plan, or unblock the task before resuming.

## Referenced Scripts

- `scripts/lifecycle/lock-manager.sh` — lock status check and lock break operations
- `scripts/lifecycle/stuck-detector.sh` — stuck detection for crash recovery path
- `scripts/lifecycle/recovery-briefing.sh` — synthesizes recovery briefing from disk state
- `scripts/state/derive-phase.sh` — derives current orchestrator state

## Referenced Templates

- `templates/recovery-briefing.md` — format for the recovery briefing output
- `templates/continue-file.md` — format of the continue file (for parsing sections)
