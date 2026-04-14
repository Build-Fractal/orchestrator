---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P05"
milestone: "M005"
name: "Update hooks.sh to parse VERDICT lines from hook stdout"
depends_on: ["T01"]
---

## Description

Update `scripts/lib/hooks.sh` so that hook scripts can communicate
structured outcomes via VERDICT lines on stdout, in addition to the
existing exit-code-based mechanism.

Currently hooks.sh discards all hook stdout (`>/dev/null` on line 157).
This task changes hooks.sh to:

1. Capture hook stdout to a temporary file instead of discarding it.
2. After the hook completes, scan captured stdout for `VERDICT:` lines
   using `parse_verdict` from verdicts.sh.
3. Map verdict values to hook outcomes:
   - `BLOCK` — treated as hook failure (same as non-zero exit + block=true)
   - `WARN` — emits `HOOK_WARNING` event with verdict reason
   - `PASS` — emits `HOOK_COMPLETE` event with verdict=PASS metadata
   - `NEEDS_REVIEW` — emits `HOOK_COMPLETE` event with verdict=NEEDS_REVIEW
     metadata (not a blocker, but signals human review needed)
4. When multiple VERDICT lines are present, the most severe verdict wins
   (severity order: BLOCK > NEEDS_REVIEW > WARN > PASS).
5. When no VERDICT line is present, behavior is unchanged — exit code
   determines outcome as before. This maintains backward compatibility
   with existing hooks that don't use the verdict protocol.

### Verdict vs Exit Code Precedence

The verdict protocol takes precedence over exit codes when a VERDICT line
is present. This means:

- Hook exits 0, emits `VERDICT:BLOCK` -> hook is blocked
- Hook exits 1, emits `VERDICT:PASS` -> hook passes (verdict overrides)
- Hook exits 0, no VERDICT line -> hook passes (legacy behavior)
- Hook exits 1, no VERDICT line -> hook block/warn per block flag (legacy)

This design allows hooks to communicate nuanced outcomes (WARN, NEEDS_REVIEW)
that exit codes cannot express.

## Steps

### Step 1 — Source verdicts.sh in hooks.sh

Add a source line for verdicts.sh after the existing source lines
(errors.sh, events.sh, run-context.sh) near the top of hooks.sh:

```bash
# shellcheck disable=SC1090
. "${_hooks_dir}/verdicts.sh"
```

### Step 2 — Add verdict severity comparison helper

Add an internal function `_hooks_verdict_severity` that maps verdict
values to numeric severity for comparison:

```bash
_hooks_verdict_severity() {
  case "$1" in
    PASS)         printf '0' ;;
    WARN)         printf '1' ;;
    NEEDS_REVIEW) printf '2' ;;
    BLOCK)        printf '3' ;;
    *)            printf '-1' ;;
  esac
}
```

### Step 3 — Add verdict extraction function

Add `_hooks_extract_verdict` that scans captured output for VERDICT lines
and returns the most severe verdict found:

```bash
# _hooks_extract_verdict <stdout_file>
# Scans a file for VERDICT: lines, returns the most severe verdict.
# Outputs: verdict<TAB>reason (from parse_verdict format)
# Returns 0 if at least one VERDICT line found, 1 otherwise.
_hooks_extract_verdict() {
  local stdout_file="$1"
  local max_severity=-1
  local max_verdict=""
  local max_reason=""
  local found=0

  while IFS= read -r line; do
    case "$line" in
      VERDICT:*)
        local parsed
        parsed="$(parse_verdict "$line")" || continue
        local v r sev
        v="$(printf '%s' "$parsed" | cut -f1)"
        r="$(printf '%s' "$parsed" | cut -f2-)"
        sev="$(_hooks_verdict_severity "$v")"
        if [ "$sev" -gt "$max_severity" ]; then
          max_severity="$sev"
          max_verdict="$v"
          max_reason="$r"
        fi
        found=1
        ;;
    esac
  done < "$stdout_file"

  if [ "$found" -eq 1 ]; then
    printf '%s\t%s\n' "$max_verdict" "$max_reason"
    return 0
  fi
  return 1
}
```

### Step 4 — Modify the hook execution block in run_hooks

The current execution block (around line 156-188) runs hooks with stdout
discarded. Change this to:

1. Capture stdout to a temp file instead of `/dev/null`.
2. After the hook completes, check for VERDICT lines.
3. If a VERDICT line is found, use it to determine the outcome instead
   of (or in addition to) the exit code.

Key changes to the execution block inside the `while` loop:

**Before** (line 156-157):
```bash
    ORCH_HOOK_SNAPSHOT="$snap" _hooks_exec_with_timeout "$ORCH_HOOK_TIMEOUT_SEC" \
      bash "$script" >/dev/null 2>&1
```

**After**:
```bash
    local hook_stdout
    hook_stdout="$(mktemp)"
    ORCH_HOOK_SNAPSHOT="$snap" _hooks_exec_with_timeout "$ORCH_HOOK_TIMEOUT_SEC" \
      bash "$script" >"$hook_stdout" 2>&1
```

Then, after the snapshot integrity check and before the exit-code-based
outcome logic, add verdict extraction:

```bash
    # --- Verdict protocol: check for VERDICT lines in hook stdout ---
    local verdict_line verdict_val verdict_reason
    if _hooks_extract_verdict "$hook_stdout"; then
      verdict_line="$(_hooks_extract_verdict "$hook_stdout")"
      verdict_val="$(printf '%s' "$verdict_line" | cut -f1)"
      verdict_reason="$(printf '%s' "$verdict_line" | cut -f2-)"
      rm -f "$hook_stdout"

      case "$verdict_val" in
        BLOCK)
          if orch_is_forced; then
            emit_event HOOK_WARNING hook="$key" lifecycle="$lifecycle" verdict="$verdict_val" reason="$verdict_reason" forced=1
          else
            emit_event HOOK_BLOCKED hook="$key" lifecycle="$lifecycle" verdict="$verdict_val" reason="$verdict_reason"
            overall_rc=1
          fi
          continue
          ;;
        WARN)
          emit_event HOOK_WARNING hook="$key" lifecycle="$lifecycle" verdict="$verdict_val" reason="$verdict_reason"
          continue
          ;;
        PASS|NEEDS_REVIEW)
          emit_event HOOK_COMPLETE hook="$key" lifecycle="$lifecycle" exit_code="$rc" verdict="$verdict_val" reason="$verdict_reason"
          continue
          ;;
      esac
    fi
    rm -f "$hook_stdout"
```

This code goes between the snapshot integrity check block and the existing
exit-code-based outcome block. The `continue` statements skip the legacy
exit-code logic when a verdict is present.

### Step 5 — Clean up temp file on all paths

Ensure `$hook_stdout` is cleaned up on all code paths, including early
continues from snapshot violation. Add `rm -f "$hook_stdout"` to the
snapshot violation block (after line 165).

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "hooks.sh captures VERDICT lines from hook stdout and maps
  BLOCK to hook failure, WARN to HOOK_WARNING event, PASS/NEEDS_REVIEW to
  HOOK_COMPLETE with verdict metadata."
- **Artifacts**: `scripts/lib/hooks.sh` (modify, contains "VERDICT:").

## Verification

Run the verification script:

```bash
bash scripts/verify/p05-hooks-verdict-parsing.sh
```

Should print PASS. This script checks that hooks.sh references VERDICT,
sources verdicts.sh, and calls parse_verdict.

### Files Touched By This Task

- `scripts/lib/hooks.sh` (modify)

## Inputs

### From Previous Tasks

- T01: `scripts/lib/verdicts.sh` must exist. Provides `parse_verdict`
  and `orch_is_verdict` used by the new code in hooks.sh.

### From Disk (Pre-existing)

- `scripts/lib/hooks.sh` — current hook dispatcher. Key areas to modify:
  - Line 3: double-sourcing guard `_HOOKS_SOURCED`
  - Lines 25-31: source block (errors.sh, events.sh, run-context.sh) —
    add verdicts.sh here
  - Lines 71-92: `_hooks_exec_with_timeout` — unchanged
  - Lines 94-191: `run_hooks` function — main modification target
  - Line 156-157: hook execution with stdout discarded (`>/dev/null 2>&1`)
    — change to capture to temp file
  - Lines 160-165: snapshot integrity check — add hook_stdout cleanup
  - Lines 169-186: exit-code-based outcome logic — add verdict extraction
    block before this

- `scripts/lib/verdicts.sh` (from T01) — provides `parse_verdict`,
  `orch_is_verdict`, verdict constants. Must be sourced before use.

- `scripts/lib/events.sh` — provides `emit_event`. Already sourced by
  hooks.sh. The verdict-aware events add `verdict=` and `reason=` key-value
  pairs to existing HOOK_COMPLETE, HOOK_WARNING, HOOK_BLOCKED event types.

## Expected Output

After completing this task:

1. `scripts/lib/hooks.sh` sources `scripts/lib/verdicts.sh`.
2. Hook stdout is captured to a temp file instead of discarded.
3. VERDICT lines in hook stdout are parsed and mapped to outcomes:
   BLOCK -> HOOK_BLOCKED, WARN -> HOOK_WARNING, PASS/NEEDS_REVIEW ->
   HOOK_COMPLETE with verdict metadata.
4. When no VERDICT line is present, exit-code-based behavior is unchanged.
5. Multiple VERDICT lines resolve to the most severe verdict.
6. Temp files are cleaned up on all code paths.
7. `bash scripts/verify/p05-hooks-verdict-parsing.sh` prints PASS.
8. `git status` shows 1 modified file (`hooks.sh`). Nothing else touched.
