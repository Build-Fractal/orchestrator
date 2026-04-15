---
schema_version: "1.0"
type: task-plan
task: "T06"
phase: "P03"
milestone: "M004"
name: "Crash Recovery End-to-End Verification Harness"
depends_on: [T05]
---

## Description

Create `scripts/engine/test-resume.sh`, a self-contained end-to-end verification script that proves the crash-recovery path works. This is the only task in P03 that is allowed to add a verification helper — it consolidates the behavior introduced by T01 (checkpoint library), T02 (resume event seam), and T05 (checkpoint_write / checkpoint_clear / resume-skip logic) into one provable scenario:

1. Clean any stale checkpoint.
2. Run the engine in dry-run mode with `ORCH_ENGINE_STOP_AFTER_TASK=T01` — simulates a crash after the first task is completed.
3. Assert the checkpoint file exists and its `last_task` field is `T01`.
4. Re-run the engine in dry-run mode WITHOUT the stop-after env var.
5. Assert the second run emits `CHECKPOINT_RESUME` and at least one `SAFETY_WARNING reason=resume_skip` event (since task T01 is already done).
6. Assert the checkpoint file is cleared after the full re-run (or not, if blocked — accept either state but assert the behavior matches the observed outcome).
7. Emit a final `RESULT:{"status":"ok",...}` on success or `RESULT:{"status":"error","error_kind":"VERIFY",...}` on any assertion failure.

The test script itself sources `scripts/lib/errors.sh` + `scripts/lib/events.sh` + `scripts/lib/run-context.sh` + `scripts/engine/checkpoint.sh`, emits at least one `EVENT:` line (per Principle II), and ends with exactly one `RESULT:` line (per FR-220 / US8 AS2).

## Steps

### Step 1: Confirm T01–T05 are complete

```bash
test -f scripts/engine/checkpoint.sh            || { echo "FAIL: run T01"; exit 1; }
test -f scripts/engine/run.sh                   || { echo "FAIL: run T02"; exit 1; }
grep -q 'ORCH_ENGINE_STOP_AFTER_TASK' scripts/engine/run.sh || { echo "FAIL: run T02 (stop-after hook)"; exit 1; }
grep -q 'checkpoint_write' scripts/engine/run.sh            || { echo "FAIL: run T05"; exit 1; }
```

### Step 2: Write `scripts/engine/test-resume.sh`

```bash
#!/usr/bin/env bash
# scripts/engine/test-resume.sh — End-to-end crash-recovery verification harness.
set -euo pipefail

_trh_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
. "${_trh_dir}/../lib/errors.sh"
# shellcheck disable=SC1090
. "${_trh_dir}/../lib/events.sh"
# shellcheck disable=SC1090
. "${_trh_dir}/../lib/run-context.sh"
# shellcheck disable=SC1090
. "${_trh_dir}/checkpoint.sh"

MILESTONE="${1:-M004}"
PHASE="${2:-P03}"
CHECKPOINT_FILE=".specify/orchestrator/milestones/${MILESTONE}/engine-checkpoint.json"

# Deterministic run context for this test.
export ORCH_RUN_SEED="test-resume-${MILESTONE}-${PHASE}"
init_run_context "$MILESTONE" "$PHASE"

emit_event SESSION_START milestone="$MILESTONE" phase="$PHASE" test="resume_e2e"

_fail() {
  local reason="$1"
  emit_event SAFETY_WARNING reason="test_failure" detail="$reason"
  emit_result error VERIFY "$reason"
  exit 1
}

# --- Step 1: Clean stale checkpoint ---
rm -f "$CHECKPOINT_FILE"

# --- Step 2: First run with simulated crash after T01 ---
out1="$(ORCH_ENGINE_STOP_AFTER_TASK=T01 ORCH_RUN_SEED="${ORCH_RUN_SEED}-run1" ORCH_DRY_RUN=1 \
  bash "${_trh_dir}/run.sh" --dry-run "$MILESTONE" "$PHASE" 2>&1 || true)"

# Assert: checkpoint exists
if ! checkpoint_detect "$MILESTONE"; then
  _fail "checkpoint not written after simulated crash (expected $CHECKPOINT_FILE)"
fi

# Assert: last_task == T01
last="$(checkpoint_read "$MILESTONE" last_task || true)"
if [ "$last" != "T01" ]; then
  _fail "checkpoint last_task is '$last', expected 'T01'"
fi

emit_event SAFETY_WARNING reason="phase1_passed" checkpoint="$CHECKPOINT_FILE" last_task="$last"

# --- Step 3: Second run WITHOUT stop-after → should resume ---
out2="$(ORCH_RUN_SEED="${ORCH_RUN_SEED}-run2" ORCH_DRY_RUN=1 \
  bash "${_trh_dir}/run.sh" --dry-run "$MILESTONE" "$PHASE" 2>&1 || true)"

# Assert: second run emitted CHECKPOINT_RESUME
if ! printf '%s\n' "$out2" | grep -q '^EVENT:CHECKPOINT_RESUME'; then
  printf '%s\n' "$out2" >&2
  _fail "second run did not emit CHECKPOINT_RESUME"
fi

# Assert: second run emitted at least one resume_skip (T01 is already done)
if ! printf '%s\n' "$out2" | grep -q 'reason="resume_skip"'; then
  printf '%s\n' "$out2" >&2
  _fail "second run did not emit resume_skip SAFETY_WARNING"
fi

emit_event SAFETY_WARNING reason="phase2_passed"

# --- Step 4: Cleanup — clear any lingering checkpoint ---
rm -f "$CHECKPOINT_FILE"

emit_event SESSION_END milestone="$MILESTONE" phase="$PHASE" test="resume_e2e" result="ok"
emit_result ok "" "resume E2E passed for ${MILESTONE}/${PHASE}"
exit 0
```

### Step 3: Make executable

```bash
chmod +x scripts/engine/test-resume.sh
```

### Step 4: Run the harness

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== T06 Verification ==="
bash -n scripts/engine/test-resume.sh && echo "PASS: syntax" || { echo "FAIL"; exit 1; }

# Happy path
bash scripts/engine/test-resume.sh M004 P03 >/tmp/t06-resume.out 2>&1
rc=$?
test "$rc" -eq 0 && echo "PASS: resume E2E passed" || { echo "FAIL: exit $rc"; cat /tmp/t06-resume.out; exit 1; }

# Events in the harness output
grep -q '^EVENT:SESSION_START' /tmp/t06-resume.out && echo "PASS: SESSION_START emitted" || echo "FAIL"
grep -q '^EVENT:SESSION_END'   /tmp/t06-resume.out && echo "PASS: SESSION_END emitted"   || echo "FAIL"

# RESULT line
tail -3 /tmp/t06-resume.out | grep -q '^RESULT:{"status":"ok"' && echo "PASS: RESULT ok" || echo "FAIL"

# Idempotency: second run of the harness should also pass
bash scripts/engine/test-resume.sh M004 P03 >/tmp/t06-resume2.out 2>&1
rc2=$?
test "$rc2" -eq 0 && echo "PASS: idempotent" || echo "FAIL: second run exit $rc2"

rm -f /tmp/t06-resume.out /tmp/t06-resume2.out .specify/orchestrator/milestones/M004/engine-checkpoint.json
echo "=== T06 complete ==="
```

## Must-Haves

### Truths

- `scripts/engine/test-resume.sh` exists and passes `bash -n`
  - Check: `bash -n scripts/engine/test-resume.sh`
- The harness sources errors.sh, events.sh, run-context.sh, and checkpoint.sh
  - Check: `grep -q 'lib/errors.sh' scripts/engine/test-resume.sh && grep -q 'lib/events.sh' scripts/engine/test-resume.sh && grep -q 'lib/run-context.sh' scripts/engine/test-resume.sh && grep -q 'engine/checkpoint.sh' scripts/engine/test-resume.sh`
- The harness calls `emit_result` exactly once at each exit path
  - Check: `grep -q 'emit_result' scripts/engine/test-resume.sh`
- The harness uses `ORCH_ENGINE_STOP_AFTER_TASK` to simulate a crash
  - Check: `grep -q 'ORCH_ENGINE_STOP_AFTER_TASK' scripts/engine/test-resume.sh`
- The harness asserts the checkpoint was written and `last_task=T01`
  - Check: `grep -q 'checkpoint_detect' scripts/engine/test-resume.sh && grep -q 'checkpoint_read' scripts/engine/test-resume.sh`
- The harness greps the second run's output for `CHECKPOINT_RESUME`
  - Check: `grep -q 'CHECKPOINT_RESUME' scripts/engine/test-resume.sh`
- No inline `date` calls
  - Check: `! grep -nE '(^|[^A-Za-z_])date[[:space:]]' scripts/engine/test-resume.sh`
- Bash 3.2 compatible
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/engine/test-resume.sh && ! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/engine/test-resume.sh`
- Running the harness from repo root exits 0
  - Check: `bash scripts/engine/test-resume.sh M004 P03 >/dev/null 2>&1`
- The harness is idempotent — running it twice back-to-back both succeed
  - Check: `bash scripts/engine/test-resume.sh M004 P03 >/dev/null 2>&1 && bash scripts/engine/test-resume.sh M004 P03 >/dev/null 2>&1`

### Artifacts

- `scripts/engine/test-resume.sh` (min 60 lines, contains "ORCH_ENGINE_STOP_AFTER_TASK")

### Key Links

- `scripts/engine/test-resume.sh` → `scripts/engine/run.sh` (harness invokes the engine)
- `scripts/engine/test-resume.sh` → `scripts/engine/checkpoint.sh` (harness uses checkpoint_detect/read)

## Verification

Run the Step 4 block from repo root. Every line must `PASS:`. If the second engine invocation does not emit `CHECKPOINT_RESUME`, the most likely root cause is that T05's resume-skip logic was not wired correctly — inspect `scripts/engine/run.sh` for the `_resume_from` branch near the top of the task loop.

## Inputs

### From Previous Tasks

- `scripts/engine/run.sh` (from T02–T05)
  - Honors `ORCH_ENGINE_STOP_AFTER_TASK=T##` by emitting `SAFETY_WARNING reason="debug_stop_after_task"` and `break`-ing out of the task loop.
  - Writes checkpoint after each task boundary via `checkpoint_write`.
  - On startup, calls `checkpoint_detect` / `checkpoint_read` and sets `$_resume_from`.
  - In the task loop, if `$_resume_from` is non-empty, emits `SAFETY_WARNING reason="resume_skip"` and `continue`s until it reaches the boundary task, at which point it emits `resume_boundary_reached` and resumes normal execution.
- `scripts/engine/checkpoint.sh` (from T01)
  - `checkpoint_detect <milestone>` — returns 0 if a checkpoint exists.
  - `checkpoint_read <milestone> <field>` — returns the value for `run_id|milestone|phase|last_task|outcome|timestamp`.

### From Disk (Pre-existing)

- `scripts/lib/errors.sh`, `events.sh`, `run-context.sh` — P02 libraries sourced by the harness.
- `.specify/orchestrator/milestones/M004/phases/P03/tasks/` — this phase's own task plans; the engine iterates them during the test.

## Expected Output

A new file `scripts/engine/test-resume.sh` at ≥60 lines, executable, that:
- Cleans the milestone's checkpoint file before each test run.
- Runs the engine with `ORCH_ENGINE_STOP_AFTER_TASK=T01` → asserts checkpoint exists with `last_task=T01`.
- Runs the engine again without the stop-after env var → asserts `CHECKPOINT_RESUME` + `resume_skip` events in the stdout stream.
- Emits `SESSION_START` / `SESSION_END` events and exactly one `RESULT:{status...}` line.
- Exits 0 on success or 1 on any assertion failure, with `_fail` helper centralizing the error path through `emit_result error VERIFY`.

NO modifications to `scripts/engine/run.sh` or `scripts/engine/checkpoint.sh`. NO new library files. The harness is the only artifact this task creates.
