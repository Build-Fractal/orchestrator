---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M004"
name: "checkpoint.sh — Atomic Crash Recovery Library"
depends_on: []
---

## Description

Create `scripts/engine/checkpoint.sh`, a Bash 3.2 sourced library that provides the crash-recovery primitives for `scripts/engine/run.sh` (T02+). It persists a JSON snapshot of the engine's position in the task loop after each task boundary, so a re-invocation after a crash can emit `CHECKPOINT_RESUME` and skip already-completed tasks.

The checkpoint lives at `.specify/orchestrator/milestones/<milestone>/engine-checkpoint.json` (sibling of `execution-log.jsonl`, `summary.md`, etc.). Writes are atomic via temp-file-then-`mv` (inherited [M002](../../../../../milestones/M002/index.md) convention — see `scripts/lifecycle/lock-manager.sh` for reference). The JSON payload is assembled with `printf` (no `jq`); reads are grep/sed-based.

This task implements:
- Principle II (Evidence Before Claims) via `CHECKPOINT_WRITE` / `CHECKPOINT_RESUME` events on every state transition.
- Principle VI (State On Disk Is Truth) — the checkpoint is the authoritative handoff between runs.
- Principle IX (Reproducibility) — no inline `date`; timestamps are pulled from `$ORCH_STARTED_AT` via the sourced `run-context.sh` helpers.
- NFR-200 (Bash 3.2), NFR-203 (double-sourcing guard), AP-001 (no proc-sub redirect targets), AP-003 (guard in first 5 lines).

## Steps

### Step 1: Create `scripts/engine/` directory

```bash
mkdir -p scripts/engine
```

### Step 2: Write `scripts/engine/checkpoint.sh` verbatim

Create the file with the following content. Every line matters — the guard placement (lines 3-4 after shebang + one-line comment) is the P02/T01 lesson: if you move the guard below line 5, the phase-level `head -5 | grep _CHECKPOINT_SOURCED` must-have check will fail even though the guard technically works.

```bash
#!/usr/bin/env bash
# scripts/engine/checkpoint.sh — Atomic engine checkpoint read/write/detect.
[ -n "${_CHECKPOINT_SOURCED:-}" ] && return 0
_CHECKPOINT_SOURCED=1

# Source this file to get:
#   - checkpoint_path <milestone>          — echoes the checkpoint file path
#   - checkpoint_write <milestone> <phase> <task> <outcome>
#   - checkpoint_read <milestone> <field>  — field in: run_id|milestone|phase|last_task|outcome|timestamp
#   - checkpoint_detect <milestone>        — returns 0 if a checkpoint exists, 1 otherwise
#   - checkpoint_clear <milestone>         — removes the checkpoint file (called on full phase success)
#
# Emits:
#   EVENT:CHECKPOINT_WRITE   on every successful checkpoint_write
#   (caller of checkpoint_read emits CHECKPOINT_RESUME — this library only persists state)
#
# Constitution:
#   Principle VI (State On Disk Is Truth) — the checkpoint is the handoff between crashed runs.
#   Principle IX (Reproducibility) — timestamps come from orch_now (ORCH_STARTED_AT).
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.

_checkpoint_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
. "${_checkpoint_dir}/../lib/errors.sh"
# shellcheck disable=SC1090
. "${_checkpoint_dir}/../lib/events.sh"
# shellcheck disable=SC1090
. "${_checkpoint_dir}/../lib/run-context.sh"

# --- Configuration ---
ORCH_CHECKPOINT_ROOT="${ORCH_CHECKPOINT_ROOT:-.specify/orchestrator/milestones}"

# _checkpoint_escape <string>
# Minimal JSON string escaping: backslash, double-quote, control chars → space.
_checkpoint_escape() {
  local s="$1"
  s="$(printf '%s' "$s" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
  s="$(printf '%s' "$s" | tr '\n' ' ' | tr '\r' ' ' | tr '\t' ' ')"
  printf '%s' "$s"
}

# checkpoint_path <milestone>
# Returns the absolute-ish path to the checkpoint JSON file for the milestone.
checkpoint_path() {
  local milestone="$1"
  if [ -z "$milestone" ]; then
    return 1
  fi
  printf '%s/%s/engine-checkpoint.json\n' "$ORCH_CHECKPOINT_ROOT" "$milestone"
}

# checkpoint_write <milestone> <phase> <task> <outcome>
# Writes atomically: build temp file, mv into place. Emits CHECKPOINT_WRITE.
checkpoint_write() {
  local milestone="$1"
  local phase="$2"
  local task="$3"
  local outcome="${4:-success}"

  if [ -z "$milestone" ] || [ -z "$phase" ] || [ -z "$task" ]; then
    emit_event SAFETY_WARNING reason="checkpoint_write_missing_args" \
      milestone="${milestone:-<empty>}" phase="${phase:-<empty>}" task="${task:-<empty>}"
    return 1
  fi

  local cp
  cp="$(checkpoint_path "$milestone")"
  local cp_dir
  cp_dir="$(dirname "$cp")"
  if [ ! -d "$cp_dir" ]; then
    mkdir -p "$cp_dir" 2>/dev/null || {
      emit_event SAFETY_WARNING reason="checkpoint_mkdir_failed" path="$cp_dir"
      return 1
    }
  fi

  local run_id ts
  run_id="${ORCH_RUN_ID:-unset}"
  ts="$(orch_now)"

  local esc_run_id esc_milestone esc_phase esc_task esc_outcome esc_ts
  esc_run_id="$(_checkpoint_escape "$run_id")"
  esc_milestone="$(_checkpoint_escape "$milestone")"
  esc_phase="$(_checkpoint_escape "$phase")"
  esc_task="$(_checkpoint_escape "$task")"
  esc_outcome="$(_checkpoint_escape "$outcome")"
  esc_ts="$(_checkpoint_escape "$ts")"

  local tmp="${cp}.tmp.$$"
  {
    printf '{\n'
    printf '  "run_id": "%s",\n'    "$esc_run_id"
    printf '  "milestone": "%s",\n' "$esc_milestone"
    printf '  "phase": "%s",\n'     "$esc_phase"
    printf '  "last_task": "%s",\n' "$esc_task"
    printf '  "outcome": "%s",\n'   "$esc_outcome"
    printf '  "timestamp": "%s"\n'  "$esc_ts"
    printf '}\n'
  } > "$tmp" 2>/dev/null || {
    rm -f "$tmp"
    emit_event SAFETY_WARNING reason="checkpoint_write_failed" path="$tmp"
    return 1
  }

  mv "$tmp" "$cp" 2>/dev/null || {
    rm -f "$tmp"
    emit_event SAFETY_WARNING reason="checkpoint_mv_failed" path="$cp"
    return 1
  }

  emit_event CHECKPOINT_WRITE milestone="$milestone" phase="$phase" \
    last_task="$task" outcome="$outcome" path="$cp"
  return 0
}

# checkpoint_read <milestone> <field>
# field is one of: run_id, milestone, phase, last_task, outcome, timestamp.
# Prints the value to stdout or returns 1 if the checkpoint or field is missing.
checkpoint_read() {
  local milestone="$1"
  local field="$2"

  if [ -z "$milestone" ] || [ -z "$field" ]; then
    return 1
  fi

  local cp
  cp="$(checkpoint_path "$milestone")"
  if [ ! -f "$cp" ]; then
    return 1
  fi

  # Parse: "field": "value"  — allow leading whitespace and optional trailing comma.
  local line
  line="$(grep -E "\"${field}\"[[:space:]]*:" "$cp" 2>/dev/null | head -1)"
  if [ -z "$line" ]; then
    return 1
  fi
  # Strip up to the colon, then strip quotes and trailing comma.
  line="${line#*:}"
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*,[[:space:]]*$//' \
    -e 's/^"//' -e 's/"$//')"
  printf '%s\n' "$line"
  return 0
}

# checkpoint_detect <milestone>
# Returns 0 if a non-empty checkpoint file exists for the milestone, 1 otherwise.
checkpoint_detect() {
  local milestone="$1"
  if [ -z "$milestone" ]; then
    return 1
  fi
  local cp
  cp="$(checkpoint_path "$milestone")"
  [ -s "$cp" ]
}

# checkpoint_clear <milestone>
# Removes the checkpoint file for the milestone. Safe to call when no checkpoint exists.
checkpoint_clear() {
  local milestone="$1"
  if [ -z "$milestone" ]; then
    return 1
  fi
  local cp
  cp="$(checkpoint_path "$milestone")"
  rm -f "$cp" 2>/dev/null
  return 0
}
```

### Step 3: Mark executable to match convention

```bash
chmod +x scripts/engine/checkpoint.sh
```

Sourced libraries do not strictly need the executable bit, but the P02 libs (`scripts/lib/*.sh`) all have it. Match the convention.

### Step 4: Run verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== T01 Verification ==="

# Syntax
bash -n scripts/engine/checkpoint.sh && echo "PASS: syntax" || { echo "FAIL: syntax"; exit 1; }

# Guard placement
head -5 scripts/engine/checkpoint.sh | grep -q '_CHECKPOINT_SOURCED' && echo "PASS: guard in head -5" || echo "FAIL: guard"

# Minimum size
lines=$(wc -l < scripts/engine/checkpoint.sh | tr -d ' ')
test "$lines" -ge 90 && echo "PASS: $lines lines" || echo "FAIL: only $lines lines"

# Sourced libs
grep -q 'lib/errors.sh'   scripts/engine/checkpoint.sh && echo "PASS: sources errors.sh"   || echo "FAIL"
grep -q 'lib/events.sh'   scripts/engine/checkpoint.sh && echo "PASS: sources events.sh"   || echo "FAIL"
grep -q 'lib/run-context' scripts/engine/checkpoint.sh && echo "PASS: sources run-context" || echo "FAIL"

# Functions defined
for fn in checkpoint_path checkpoint_write checkpoint_read checkpoint_detect checkpoint_clear; do
  grep -q "^${fn}()" scripts/engine/checkpoint.sh && echo "PASS: ${fn} defined" || echo "FAIL: ${fn}"
done

# No inline date
! grep -nE '(^|[^A-Za-z_])date[[:space:]]' scripts/engine/checkpoint.sh && echo "PASS: no inline date" || echo "FAIL: inline date found"

# Bash 3.2 compatible
! grep -qE 'declare -A|readarray|mapfile' scripts/engine/checkpoint.sh && echo "PASS: Bash 3.2 compat" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/engine/checkpoint.sh && echo "PASS: no proc-sub redirect (AP-001)" || echo "FAIL"

# Double-source idempotent
bash -c '. scripts/engine/checkpoint.sh; . scripts/engine/checkpoint.sh; type checkpoint_write >/dev/null' \
  && echo "PASS: double-source idempotent" || echo "FAIL"

# Behavioral: checkpoint_path
path="$(bash -c '. scripts/engine/checkpoint.sh; checkpoint_path M999')"
[ "$path" = ".specify/orchestrator/milestones/M999/engine-checkpoint.json" ] \
  && echo "PASS: checkpoint_path format" || echo "FAIL: got '$path'"

# Behavioral: write → read round trip (uses a tmp ORCH_CHECKPOINT_ROOT)
tmp_root="$(mktemp -d)"
bash -c "
  set -e
  export ORCH_CHECKPOINT_ROOT='$tmp_root'
  export ORCH_RUN_SEED='t01-test'
  . scripts/lib/run-context.sh
  init_run_context M999 P03
  . scripts/engine/checkpoint.sh
  checkpoint_write M999 P03 T02 success >/dev/null
  test -f '$tmp_root/M999/engine-checkpoint.json'
  rid=\$(checkpoint_read M999 run_id)
  task=\$(checkpoint_read M999 last_task)
  test \"\$rid\" = \"\$ORCH_RUN_ID\"
  test \"\$task\" = 'T02'
  checkpoint_detect M999
  checkpoint_clear M999
  test ! -f '$tmp_root/M999/engine-checkpoint.json'
" && echo "PASS: round-trip" || echo "FAIL: round-trip"
rm -rf "$tmp_root"

# Behavioral: CHECKPOINT_WRITE event on successful write
tmp_root2="$(mktemp -d)"
out="$(bash -c "
  export ORCH_CHECKPOINT_ROOT='$tmp_root2'
  export ORCH_RUN_SEED='t01-evt'
  . scripts/lib/run-context.sh
  init_run_context M999 P03
  . scripts/engine/checkpoint.sh
  checkpoint_write M999 P03 T01 success
")"
echo "$out" | grep -q '^EVENT:CHECKPOINT_WRITE' && echo "PASS: emits CHECKPOINT_WRITE" || echo "FAIL: no event"
rm -rf "$tmp_root2"

echo "=== T01 complete ==="
```

Every line should print `PASS:`. If any `FAIL:` appears, fix the root cause and re-run before writing the task summary.

## Must-Haves

### Truths

- `scripts/engine/checkpoint.sh` passes `bash -n`
  - Check: `bash -n scripts/engine/checkpoint.sh`
- Double-sourcing guard within the first 5 lines
  - Check: `head -5 scripts/engine/checkpoint.sh | grep -q '_CHECKPOINT_SOURCED'`
- File sources errors.sh, events.sh, and run-context.sh
  - Check: `grep -q 'lib/errors.sh' scripts/engine/checkpoint.sh && grep -q 'lib/events.sh' scripts/engine/checkpoint.sh && grep -q 'lib/run-context.sh' scripts/engine/checkpoint.sh`
- All 5 public functions defined
  - Check: `for fn in checkpoint_path checkpoint_write checkpoint_read checkpoint_detect checkpoint_clear; do grep -q "^${fn}()" scripts/engine/checkpoint.sh || exit 1; done && echo PASS`
- No inline `date` calls (Principle IX)
  - Check: `! grep -nE '(^|[^A-Za-z_])date[[:space:]]' scripts/engine/checkpoint.sh`
- Bash 3.2 compatible (no associative arrays, no readarray, no mapfile, no proc-sub redirect)
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/engine/checkpoint.sh && ! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/engine/checkpoint.sh`
- Atomic write via temp-file-then-mv
  - Check: `grep -q '\.tmp\.\$\$' scripts/engine/checkpoint.sh && grep -qE 'mv[[:space:]]+"\$tmp"' scripts/engine/checkpoint.sh`
- `checkpoint_write` emits CHECKPOINT_WRITE on success
  - Check: `grep -q 'emit_event CHECKPOINT_WRITE' scripts/engine/checkpoint.sh`

### Artifacts

- `scripts/engine/checkpoint.sh` (min 90 lines, contains "_CHECKPOINT_SOURCED")

### Key Links

- `scripts/engine/checkpoint.sh` → `scripts/lib/errors.sh` (sourced for emit_result path)
- `scripts/engine/checkpoint.sh` → `scripts/lib/events.sh` (sourced for emit_event CHECKPOINT_WRITE)
- `scripts/engine/checkpoint.sh` → `scripts/lib/run-context.sh` (sourced for orch_now / ORCH_RUN_ID)

## Verification

Run the full verification block from Step 4 above from the repo root. All PASS lines must print.

## Inputs

### From Previous Tasks

None — T01 is the first task of P03 and has no upstream task dependencies.

### From Disk (Pre-existing)

- `scripts/lib/errors.sh` — already on disk from P02. Provides `emit_result` / `orch_is_error_kind`. Sourced at load time via relative path `$(dirname "${BASH_SOURCE[0]}")/../lib/errors.sh`.
- `scripts/lib/events.sh` — already on disk from P02. Provides `emit_event` and `ORCH_EVENT_TYPES`. The type `CHECKPOINT_WRITE` and `CHECKPOINT_RESUME` are both in the canonical 19-entry registry. `emit_event` signature: `emit_event <TYPE> [key=value ...]` — values containing whitespace auto-quote.
- `scripts/lib/run-context.sh` — already on disk from P02. Provides `init_run_context`, `orch_now`, `orch_is_forced`, `orch_is_dry_run`. `orch_now` returns `$ORCH_STARTED_AT` when set (no inline `date`). `init_run_context` exports `ORCH_RUN_ID`, `ORCH_STARTED_AT`, `ORCH_FORCE`, `ORCH_DRY_RUN`, `ORCH_RUN_MILESTONE`, `ORCH_RUN_PHASE`.
- `.specify/memory/constitution.md` — Principles II (emit events on state changes), VI (state on disk), IX (no inline date). Referenced via comments.
- `ANTIPATTERNS.md` — AP-001 (no proc-sub redirect targets), AP-003 (guard placement in head -5).
- `scripts/lifecycle/lock-manager.sh` — reference for atomic temp-file-then-mv pattern if needed.

## Expected Output

A new file `scripts/engine/checkpoint.sh` at ≥90 lines with:
- Shebang line 1, one-line comment line 2, `[ -n "${_CHECKPOINT_SOURCED:-}" ] && return 0` on line 3, `_CHECKPOINT_SOURCED=1` on line 4.
- Relative sourcing of `../lib/errors.sh`, `../lib/events.sh`, `../lib/run-context.sh` via `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`.
- 5 public functions: `checkpoint_path`, `checkpoint_write`, `checkpoint_read`, `checkpoint_detect`, `checkpoint_clear`.
- 1 internal helper: `_checkpoint_escape`.
- Atomic write pattern: `"${cp}.tmp.$$"` temp file, `mv` into place.
- `emit_event CHECKPOINT_WRITE ...` call inside `checkpoint_write` on success.
- `ORCH_CHECKPOINT_ROOT` env override with default `.specify/orchestrator/milestones`.
- No inline `date`, no `jq`, no Bash 4+ syntax, no proc-sub redirect.

No modifications to any other file. No touching of `.specify/orchestrator/milestones/M004/engine-checkpoint.json` — that file is created by runtime invocations in T05/T06.
