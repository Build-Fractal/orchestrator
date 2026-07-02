---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M045"
name: "Status reader scripts/diagnostics/self-continue-status.sh (FR-10 surface)"
depends_on: ["T01"]
---

## Prerequisites

- T01 complete: the driver emits FR-9/FR-10 records to `--log`.

## Description

A read-only status helper that inspects a self-continue log and reports whether the run is healthy, complete, or STALLED (FR-10 surface). Stall = the LAST record in the log is `self_continue_unconfirmed` (a segment started but never resolved).

## Steps

1. Create `scripts/diagnostics/self-continue-status.sh`:
   ```sh
   #!/usr/bin/env sh
   # self-continue-status.sh <log-path>
   # Reports the self-continue run health from its FR-9/FR-10 JSONL log (M045).
   #   SELF_CONTINUE:STALLED     — last record is self_continue_unconfirmed (segment never resolved)
   #   SELF_CONTINUE:OK          — last record is scheduled/terminal/cap/unavailable
   #   SELF_CONTINUE:NO_LOG      — log missing or empty
   set -eu
   LOG="${1:-}"
   if [ -z "$LOG" ] || [ ! -s "$LOG" ]; then
     echo "SELF_CONTINUE:NO_LOG"; exit 0
   fi
   LAST="$(tail -n 1 "$LOG")"
   SCHED="$(grep -c 'self_continue_scheduled' "$LOG" 2>/dev/null || echo 0)"
   case "$LAST" in
     *self_continue_unconfirmed*)
       echo "SELF_CONTINUE:STALLED scheduled=$SCHED (last segment never resolved)"; exit 0 ;;
     *)
       echo "SELF_CONTINUE:OK scheduled=$SCHED last=$(printf '%s' "$LAST" | sed -n 's/.*\"type\":\"\([a-z_]*\)\".*/\1/p')"; exit 0 ;;
   esac
   ```
2. `chmod +x scripts/diagnostics/self-continue-status.sh`.
3. Document it in one line in `commands/auto.md`'s `## Self-Continue` section (after the "Outcome marker" paragraph): "Run health can be inspected read-only with `scripts/diagnostics/self-continue-status.sh <log-path>` — reports `SELF_CONTINUE:STALLED` if the last segment never resolved (FR-10)."
4. Smoke-test: create a scratch log with a trailing `self_continue_unconfirmed` line → expect `SELF_CONTINUE:STALLED`; append a `self_continue_terminal` line → expect `SELF_CONTINUE:OK`.

## Must-Haves

- `self-continue-status.sh` reports `SELF_CONTINUE:STALLED` when the last log record is `self_continue_unconfirmed`, `SELF_CONTINUE:OK` otherwise, `SELF_CONTINUE:NO_LOG` for missing/empty.
- Read-only (no writes).

## Verification

`bash scripts/diagnostics/self-continue-status.sh /dev/null`

## Inputs

### From Previous Tasks
- `scripts/lifecycle/self-continue-drive.sh --log <path>` (T01) — appends `self_continue_{unconfirmed,scheduled,terminal,cap_reached,unavailable}` JSONL records.

### From Disk (Pre-existing)
- `commands/auto.md` — `## Self-Continue` section (one-line doc addition).

## Constraints

- Read-only; POSIX sh; no timestamps.
- `## Verification` block = check commands only (AD-19).

## Expected Output

`scripts/diagnostics/self-continue-status.sh` surfaces stall vs healthy from the log; one-line doc in auto.md.
