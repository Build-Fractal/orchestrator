---
schema_version: "1.0"
type: task-summary
task: "T01"
phase: "P04"
milestone: "M045"
name: "Add FR-9/FR-10 log emission + stall detection to the driver"
outcome: success
---

Extended `scripts/lifecycle/self-continue-drive.sh` additively (no rewrite of the P03 loop):

- Added `LOG=""` default and a `--log <path>` arg-parse case.
- Added a `log_event()` helper that appends a JSONL line to `$LOG` only when `--log` is given (no-op otherwise).
- Cap-check branch now emits a `self_continue_cap_reached` record before `exit 0`.
- Before each segment run (immediately before `rm -f "$OUTCOME_FILE"`) the driver records a `self_continue_unconfirmed` record with `pend=$((cont+1))`.
- Immediately after computing `OUTCOME`, added a structural FR-10 stall interception: `OUTCOME=unknown` (no marker written) emits `SELF_CONTINUE:STALLED continuation=... continuations=... progress=...` on stdout and exits 0, leaving the dangling `self_continue_unconfirmed` as the LAST log line.
- The `*AUTO:SELF_CONTINUE*` case emits `self_continue_scheduled` per re-spawn.
- The terminal `*)` case emits `self_continue_unavailable` (headless-unavailable decision) or `self_continue_terminal` otherwise, before the existing `SELF_CONTINUE:TERMINAL` stdout line.

Stall detection is structural and timestamp-free (Principle IX): a dangling `self_continue_unconfirmed` as the last record is the signal. The P03 stdout contract is unchanged — new records go only to `--log`.

Verifier results:
- `bash tools/verify/m045-p03-driver-terminal.sh` → PASS: all 5 terminal outcomes stop with no re-spawn
- `bash tools/verify/m045-p03-driver-cap.sh` → PASS: cap halts; progress=1 on thrash, progress=3 on healthy advance
- `bash tools/verify/m045-p03-legacy-golden.sh` → PASS: golden matches (AUTO:ROTATE_EXIT reason=not-armed)
