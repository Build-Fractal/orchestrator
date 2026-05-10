---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P03"
milestone: "M004"
name: "run.sh — Context Assembly Pipeline Integration (Build / Compress / Select-Model)"
depends_on: [T03]
---

## Description

Edit `scripts/engine/run.sh` to wire the three existing dispatch scripts into the task loop — `scripts/dispatch/build-context.sh`, `scripts/dispatch/compress-payload.sh`, `scripts/dispatch/select-model.sh`. After this task, per iteration the engine:

1. Builds a dispatch payload for the current task via `build-context.sh`.
2. Pipes that payload through `compress-payload.sh` with a budget derived from the selected model.
3. Runs `select-model.sh standard` to resolve model id + context budget from `templates/routing.yaml`.
4. Emits `DISPATCH_START model=<id> tokens_estimated=<n> payload_bytes=<b>` and — in real mode — invokes the agent (placeholder for this phase; the real agent call is beyond M004 scope).
5. In `--dry-run`, skips the agent call but still emits `DISPATCH_START dry_run=1`.

Temp files are cleaned via the existing `trap` on EXIT (extended here to clean multiple paths). All stages are failure-tolerant: if any script exits non-zero, the engine emits `emit_event SAFETY_WARNING reason=<stage>_failed` and the task is marked `TASK_COMPLETE outcome=failed`; the overall run exit is degraded (incremented `_blocked`).

Token budget math: `build-context.sh` writes a payload of `$payload_bytes` bytes. A cheap estimate is `$((payload_bytes / 4))` tokens — this is not precise but matches `compress-payload.sh`'s own estimator (see its `estimate_tokens` function comment: "chars / 4, rounded to nearest 100"). The engine uses the compressed payload's byte count for `tokens_estimated` in the DISPATCH_START event.

## Steps

### Step 1: Confirm T03 is complete

```bash
grep -q 'guard_payload_sanity' scripts/engine/run.sh || { echo "FAIL: run T03 first"; exit 1; }
```

### Step 2: Extend the EXIT trap for multiple temp files

Near the top of `scripts/engine/run.sh`, find the existing line:
```bash
trap 'rm -f "$_pending_tmp"' EXIT
```

Replace it with:
```bash
# --- Temp files cleaned on any exit ---
_payload_file=""
_compressed_file=""
trap '
  rm -f "$_pending_tmp" 2>/dev/null
  [ -n "$_payload_file" ]     && rm -f "$_payload_file"     2>/dev/null
  [ -n "$_compressed_file" ]  && rm -f "$_compressed_file"  2>/dev/null
' EXIT
```

### Step 3: Call `select-model.sh` once, before the task loop

Add the following block after the budget accumulators and before `while IFS= read -r task_id; do`:

```bash
# --- T04: Resolve model + context budget from routing.yaml ---
# For T04, all tasks use the "standard" tier. Future tiers (heavy/light) can be
# parameterized by classify-complexity.sh output — see P05 for the recipe-driven
# refactor. The engine reads the model id and budget once per session.
_model_budget_line=""
if _model_budget_line="$(bash scripts/dispatch/select-model.sh standard --routing-config templates/routing.yaml 2>/dev/null)"; then
  _selected_model="$(printf '%s' "$_model_budget_line" | awk '{print $1}')"
  _context_budget="$(printf '%s' "$_model_budget_line" | awk '{print $2}')"
  : "${_selected_model:=claude-sonnet-4-6}"
  : "${_context_budget:=150000}"
else
  _selected_model="claude-sonnet-4-6"
  _context_budget="150000"
  emit_event SAFETY_WARNING reason="select_model_fallback" tier="standard"
fi
emit_event SAFETY_WARNING reason="model_selected" model="$_selected_model" budget="$_context_budget"
```

Note: the second `SAFETY_WARNING reason="model_selected"` is deliberately a warning, not a new event type — the canonical 19-entry registry in events.sh does not include `MODEL_SELECTED`, and we do not want to trigger the unknown-type companion warning machinery. A `SAFETY_WARNING` at startup is the correct observability surface for "here is what the engine picked."

### Step 4: Insert context-assembly pipeline inside the task loop

After the pre-dispatch guards (from T03) and BEFORE the `if orch_is_dry_run; then ... else ... fi` block, insert:

```bash
  # --- T04: Context assembly pipeline ---
  _payload_file="$(mktemp)"
  _compressed_file="$(mktemp)"

  if ! bash scripts/dispatch/build-context.sh .specify/orchestrator "$ENGINE_MILESTONE" "$ENGINE_PHASE" "$task_id" > "$_payload_file" 2>/dev/null; then
    emit_event SAFETY_WARNING reason="build_context_failed" task="$task_id"
    _blocked=$((_blocked + 1))
    emit_event TASK_COMPLETE task="$task_id" outcome="failed" reason="build_context"
    rm -f "$_payload_file" "$_compressed_file"
    _payload_file=""; _compressed_file=""
    continue
  fi

  if ! bash scripts/dispatch/compress-payload.sh --budget "$_context_budget" --input "$_payload_file" > "$_compressed_file" 2>/dev/null; then
    emit_event SAFETY_WARNING reason="compress_failed" task="$task_id"
    _blocked=$((_blocked + 1))
    emit_event TASK_COMPLETE task="$task_id" outcome="failed" reason="compress"
    rm -f "$_payload_file" "$_compressed_file"
    _payload_file=""; _compressed_file=""
    continue
  fi

  # Replace _payload_file with the compressed file for guard_payload_sanity
  # (T03 uses $_payload_file). The rest of the pipeline operates on the
  # compressed variant from here forward.
  _payload_file="$_compressed_file"
  _compressed_file=""

  _payload_bytes=$(wc -c < "$_payload_file" 2>/dev/null | tr -d ' ')
  _tokens_est=$(( _payload_bytes / 4 ))

  # --- T04: DISPATCH_START event (also fires in dry-run mode) ---
  if orch_is_dry_run; then
    emit_event DISPATCH_START task="$task_id" model="$_selected_model" \
      tokens_estimated="$_tokens_est" payload_bytes="$_payload_bytes" dry_run=1
  else
    emit_event DISPATCH_START task="$task_id" model="$_selected_model" \
      tokens_estimated="$_tokens_est" payload_bytes="$_payload_bytes"
  fi
```

Important: the pre-dispatch guard block from T03 referenced `_payload_file`. Because T04 now sets `_payload_file` earlier in the same loop iteration, the guard sees a real file in real mode. In dry-run mode, T03's `dry_run_guard_skipped` branch still short-circuits the guard.

BUT — the execution order in the loop becomes:
1. `run_hooks PRE_DISPATCH` (T02)
2. T04 context-build / compress (this task)
3. T03 pre-dispatch guards (payload_sanity, budget)
4. T03 post-dispatch output-sanity guard (still a placeholder; T05 wires real output)
5. T02 dry-run / real-dispatch placeholder
6. T05 verify / record / checkpoint (coming)

This order violates the conceptual "guards before expensive work" rule because build-context is already expensive. To preserve the correct order, **T04 must insert the context-assembly block AFTER `run_hooks PRE_DISPATCH` but BEFORE the T03 guard block** — i.e., swap the T03 guard placement so guards run after payload exists. Specifically:

**Re-organize the task loop body as:**
```
1. emit_event TASK_START
2. run_hooks PRE_DISPATCH
3. T04 context build + compress (sets $_payload_file)
4. T03 guards (payload_sanity uses $_payload_file, budget runs)
5. emit_event DISPATCH_START
6. dry-run skip OR real dispatch → $_output_file
7. T03 output-sanity guard
8. T05 verify / record / checkpoint (coming)
9. emit_event TASK_COMPLETE
```

If T03 placed its guards before the T04 insertion point, **move** the T03 block to be after the T04 context-assembly block. This is a mechanical move — the guard logic itself is unchanged.

### Step 5: Replace the dry-run / real-dispatch placeholder

Find the existing block left by T02:

```bash
  if orch_is_dry_run; then
    emit_event TASK_COMPLETE task="$task_id" outcome="dry_run" phase="$ENGINE_PHASE"
  else
    emit_event TASK_COMPLETE task="$task_id" outcome="skeleton_noop" phase="$ENGINE_PHASE"
  fi
```

Replace it with:

```bash
  # --- T04: Dispatch (real mode) / dry-run skip ---
  _output_file="$(mktemp)"
  if orch_is_dry_run; then
    printf 'dry-run: %s %s %s\n' "$ENGINE_MILESTONE" "$ENGINE_PHASE" "$task_id" > "$_output_file"
    emit_event SAFETY_WARNING reason="dispatch_skipped_dry_run" task="$task_id"
  else
    # Real agent dispatch is out of M004 scope — the engine writes a stub so the
    # downstream output-sanity guard and verify/record pipeline can observe a
    # non-empty file. P05+ will replace this with an actual model call.
    printf 'stub-dispatch: %s %s %s (agent invocation not implemented in M004)\n' \
      "$ENGINE_MILESTONE" "$ENGINE_PHASE" "$task_id" > "$_output_file"
    emit_event SAFETY_WARNING reason="dispatch_stub" task="$task_id"
  fi
```

After T04, the T05 task will add the verify + record + checkpoint steps and the final `TASK_COMPLETE` emission for the success path. For T04, emit `TASK_COMPLETE` provisionally at the end of the task loop so the invariant "every task iteration ends with exactly one TASK_COMPLETE event" is preserved:

Find the end of the loop body (after T03's output-sanity block) and ensure the following is present:

```bash
  # --- T04 provisional TASK_COMPLETE (T05 may replace this with verify-gated outcome) ---
  emit_event TASK_COMPLETE task="$task_id" outcome="dispatched" \
    model="$_selected_model" tokens_estimated="$_tokens_est"

  _completed=$((_completed + 1))

  # Cleanup task-scoped temp files
  rm -f "$_payload_file" "$_output_file" 2>/dev/null
  _payload_file=""; _output_file=""
```

Note: the T02 skeleton already had a `TASK_COMPLETE dry_run` emit. T04 replaces that single emission with the block above. Make sure only ONE `TASK_COMPLETE` fires per task iteration (the blocked-path `continue` statements from T03 already emit their own blocked-outcome `TASK_COMPLETE` and then `continue`, so they are not double-counted).

### Step 6: Verify

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== T04 Verification ==="
bash -n scripts/engine/run.sh && echo "PASS: syntax" || { echo "FAIL: syntax"; exit 1; }

# All three dispatch scripts are referenced
grep -q 'scripts/dispatch/build-context.sh'   scripts/engine/run.sh && echo "PASS: build-context"   || echo "FAIL"
grep -q 'scripts/dispatch/compress-payload.sh' scripts/engine/run.sh && echo "PASS: compress-payload" || echo "FAIL"
grep -q 'scripts/dispatch/select-model.sh'    scripts/engine/run.sh && echo "PASS: select-model"   || echo "FAIL"

# DISPATCH_START event emitted
grep -q 'emit_event DISPATCH_START' scripts/engine/run.sh && echo "PASS: DISPATCH_START"            || echo "FAIL"

# Temp file cleanup
grep -q '_payload_file'     scripts/engine/run.sh && echo "PASS: payload tmp var"    || echo "FAIL"
grep -q '_compressed_file'  scripts/engine/run.sh && echo "PASS: compressed tmp var" || echo "FAIL"
grep -q '_output_file'      scripts/engine/run.sh && echo "PASS: output tmp var"     || echo "FAIL"

# Dry-run invocation still passes
ORCH_RUN_SEED='t04-dry' ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 >/tmp/t04-dry.out 2>&1
rc=$?
test "$rc" -eq 0 && echo "PASS: dry-run exit 0" || echo "FAIL: exit $rc (see /tmp/t04-dry.out)"

# DISPATCH_START appears in event stream
grep -q '^EVENT:DISPATCH_START' /tmp/t04-dry.out && echo "PASS: DISPATCH_START event" || echo "FAIL"

# TASK_COMPLETE still fires per task
grep -q '^EVENT:TASK_COMPLETE' /tmp/t04-dry.out && echo "PASS: TASK_COMPLETE still present" || echo "FAIL"

# Final RESULT ok
tail -5 /tmp/t04-dry.out | grep -q '^RESULT:{"status":"ok"' && echo "PASS: RESULT ok" || echo "FAIL"

# No inline date introduced
! grep -nE '(^|[^A-Za-z_])date[[:space:]]' scripts/engine/run.sh && echo "PASS: no inline date" || echo "FAIL"

rm -f /tmp/t04-dry.out
echo "=== T04 complete ==="
```

## Must-Haves

### Truths

- `scripts/engine/run.sh` passes `bash -n` (still)
  - Check: `bash -n scripts/engine/run.sh`
- All three dispatch scripts are referenced by relative path
  - Check: `grep -q 'scripts/dispatch/build-context.sh' scripts/engine/run.sh && grep -q 'scripts/dispatch/compress-payload.sh' scripts/engine/run.sh && grep -q 'scripts/dispatch/select-model.sh' scripts/engine/run.sh`
- Engine emits `DISPATCH_START` events
  - Check: `grep -q 'emit_event DISPATCH_START' scripts/engine/run.sh`
- Engine cleans payload/compressed/output temp files (trap or explicit rm)
  - Check: `grep -q '_payload_file' scripts/engine/run.sh && grep -q '_output_file' scripts/engine/run.sh && grep -q 'rm -f' scripts/engine/run.sh`
- Dry-run invocation still exits 0
  - Check: `ORCH_RUN_SEED=t04-c ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 >/dev/null 2>&1`
- Dry-run invocation emits at least one `DISPATCH_START` event
  - Check: `ORCH_RUN_SEED=t04-c2 ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>&1 | grep -q '^EVENT:DISPATCH_START'`
- Dry-run invocation still emits `TASK_COMPLETE` and `PHASE_COMPLETE`
  - Check: `ORCH_RUN_SEED=t04-c3 ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>&1 | grep -q '^EVENT:TASK_COMPLETE' && ORCH_RUN_SEED=t04-c3b ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>&1 | grep -q '^EVENT:PHASE_COMPLETE'`

### Artifacts

- `scripts/engine/run.sh` (min 260 lines, contains "DISPATCH_START")

### Key Links

- `scripts/engine/run.sh` → `scripts/dispatch/build-context.sh`
- `scripts/engine/run.sh` → `scripts/dispatch/compress-payload.sh`
- `scripts/engine/run.sh` → `scripts/dispatch/select-model.sh`

## Verification

Run the Step 6 block from repo root. Every line must print `PASS:`. The dry-run invocation should still produce a final `RESULT:{"status":"ok"...}` even though `build-context.sh` may emit warnings (it is tolerant of mostly-empty task directories).

## Inputs

### From Previous Tasks

- `scripts/engine/run.sh` (from T02/T03)
  - T02 added arg parsing, session lifecycle events, task loop skeleton, `run_hooks PRE_DISPATCH`.
  - T03 added four guard references, budget accumulators, blocked-outcome handling.
  - T02/T03 left placeholder comments indicating where T04 should insert the context-assembly pipeline.
  - Uses `_pending_tmp`, `_completed`, `_blocked` vars; this task adds `_payload_file`, `_compressed_file`, `_output_file`, `_selected_model`, `_context_budget`, `_payload_bytes`, `_tokens_est`.

### From Disk (Pre-existing)

- `scripts/dispatch/build-context.sh` — `build-context.sh <orchestrator-root> <milestone-id> <phase-id> <task-id>` writes the assembled payload to stdout. Exits 1 on missing files. For this task, the engine invokes it as `bash scripts/dispatch/build-context.sh .specify/orchestrator M004 P03 T##`. The script is tolerant of not-yet-existing task plans in most cases; if it errors, the engine emits a SAFETY_WARNING and skips the task.
- `scripts/dispatch/compress-payload.sh` — `compress-payload.sh --budget TOKENS --input FILE` compresses the payload and writes the compressed result to stdout. Exits 0 on success. Stderr contains compression stats ("Compressed: X tokens -> Y tokens ...").
- `scripts/dispatch/select-model.sh` — `select-model.sh <tier> --routing-config <file>` writes `<model-id> <context-budget>` to stdout (two space-separated tokens). Tiers: heavy, standard, light. Exit 1 on invalid tier.
- `templates/routing.yaml` — already exists from P04 (extended with fallback chains). Contains `models.standard.id` and `models.standard.context_budget`.
- `scripts/lib/events.sh` — `DISPATCH_START` is in the canonical event registry. `SAFETY_WARNING` is also in the registry.

## Expected Output

Modified `scripts/engine/run.sh` at ≥260 lines with:
- Extended EXIT trap cleaning multiple temp files.
- `select-model.sh` call before the task loop producing `$_selected_model` and `$_context_budget`.
- Per-iteration context build + compress pipeline creating `$_payload_file` and `$_output_file`.
- `emit_event DISPATCH_START` emitted for every task (with `dry_run=1` in dry-run mode).
- Real-dispatch branch writes a stub output file (agent invocation is out of M004 scope).
- Exactly ONE `TASK_COMPLETE` event per task iteration regardless of path (dry-run, real, blocked, failed).
- The T03 guard block has been relocated (if necessary) to run AFTER the T04 context-build block, so `guard_payload_sanity "$_payload_file"` sees a real file.

NO changes to any file outside `scripts/engine/run.sh`. NO changes to the dispatch scripts themselves — P05 owns that refactor.
