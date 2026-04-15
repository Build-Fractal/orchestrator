---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M004"
name: "run.sh — Safety Rail Integration (Guards in the Task Loop)"
depends_on: [T02]
---

## Description

Edit `scripts/engine/run.sh` (created by T02) to wire the four P02 guards into the task loop at the correct precedence points. This task only modifies `scripts/engine/run.sh` — no other files are touched.

Guard placement order per FR-224 / US6:
1. `guard_payload_sanity <payload_file>` — pre-dispatch, before any agent call, blocks if payload is missing / empty / <100 chars.
2. `guard_budget <cum_cost_cents> <max_cost_cents> <cum_dur_sec> <max_dur_sec>` — pre-dispatch, blocks if cumulative spend exceeds caps.
3. `guard_output_sanity <output_file>` — post-dispatch, blocks if agent output is missing / empty / <100 chars.
4. `guard_phase_complete <phase_dir>` — pre-advance, blocks if the phase has no SUMMARY.md or no `## ` content section.

Every guard already:
- Returns 0 on pass or forced-override.
- Returns non-zero on block.
- Emits `GUARD_BLOCKED` on block, or `GUARD_WARNING forced=1` under `ORCH_FORCE`.
- Is Bash-3.2-compatible.

So this task is purely wiring + block-path handling.

Dry-run special case: payload / output files do not exist in dry-run mode. Guards must be short-circuited. The engine emits `SAFETY_WARNING reason=dry_run_guard_skipped guard=<name>` for auditability, then proceeds as if the guard had passed. `guard_phase_complete` still runs in dry-run because the phase directory is always present.

Budget tracking: introduce four integer accumulators (`_cum_cost_cents`, `_max_cost_cents`, `_cum_dur_sec`, `_max_dur_sec`). For T03 they are hard-coded to 0 caps (disabled — `guard_budget` treats 0 as "disabled"); T05 may wire real values from config, but that is not required for this task.

Block-path handling: when any pre-dispatch guard returns non-zero, the engine:
- Emits `TASK_COMPLETE task=<id> outcome=blocked reason=<guard_name>`.
- Increments `_blocked`.
- Skips the rest of this task's inner loop (context build, dispatch, verify) via `continue`.
- Does NOT write a checkpoint for a blocked task (T05 owns checkpoint semantics).

## Steps

### Step 1: Read the current `scripts/engine/run.sh`

```bash
cat scripts/engine/run.sh
```

Locate the task loop. T02 left explicit comments: `# T03 inserts guard_payload_sanity / guard_budget here.` and `# T05 inserts guard_output_sanity ... here.`

### Step 2: Introduce budget accumulators before the task loop

Add the following block immediately before the `while IFS= read -r task_id; do` line:

```bash
# --- Budget accumulators (T05 may wire real caps from config) ---
_cum_cost_cents=0
_max_cost_cents=0   # 0 = disabled per guard_budget contract
_cum_dur_sec=0
_max_dur_sec=0      # 0 = disabled per guard_budget contract
```

### Step 3: Insert pre-dispatch guards after `run_hooks PRE_DISPATCH`

Replace the placeholder comment `# T03 inserts guard_payload_sanity / guard_budget here.` with:

```bash
  # --- T03: Pre-dispatch safety rails ---
  # In dry-run mode, payload does not exist yet (T04 will create it). Emit a
  # dry-run warning for auditability but skip the file-based guard.
  if orch_is_dry_run; then
    emit_event SAFETY_WARNING reason="dry_run_guard_skipped" guard="payload_sanity" task="$task_id"
  else
    # Payload file path is established by T04. For T03, use a placeholder that
    # points at a temp file the engine will populate in T04. If T04 has not run
    # yet, the guard will legitimately block — that is expected.
    _payload_file="${_payload_file:-}"
    if [ -n "$_payload_file" ]; then
      if ! guard_payload_sanity "$_payload_file"; then
        _blocked=$((_blocked + 1))
        emit_event TASK_COMPLETE task="$task_id" outcome="blocked" reason="payload_sanity"
        continue
      fi
    else
      emit_event SAFETY_WARNING reason="payload_file_unset" task="$task_id"
    fi
  fi

  # Budget guard always runs (handles cold state via 0-cap disabled behavior).
  if ! guard_budget "$_cum_cost_cents" "$_max_cost_cents" "$_cum_dur_sec" "$_max_dur_sec"; then
    _blocked=$((_blocked + 1))
    emit_event TASK_COMPLETE task="$task_id" outcome="blocked" reason="budget"
    continue
  fi
```

### Step 4: Insert post-dispatch guard after the dispatch placeholder

Replace the placeholder comment `# T05 inserts guard_output_sanity ... here.` with:

```bash
  # --- T03: Post-dispatch output sanity check (pre-verify) ---
  if orch_is_dry_run; then
    emit_event SAFETY_WARNING reason="dry_run_guard_skipped" guard="output_sanity" task="$task_id"
  else
    _output_file="${_output_file:-}"
    if [ -n "$_output_file" ]; then
      if ! guard_output_sanity "$_output_file"; then
        _blocked=$((_blocked + 1))
        emit_event TASK_COMPLETE task="$task_id" outcome="blocked" reason="output_sanity"
        continue
      fi
    else
      emit_event SAFETY_WARNING reason="output_file_unset" task="$task_id"
    fi
  fi
```

### Step 5: Insert pre-advance guard before PHASE_COMPLETE emission

Immediately before the `emit_event PHASE_COMPLETE ...` line, add:

```bash
# --- T03: Pre-advance phase-completeness guard ---
# Runs in both dry-run and real modes — the phase directory itself is always
# checkable. A force-override downgrades this block to GUARD_WARNING.
if ! guard_phase_complete "$PHASE_DIR"; then
  # In dry-run mode, the phase may legitimately have no SUMMARY.md (the engine
  # is exercising the skeleton). Downgrade to warning rather than erroring out.
  if orch_is_dry_run; then
    emit_event SAFETY_WARNING reason="dry_run_phase_incomplete" phase_dir="$PHASE_DIR"
  else
    emit_result error VERIFY "phase_complete guard blocked advance for $PHASE_DIR"
    exit 5
  fi
fi
```

### Step 6: Verify

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== T03 Verification ==="
bash -n scripts/engine/run.sh && echo "PASS: syntax" || { echo "FAIL: syntax"; exit 1; }

# All four guards referenced
for g in guard_payload_sanity guard_budget guard_output_sanity guard_phase_complete; do
  grep -q "$g" scripts/engine/run.sh && echo "PASS: $g wired" || echo "FAIL: $g missing"
done

# Budget accumulators introduced
grep -q '_cum_cost_cents' scripts/engine/run.sh && echo "PASS: cost accumulator" || echo "FAIL"
grep -q '_max_cost_cents' scripts/engine/run.sh && echo "PASS: cost cap var"     || echo "FAIL"
grep -q '_cum_dur_sec'    scripts/engine/run.sh && echo "PASS: dur accumulator"  || echo "FAIL"

# Block path emits outcome=blocked
grep -q 'outcome="blocked"' scripts/engine/run.sh && echo "PASS: blocked outcome" || echo "FAIL"

# Dry-run guard skip event
grep -q 'dry_run_guard_skipped' scripts/engine/run.sh && echo "PASS: dry-run skip marker" || echo "FAIL"

# Dry-run invocation still passes (no guards should block in dry-run mode)
ORCH_RUN_SEED='t03-dry' ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 >/tmp/t03-dry.out 2>&1
rc=$?
test "$rc" -eq 0 && echo "PASS: dry-run exit 0" || echo "FAIL: exit $rc"

# SAFETY_WARNING dry_run_guard_skipped emitted for payload and output
grep -q 'guard="payload_sanity"' /tmp/t03-dry.out && echo "PASS: payload_sanity skipped in dry-run" || echo "FAIL"
grep -q 'guard="output_sanity"'  /tmp/t03-dry.out && echo "PASS: output_sanity skipped in dry-run" || echo "FAIL"

# Still has ≥4 EVENT lines + final RESULT ok
ecount=$(grep -c '^EVENT:' /tmp/t03-dry.out || echo 0)
test "$ecount" -ge 4 && echo "PASS: $ecount events" || echo "FAIL"
tail -5 /tmp/t03-dry.out | grep -q '^RESULT:{"status":"ok"' && echo "PASS: RESULT ok" || echo "FAIL"

# No inline date introduced
! grep -nE '(^|[^A-Za-z_])date[[:space:]]' scripts/engine/run.sh && echo "PASS: no inline date" || echo "FAIL"

rm -f /tmp/t03-dry.out
echo "=== T03 complete ==="
```

## Must-Haves

### Truths

- `scripts/engine/run.sh` passes `bash -n` (still)
  - Check: `bash -n scripts/engine/run.sh`
- All four guards are referenced in `run.sh`
  - Check: `for g in guard_payload_sanity guard_budget guard_output_sanity guard_phase_complete; do grep -q "$g" scripts/engine/run.sh || exit 1; done && echo PASS`
- The task loop emits `outcome="blocked"` on guard failure
  - Check: `grep -q 'outcome="blocked"' scripts/engine/run.sh`
- Dry-run path emits `dry_run_guard_skipped` SAFETY_WARNING
  - Check: `grep -q 'dry_run_guard_skipped' scripts/engine/run.sh`
- Budget accumulator variables are introduced
  - Check: `grep -q '_cum_cost_cents' scripts/engine/run.sh && grep -q '_cum_dur_sec' scripts/engine/run.sh`
- Dry-run invocation still exits 0 (guards do not block in dry-run)
  - Check: `ORCH_RUN_SEED=t03-c ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 >/dev/null 2>&1`
- Dry-run emits payload and output guard-skipped warnings
  - Check: `ORCH_RUN_SEED=t03-c2 ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>&1 | grep -q 'guard="payload_sanity"' && ORCH_RUN_SEED=t03-c2b ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>&1 | grep -q 'guard="output_sanity"'`

### Artifacts

- `scripts/engine/run.sh` (min 200 lines, contains "guard_payload_sanity")

### Key Links

- `scripts/engine/run.sh` → `scripts/lib/guards.sh` (new key link — T02 did not call any guards)

## Verification

Run the Step 6 block from repo root. All lines must print `PASS:`. No new files should be created.

## Inputs

### From Previous Tasks

- `scripts/engine/run.sh` (from P03/T02)
  - Walking skeleton: argument parsing, session lifecycle events, task loop iterating `T##-PLAN.md` files without summaries, `run_hooks PRE_DISPATCH` in the loop, `checkpoint_detect`/`checkpoint_read` at session start, `emit_result` at the final line.
  - Comments label exact insertion points: `# T03 inserts guard_payload_sanity / guard_budget here.` and `# T05 inserts guard_output_sanity ... here.`
  - Uses `_completed` and `_blocked` counters in the loop; this task increments `_blocked` on guard failure.
  - Already declares `_pending_tmp` temp file and `trap 'rm -f "$_pending_tmp"' EXIT`.
- `scripts/engine/checkpoint.sh` (from P03/T01) — sourced by T02; not modified here.

### From Disk (Pre-existing)

- `scripts/lib/guards.sh` — provides the 4 guard functions. Key contracts:
  - `guard_payload_sanity <file>` — blocks if file missing / empty / <100 chars (env `ORCH_GUARD_MIN_PAYLOAD_CHARS` override).
  - `guard_budget <cum_cost> <max_cost> [cum_dur] [max_dur]` — blocks if cum exceeds cap; 0 cap = disabled.
  - `guard_output_sanity <file>` — blocks if output missing / empty / <100 chars (`ORCH_GUARD_MIN_OUTPUT_CHARS`).
  - `guard_phase_complete <phase_dir>` — blocks if no `P*-SUMMARY.md` / `SUMMARY.md` with `^## ` section.
  - All emit `GUARD_BLOCKED guard=<name> reason=<text>` on block, or `GUARD_WARNING forced=1` under `ORCH_FORCE`.
- `scripts/lib/events.sh` — `SAFETY_WARNING` is in the canonical registry; emit with `emit_event SAFETY_WARNING reason="..."`.

## Expected Output

Modified `scripts/engine/run.sh` at ≥200 lines with:
- Four guard functions referenced by name.
- Budget accumulator variables defined before the task loop.
- Pre-dispatch guard block replacing the T03 placeholder comment.
- Post-dispatch guard block replacing the T05 placeholder (T05 will still add verify/record/checkpoint; the output-sanity guard stays where T03 placed it).
- Pre-advance `guard_phase_complete` call before `emit_event PHASE_COMPLETE`.
- Dry-run guard-skip branches emitting `SAFETY_WARNING reason="dry_run_guard_skipped"`.

NO changes to any file outside `scripts/engine/run.sh`. NO changes to any T01 or T02 output.
