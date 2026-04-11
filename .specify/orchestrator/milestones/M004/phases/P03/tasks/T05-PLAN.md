---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P03"
milestone: "M004"
name: "run.sh — Verify / Record / Checkpoint Wiring + Dry-Run Path Completion"
depends_on: [T04]
---

## Description

Edit `scripts/engine/run.sh` to complete the pipeline after dispatch: run verification, call `run_hooks POST_VERIFY`, record the result to `execution-log.jsonl`, call `run_hooks POST_DISPATCH`, write a checkpoint, and — at phase end — call `run_hooks PRE_ADVANCE` and `checkpoint_clear`. This task finishes the engine's happy path.

After this task, the dry-run dispatch of `scripts/engine/run.sh --dry-run M004 P03` must:
- Emit `VERIFY_START`, `VERIFY_COMPLETE`, `CHECKPOINT_WRITE` events per task.
- Call `run_hooks POST_DISPATCH`, `run_hooks POST_VERIFY`, and `run_hooks PRE_ADVANCE` at the correct lifecycle points.
- Append one JSONL entry to the execution log per task (with `run_id` field populated for correlation).
- Write a checkpoint file to `.specify/orchestrator/milestones/M004/engine-checkpoint.json` after the first task boundary.
- On full phase success, `checkpoint_clear` removes the checkpoint.
- Emit exactly one final `RESULT:{...}` line.

Verification script invocation caveat: `scripts/verify/check-must-haves.sh <phase-dir>` has a PROJECT_ROOT detection bug when phase dirs live at `.specify/orchestrator/milestones/M###/phases/P##/` (P06 owns fixing it per the P02 summary). To avoid the bug, the engine must **always invoke check-must-haves.sh from the repo root** using `(cd "$REPO_ROOT" && bash scripts/verify/check-must-haves.sh "$PHASE_DIR")`. Do not try to fix the PROJECT_ROOT bug in this task — that is P06's work.

## Steps

### Step 1: Confirm T04 is complete

```bash
grep -q 'DISPATCH_START' scripts/engine/run.sh || { echo "FAIL: run T04 first"; exit 1; }
```

### Step 2: Compute `REPO_ROOT` once at session start

Add this line immediately after `init_run_context "$ENGINE_MILESTONE" "$ENGINE_PHASE"`:

```bash
# Repo root for verify/record helpers that misbehave from nested cwd (P06 owns the fix).
REPO_ROOT="$(cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" && pwd)"
EXECUTION_LOG=".specify/orchestrator/milestones/${ENGINE_MILESTONE}/execution-log.jsonl"
```

### Step 3: Wire verify + record after the dispatch output file exists

Find the T04 block that writes `$_output_file` (the stub-dispatch or dry-run printf). Immediately after it — and after the T03 output-sanity guard — insert:

```bash
  # --- T05: Verification stage ---
  emit_event VERIFY_START task="$task_id" phase="$ENGINE_PHASE"

  _verify_result="skipped"
  if orch_is_dry_run; then
    # Dry-run: we do not actually call check-must-haves.sh because the phase
    # summary does not exist yet. Emit a SAFETY_WARNING instead and treat the
    # verification as passed for the purposes of the loop continuing.
    emit_event SAFETY_WARNING reason="verify_skipped_dry_run" task="$task_id"
    _verify_result="skipped"
  else
    if (cd "$REPO_ROOT" && bash scripts/verify/check-must-haves.sh "$PHASE_DIR") >/tmp/engine-verify.$$.out 2>&1; then
      _verify_result="pass"
    else
      _verify_result="fail"
    fi
    cat /tmp/engine-verify.$$.out 2>/dev/null || true
    rm -f /tmp/engine-verify.$$.out
  fi

  emit_event VERIFY_COMPLETE task="$task_id" result="$_verify_result"

  # --- T05: POST_VERIFY hooks ---
  if ! run_hooks POST_VERIFY "$PHASE_DIR"; then
    _blocked=$((_blocked + 1))
    emit_event TASK_COMPLETE task="$task_id" outcome="blocked" reason="hook_post_verify"
    rm -f "$_payload_file" "$_output_file" 2>/dev/null
    _payload_file=""; _output_file=""
    continue
  fi

  # --- T05: Record result to execution log ---
  _record_outcome="success"
  if [ "$_verify_result" = "fail" ]; then
    _record_outcome="failure"
  fi
  if ! (cd "$REPO_ROOT" && bash scripts/lifecycle/record-result.sh "$EXECUTION_LOG" \
         --milestone="$ENGINE_MILESTONE" --phase="$ENGINE_PHASE" --task="$task_id" \
         --outcome="$_record_outcome" --verification_result="$_verify_result" \
         --model="$_selected_model" --payload_bytes="$_payload_bytes" \
         --dispatch_method="engine") >/dev/null 2>&1; then
    emit_event SAFETY_WARNING reason="record_result_failed" task="$task_id"
  fi

  # --- T05: POST_DISPATCH hooks (called after record so hooks see the final outcome) ---
  if ! run_hooks POST_DISPATCH "$PHASE_DIR"; then
    emit_event SAFETY_WARNING reason="hook_post_dispatch_warning" task="$task_id"
    # POST_DISPATCH failure does not block — warn only.
  fi

  # --- T05: Checkpoint after task boundary ---
  checkpoint_write "$ENGINE_MILESTONE" "$ENGINE_PHASE" "$task_id" "$_record_outcome" || true
```

### Step 4: Replace the provisional T04 `TASK_COMPLETE` emission

T04 emitted a provisional `TASK_COMPLETE task="$task_id" outcome="dispatched" ...`. Replace it with the verify-gated outcome:

```bash
  # --- T05: Final TASK_COMPLETE with verify-gated outcome ---
  emit_event TASK_COMPLETE task="$task_id" outcome="$_record_outcome" \
    model="$_selected_model" verify="$_verify_result" \
    tokens_estimated="$_tokens_est"

  _completed=$((_completed + 1))

  # Cleanup task-scoped temp files
  rm -f "$_payload_file" "$_output_file" 2>/dev/null
  _payload_file=""; _output_file=""
```

### Step 5: Wire PRE_ADVANCE hook before the pre-advance guard and checkpoint_clear on success

Find the existing T03 pre-advance `guard_phase_complete` call. Immediately BEFORE it, add:

```bash
# --- T05: PRE_ADVANCE hooks (last chance for Conversus to gate phase transition) ---
if ! run_hooks PRE_ADVANCE "$PHASE_DIR"; then
  emit_result error STATE "PRE_ADVANCE hook blocked phase completion"
  exit 6
fi
```

Immediately AFTER the `emit_event PHASE_COMPLETE ...` line, add:

```bash
# --- T05: Clear checkpoint on successful phase completion ---
if [ "$_blocked" -eq 0 ]; then
  checkpoint_clear "$ENGINE_MILESTONE"
fi
```

### Step 6: Handle resume-from-checkpoint in the task loop

Inside the task loop, immediately after `[ -z "$task_id" ] && continue`, add resume-skip logic. T02 set `$_resume_from` at session start; T05 now uses it:

```bash
  # --- T05: Resume skip — if a checkpoint says we already completed past this task, skip. ---
  if [ -n "${_resume_from:-}" ]; then
    if [ "$task_id" = "$_resume_from" ]; then
      # Found the boundary; clear _resume_from so subsequent tasks run.
      emit_event SAFETY_WARNING reason="resume_boundary_reached" task="$task_id"
      _resume_from=""
      continue
    fi
    # Still behind the resume boundary — skip this task.
    emit_event SAFETY_WARNING reason="resume_skip" task="$task_id"
    continue
  fi
```

### Step 7: Verify

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== T05 Verification ==="
bash -n scripts/engine/run.sh && echo "PASS: syntax" || { echo "FAIL"; exit 1; }

# Verify / record / checkpoint_write / checkpoint_clear all present
grep -q 'check-must-haves.sh'                      scripts/engine/run.sh && echo "PASS: verify"       || echo "FAIL"
grep -q 'record-result.sh'                         scripts/engine/run.sh && echo "PASS: record"       || echo "FAIL"
grep -q 'emit_event VERIFY_START'                  scripts/engine/run.sh && echo "PASS: VERIFY_START" || echo "FAIL"
grep -q 'emit_event VERIFY_COMPLETE'               scripts/engine/run.sh && echo "PASS: VERIFY_DONE"  || echo "FAIL"
grep -q 'checkpoint_write'                         scripts/engine/run.sh && echo "PASS: cp_write"     || echo "FAIL"
grep -q 'checkpoint_clear'                         scripts/engine/run.sh && echo "PASS: cp_clear"     || echo "FAIL"

# All 4 hook lifecycle points called
for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do
  grep -q "run_hooks ${p}" scripts/engine/run.sh && echo "PASS: run_hooks ${p}" || echo "FAIL: ${p}"
done

# Clean checkpoint before the test to guarantee the write happens
rm -f .specify/orchestrator/milestones/M004/engine-checkpoint.json

# Dry-run invocation still exits 0
ORCH_RUN_SEED='t05-dry' ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 >/tmp/t05-dry.out 2>&1
rc=$?
test "$rc" -eq 0 && echo "PASS: dry-run exit 0" || echo "FAIL: exit $rc (see /tmp/t05-dry.out)"

# Events present
grep -q '^EVENT:VERIFY_START'    /tmp/t05-dry.out && echo "PASS: VERIFY_START event"    || echo "FAIL"
grep -q '^EVENT:VERIFY_COMPLETE' /tmp/t05-dry.out && echo "PASS: VERIFY_COMPLETE event" || echo "FAIL"
grep -q '^EVENT:CHECKPOINT_WRITE' /tmp/t05-dry.out && echo "PASS: CHECKPOINT_WRITE event" || echo "FAIL"

# Checkpoint file created
# (checkpoint_clear is called on full success — so the file may or may not
# exist at the end of the dry-run depending on blocked count. For T05 we
# verify that it was written at some point by looking at the event log.)
grep -q '^EVENT:CHECKPOINT_WRITE' /tmp/t05-dry.out && echo "PASS: checkpoint was written" || echo "FAIL"

# Final RESULT ok
tail -5 /tmp/t05-dry.out | grep -q '^RESULT:' && echo "PASS: RESULT present" || echo "FAIL"

# No inline date
! grep -nE '(^|[^A-Za-z_])date[[:space:]]' scripts/engine/run.sh && echo "PASS: no inline date" || echo "FAIL"

rm -f /tmp/t05-dry.out
echo "=== T05 complete ==="
```

## Must-Haves

### Truths

- `scripts/engine/run.sh` passes `bash -n`
  - Check: `bash -n scripts/engine/run.sh`
- All 4 hook lifecycle points are invoked
  - Check: `for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do grep -q "run_hooks ${p}" scripts/engine/run.sh || exit 1; done && echo PASS`
- Verify / record / checkpoint wiring present
  - Check: `grep -q 'check-must-haves.sh' scripts/engine/run.sh && grep -q 'record-result.sh' scripts/engine/run.sh && grep -q 'checkpoint_write' scripts/engine/run.sh && grep -q 'checkpoint_clear' scripts/engine/run.sh`
- `VERIFY_START` and `VERIFY_COMPLETE` events are emitted
  - Check: `grep -q 'emit_event VERIFY_START' scripts/engine/run.sh && grep -q 'emit_event VERIFY_COMPLETE' scripts/engine/run.sh`
- Check-must-haves and record-result are invoked from `$REPO_ROOT` (not nested cwd)
  - Check: `grep -q 'cd "\$REPO_ROOT" && bash scripts/verify/check-must-haves.sh' scripts/engine/run.sh && grep -q 'cd "\$REPO_ROOT" && bash scripts/lifecycle/record-result.sh' scripts/engine/run.sh`
- Dry-run invocation exits 0
  - Check: `rm -f .specify/orchestrator/milestones/M004/engine-checkpoint.json; ORCH_RUN_SEED=t05-c ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 >/dev/null 2>&1`
- Dry-run emits `CHECKPOINT_WRITE` event
  - Check: `rm -f .specify/orchestrator/milestones/M004/engine-checkpoint.json; ORCH_RUN_SEED=t05-c2 ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>&1 | grep -q '^EVENT:CHECKPOINT_WRITE'`
- Dry-run emits `VERIFY_START` and `VERIFY_COMPLETE`
  - Check: `rm -f .specify/orchestrator/milestones/M004/engine-checkpoint.json; out=$(ORCH_RUN_SEED=t05-c3 ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>&1); echo "$out" | grep -q '^EVENT:VERIFY_START' && echo "$out" | grep -q '^EVENT:VERIFY_COMPLETE'`

### Artifacts

- `scripts/engine/run.sh` (min 300 lines, contains "checkpoint_write")

### Key Links

- `scripts/engine/run.sh` → `scripts/verify/check-must-haves.sh`
- `scripts/engine/run.sh` → `scripts/lifecycle/record-result.sh`

## Verification

Run the Step 7 block. Every line must `PASS:`. After the dry-run test, there may or may not be a lingering checkpoint file at `.specify/orchestrator/milestones/M004/engine-checkpoint.json` depending on whether the phase completed fully — that is expected behavior and is not part of the must-haves.

## Inputs

### From Previous Tasks

- `scripts/engine/run.sh` (from T02/T03/T04)
  - Loop variables available: `$task_id`, `$_payload_file`, `$_output_file`, `$_selected_model`, `$_payload_bytes`, `$_tokens_est`, `$_verify_result` (new), `$_record_outcome` (new).
  - `$_resume_from` is set at session start by T02's `checkpoint_read` call.
  - Placeholder comments from T02 indicated where T05 inserts verify/record/checkpoint wiring; those placeholders may have been consumed by T03/T04 edits — the insertion points are now:
    1. After the T04 `printf ... > "$_output_file"` block and T03 output-sanity guard.
    2. Before the T03 `guard_phase_complete "$PHASE_DIR"` call (PRE_ADVANCE hook).
    3. After the `emit_event PHASE_COMPLETE` line (checkpoint_clear).
- `scripts/engine/checkpoint.sh` (from T01) — provides `checkpoint_write`, `checkpoint_clear`, `checkpoint_read`, `checkpoint_detect`.

### From Disk (Pre-existing)

- `scripts/verify/check-must-haves.sh` — takes a `<phase-dir>` argument; exits 0 on pass, 1 on fail. KNOWN BUG: when invoked from a nested cwd, the PROJECT_ROOT auto-detection picks the wrong directory. The engine works around this by always `cd "$REPO_ROOT"` before invocation. P06 owns the actual fix — do not fix it here.
- `scripts/lifecycle/record-result.sh` — `<execution-log> --milestone=... --phase=... --task=... --outcome=success|failure|retry|blocked|... [--verification_result=...] [--model=...] [--payload_bytes=...] [--dispatch_method=engine]`. Appends one JSONL line to `<execution-log>`. Prints `RECORD:APPENDED <path>` to stdout on success.
- `scripts/lib/events.sh` — `VERIFY_START`, `VERIFY_COMPLETE`, `CHECKPOINT_WRITE`, `SAFETY_WARNING` are all in the canonical registry.
- `scripts/lib/hooks.sh` — `run_hooks POST_DISPATCH|POST_VERIFY|PRE_ADVANCE <state_source>`. All 4 lifecycle points are handled by the same function.
- `.specify/orchestrator/milestones/M004/execution-log.jsonl` — target log file; the engine passes its path via `$EXECUTION_LOG`.

## Expected Output

Modified `scripts/engine/run.sh` at ≥300 lines with:
- `REPO_ROOT` and `EXECUTION_LOG` computed once at session start.
- Verify stage with `VERIFY_START` / `VERIFY_COMPLETE` events and dry-run short-circuit.
- `run_hooks POST_VERIFY` after verification.
- `record-result.sh` called with run-context-populated fields.
- `run_hooks POST_DISPATCH` after record (warning-only on failure).
- `checkpoint_write` after each task boundary.
- `run_hooks PRE_ADVANCE` before `guard_phase_complete`.
- `checkpoint_clear` after `PHASE_COMPLETE` on full success.
- Resume-skip logic honoring `$_resume_from` at task-loop top.
- Exactly one `TASK_COMPLETE` per task iteration with `outcome="$_record_outcome"`.

NO changes to any file outside `scripts/engine/run.sh`. NO attempt to fix the PROJECT_ROOT bug in check-must-haves.sh (that is P06).
