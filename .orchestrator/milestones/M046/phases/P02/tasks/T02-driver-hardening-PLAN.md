---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M046"
name: "Driver injection hardening + deterministic CHILD_ABORT wrapper"
depends_on: []
---

## Prerequisites

- `scripts/lifecycle/self-continue-drive.sh` exists (verified at plan time; 87 lines, POSIX sh). The injection target is line 57: `sh -c "$AUTO_CMD" >/dev/null 2>&1 || true`. The string-default is line 40: `[ -n "$AUTO_CMD" ] || AUTO_CMD="claude -p \"orchestrator:auto $MILESTONE_DIR\""`.
- Existing M045 driver verifiers (`tools/verify/m045-p03-driver-terminal.sh`, `tools/verify/m045-p03-driver-cap.sh`, `tools/verify/m045-p04-stall.sh`) exist and pass today — they MUST still pass after this task.
- T01 is not a hard prerequisite (this task tests the driver with stubs), but the continue-class words below must match T01's vocabulary table in `P02-PLAN.md`.

## Description

Harden `scripts/lifecycle/self-continue-drive.sh` (M046 FR-15 + the driver half of FR-14, Gap 4):

1. **Charset allowlist** on the milestone-dir argument, enforced before the value reaches ANY command line.
2. **Argv-array child spawn** — replace the `sh -c "$AUTO_CMD"` string interpolation with positional-parameter argv construction (POSIX sh has no arrays; `set --` inside a function is the standard idiom).
3. **Deterministic exit wrapper** — capture the child's real exit status (today discarded by `|| true`) and implement the CHILD_ABORT truth table from `P02-PLAN.md`.
4. **Atomic `child_abort` marker write** (temp + `mv -f`).
5. **Continue-class mapping** — `rotation|planning|phase_complete|validating` all map to `CONTEXT:ROTATE` (re-spawn path); everything else remains terminal.
6. **Env-gate export** — export `ORCHESTRATOR_SELF_CONTINUE_MARKER=1` so the child (real `claude -p` or fixture stub, and transitively `auto-loop.sh`) activates T01's deterministic writer.

`self-continue-branch.sh` and `self-continue-status.sh` are NOT modified.

## Steps

1. Read `scripts/lifecycle/self-continue-drive.sh` in full.

2. **Charset allowlist** — immediately after `MILESTONE_DIR="$1"; shift` (line 20), insert (exact syntax matters; the bracket expression allows letters, digits, underscore, dot, slash, hyphen):

   ```
   # M046 FR-15: strict charset allowlist — the milestone dir reaches a child
   # command line, so reject shell metacharacters, leading '-', and '..' outright.
   case "$MILESTONE_DIR" in
     ''|-*|*..*|*[!A-Za-z0-9_./-]*)
       echo "SELF_CONTINUE:REJECT reason=milestone-dir-charset"
       echo "self-continue-drive.sh: milestone-dir contains disallowed characters (allowed: A-Za-z0-9 _ . / -): $MILESTONE_DIR" >&2
       exit 2 ;;
   esac
   ```

3. **Argv spawn + wrapper** — remove line 40's string default (`AUTO_CMD` stays empty when not supplied) and replace line 57 (`sh -c "$AUTO_CMD" >/dev/null 2>&1 || true`) with a call to a new function. Add the function near the top (after the option-parse loop):

   ```
   # M046 FR-15/FR-14: spawn the child via an argv array (no sh -c string
   # re-parse). A custom --auto-cmd is whitespace-split verbatim with globbing
   # disabled — metacharacters become inert argv bytes, never shell syntax.
   # Captures the child's real exit status in CHILD_RC (previously discarded).
   CHILD_RC=0
   run_child() {
     CHILD_RC=0
     if [ -n "$AUTO_CMD" ]; then
       set -f
       # shellcheck disable=SC2086
       set -- $AUTO_CMD
       set +f
     else
       set -- claude -p "orchestrator:auto $MILESTONE_DIR"
     fi
     ORCHESTRATOR_SELF_CONTINUE_MARKER=1 "$@" >/dev/null 2>&1 || CHILD_RC=$?
     return 0
   }
   ```

   Call site replacing line 57: `run_child`. Behavior notes: `--auto-cmd` loses shell-quoting support (documented semantic change — it is whitespace-split, no quotes/expansion; every existing M045 fixture passes simple `sh /path/stub.sh` forms, verified at plan time); the default `claude` spawn passes the milestone dir inside ONE argv element, already charset-validated.

4. **CHILD_ABORT truth table** — after `run_child`, BEFORE the existing `OUTCOME_RAW="$(cat ...)"` read, implement (exactly the table from `P02-PLAN.md` "Driver Wrapper Truth Table"):

   ```
   # M046 FR-14: deterministic CHILD_ABORT terminal for killed/crashed children.
   # rc>=128 (signal-killed): any marker present may be mid-segment stale — overwrite.
   # 1<=rc<=127 with no marker: child crashed before reporting — write child_abort.
   # 1<=rc<=127 with a marker: keep it (auto-loop's exit-keyed report is authoritative).
   # rc=0 with no marker: leave absent — the M045 unknown->STALLED path is preserved.
   if [ "$CHILD_RC" -ge 128 ] || { [ "$CHILD_RC" -ne 0 ] && [ ! -f "$OUTCOME_FILE" ]; }; then
     _abort_tmp="$OUTCOME_FILE.tmp.$$"
     printf 'child_abort\n' > "$_abort_tmp"
     mv -f "$_abort_tmp" "$OUTCOME_FILE"
   fi
   ```

5. **Distinct CHILD_ABORT terminal surface** — in the decision handling, when `OUTCOME` is `child_abort`, emit the distinct line and log event instead of the generic TERMINAL line. Concretely, after `OUTCOME`/`PHASE` are parsed and before the `rotation` STATUS mapping, insert:

   ```
   if [ "$OUTCOME" = "child_abort" ]; then
     log_event "{\"type\":\"self_continue_child_abort\",\"rc\":$CHILD_RC,\"continuations\":$cont,\"progress\":$progress}"
     echo "SELF_CONTINUE:CHILD_ABORT rc=$CHILD_RC continuations=$cont progress=$progress"
     exit 0
   fi
   ```

6. **Continue-class mapping** — replace the single-outcome line 65 (`if [ "$OUTCOME" = "rotation" ]; then STATUS="CONTEXT:ROTATE"; else STATUS="CONTEXT:OK"; fi`) with a case over the continue-class set:

   ```
   case "$OUTCOME" in
     rotation|planning|phase_complete|validating) STATUS="CONTEXT:ROTATE" ;;
     *) STATUS="CONTEXT:OK" ;;
   esac
   ```

   `self-continue-branch.sh` is consumed unchanged — arming/headless gates still govern the re-spawn decision.

7. Update the header comment block (lines 9–12) to document the extended vocabulary (continue-class: `rotation|planning|phase_complete|validating`; terminals now include `error|unexpected_state|planning_failed|child_abort`), the argv-spawn semantics of `--auto-cmd`, and the charset allowlist.

8. **Author `tools/verify/m046-p02-injection-reject.sh`** (POSIX sh, executable, `set -eu`, model on `tools/verify/m045-p03-driver-terminal.sh`). Behavior:
   - `TMP="$(mktemp -d)"` with cleanup trap; sentinel path `$TMP/pwned` (must never exist afterward).
   - Attack cases (each invoked with the literal name safely quoted by the verifier itself): a dir name containing `;` + a `touch` of the sentinel; one containing `$(touch ...)`; one containing backticks; one containing a space; one starting with `-`; one containing `..`.
   - For each: run `sh scripts/lifecycle/self-continue-drive.sh "<attack-name>" --min-interval 0`; assert non-zero exit, stdout contains `SELF_CONTINUE:REJECT reason=milestone-dir-charset`, and the sentinel file does NOT exist.
   - Also one positive control: a clean scratch dir name is NOT rejected (drive it with a `complete`-writing stub so it terminates immediately).
   - `PASS:`/`FAIL:` per case; non-zero exit on any failure.

9. **Author `tools/verify/m046-p02-driver-continue-class.sh`** (POSIX sh, executable, `set -eu`). Stub-driven (stubs are the established M045 driver-fixture idiom; SC-9's non-stubbed battery is T03's job):
   - Continue-class leg: for each word `planning P01` / `phase_complete P01` / `validating` / `rotation P01`, a stub writes that marker (atomically or not — stub side) and exits 0; run the driver with `--min-interval 0 --max-continuations 1 --auto-cmd "sh <stub>"`; assert output contains `SELF_CONTINUE:SCHEDULED continuation=1` (re-spawn happened) and ends with `SELF_CONTINUE:CAP_REACHED continuations=1`.
   - Terminal leg: for each word `error` / `unexpected_state` / `planning_failed`, same shape; assert `SELF_CONTINUE:TERMINAL outcome=<word>` with `continuations=0` (no re-spawn).
   - `child_abort` synthetic leg: stub writes `child_abort` itself, exits 0; assert the distinct `SELF_CONTINUE:CHILD_ABORT` line appears and no re-spawn occurs.
   - `PASS:`/`FAIL:` per case; non-zero exit on any failure.
   - Note: like the M045 driver verifiers, this relies on `detect-capabilities.sh` reporting `headless_reentry=true` on the dev machine (verified: `m045-p03-driver-cap.sh` passes today, which requires the same).

## Must-Haves

- A metacharacter-bearing milestone-dir name is rejected before reaching any command line; no injected side effect executes (SC-10 / FR-15)
  - Check: `bash tools/verify/m046-p02-injection-reject.sh`
- Continue-class markers re-spawn; error-class markers terminate with no re-spawn; the synthetic `child_abort` word surfaces the distinct terminal line
  - Check: `bash tools/verify/m046-p02-driver-continue-class.sh`

## Verification

```bash
bash tools/verify/m046-p02-injection-reject.sh
bash tools/verify/m046-p02-driver-continue-class.sh
bash tools/verify/m045-p03-driver-terminal.sh
bash tools/verify/m045-p03-driver-cap.sh
bash tools/verify/m045-p04-stall.sh
```

## Notes

Expected output: the two new verifiers end with `PASS:` summaries; the three M045 verifiers are the regression gate for the wrapper truth table — `m045-p03-driver-terminal.sh` expects `PASS: all 5 terminal outcomes stop with no re-spawn`, `m045-p03-driver-cap.sh` expects `PASS: cap halts; progress=1 on thrash, progress=3 on healthy advance`, `m045-p04-stall.sh` expects `PASS: stall surfaced by driver and status reader`. All three use rc=0 stubs, so they exercise the `rc=0 + marker present/absent` rows of the truth table.

The real-kill (`rc>=128`) and crash (`rc!=0`, no marker) legs are T03's `m046-p02-child-abort.sh` — do not duplicate them here.

## Inputs

### From Previous Tasks

- Marker vocabulary table from `P02-PLAN.md` (T01 implements the auto-loop side; this task only needs the word list: continue-class `rotation|planning|phase_complete|validating`, error terminals `error|unexpected_state|planning_failed`, driver-owned `child_abort`).

### From Disk (Pre-existing)

- `scripts/lifecycle/self-continue-drive.sh` — the modify target. Key internals: `MILESTONE_DIR="$1"` (line 20), silent `MAX_CONT=20` default (line 21 — DO NOT change; FR-13 fail-closed caps are P04/P05 scope), `OUTCOME_FILE="$MILESTONE_DIR/.self-continue-outcome"` (line 39), string default (line 40), `sh -c` spawn (line 57), outcome parse via `awk` (lines 59–60), STATUS mapping (line 65), decision via `self-continue-branch.sh` (line 66).
- `scripts/lifecycle/self-continue-branch.sh` — consumed unchanged; emits `AUTO:SELF_CONTINUE` only for `CONTEXT:ROTATE` + armed + headless.
- `scripts/diagnostics/self-continue-status.sh` — consumed unchanged; any non-`unconfirmed` last log record reports OK, so the new `self_continue_child_abort` event needs no reader change.
- `tools/verify/m045-p03-driver-terminal.sh`, `tools/verify/m045-p03-driver-cap.sh`, `tools/verify/m045-p04-stall.sh` — regression gates and the stub-fixture idiom to model.

## Constraints

- Do NOT touch `auto-loop.sh` (T01's file — CON-2 blast radius), `self-continue-branch.sh`, or `self-continue-status.sh`.
- Keep the driver POSIX sh (`#!/usr/bin/env sh`, `set -eu`) — no bashisms, no arrays, no `local`.
- Keep the silent `MAX_CONT=20` default and the stop-file/cap/log semantics byte-compatible (M045 attended behavior; FR-13/FR-10 hardening is P04/P05 scope).
- `--auto-cmd` semantic change (whitespace-split, no shell evaluation) must be documented in the header comment.
- All marker writes atomic (temp + `mv -f` in the same directory).

## Expected Output

- `scripts/lifecycle/self-continue-drive.sh` hardened per steps 2–7.
- `tools/verify/m046-p02-injection-reject.sh`, `tools/verify/m046-p02-driver-continue-class.sh` — both green.
- All three M045 driver verifiers still green.
