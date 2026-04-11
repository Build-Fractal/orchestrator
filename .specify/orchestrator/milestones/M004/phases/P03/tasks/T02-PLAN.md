---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P03"
milestone: "M004"
name: "run.sh — Skeleton, Arg Parsing, Session Lifecycle, Task Loop"
depends_on: [T01]
---

## Description

Create `scripts/engine/run.sh`, the mechanical pipeline coordinator that will eventually dispatch every task in a phase with run-context threading, structured events, safety rails, hooks, and checkpointing. THIS TASK builds only the walking skeleton — later tasks (T03 = guards, T04 = context assembly + dispatch, T05 = verify + record + checkpoint wiring, T06 = resume E2E) will flesh out the inside of the task loop.

After this task:
- `bash scripts/engine/run.sh` with no args prints a usage message, exits non-zero, and emits `RESULT:{"status":"error","error_kind":"CONFIG",...}`.
- `bash scripts/engine/run.sh --dry-run M004 P03` initializes deterministic run context, emits `SESSION_START`, discovers pending tasks from the phase plan directory, emits `TASK_START` + `TASK_COMPLETE outcome=dry_run` for each, calls `run_hooks PRE_DISPATCH` once per task (at minimum so the hook integration seam is live), emits `PHASE_COMPLETE`, `SESSION_END`, and `RESULT:{"status":"ok",...}`.
- Run context is initialized exactly once per invocation; all emitted events share the same `run_id`.
- `checkpoint_detect` + `checkpoint_read` are called at startup so T05 only needs to wire resumption logic — not add the plumbing.

This task implements:
- FR-200 / FR-201 (engine threads run context)
- FR-202 (engine emits structured events at session/task/phase boundaries)
- FR-204 (--dry-run support — the skeleton already covers the no-dispatch branch; T04 will add the dispatch branch)
- US1 AS1 (events on stdout in parseable format), AS4 (shared run_id), AS5 (dry-run pipeline)
- Principle II (structured events), Principle IX (orch_now timestamps, no inline date), Principle XII (hooks integrated via run_hooks)

## Steps

### Step 1: Confirm prerequisites exist

```bash
test -f scripts/lib/errors.sh      || { echo "FAIL: missing errors.sh"; exit 1; }
test -f scripts/lib/events.sh      || { echo "FAIL: missing events.sh"; exit 1; }
test -f scripts/lib/run-context.sh || { echo "FAIL: missing run-context.sh"; exit 1; }
test -f scripts/lib/guards.sh      || { echo "FAIL: missing guards.sh"; exit 1; }
test -f scripts/lib/hooks.sh       || { echo "FAIL: missing hooks.sh"; exit 1; }
test -f scripts/engine/checkpoint.sh || { echo "FAIL: missing checkpoint.sh — run T01 first"; exit 1; }
```

### Step 2: Write `scripts/engine/run.sh` verbatim

```bash
#!/usr/bin/env bash
# scripts/engine/run.sh — Orchestrator engine: mechanical pipeline coordinator.
set -euo pipefail

# --- Help / usage ---
_engine_usage() {
  cat <<'EOF'
Usage: scripts/engine/run.sh [--dry-run] [--force] <milestone> <phase>

Positional:
  <milestone>  Milestone id (e.g., M004)
  <phase>      Phase id (e.g., P03)

Flags:
  --dry-run    Execute the full pipeline except actual agent dispatch.
               Events are emitted, guards run, but no payload is sent to a model.
  --force      Downgrade guard blocks to GUARD_WARNING (operator override).
               Hook tampering detection (HOOK_VIOLATION) is NEVER overridable.
  -h, --help   Show this message.

Environment:
  ORCH_RUN_SEED        Seed init_run_context for reproducible run_id + timestamps.
  ORCH_DRY_RUN=1       Equivalent to --dry-run.
  ORCH_FORCE=1         Equivalent to --force.
  ORCH_ENGINE_STOP_AFTER_TASK  Debug hook for T06 (simulated crash).
EOF
}

# --- Resolve own directory so we can source libs via relative paths ---
_engine_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_engine_lib="${_engine_dir}/../lib"
# shellcheck disable=SC1090
. "${_engine_lib}/errors.sh"
# shellcheck disable=SC1090
. "${_engine_lib}/events.sh"
# shellcheck disable=SC1090
. "${_engine_lib}/run-context.sh"
# shellcheck disable=SC1090
. "${_engine_lib}/guards.sh"
# shellcheck disable=SC1090
. "${_engine_lib}/hooks.sh"
# shellcheck disable=SC1090
. "${_engine_dir}/checkpoint.sh"

# --- Argument parsing ---
ENGINE_DRY_RUN=""
ENGINE_FORCE=""
ENGINE_MILESTONE=""
ENGINE_PHASE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) ENGINE_DRY_RUN=1; shift ;;
    --force)   ENGINE_FORCE=1; shift ;;
    -h|--help) _engine_usage; exit 0 ;;
    --)        shift; break ;;
    -*)
      _engine_usage >&2
      emit_result error CONFIG "unknown flag: $1"
      exit 2
      ;;
    *)
      if [ -z "$ENGINE_MILESTONE" ]; then
        ENGINE_MILESTONE="$1"
      elif [ -z "$ENGINE_PHASE" ]; then
        ENGINE_PHASE="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$ENGINE_MILESTONE" ] || [ -z "$ENGINE_PHASE" ]; then
  _engine_usage >&2
  emit_result error CONFIG "missing required positional args: <milestone> <phase>"
  exit 2
fi

# Merge env flags into CLI flags (env wins if CLI absent).
if [ -n "${ORCH_DRY_RUN:-}" ]; then ENGINE_DRY_RUN=1; fi
if [ -n "${ORCH_FORCE:-}" ];   then ENGINE_FORCE=1;   fi

# Export so sibling libraries (guards.sh, hooks.sh) see the flags via orch_is_*.
export ORCH_DRY_RUN="${ENGINE_DRY_RUN:-}"
export ORCH_FORCE="${ENGINE_FORCE:-}"

# --- Initialize run context (deterministic if ORCH_RUN_SEED is set) ---
init_run_context "$ENGINE_MILESTONE" "$ENGINE_PHASE"

# --- Resolve phase directory and pending-task list ---
PHASE_DIR=".specify/orchestrator/milestones/${ENGINE_MILESTONE}/phases/${ENGINE_PHASE}"
if [ ! -d "$PHASE_DIR" ]; then
  emit_event SAFETY_WARNING reason="phase_dir_missing" phase_dir="$PHASE_DIR"
  emit_result error STATE "phase directory not found: $PHASE_DIR"
  exit 3
fi

TASKS_DIR="${PHASE_DIR}/tasks"
if [ ! -d "$TASKS_DIR" ]; then
  emit_event SAFETY_WARNING reason="tasks_dir_missing" tasks_dir="$TASKS_DIR"
  emit_result error STATE "tasks directory not found: $TASKS_DIR"
  exit 3
fi

# Discover pending tasks: every T##-PLAN.md without a sibling T##-SUMMARY.md.
# Use a mktemp temp file + while-read loop per AP-001 (no process substitution redirect).
_pending_tmp="$(mktemp)"
trap 'rm -f "$_pending_tmp"' EXIT

_pending_count=0
for plan in "$TASKS_DIR"/T*-PLAN.md; do
  [ -f "$plan" ] || continue
  task_id="$(basename "$plan" | sed 's/-PLAN\.md$//')"
  summary="${TASKS_DIR}/${task_id}-SUMMARY.md"
  if [ ! -f "$summary" ]; then
    printf '%s\n' "$task_id" >> "$_pending_tmp"
    _pending_count=$((_pending_count + 1))
  fi
done

# --- Session start event ---
emit_event SESSION_START \
  milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE" \
  pending_tasks="$_pending_count" \
  dry_run="${ENGINE_DRY_RUN:-0}" forced="${ENGINE_FORCE:-0}"

# --- Crash-recovery detection ---
# T05 will wire actual resumption logic. For now, emit CHECKPOINT_RESUME
# when a prior checkpoint exists so the observability seam is in place.
_resume_from=""
if checkpoint_detect "$ENGINE_MILESTONE"; then
  _resume_from="$(checkpoint_read "$ENGINE_MILESTONE" last_task 2>/dev/null || true)"
  emit_event CHECKPOINT_RESUME milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE" \
    last_task="${_resume_from:-unknown}"
fi

# --- Phase start event ---
emit_event PHASE_START milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE" \
  pending_tasks="$_pending_count"

# --- Task loop (walking skeleton — T03/T04/T05 extend this) ---
_completed=0
_blocked=0
while IFS= read -r task_id; do
  [ -z "$task_id" ] && continue

  emit_event TASK_START task="$task_id" milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE"

  # Hook integration seam — PRE_DISPATCH fires even in the skeleton so that
  # Conversus / monitoring hooks can observe dry-run sessions. State source is
  # the phase directory; hooks receive a frozen snapshot via ORCH_HOOK_SNAPSHOT.
  if ! run_hooks PRE_DISPATCH "$PHASE_DIR" >/tmp/engine-hook-pre-dispatch.$$.out 2>&1; then
    # Hook blocked — skip this task, do not advance.
    cat /tmp/engine-hook-pre-dispatch.$$.out 2>/dev/null || true
    rm -f /tmp/engine-hook-pre-dispatch.$$.out
    _blocked=$((_blocked + 1))
    emit_event TASK_COMPLETE task="$task_id" outcome="blocked" reason="hook_pre_dispatch"
    continue
  fi
  cat /tmp/engine-hook-pre-dispatch.$$.out 2>/dev/null || true
  rm -f /tmp/engine-hook-pre-dispatch.$$.out

  # T03 inserts guard_payload_sanity / guard_budget here.
  # T04 inserts build-context → compress → select-model → dispatch here.
  # T05 inserts guard_output_sanity / check-must-haves / record-result / checkpoint_write here.

  if orch_is_dry_run; then
    emit_event TASK_COMPLETE task="$task_id" outcome="dry_run" phase="$ENGINE_PHASE"
  else
    # Real-dispatch placeholder. T04/T05 replace this branch with the actual
    # context-build / dispatch / verify pipeline.
    emit_event TASK_COMPLETE task="$task_id" outcome="skeleton_noop" phase="$ENGINE_PHASE"
  fi

  _completed=$((_completed + 1))

  # T06 debug stop-after hook for simulated-crash testing.
  if [ -n "${ORCH_ENGINE_STOP_AFTER_TASK:-}" ] && [ "$task_id" = "$ORCH_ENGINE_STOP_AFTER_TASK" ]; then
    emit_event SAFETY_WARNING reason="debug_stop_after_task" task="$task_id"
    break
  fi
done < "$_pending_tmp"

# --- Phase completion ---
emit_event PHASE_COMPLETE milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE" \
  completed="$_completed" blocked="$_blocked"

# --- Session end ---
emit_event SESSION_END milestone="$ENGINE_MILESTONE" phase="$ENGINE_PHASE" \
  completed="$_completed" blocked="$_blocked" dry_run="${ENGINE_DRY_RUN:-0}"

# --- Final result ---
if [ "$_blocked" -gt 0 ]; then
  emit_result error STATE "phase ${ENGINE_PHASE} ended with ${_blocked} blocked task(s)"
  exit 4
fi
emit_result ok "" "engine completed ${ENGINE_MILESTONE}/${ENGINE_PHASE} (dry_run=${ENGINE_DRY_RUN:-0}, completed=${_completed})"
exit 0
```

### Step 3: Make executable

```bash
chmod +x scripts/engine/run.sh
```

### Step 4: Verify

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== T02 Verification ==="
bash -n scripts/engine/run.sh && echo "PASS: syntax" || { echo "FAIL: syntax"; exit 1; }

# Usage/no-args behavior
out="$(bash scripts/engine/run.sh 2>&1 || true)"
echo "$out" | grep -q 'Usage'                   && echo "PASS: usage on no-args" || echo "FAIL"
echo "$out" | grep -q '"error_kind":"CONFIG"'   && echo "PASS: CONFIG result"    || echo "FAIL"

# Dry-run happy path
ORCH_RUN_SEED='t02-dry' ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 >/tmp/t02-dry.out 2>&1
rc=$?
test "$rc" -eq 0 && echo "PASS: dry-run exit 0" || echo "FAIL: exit $rc"

# Events present
grep -q '^EVENT:SESSION_START'    /tmp/t02-dry.out && echo "PASS: SESSION_START"    || echo "FAIL"
grep -q '^EVENT:SESSION_END'      /tmp/t02-dry.out && echo "PASS: SESSION_END"      || echo "FAIL"
grep -q '^EVENT:PHASE_START'      /tmp/t02-dry.out && echo "PASS: PHASE_START"      || echo "FAIL"
grep -q '^EVENT:PHASE_COMPLETE'   /tmp/t02-dry.out && echo "PASS: PHASE_COMPLETE"   || echo "FAIL"
grep -q '^EVENT:TASK_START'       /tmp/t02-dry.out && echo "PASS: TASK_START"       || echo "FAIL"
grep -q '^EVENT:TASK_COMPLETE'    /tmp/t02-dry.out && echo "PASS: TASK_COMPLETE"    || echo "FAIL"

# ≥ 4 EVENT lines
ecount=$(grep -c '^EVENT:' /tmp/t02-dry.out || echo 0)
test "$ecount" -ge 4 && echo "PASS: $ecount EVENT lines (>=4)" || echo "FAIL: only $ecount"

# Single shared run_id
uniq_run=$(grep '^EVENT:' /tmp/t02-dry.out | grep -oE 'run_id=[^ ]+' | sort -u | wc -l | tr -d ' ')
test "$uniq_run" -eq 1 && echo "PASS: shared run_id" || echo "FAIL: $uniq_run run_ids"

# Final RESULT line
tail -5 /tmp/t02-dry.out | grep -q '^RESULT:{"status":"ok"' && echo "PASS: final RESULT ok" || echo "FAIL"

# No inline date in the engine file
! grep -nE '(^|[^A-Za-z_])date[[:space:]]' scripts/engine/run.sh && echo "PASS: no inline date" || echo "FAIL"

# Bash 3.2 compat
! grep -qE 'declare -A|readarray|mapfile' scripts/engine/run.sh && echo "PASS: Bash 3.2 compat" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/engine/run.sh && echo "PASS: no proc-sub redirect" || echo "FAIL"

rm -f /tmp/t02-dry.out
echo "=== T02 complete ==="
```

## Must-Haves

### Truths

- `scripts/engine/run.sh` passes `bash -n`
  - Check: `bash -n scripts/engine/run.sh`
- Script sources all 5 P02 libraries + `scripts/engine/checkpoint.sh`
  - Check: `for lib in errors events run-context guards hooks; do grep -q "lib/${lib}.sh" scripts/engine/run.sh || exit 1; done && grep -q 'engine/checkpoint.sh' scripts/engine/run.sh`
- Script calls `init_run_context` exactly once
  - Check: `test "$(grep -c 'init_run_context' scripts/engine/run.sh)" -ge 1`
- Script emits SESSION_START, SESSION_END, PHASE_START, PHASE_COMPLETE, TASK_START, TASK_COMPLETE events
  - Check: `for e in SESSION_START SESSION_END PHASE_START PHASE_COMPLETE TASK_START TASK_COMPLETE; do grep -q "emit_event ${e}" scripts/engine/run.sh || exit 1; done && echo PASS`
- Script calls `run_hooks PRE_DISPATCH` inside the task loop
  - Check: `grep -q 'run_hooks PRE_DISPATCH' scripts/engine/run.sh`
- Script calls `checkpoint_detect` and `checkpoint_read` at session start
  - Check: `grep -q 'checkpoint_detect' scripts/engine/run.sh && grep -q 'checkpoint_read' scripts/engine/run.sh`
- No-args invocation emits `RESULT:` with `error_kind CONFIG`
  - Check: `bash scripts/engine/run.sh 2>&1 | grep -q '"error_kind":"CONFIG"'`
- Dry-run invocation exits 0
  - Check: `ORCH_RUN_SEED=t02-c1 ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 >/dev/null 2>&1`
- Dry-run invocation emits ≥ 4 EVENT lines
  - Check: `ORCH_RUN_SEED=t02-c2 ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>/dev/null | grep -c '^EVENT:' | awk '{ if ($1 >= 4) exit 0; else exit 1 }'`
- All EVENT lines from a seeded dry-run share the same `run_id`
  - Check: `ORCH_RUN_SEED=t02-c3 ORCH_DRY_RUN=1 bash scripts/engine/run.sh --dry-run M004 P03 2>/dev/null | grep '^EVENT:' | grep -oE 'run_id=[^ ]+' | sort -u | wc -l | tr -d ' ' | grep -q '^1$'`
- No inline `date` calls
  - Check: `! grep -nE '(^|[^A-Za-z_])date[[:space:]]' scripts/engine/run.sh`
- Bash 3.2 compatible (no associative arrays, no readarray, no mapfile, no proc-sub redirect)
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/engine/run.sh && ! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/engine/run.sh`

### Artifacts

- `scripts/engine/run.sh` (min 150 lines, contains "init_run_context")

### Key Links

- `scripts/engine/run.sh` → `scripts/lib/errors.sh`
- `scripts/engine/run.sh` → `scripts/lib/events.sh`
- `scripts/engine/run.sh` → `scripts/lib/run-context.sh`
- `scripts/engine/run.sh` → `scripts/lib/guards.sh`
- `scripts/engine/run.sh` → `scripts/lib/hooks.sh`
- `scripts/engine/run.sh` → `scripts/engine/checkpoint.sh`

## Verification

Run the full verification block from Step 4. Every line must print `PASS:`. If the dry-run invocation finds no pending tasks (because all P03 T##-SUMMARY.md files already exist), the loop will be empty but SESSION_START/PHASE_START/PHASE_COMPLETE/SESSION_END still fire — that is still ≥ 4 EVENT lines, so the must-have passes.

## Inputs

### From Previous Tasks

- `scripts/engine/checkpoint.sh` (from P03/T01)
  - Key API:
    - `checkpoint_path <milestone>` — echo the checkpoint file path.
    - `checkpoint_write <milestone> <phase> <task> <outcome>` — atomic write, emits CHECKPOINT_WRITE.
    - `checkpoint_read <milestone> <field>` — echo value or return 1.
    - `checkpoint_detect <milestone>` — return 0 if checkpoint file exists and is non-empty.
    - `checkpoint_clear <milestone>` — remove checkpoint file.
  - Key types: no types; plain shell strings.

### From Disk (Pre-existing)

- `scripts/lib/errors.sh` — `emit_result <status> [kind] [detail]`. Status must be `ok` or `error`. Kind must be in CONFIG|STATE|DISPATCH|VERIFY|BUDGET|IO or it is remapped to CONFIG.
- `scripts/lib/events.sh` — `emit_event <TYPE> [key=value ...]`. Canonical types include SESSION_START/SESSION_END/PHASE_START/PHASE_COMPLETE/TASK_START/TASK_COMPLETE/DISPATCH_START/GUARD_BLOCKED/HOOK_START/HOOK_COMPLETE/CHECKPOINT_WRITE/CHECKPOINT_RESUME/SAFETY_WARNING. Values with whitespace auto-quote.
- `scripts/lib/run-context.sh` — `init_run_context [milestone] [phase]` exports ORCH_RUN_ID, ORCH_STARTED_AT, ORCH_FORCE, ORCH_DRY_RUN, ORCH_RUN_MILESTONE, ORCH_RUN_PHASE. Deterministic when `ORCH_RUN_SEED` is set. `orch_now` returns frozen timestamp. `orch_is_forced` / `orch_is_dry_run` accept `1|true|TRUE|yes|YES`.
- `scripts/lib/guards.sh` — `guard_payload_sanity`, `guard_budget`, `guard_output_sanity`, `guard_phase_complete`. All return non-zero on block. This task does not call them (T03 does).
- `scripts/lib/hooks.sh` — `run_hooks <lifecycle_point> <state_source> [hooks_yaml_path]`. Lifecycle points: PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE. `state_source` can be a file or a directory (hooks.sh auto-handles both). Gracefully degrades to SAFETY_WARNING if `templates/hooks.yaml` is missing.
- `.specify/orchestrator/milestones/M004/phases/P03/tasks/` — the phase's own tasks directory; the engine will discover `T##-PLAN.md` files here. During T02 verification, a P03 dry-run iterates its own planned tasks (T01–T06).
- `templates/hooks.yaml` — already exists from P04. `run_hooks` loads it automatically.

## Expected Output

A new file `scripts/engine/run.sh` at ≥150 lines with:
- Shebang + `set -euo pipefail` + usage function + relative sourcing of 5 libs + checkpoint.sh.
- Argument parser accepting `--dry-run`, `--force`, `-h|--help`, `<milestone> <phase>` positionals.
- Usage-on-no-args path calling `emit_result error CONFIG` and `exit 2`.
- Single `init_run_context` call with the positional args.
- Phase-dir / tasks-dir existence checks with `emit_result error STATE` on failure.
- Pending-task discovery loop writing to `$(mktemp)` file (AP-001 compliance).
- `SESSION_START` → `checkpoint_detect`/`CHECKPOINT_RESUME` → `PHASE_START` → task loop → `PHASE_COMPLETE` → `SESSION_END` → `emit_result ok` (happy path).
- `run_hooks PRE_DISPATCH "$PHASE_DIR"` inside the task loop with exit-code handling (blocked tasks increment `_blocked` counter and emit `TASK_COMPLETE outcome=blocked`).
- Debug stop-after hook (`ORCH_ENGINE_STOP_AFTER_TASK`) for T06.
- Comments labeling where T03/T04/T05 will insert their logic so later agents know exactly where to edit.

No changes to any file outside `scripts/engine/run.sh` in this task.
