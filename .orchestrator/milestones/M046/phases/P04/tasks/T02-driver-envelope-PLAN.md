---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M046"
name: "Driver integration — flags, fail-closed gate, watchdog wiring, reserve/reconcile, thrash"
depends_on: [T01]
---

## Prerequisites

- `scripts/lifecycle/unattended-envelope.sh` exists (T01 deliverable) with the 11-function
  surface documented in `tasks/T01-envelope-lib-PLAN.md` (`envelope_caps_problems`,
  `envelope_ledger_init`, `envelope_next_segment`, `envelope_reserve`, `envelope_reconcile`,
  `envelope_forfeit`, `envelope_spent_total`, `envelope_observed_cost`,
  `envelope_parse_total_cost`, `envelope_write_kill_reason`, `envelope_watchdog`).
- `tools/verify/m046-p04-envelope-unit.sh` is green (run it first; if it fails, stop and fix T01).
- `scripts/lifecycle/self-continue-drive.sh` is the P02-hardened driver (~150 lines): charset
  allowlist on `$MILESTONE_DIR` (exit 2 `SELF_CONTINUE:REJECT`), argv-array `run_child()` with
  `CHILD_RC` capture, CHILD_ABORT truth table after `run_child`, marker read + continue-class
  mapping, `self-continue-branch.sh` decision, `SCHEDULED`/`TERMINAL`/`CAP_REACHED`/`STOPPED`/
  `STALLED` emissions.
- The four P02 driver verifiers exist and are green pre-change:
  `tools/verify/m046-p02-legacy-parity.sh`, `tools/verify/m046-p02-child-abort.sh`,
  `tools/verify/m046-p02-driver-continue-class.sh`, `tools/verify/m046-p02-injection-reject.sh`.

## Description

Wire the envelope into `scripts/lifecycle/self-continue-drive.sh` behind an explicit
`--unattended` flag (FR-6: default OFF, no config enable). Adds: the FR-13 fail-closed
refuse-to-start gate IN THE DRIVER (SC-8); backgrounded child + foreground
`envelope_watchdog` with SIGKILL under `--unattended` (FR-7/FR-10/D016); hard-limit env
exports into the child (FR-7 "pass hard limits into the child"); reserve-then-spend around
every segment (FR-8); kill-reason consumption into distinct terminals; and the
`SELF_CONTINUE:THRASH` terminal (FR-12, default 2 no-progress segments).

**FR-17/CON-2 invariant:** every new runtime behavior is inside `if [ "$UNATTENDED" = "true" ]`
guards (or in the unattended branch of `run_child`). The attended flow — same flags as M045 —
must remain behaviorally identical; the four P02 verifiers are the regression oracle.
`auto-loop.sh` is NOT touched.

## Steps

1. **Flag parsing** — extend the existing `while [ $# -gt 0 ]` case in
   `scripts/lifecycle/self-continue-drive.sh`. New variables initialized beside
   `MAX_CONT=20; ...`:

   ```sh
   UNATTENDED=false; MAX_CONT_SET=false; BUDGET_USD=""; WALL_S=""
   RESERVE_USD="1.00"; THRASH_N=2; POLL_S=1; COST_LOG=""
   ```

   New cases (existing cases unchanged; note `--max-continuations` additionally sets
   `MAX_CONT_SET=true`):

   ```sh
   --max-continuations) MAX_CONT="$2"; MAX_CONT_SET=true; shift 2 ;;
   --unattended) UNATTENDED=true; shift ;;
   --max-budget-usd) BUDGET_USD="$2"; shift 2 ;;
   --max-wall-clock-s) WALL_S="$2"; shift 2 ;;
   --segment-reserve-usd) RESERVE_USD="$2"; shift 2 ;;
   --thrash-threshold) THRASH_N="$2"; shift 2 ;;
   --watchdog-poll-s) POLL_S="$2"; shift 2 ;;
   --cost-log) COST_LOG="$2"; shift 2 ;;
   ```

2. **Source the library + fail-closed gate** — after the existing
   `SCRIPT_DIR`/`REPO_ROOT`/`BRANCH`/`OUTCOME_FILE` block:

   ```sh
   . "$SCRIPT_DIR/unattended-envelope.sh"

   REASON_FILE="$MILESTONE_DIR/.self-continue-kill-reason"
   LEDGER="$MILESTONE_DIR/.self-continue-budget-ledger"
   RESULT_FILE="$MILESTONE_DIR/.self-continue-segment-result.json"
   [ -n "$COST_LOG" ] || COST_LOG="$MILESTONE_DIR/execution-log.jsonl"

   if [ "$UNATTENDED" = "true" ]; then
     _caps="$(envelope_caps_problems "$BUDGET_USD" "$MAX_CONT_SET" "$MAX_CONT" "$WALL_S")"
     if [ "$_caps" != "ok" ]; then
       echo "SELF_CONTINUE:REFUSE $_caps"
       echo "self-continue-drive.sh: --unattended requires explicit --max-budget-usd, --max-continuations, and --max-wall-clock-s (fail-closed, FR-13): $_caps" >&2
       exit 2
     fi
     RUN_START_EPOCH="$(date +%s)"
     DEADLINE_EPOCH=$((RUN_START_EPOCH + WALL_S))
     envelope_ledger_init "$LEDGER" "$BUDGET_USD" "$WALL_S" "$MAX_CONT"
     rm -f "$REASON_FILE"
   fi
   ```

   `SELF_CONTINUE:REFUSE` output format is exactly `SELF_CONTINUE:REFUSE reason=caps-unset
   missing=<csv>` or `SELF_CONTINUE:REFUSE reason=caps-invalid invalid=<csv>` — implement by
   having the gate prefix `reason=` onto the library's first word (i.e. emit
   `SELF_CONTINUE:REFUSE reason=$_caps` with the library returning `caps-unset missing=...`;
   pick one consistent shape and mirror it in the T02 verifier and commands/auto.md). The gate
   runs BEFORE the capability probe and BEFORE the loop — no ledger reserve, no spawn, on refusal.
   Note: `envelope_ledger_init` runs only after the gate passes.

3. **run_child unattended branch** — extend `run_child()` keeping the attended branch
   byte-identical (same `ORCHESTRATOR_SELF_CONTINUE_MARKER=1 "$@" >/dev/null 2>&1 || CHILD_RC=$?`
   line). Unattended branch:

   ```sh
   if [ "$UNATTENDED" = "true" ]; then
     : > "$RESULT_FILE"
     ORCHESTRATOR_SELF_CONTINUE_MARKER=1 \
     ORCHESTRATOR_UNATTENDED=1 \
     ORCHESTRATOR_MAX_BUDGET_USD="$BUDGET_USD" \
     ORCHESTRATOR_BUDGET_REMAINING_USD="$SEG_REMAINING_USD" \
     ORCHESTRATOR_WALL_CLOCK_DEADLINE_EPOCH="$DEADLINE_EPOCH" \
     ORCHESTRATOR_MAX_CONTINUATIONS="$MAX_CONT" \
       "$@" > "$RESULT_FILE" 2>&1 &
     CHILD_PID=$!
     envelope_watchdog "$CHILD_PID" "$POLL_S" "$STOP_FILE" "$DEADLINE_EPOCH" \
       "$BUDGET_USD" "$SEG_SPENT_BEFORE" "$COST_LOG" "$COST_BASELINE_LINES" "$REASON_FILE"
     wait "$CHILD_PID" && CHILD_RC=0 || CHILD_RC=$?
   else
     <existing attended line, unchanged>
   fi
   ```

   The env exports are the FR-7 "pass hard limits into the child" leg (the child can
   self-abort; P07's instruments will read the same names — document them in a header
   comment). Default `claude` argv under unattended gains `--output-format json`:
   in the `else` (no `--auto-cmd`) argv construction, when `UNATTENDED=true` use
   `set -- claude -p --output-format json "orchestrator:auto $MILESTONE_DIR"`.

4. **Pre-spawn envelope checks + reserve** — inside the main loop, after the existing
   stop-file and `MAX_CONT` checks, before `rm -f "$OUTCOME_FILE"`; all inside
   `if [ "$UNATTENDED" = "true" ]`:

   ```sh
   _now="$(date +%s)"
   if [ "$_now" -ge "$DEADLINE_EPOCH" ]; then
     log_event "{\"type\":\"self_continue_wall_clock\",\"stage\":\"pre-spawn\",...}"
     echo "SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=pre-spawn elapsed_s=$((_now-RUN_START_EPOCH)) cap_s=$WALL_S continuations=$cont progress=$progress"
     exit 0
   fi
   SEG_SPENT_BEFORE="$(envelope_spent_total "$LEDGER")"
   if <awk: SEG_SPENT_BEFORE + RESERVE_USD > BUDGET_USD>; then
     log_event "{\"type\":\"self_continue_budget\",\"stage\":\"pre-spawn\",...}"
     echo "SELF_CONTINUE:BUDGET_EXCEEDED stage=pre-spawn spent=$SEG_SPENT_BEFORE reserve=$RESERVE_USD cap=$BUDGET_USD continuations=$cont progress=$progress"
     exit 0
   fi
   SEG_ID="$(envelope_next_segment "$LEDGER")"
   envelope_reserve "$LEDGER" "$SEG_ID" "$RESERVE_USD"
   SEG_REMAINING_USD="<awk: BUDGET_USD - SEG_SPENT_BEFORE>"
   COST_BASELINE_LINES=0
   [ -f "$COST_LOG" ] && COST_BASELINE_LINES="$(wc -l < "$COST_LOG" | tr -d ' ')"
   ```

   Reserve is written to disk BEFORE the spawn (FR-8 ordering — a driver crash between
   reserve and reconcile leaves the reserve spent).

5. **Post-segment reconcile + kill-reason terminals** — immediately after the existing
   P02 CHILD_ABORT-marker block (keep that block byte-identical), inside the unattended guard:

   ```sh
   _actual="$(envelope_parse_total_cost "$RESULT_FILE")"
   if [ -n "$_actual" ]; then
     envelope_reconcile "$LEDGER" "$SEG_ID" "$_actual" "total_cost_usd"
   else
     _obs="$(envelope_observed_cost "$COST_LOG" "$COST_BASELINE_LINES")"
     _forfeit="<awk: max(RESERVE_USD, _obs)>"
     envelope_forfeit "$LEDGER" "$SEG_ID" "$_forfeit" "unreconciled"
   fi
   if [ -f "$REASON_FILE" ]; then
     _reason_line="$(cat "$REASON_FILE")"; rm -f "$REASON_FILE"
     _reason="$(printf '%s' "$_reason_line" | awk '{print $1}')"
     _spent_now="$(envelope_spent_total "$LEDGER")"
     case "$_reason" in
       budget-exceeded)
         log_event ...; echo "SELF_CONTINUE:BUDGET_EXCEEDED stage=mid-segment spent=$_spent_now $_rest cap=$BUDGET_USD continuations=$cont progress=$progress"; exit 0 ;;
       wall-clock-exceeded)
         log_event ...; echo "SELF_CONTINUE:WALL_CLOCK_EXCEEDED stage=mid-segment $_rest continuations=$cont progress=$progress"; exit 0 ;;
       stop-file)
         log_event ...; echo "SELF_CONTINUE:STOPPED reason=stop-file stage=mid-segment continuations=$cont progress=$progress"; exit 0 ;;
     esac
   fi
   ```

   (`$_rest` = the detail words the watchdog wrote after the reason word, e.g.
   `observed=6.00 spent_before=0 cap=5`.) Kill-reason consumption happens AFTER reconcile so
   the ledger is complete at terminal time, and BEFORE the marker/`STALLED`/`CHILD_ABORT`
   emission path so the envelope terminal takes precedence over a generic `CHILD_ABORT`
   line for envelope-initiated kills. The marker file itself keeps whatever the P02 wrapper
   wrote (`child_abort` on rc>=128) — that block is untouched; only the driver's terminal
   line changes for envelope kills.

6. **Thrash terminal** — in the `*AUTO:SELF_CONTINUE*` decision branch: initialize
   `no_prog=0` beside `cont=0`; after the existing progress-increment logic, add (guarded):

   ```sh
   if [ "$UNATTENDED" = "true" ]; then
     if <progress incremented this segment>; then no_prog=0; else no_prog=$((no_prog+1)); fi
     if [ "$no_prog" -ge "$THRASH_N" ]; then
       log_event "{\"type\":\"self_continue_thrash\",\"no_progress_segments\":$no_prog,...}"
       echo "SELF_CONTINUE:THRASH no_progress_segments=$no_prog threshold=$THRASH_N continuations=$cont progress=$progress"
       exit 0
     fi
   fi
   ```

   Implementation detail: capture whether progress incremented by comparing `$progress`
   before/after the existing `if [ -n "$PHASE" ] ...` block. THRASH halts INSTEAD of
   emitting `SCHEDULED` for that continuation (place the check before the `SCHEDULED`
   echo). Attended runs never evaluate it (FR-12 is unattended-only).

7. **Header comment** — extend the file header: new flags, the D016 wall-clock resolution,
   the three new dotfiles, the new terminal lines, the env-export contract, and the
   ledger-reset-by-deletion operator note.

8. **Author `tools/verify/m046-p04-fail-closed.sh`** (SC-8; `#!/usr/bin/env sh`, `set -eu`,
   mktemp scratch, PASS/FAIL counters, `SUMMARY:` line — P02 verifier shape). Cases, each
   invoking the driver DIRECTLY (`sh scripts/lifecycle/self-continue-drive.sh <scratch-M> ...`,
   which IS the bypass-the-CLI path SC-8 requires), each with a stub `--auto-cmd` child that
   touches a sentinel file so "no spawn" is assertable:

   - `--unattended` with NO caps → exit 2, output has `SELF_CONTINUE:REFUSE` and
     `caps-unset` and all three names (`budget`, `continuations`, `wall-clock`); sentinel
     absent; no ledger file created.
   - `--unattended --max-continuations 3 --max-wall-clock-s 60` (budget missing) → refuse,
     `missing=budget` only.
   - `--unattended --max-budget-usd 5 --max-wall-clock-s 60` (continuations missing —
     proves the silent `MAX_CONT=20` default is DEAD on the unattended path) → refuse,
     `missing=continuations`.
   - `--unattended --max-budget-usd 5 --max-continuations 3` (wall-clock missing) → refuse,
     `missing=wall-clock`.
   - `--unattended --max-budget-usd abc --max-continuations 3 --max-wall-clock-s 60` →
     exit 2, `caps-invalid`, sentinel absent.
   - All three caps valid + trivial child (writes `complete` marker, prints
     `{"total_cost_usd":0.01}`, touches sentinel, exit 0) → exit 0, sentinel PRESENT,
     `SELF_CONTINUE:TERMINAL outcome=complete` — proves refusal is cap-driven, not
     flag-driven.
   - Attended control: same missing-caps invocation WITHOUT `--unattended` → runs (sentinel
     present), no `REFUSE` line — FR-6/FR-17: the gate binds only the unattended path.

9. **Author `tools/verify/m046-p04-attended-parity.sh`** — FR-17 wrapper: runs
   `bash tools/verify/m046-p02-legacy-parity.sh`, `bash tools/verify/m046-p02-child-abort.sh`,
   `bash tools/verify/m046-p02-driver-continue-class.sh`,
   `bash tools/verify/m046-p02-injection-reject.sh` from `REPO_ROOT` (cd first — P02 suite
   precedent), reports per-member PASS/FAIL + `SUMMARY:` line, exit 1 on any member failure.

10. `chmod +x` both new verifiers. Run all Verification commands.

## Must-Haves

- Fail-closed refuse-to-start in the driver, no silent MAX_CONT default on the unattended path (phase Truth 1)
  - Check: `bash tools/verify/m046-p04-fail-closed.sh`
- Attended driver path behaviorally unchanged — four P02 verifiers green (phase Truth 8)
  - Check: `bash tools/verify/m046-p04-attended-parity.sh`
- Artifact: scripts/lifecycle/self-continue-drive.sh (min 230 lines, contains "SELF_CONTINUE:REFUSE")
- Artifact: tools/verify/m046-p04-fail-closed.sh (min 60 lines, contains "caps-unset")
- Artifact: tools/verify/m046-p04-attended-parity.sh (min 20 lines, contains "m046-p02-legacy-parity")
- Key Link: scripts/lifecycle/self-continue-drive.sh → scripts/lifecycle/unattended-envelope.sh

## Verification

```bash
bash tools/verify/m046-p04-fail-closed.sh
bash tools/verify/m046-p04-attended-parity.sh
bash tools/verify/m046-p04-envelope-unit.sh
sh -n scripts/lifecycle/self-continue-drive.sh
```

## Notes

Expected: both new verifiers end `SUMMARY: pass=N fail=0` exit 0; the parity wrapper shows
all four P02 members PASS; the T01 unit verifier stays green (no library regression);
`sh -n` silent.

Watchdog/terminal behavioral coverage (SC-3/SC-4/SC-6/SC-7 and the wall-clock legs) is
deliberately NOT verified in this task — T03/T04 author those harnesses against the surface
this task lands. Keep this task's scope to: gate, wiring, terminals, thrash, parity.

If any P02 verifier fails after the edit, the FR-17 invariant is broken — fix the driver,
do not touch the P02 verifiers or goldens.

## Inputs

### From Previous Tasks

- `scripts/lifecycle/unattended-envelope.sh` (from T01)
  - Key API: the 11 `envelope_*` functions with contracts as specified in
    `T01-envelope-lib-PLAN.md` step 1 (arguments, stdout shapes, fail-closed semantics).
  - Key behavior: `envelope_caps_problems` returns `ok` / `caps-unset missing=<csv>` /
    `caps-invalid invalid=<csv>`; `envelope_watchdog` blocks until the child dies and
    writes the kill-reason file atomically BEFORE `kill -9`; `envelope_spent_total`
    counts bare reserves as spent.

### From Disk (Pre-existing)

- `scripts/lifecycle/self-continue-drive.sh` — the file to modify (P02 shape: charset gate
  ~lines 40–48, flag loop ~50–60, `run_child` ~66–79, main loop ~92–150).
- `tools/verify/m046-p02-*.sh` (4 files) — attended-parity regression oracle, invoked by the
  new wrapper.

## Constraints

- CON-2: `scripts/lifecycle/auto-loop.sh` MUST NOT be modified.
- FR-17: attended behavior byte-compatible — all new runtime paths guarded by
  `UNATTENDED=true`; the attended `run_child` line and the P02 CHILD_ABORT block stay
  byte-identical.
- FR-6: `--unattended` is the ONLY activation; no config read may enable it.
- POSIX sh (`#!/usr/bin/env sh`, `set -eu`), bash-3.2-safe.
- Verifiers create scratch trees via mktemp only; never write into the repo tree or
  `.orchestrator/` state.

## Expected Output

Envelope-integrated `self-continue-drive.sh` (attended parity green), plus
`tools/verify/m046-p04-fail-closed.sh` and `tools/verify/m046-p04-attended-parity.sh`,
all green.
