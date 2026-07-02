---
schema_version: "1.0"
type: task-summary
task: "T02"
phase: "P04"
milestone: "M045"
name: "Status reader scripts/diagnostics/self-continue-status.sh (FR-10 surface)"
outcome: success
---

Created `scripts/diagnostics/self-continue-status.sh` — a read-only POSIX-sh helper that inspects a self-continue `--log` file and reports run health:

- `SELF_CONTINUE:NO_LOG` when the log arg is missing or the file is empty.
- `SELF_CONTINUE:STALLED scheduled=<N> (last segment never resolved)` when the LAST record is `self_continue_unconfirmed` (FR-10 surface).
- `SELF_CONTINUE:OK scheduled=<N> last=<type>` otherwise, extracting the last record's `type` via `sed`.

The reader performs no writes. A header comment names `scripts/lifecycle/self-continue-drive.sh --log <path>` as the log producer (the P04 key link). Added a one-line doc note to `commands/auto.md`'s `## Self-Continue` section (after the Outcome-marker paragraph) pointing operators at the reader.

Verifier results:
- `bash scripts/diagnostics/self-continue-status.sh /dev/null` → `SELF_CONTINUE:NO_LOG`
- Exercised end-to-end by `tools/verify/m045-p04-stall.sh` (status reader reports STALLED) → PASS.
