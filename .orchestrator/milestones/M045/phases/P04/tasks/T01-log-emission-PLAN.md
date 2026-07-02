---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P04"
milestone: "M045"
name: "Add FR-9/FR-10 log emission + stall detection to the driver"
depends_on: []
---

## Prerequisites

- `scripts/lifecycle/self-continue-drive.sh` exists (P03). Read it first — you are ADDING to it, not rewriting.

## Description

Extend the driver with an optional `--log <path>` that appends FR-9 continuity JSONL records, plus FR-10 stall handling: a segment that produces no outcome marker (spawned process crashed / never wrote `.self-continue-outcome`) leaves a dangling `self_continue_unconfirmed` record as the LAST log line and emits `SELF_CONTINUE:STALLED`. Deterministic (no timestamps) — stall is detected structurally (unconfirmed record not followed by a resolving record), which keeps fixtures hermetic.

## Steps

1. In `scripts/lifecycle/self-continue-drive.sh`:
   a. Add `--log <path>` to the arg-parse `case` (set `LOG="$2"; shift 2`); initialize `LOG=""` alongside the other defaults.
   b. Add a helper after arg parsing:
   ```sh
   log_event() { [ -n "$LOG" ] && printf '%s\n' "$1" >> "$LOG"; return 0; }
   ```
   c. In the cap-check branch, before `exit 0`, add:
   ```sh
   log_event "{\"type\":\"self_continue_cap_reached\",\"continuations\":$cont,\"progress\":$progress}"
   ```
   d. Immediately before `rm -f "$OUTCOME_FILE"`, record the pending (unconfirmed) segment:
   ```sh
   pend=$((cont+1))
   log_event "{\"type\":\"self_continue_unconfirmed\",\"continuation\":$pend}"
   ```
   e. Immediately AFTER computing `OUTCOME` (after the `awk` lines), add the stall interception BEFORE the `if [ "$OUTCOME" = "rotation" ]` line:
   ```sh
   if [ "$OUTCOME" = "unknown" ]; then
     echo "SELF_CONTINUE:STALLED continuation=$pend continuations=$cont progress=$progress"
     exit 0
   fi
   ```
   (On stall, the `self_continue_unconfirmed` record stays the LAST log line — the structural stall signal — because no resolving record follows.)
   f. In the `*AUTO:SELF_CONTINUE*` case, after incrementing, add:
   ```sh
   log_event "{\"type\":\"self_continue_scheduled\",\"continuation\":$cont,\"progress\":$progress,\"phase\":\"$PHASE\"}"
   ```
   g. In the `*)` (else / terminal) case, before the `echo "SELF_CONTINUE:TERMINAL"`, add:
   ```sh
   case "$DECISION" in
     *headless-unavailable*) log_event "{\"type\":\"self_continue_unavailable\",\"reason\":\"headless-unavailable\"}" ;;
     *) log_event "{\"type\":\"self_continue_terminal\",\"outcome\":\"$OUTCOME\",\"continuations\":$cont,\"progress\":$progress}" ;;
   esac
   ```
2. Re-run the P03 verifiers to confirm no regression:
   `bash tools/verify/m045-p03-driver-terminal.sh` and `bash tools/verify/m045-p03-driver-cap.sh` must still PASS.

## Must-Haves

- `--log` appends `self_continue_unconfirmed` before each segment, `self_continue_scheduled` per re-spawn, `self_continue_terminal`/`self_continue_cap_reached`/`self_continue_unavailable` at stops.
- Unknown outcome → `SELF_CONTINUE:STALLED` on stdout + `self_continue_unconfirmed` left as the last log record.
- P03 SC-2/SC-3 verifiers still PASS.

## Verification

`bash tools/verify/m045-p03-driver-terminal.sh`
`bash tools/verify/m045-p03-driver-cap.sh`

## Inputs

### From Disk (Pre-existing)
- `scripts/lifecycle/self-continue-drive.sh` (P03) — loop with cap/terminal/stop-file; vars `cont`, `progress`, `PHASE`, `OUTCOME`, `DECISION`, `OUTCOME_FILE`.

## Constraints

- Additive to the existing driver; do not change its P03 stdout contract (the new records go only to `--log`; stdout still emits SCHEDULED/TERMINAL/CAP_REACHED/STOPPED, plus the new STALLED).
- No timestamps (Principle IX) — stall is structural (dangling unconfirmed).
- POSIX sh.

## Expected Output

Driver emits FR-9 JSONL records under `--log` and a deterministic FR-10 stall signal; P03 verifiers still green.
