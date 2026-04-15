---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M004"
name: "hooks.sh — Hook Lifecycle Dispatch"
depends_on: [T01, T02, T03, T04]
---

## Description

Implement `scripts/lib/hooks.sh` — a Bash 3.2 compatible sourced library that provides `run_hooks`, the engine's hook-lifecycle dispatcher. Hooks are the integration seam for external tools (Conversus deliberation gate, monitoring, audit) per the spec's US5. This library enforces Principle XII (Hook Isolation): hooks receive a **chmod 444 frozen state snapshot** in a temp file, cannot modify engine state, are killed at a timeout (default 30s), and block the pipeline when they fail unless explicitly marked `block_on_fail: false`.

The main entry point is:

```
run_hooks <lifecycle_point> <state_source>
```

Where:
- `<lifecycle_point>` is one of `PRE_DISPATCH`, `POST_DISPATCH`, `POST_VERIFY`, `PRE_ADVANCE` (US5 AS2)
- `<state_source>` is a path to the state file or directory to snapshot and pass to each hook

`run_hooks` performs these steps:
1. Resolve `templates/hooks.yaml` (or the most-specific recipe per FR-211 when available)
2. Discover hook entries for the given lifecycle point via `parse_recipe_hooks` from `scripts/lib/recipe-parser.sh` (already delivered by M004 P04 — note P02 runs in parallel with P04, so **graceful degradation is required**: when `recipe-parser.sh` is unavailable, `run_hooks` emits `SAFETY_WARNING reason=recipe_parser_unavailable` and returns 0 without executing hooks)
3. For each enabled hook:
   a. Create a read-only snapshot: copy `<state_source>` to a temp file, then `chmod 444`
   b. Emit `EVENT:HOOK_START hook=<name> lifecycle=<point>`
   c. Execute the hook script with `ORCH_HOOK_SNAPSHOT=<snapshot_path>` in the environment, enforcing the timeout
   d. After execution, check snapshot modification time / mode — if the file was modified, emit `EVENT:HOOK_VIOLATION` and block unconditionally (violation is never a warn)
   e. Clean up snapshot
   f. If the hook exited non-zero and `block_on_fail: true`, emit `EVENT:HOOK_BLOCKED` and return non-zero
   g. If the hook exited non-zero and `block_on_fail: false`, emit `EVENT:HOOK_WARNING`
   h. If exit was zero, emit `EVENT:HOOK_COMPLETE`
4. Return 0 if all hooks passed or were non-blocking, non-zero if any blocking hook failed

The hook timeout uses a portable Bash 3.2 pattern (spawn + sleep + kill), because `timeout(1)` is not available on stock macOS.

`run_hooks` also honors `ORCH_FORCE=1`: a blocking failure becomes a warning under force, matching the guards.sh pattern.

This implements:
- FR-223 (`lib/hooks.sh` discovers and executes hook scripts, passing frozen state snapshots)
- US5 AS1-6 (hook config, 4 lifecycle points, read-only snapshots, block behavior, disable flag)
- Principle XII (Hook Isolation)
- Principle II (structured events)
- NFR-200 (Bash 3.2 compatible)
- NFR-203 (double-sourcing guard)
- NFR-205 (hook execution timeout, default 30s)

## Steps

### Step 1: Verify T01-T04 are in place

```bash
for f in errors events run-context guards; do
  test -f "scripts/lib/${f}.sh" || { echo "ERROR: ${f}.sh missing"; exit 1; }
done
```

### Step 2: Create `scripts/lib/hooks.sh`

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# scripts/lib/hooks.sh — Hook lifecycle dispatcher with sandbox enforcement.
#
# Source this file to get:
#   - run_hooks <lifecycle_point> <state_source> [hooks_yaml_path]
#
# Lifecycle points (US5 AS2):
#   PRE_DISPATCH, POST_DISPATCH, POST_VERIFY, PRE_ADVANCE
#
# Principle XII (Hook Isolation): hooks receive a chmod 444 frozen state
# snapshot via $ORCH_HOOK_SNAPSHOT, are killed at timeout (default 30s), and
# cannot modify engine state. Snapshot modification triggers HOOK_VIOLATION.
#
# Graceful degradation: if scripts/lib/recipe-parser.sh is unavailable (e.g.,
# during P02 bootstrap when P04 has not yet run), run_hooks emits a
# SAFETY_WARNING and returns 0 — callers continue without hook enforcement.
#
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.

# --- Double-sourcing guard ---
[ -n "${_HOOKS_SOURCED:-}" ] && return 0
_HOOKS_SOURCED=1

_hooks_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
. "${_hooks_dir}/errors.sh"
# shellcheck disable=SC1090
. "${_hooks_dir}/events.sh"
# shellcheck disable=SC1090
. "${_hooks_dir}/run-context.sh"

# --- Configuration ---
ORCH_HOOK_TIMEOUT_SEC="${ORCH_HOOK_TIMEOUT_SEC:-30}"
ORCH_HOOKS_YAML_DEFAULT="${ORCH_HOOKS_YAML_DEFAULT:-templates/hooks.yaml}"

# _hooks_parser_available
# Returns 0 if scripts/lib/recipe-parser.sh is present AND provides
# parse_recipe_hooks. Safe to call without sourcing.
_hooks_parser_available() {
  local p="${_hooks_dir}/recipe-parser.sh"
  [ -f "$p" ] || return 1
  # Source it in a subshell to check for the function without polluting env.
  (
    # shellcheck disable=SC1090
    . "$p" 2>/dev/null || exit 1
    type parse_recipe_hooks >/dev/null 2>&1
  )
}

# _hooks_snapshot_create <source> <dest>
# Copies <source> to <dest> (file or tar of dir) and sets chmod 444.
# Returns 0 on success. Dest must be a file path.
_hooks_snapshot_create() {
  local src="$1"
  local dest="$2"
  if [ -f "$src" ]; then
    cp "$src" "$dest" || return 1
  elif [ -d "$src" ]; then
    # Tar the directory into a single sealed file.
    (cd "$src" && tar -cf - .) > "$dest" 2>/dev/null || return 1
  else
    # No source — write a stub so the file exists for chmod.
    printf 'no-state\n' > "$dest" || return 1
  fi
  chmod 444 "$dest" || return 1
  return 0
}

# _hooks_snapshot_unchanged <path> <original_mtime>
# Returns 0 if the snapshot's mtime still matches original_mtime (and mode is
# still 444). Non-zero indicates modification.
_hooks_snapshot_unchanged() {
  local p="$1"
  local orig="$2"
  local cur
  # stat is platform-divergent; try GNU then BSD.
  cur="$(stat -c '%Y' "$p" 2>/dev/null || stat -f '%m' "$p" 2>/dev/null || echo 0)"
  [ "$cur" = "$orig" ] || return 1
  # Verify mode is still 444 (readable, not writable).
  [ -w "$p" ] && return 1
  return 0
}

# _hooks_exec_with_timeout <timeout_sec> <command...>
# Runs the command with a portable timeout. Returns the command's exit code,
# or 124 on timeout. Bash 3.2 compatible (no `timeout(1)` dependency).
_hooks_exec_with_timeout() {
  local to="$1"
  shift
  "$@" &
  local cmd_pid=$!
  (
    sleep "$to"
    kill -TERM "$cmd_pid" 2>/dev/null
    sleep 1
    kill -KILL "$cmd_pid" 2>/dev/null
  ) &
  local watchdog_pid=$!
  local rc=0
  if wait "$cmd_pid" 2>/dev/null; then
    rc=0
  else
    rc=$?
  fi
  kill "$watchdog_pid" 2>/dev/null
  wait "$watchdog_pid" 2>/dev/null
  return "$rc"
}

# run_hooks <lifecycle_point> <state_source> [hooks_yaml_path]
# Public entry point. See header for behavior.
run_hooks() {
  local lifecycle="$1"
  local state_src="$2"
  local yaml="${3:-$ORCH_HOOKS_YAML_DEFAULT}"

  case "$lifecycle" in
    PRE_DISPATCH|POST_DISPATCH|POST_VERIFY|PRE_ADVANCE) ;;
    *)
      emit_event SAFETY_WARNING reason="unknown_lifecycle_point" lifecycle="$lifecycle"
      return 0
      ;;
  esac

  if ! _hooks_parser_available; then
    emit_event SAFETY_WARNING reason=recipe_parser_unavailable lifecycle="$lifecycle"
    return 0
  fi

  if [ ! -f "$yaml" ]; then
    emit_event SAFETY_WARNING reason=hooks_yaml_missing path="$yaml"
    return 0
  fi

  # shellcheck disable=SC1090
  . "${_hooks_dir}/recipe-parser.sh"

  # parse_recipe_hooks emits pipe-delimited lines:
  #   <key>|<name>|<script>|<enabled>|<block_on_fail>|<description>
  local hook_lines
  hook_lines="$(parse_recipe_hooks "$yaml" "$lifecycle" 2>/dev/null)"
  if [ -z "$hook_lines" ]; then
    return 0
  fi

  local overall_rc=0
  local line key name script enabled block desc
  local snap tmp_mtime rc

  # Use a temp file to avoid process substitution (AP-001).
  local _tmp
  _tmp="$(mktemp)"
  printf '%s\n' "$hook_lines" > "$_tmp"

  while IFS='|' read -r key name script enabled block desc; do
    [ -z "$key" ] && continue
    case "${enabled:-true}" in
      false|FALSE|0|no|NO) continue ;;
    esac

    if [ ! -x "$script" ] && [ ! -f "$script" ]; then
      emit_event SAFETY_WARNING reason=hook_script_missing hook="$key" script="$script"
      continue
    fi

    # Build snapshot
    snap="$(mktemp)"
    if ! _hooks_snapshot_create "$state_src" "$snap"; then
      emit_event HOOK_BLOCKED hook="$key" reason="snapshot_create_failed"
      rm -f "$snap"
      overall_rc=1
      continue
    fi
    tmp_mtime="$(stat -c '%Y' "$snap" 2>/dev/null || stat -f '%m' "$snap" 2>/dev/null || echo 0)"

    emit_event HOOK_START hook="$key" lifecycle="$lifecycle" script="$script"

    ORCH_HOOK_SNAPSHOT="$snap" _hooks_exec_with_timeout "$ORCH_HOOK_TIMEOUT_SEC" \
      bash "$script" >/dev/null 2>&1
    rc=$?

    # Check for snapshot tampering BEFORE evaluating exit code.
    if ! _hooks_snapshot_unchanged "$snap" "$tmp_mtime"; then
      emit_event HOOK_VIOLATION hook="$key" reason="snapshot_modified" script="$script"
      rm -f "$snap"
      overall_rc=1
      continue
    fi

    rm -f "$snap"

    if [ "$rc" -eq 0 ]; then
      emit_event HOOK_COMPLETE hook="$key" lifecycle="$lifecycle" exit_code=0
      continue
    fi

    # Non-zero exit: block or warn
    case "${block:-true}" in
      false|FALSE|0|no|NO)
        emit_event HOOK_WARNING hook="$key" lifecycle="$lifecycle" exit_code="$rc"
        ;;
      *)
        if orch_is_forced; then
          emit_event HOOK_WARNING hook="$key" lifecycle="$lifecycle" exit_code="$rc" forced=1
        else
          emit_event HOOK_BLOCKED hook="$key" lifecycle="$lifecycle" exit_code="$rc"
          overall_rc=1
        fi
        ;;
    esac
  done < "$_tmp"

  rm -f "$_tmp"
  return "$overall_rc"
}
```

### Step 3: Make executable

```bash
chmod +x scripts/lib/hooks.sh
```

### Step 4: Verify

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

test -f scripts/lib/hooks.sh && echo "PASS: file" || echo "FAIL"
lines=$(wc -l < scripts/lib/hooks.sh | tr -d ' ')
test "$lines" -ge 140 && echo "PASS: $lines lines" || echo "FAIL: $lines"
head -5 scripts/lib/hooks.sh | grep -q '_HOOKS_SOURCED' && echo "PASS: guard" || echo "FAIL"

grep -q '^run_hooks()' scripts/lib/hooks.sh && echo "PASS: run_hooks" || echo "FAIL"

grep -q 'chmod 444' scripts/lib/hooks.sh && echo "PASS: chmod 444" || echo "FAIL"
grep -q 'HOOK_BLOCKED' scripts/lib/hooks.sh && echo "PASS: HOOK_BLOCKED" || echo "FAIL"
grep -q 'HOOK_VIOLATION' scripts/lib/hooks.sh && echo "PASS: HOOK_VIOLATION" || echo "FAIL"
grep -q 'ORCH_HOOK_TIMEOUT_SEC' scripts/lib/hooks.sh && echo "PASS: timeout" || echo "FAIL"

# Lifecycle points
for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do
  grep -q "$p" scripts/lib/hooks.sh && echo "PASS: $p" || echo "FAIL: $p"
done

! grep -qE 'declare -A|readarray|mapfile' scripts/lib/hooks.sh && echo "PASS: Bash 3.2" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/hooks.sh && echo "PASS: no proc sub" || echo "FAIL"
! grep -qE 'sed -i[^A-Za-z_]' scripts/lib/hooks.sh && echo "PASS: no sed -i" || echo "FAIL"

# Behavioral: graceful degradation when recipe-parser.sh is absent
# (it IS absent in P02 until P04 completes)
if [ ! -f scripts/lib/recipe-parser.sh ]; then
  out="$(bash -c '. scripts/lib/hooks.sh; run_hooks PRE_DISPATCH /tmp/nonexistent' 2>&1)"
  echo "$out" | grep -q 'recipe_parser_unavailable' && echo "PASS: graceful degradation" || echo "FAIL: $out"
fi

# Behavioral: unknown lifecycle point produces SAFETY_WARNING
out="$(bash -c '. scripts/lib/hooks.sh; run_hooks BOGUS /tmp/x' 2>&1)"
echo "$out" | grep -q 'unknown_lifecycle_point' && echo "PASS: unknown lifecycle" || echo "FAIL: $out"

# Double-sourcing idempotent
bash -c '. scripts/lib/hooks.sh; . scripts/lib/hooks.sh; type run_hooks >/dev/null' && echo "PASS: idempotent" || echo "FAIL"

# All 5 libraries load in order without error
bash -c '. scripts/lib/errors.sh; . scripts/lib/events.sh; . scripts/lib/run-context.sh; . scripts/lib/guards.sh; . scripts/lib/hooks.sh; type emit_result emit_event init_run_context guard_payload_sanity run_hooks >/dev/null' && echo "PASS: all 5 libs load" || echo "FAIL"
```

Every line should print `PASS:`.

## Must-Haves

### Truths

- `scripts/lib/hooks.sh` has a double-sourcing guard
  - Check: `head -5 scripts/lib/hooks.sh | grep -q '_HOOKS_SOURCED'`
- `run_hooks` function is defined
  - Check: `grep -q '^run_hooks()' scripts/lib/hooks.sh`
- All 4 lifecycle points are recognized
  - Check: `for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do grep -q "$p" scripts/lib/hooks.sh || exit 1; done && echo PASS`
- Frozen snapshots use `chmod 444` per Principle XII
  - Check: `grep -q 'chmod 444' scripts/lib/hooks.sh`
- Hook timeout is enforced and configurable via `ORCH_HOOK_TIMEOUT_SEC`
  - Check: `grep -q 'ORCH_HOOK_TIMEOUT_SEC' scripts/lib/hooks.sh`
- HOOK_BLOCKED and HOOK_VIOLATION events are emitted
  - Check: `grep -q 'HOOK_BLOCKED' scripts/lib/hooks.sh && grep -q 'HOOK_VIOLATION' scripts/lib/hooks.sh`
- Graceful degradation: when recipe-parser.sh is absent, run_hooks emits SAFETY_WARNING and returns 0
  - Check: `grep -q 'recipe_parser_unavailable' scripts/lib/hooks.sh`
- hooks.sh sources errors.sh, events.sh, and run-context.sh (but NOT recipe-parser.sh at load time)
  - Check: `grep -q 'errors\.sh' scripts/lib/hooks.sh && grep -q 'events\.sh' scripts/lib/hooks.sh && grep -q 'run-context\.sh' scripts/lib/hooks.sh`
- Bash 3.2 compatible, no process substitution, no `sed -i`
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/lib/hooks.sh && ! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/hooks.sh && ! grep -qE 'sed -i[^A-Za-z_]' scripts/lib/hooks.sh`
- Library is idempotent under double-sourcing
  - Check: `bash -c '. scripts/lib/hooks.sh; . scripts/lib/hooks.sh; type run_hooks >/dev/null'`
- All 5 P02 libraries load successfully in sequence
  - Check: `bash -c '. scripts/lib/errors.sh; . scripts/lib/events.sh; . scripts/lib/run-context.sh; . scripts/lib/guards.sh; . scripts/lib/hooks.sh; type emit_result emit_event init_run_context guard_payload_sanity run_hooks >/dev/null'`

### Artifacts

- `scripts/lib/hooks.sh` (min 140 lines, contains "_HOOKS_SOURCED")

### Key Links

- `scripts/lib/hooks.sh` → `scripts/lib/errors.sh` (sources)
- `scripts/lib/hooks.sh` → `scripts/lib/events.sh` (emits HOOK_* events)
- `scripts/lib/hooks.sh` → `scripts/lib/run-context.sh` (reads ORCH_FORCE via orch_is_forced)
- `scripts/lib/hooks.sh` → `.specify/memory/constitution.md` (implements Principle XII Hook Isolation)

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T05 Verification ==="

test -f scripts/lib/hooks.sh && echo "PASS: file" || { echo "FAIL"; exit 1; }
lines=$(wc -l < scripts/lib/hooks.sh | tr -d ' ')
test "$lines" -ge 140 && echo "PASS: $lines lines" || echo "FAIL: $lines"
head -5 scripts/lib/hooks.sh | grep -q '_HOOKS_SOURCED' && echo "PASS: guard" || echo "FAIL"

grep -q '^run_hooks()' scripts/lib/hooks.sh && echo "PASS: run_hooks defined" || echo "FAIL"
grep -q 'chmod 444' scripts/lib/hooks.sh && echo "PASS: chmod 444" || echo "FAIL"
grep -q 'HOOK_BLOCKED' scripts/lib/hooks.sh && echo "PASS: HOOK_BLOCKED" || echo "FAIL"
grep -q 'HOOK_VIOLATION' scripts/lib/hooks.sh && echo "PASS: HOOK_VIOLATION" || echo "FAIL"
grep -q 'ORCH_HOOK_TIMEOUT_SEC' scripts/lib/hooks.sh && echo "PASS: timeout" || echo "FAIL"
grep -q 'recipe_parser_unavailable' scripts/lib/hooks.sh && echo "PASS: graceful degradation" || echo "FAIL"

for p in PRE_DISPATCH POST_DISPATCH POST_VERIFY PRE_ADVANCE; do
  grep -q "$p" scripts/lib/hooks.sh && echo "PASS: $p" || echo "FAIL: $p"
done

! grep -qE 'declare -A|readarray|mapfile' scripts/lib/hooks.sh && echo "PASS: Bash 3.2" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/hooks.sh && echo "PASS: no proc sub" || echo "FAIL"
! grep -qE 'sed -i[^A-Za-z_]' scripts/lib/hooks.sh && echo "PASS: no sed -i" || echo "FAIL"

bash -c '. scripts/lib/hooks.sh; run_hooks BOGUS /tmp/x' 2>&1 | grep -q 'unknown_lifecycle_point' && echo "PASS: unknown lifecycle" || echo "FAIL"

bash -c '. scripts/lib/hooks.sh; . scripts/lib/hooks.sh; type run_hooks >/dev/null' && echo "PASS: idempotent" || echo "FAIL"

bash -c '. scripts/lib/errors.sh; . scripts/lib/events.sh; . scripts/lib/run-context.sh; . scripts/lib/guards.sh; . scripts/lib/hooks.sh; type emit_result emit_event init_run_context guard_payload_sanity run_hooks >/dev/null' && echo "PASS: all 5 libs load" || echo "FAIL"

echo "=== T05 complete ==="
```

## Inputs

### From Previous Tasks

- `scripts/lib/errors.sh` (from T01)
  - Key API: `emit_result <status> [error_kind] [detail]`
  - Key types: `ORCH_ERR_STATE`, `ORCH_ERR_IO`, `ORCH_ERR_DISPATCH`
  - Behavioral contract: hooks.sh sources errors.sh so downstream callers inherit the taxonomy. Hooks themselves don't emit RESULT; the engine invokes `emit_result` after hook dispatch.

- `scripts/lib/events.sh` (from T02)
  - Key API: `emit_event <TYPE> [key=value ...]`
  - Key types used by this task: `HOOK_START`, `HOOK_COMPLETE`, `HOOK_BLOCKED`, `HOOK_VIOLATION`, `HOOK_WARNING` (all pre-registered in events.sh canonical registry), `SAFETY_WARNING` (for graceful degradation paths)
  - Behavioral contract: events are printed to stdout on single lines. Values with whitespace are auto-quoted.

- `scripts/lib/run-context.sh` (from T03)
  - Key API: `orch_is_forced` (returns 0 when ORCH_FORCE is truthy)
  - Exported vars used: `ORCH_FORCE` (indirectly via orch_is_forced)
  - Behavioral contract: hooks.sh calls `orch_is_forced` to convert a blocking failure into a warning under `--force`.

- `scripts/lib/guards.sh` (from T04)
  - Not sourced at runtime, but shares conventions: guards.sh established the `_block` helper pattern (emit GUARD_BLOCKED on fail, GUARD_WARNING on forced). hooks.sh adopts the same pattern for HOOK_BLOCKED / HOOK_WARNING to keep the event stream consistent. T04 must complete before T05 so the conventions are in place.

- **Not a task dependency, but a sibling consumer** — `scripts/lib/recipe-parser.sh` (from M004 P04, may not exist yet when T05 runs)
  - Key API (when available): `parse_recipe_hooks <file> <lifecycle_point>` — outputs pipe-delimited lines: `<key>|<name>|<script>|<enabled>|<block_on_fail>|<description>`
  - Behavioral contract: `run_hooks` detects whether recipe-parser.sh exists via `_hooks_parser_available`. If absent, `run_hooks` emits `SAFETY_WARNING reason=recipe_parser_unavailable` and returns 0 without enforcing hooks. This keeps P02 independent of P04 — both phases can execute concurrently per the M004 roadmap's parallel dependency graph.

### From Disk (Pre-existing)

- `.specify/memory/constitution.md` — Principle XII (Hook Isolation): chmod 444 snapshots, timeout enforcement, hooks cannot modify engine state. Principle II amendment for structured events.
- `ANTIPATTERNS.md` — AP-001 (no process substitution — use temp file + while read), AP-002 (no `sed -i`), AP-003 (double-sourcing guard).
- `specs/004-engine-architecture/spec.md` — FR-223 (`lib/hooks.sh` discovers and executes hook scripts, passing frozen state snapshots). US5 AS1-6 define the exact hook behavior contract. Edge case 4: "Snapshot is chmod 444; if hook force-writes, engine detects modification and emits HOOK_VIOLATION event". NFR-205: hook execution timeout 30s configurable.

## Expected Output

The file `scripts/lib/hooks.sh` containing:
- Shebang and descriptive header referencing Principle XII and graceful degradation
- Double-sourcing guard (`_HOOKS_SOURCED`)
- Relative-path sourcing of errors.sh, events.sh, run-context.sh
- Configurable `ORCH_HOOK_TIMEOUT_SEC` (default 30) and `ORCH_HOOKS_YAML_DEFAULT` (default `templates/hooks.yaml`)
- `_hooks_parser_available` internal: probes for `scripts/lib/recipe-parser.sh` and checks that `parse_recipe_hooks` is defined
- `_hooks_snapshot_create <src> <dest>` internal: copies file or tars directory into a read-only (chmod 444) snapshot file
- `_hooks_snapshot_unchanged <path> <mtime>` internal: platform-portable modification detection using `stat -c '%Y'` / `stat -f '%m'` fallback
- `_hooks_exec_with_timeout <sec> <cmd...>` internal: portable timeout wrapper using a background watchdog (no dependency on `timeout(1)`)
- `run_hooks <lifecycle_point> <state_source> [hooks_yaml_path]` public entry:
  - Validates lifecycle point against the 4 allowed values
  - Returns 0 with SAFETY_WARNING when recipe-parser.sh is unavailable
  - Returns 0 with SAFETY_WARNING when the hooks.yaml file is missing
  - Parses hook entries via `parse_recipe_hooks`, iterates them via a temp-file pattern (no process substitution)
  - Skips disabled hooks
  - Builds a chmod 444 snapshot per hook, runs the hook with `ORCH_HOOK_SNAPSHOT` env var, enforces timeout
  - Detects snapshot tampering → HOOK_VIOLATION (always blocking, never downgrade)
  - On non-zero exit: HOOK_BLOCKED (default) or HOOK_WARNING (`block_on_fail: false`), HOOK_WARNING under `ORCH_FORCE=1`
  - Returns non-zero if any blocking hook failed
- File ≥ 140 lines, Bash 3.2 compatible, no process substitution as redirection target, no `sed -i`
