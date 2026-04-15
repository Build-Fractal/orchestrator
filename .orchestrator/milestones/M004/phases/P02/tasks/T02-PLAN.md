---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M004"
name: "events.sh — Structured Event Emission"
depends_on: [T01]
---

## Description

Implement `scripts/lib/events.sh` — a Bash 3.2 compatible sourced library providing `emit_event`, the structured event emitter used by every engine-managed script. Events are the observable evidence trail for engine coordination per the amended Principle II. The library also declares a canonical event type registry so downstream consumers (dashboards, Conversus integration, the P03 engine coordinator) can dispatch on `type` without parsing free-form strings.

`emit_event` outputs exactly one line per call to stdout in the form:
```
EVENT:<TYPE> timestamp=<iso8601> run_id=<id> key=value key=value ...
```
Where `<TYPE>` is drawn from the canonical registry (enforcement: warning only — unknown types produce a `SAFETY_WARNING` event rather than a hard error, so callers can extend the registry over time as new event types are added). Timestamps come from `$ORCH_STARTED_AT` when run-context has been loaded; otherwise the library falls back to a single `date -u +%Y-%m-%dT%H:%M:%SZ` call (acceptable because events.sh can be sourced standalone for ad-hoc use). Key-value pairs are passed as positional arguments in `key=value` form and are shell-quoted only if they contain whitespace.

The canonical registry includes at minimum:
- Engine lifecycle: `SESSION_START`, `SESSION_END`, `TASK_START`, `TASK_COMPLETE`, `PHASE_START`, `PHASE_COMPLETE`
- Safety rails: `GUARD_BLOCKED`, `GUARD_WARNING`, `SAFETY_WARNING`
- Hooks: `HOOK_START`, `HOOK_COMPLETE`, `HOOK_BLOCKED`, `HOOK_VIOLATION`
- Dispatch: `DISPATCH_START`, `DISPATCH_FALLBACK`, `VERIFY_COMPLETE`

This implements:
- FR-221 (emit_event produces parseable EVENT lines)
- Principle II amendment (mandatory structured events from engine-managed scripts)
- Principle IX (deterministic timestamps via $ORCH_STARTED_AT)
- NFR-200 (Bash 3.2 compatible)
- NFR-203 (double-sourcing guard)

## Steps

### Step 1: Verify T01 is in place

```bash
test -f scripts/lib/errors.sh || { echo "ERROR: T01 errors.sh must exist first"; exit 1; }
```

### Step 2: Create `scripts/lib/events.sh`

Write the following content verbatim:

```bash
#!/usr/bin/env bash
# scripts/lib/events.sh — Structured event emission for engine-managed scripts.
#
# Source this file to get:
#   - emit_event <TYPE> [key=value ...]  — prints a single EVENT: line
#   - ORCH_EVENT_TYPES                    — newline-separated canonical registry
#   - orch_is_event_type <type>           — validates a type against the registry
#
# Bash 3.2 compatible (NFR-200). Double-sourcing guard per NFR-203 / AP-003.
#
# Constitution:
#   Principle II (amended): engine-managed scripts MUST emit structured events.
#   Principle IX: timestamps derive from $ORCH_STARTED_AT when set, so events
#   from the same run share the same frozen session timestamp.

# --- Double-sourcing guard ---
[ -n "${_EVENTS_SOURCED:-}" ] && return 0
_EVENTS_SOURCED=1

# --- Canonical event type registry (FR-221) ---
# Engine lifecycle events correlate to the dispatch pipeline stages.
# Safety/hook events correspond to guard and hook outcomes.
# Dispatch events are emitted by the P03 engine and P06 scripts.
ORCH_EVENT_TYPES="SESSION_START
SESSION_END
PHASE_START
PHASE_COMPLETE
TASK_START
TASK_COMPLETE
DISPATCH_START
DISPATCH_FALLBACK
VERIFY_START
VERIFY_COMPLETE
GUARD_BLOCKED
GUARD_WARNING
SAFETY_WARNING
HOOK_START
HOOK_COMPLETE
HOOK_BLOCKED
HOOK_VIOLATION
CHECKPOINT_WRITE
CHECKPOINT_RESUME"

export ORCH_EVENT_TYPES

# orch_is_event_type <type>
# Returns 0 if <type> is in the canonical registry, 1 otherwise. This is a
# warning-level check: emit_event still prints unknown types but also emits a
# SAFETY_WARNING so the drift is observable.
orch_is_event_type() {
  local t="$1"
  [ -z "$t" ] && return 1
  case "$t" in
    SESSION_START|SESSION_END|PHASE_START|PHASE_COMPLETE|TASK_START|TASK_COMPLETE) return 0 ;;
    DISPATCH_START|DISPATCH_FALLBACK|VERIFY_START|VERIFY_COMPLETE) return 0 ;;
    GUARD_BLOCKED|GUARD_WARNING|SAFETY_WARNING) return 0 ;;
    HOOK_START|HOOK_COMPLETE|HOOK_BLOCKED|HOOK_VIOLATION) return 0 ;;
    CHECKPOINT_WRITE|CHECKPOINT_RESUME) return 0 ;;
    *) return 1 ;;
  esac
}

# _orch_events_timestamp
# Returns an ISO-8601 UTC timestamp. Prefers $ORCH_STARTED_AT (set by
# init_run_context in run-context.sh) for determinism. Falls back to a single
# date call when run-context is not loaded.
_orch_events_timestamp() {
  if [ -n "${ORCH_STARTED_AT:-}" ]; then
    printf '%s' "$ORCH_STARTED_AT"
  else
    date -u +%Y-%m-%dT%H:%M:%SZ
  fi
}

# _orch_events_quote <string>
# Shell-safe quoting for event values: if the value contains whitespace, wrap
# it in double quotes and escape internal double quotes. Otherwise emit as-is.
_orch_events_quote() {
  local s="$1"
  case "$s" in
    *[[:space:]]*|*'"'*)
      s="$(printf '%s' "$s" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')"
      printf '"%s"' "$s"
      ;;
    *)
      printf '%s' "$s"
      ;;
  esac
}

# emit_event <TYPE> [key=value ...]
# Prints a single EVENT: line to stdout. TYPE is uppercase from the canonical
# registry (unknown types trigger a SAFETY_WARNING companion event). Remaining
# args are key=value pairs; values containing whitespace are shell-quoted.
#
# Examples:
#   emit_event SESSION_START run_id="$ORCH_RUN_ID" milestone=M004
#   emit_event TASK_START task=T02 phase=P02
#   emit_event GUARD_BLOCKED guard=payload_sanity reason="empty payload"
emit_event() {
  local type="$1"
  shift || true

  if [ -z "$type" ]; then
    type="SAFETY_WARNING"
    set -- "reason=emit_event_missing_type" "$@"
  fi

  if ! orch_is_event_type "$type"; then
    # Emit the original event first (callers extending the registry), then a
    # companion SAFETY_WARNING so the drift is observable in the event stream.
    _orch_events_print "$type" "$@"
    _orch_events_print "SAFETY_WARNING" "reason=unknown_event_type" "original_type=$type"
    return 0
  fi

  _orch_events_print "$type" "$@"
}

# Internal: format and print one EVENT: line.
_orch_events_print() {
  local type="$1"
  shift || true

  local ts run_id out
  ts="$(_orch_events_timestamp)"
  run_id="${ORCH_RUN_ID:-unset}"
  out="EVENT:${type} timestamp=${ts} run_id=${run_id}"

  local kv key val
  for kv in "$@"; do
    case "$kv" in
      *=*)
        key="${kv%%=*}"
        val="${kv#*=}"
        val="$(_orch_events_quote "$val")"
        out="${out} ${key}=${val}"
        ;;
      *)
        out="${out} ${kv}"
        ;;
    esac
  done

  printf '%s\n' "$out"
}
```

### Step 3: Make the file executable

```bash
chmod +x scripts/lib/events.sh
```

### Step 4: Verify

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Basic static checks
test -f scripts/lib/events.sh && echo "PASS: file exists" || echo "FAIL"
lines=$(wc -l < scripts/lib/events.sh | tr -d ' ')
test "$lines" -ge 80 && echo "PASS: $lines lines" || echo "FAIL: $lines"

head -5 scripts/lib/events.sh | grep -q '_EVENTS_SOURCED' && echo "PASS: guard" || echo "FAIL"

# Canonical registry includes all required types
for t in SESSION_START TASK_START TASK_COMPLETE PHASE_COMPLETE GUARD_BLOCKED HOOK_BLOCKED HOOK_VIOLATION SAFETY_WARNING; do
  grep -q "$t" scripts/lib/events.sh && echo "PASS: $t" || echo "FAIL: $t"
done

grep -q '^emit_event()' scripts/lib/events.sh && echo "PASS: emit_event defined" || echo "FAIL"

# Bash 3.2 checks
! grep -qE 'declare -A|readarray|mapfile' scripts/lib/events.sh && echo "PASS: Bash 3.2" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/events.sh && echo "PASS: no proc sub" || echo "FAIL"

# Behavioral: emit_event prints a parseable line with run_id
out="$(bash -c 'ORCH_RUN_ID=rid-123 ORCH_STARTED_AT=2026-04-10T00:00:00Z . scripts/lib/events.sh; emit_event TASK_START task=T02 phase=P02')"
echo "$out" | grep -q '^EVENT:TASK_START ' && echo "PASS: EVENT prefix" || echo "FAIL: $out"
echo "$out" | grep -q 'run_id=rid-123' && echo "PASS: run_id threaded" || echo "FAIL: $out"
echo "$out" | grep -q 'timestamp=2026-04-10T00:00:00Z' && echo "PASS: deterministic ts" || echo "FAIL: $out"
echo "$out" | grep -q 'task=T02' && echo "PASS: kv pair" || echo "FAIL: $out"

# Behavioral: quoting for values with whitespace
out="$(bash -c 'ORCH_STARTED_AT=now . scripts/lib/events.sh; emit_event GUARD_BLOCKED guard=payload reason="empty payload"')"
echo "$out" | grep -q 'reason="empty payload"' && echo "PASS: ws quoting" || echo "FAIL: $out"

# Behavioral: unknown type produces companion SAFETY_WARNING
out="$(bash -c '. scripts/lib/events.sh; emit_event FOOBAR')"
echo "$out" | grep -q '^EVENT:SAFETY_WARNING ' && echo "PASS: unknown type warns" || echo "FAIL: $out"

# Double-sourcing idempotent
bash -c '. scripts/lib/events.sh; . scripts/lib/events.sh; type emit_event >/dev/null' && echo "PASS: idempotent" || echo "FAIL"
```

Every line should print `PASS:`.

## Must-Haves

### Truths

- `scripts/lib/events.sh` has a double-sourcing guard
  - Check: `head -5 scripts/lib/events.sh | grep -q '_EVENTS_SOURCED'`
- `emit_event` function is defined
  - Check: `grep -q '^emit_event()' scripts/lib/events.sh`
- Canonical registry contains required engine event types
  - Check: `for t in SESSION_START TASK_START TASK_COMPLETE PHASE_COMPLETE GUARD_BLOCKED HOOK_BLOCKED HOOK_VIOLATION; do grep -q "$t" scripts/lib/events.sh || exit 1; done && echo PASS`
- Bash 3.2 compatible
  - Check: `! grep -qE 'declare -A|readarray|mapfile' scripts/lib/events.sh && ! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/events.sh`
- `emit_event` prints EVENT: prefixed output
  - Check: `bash -c '. scripts/lib/events.sh; emit_event TASK_START task=T02' | grep -q '^EVENT:TASK_START'`
- `emit_event` threads `$ORCH_RUN_ID` and `$ORCH_STARTED_AT` when set (Principle IX)
  - Check: `bash -c 'ORCH_RUN_ID=abc ORCH_STARTED_AT=2026-04-10T00:00:00Z . scripts/lib/events.sh; emit_event TASK_START' | grep -q 'run_id=abc' && bash -c 'ORCH_RUN_ID=abc ORCH_STARTED_AT=2026-04-10T00:00:00Z . scripts/lib/events.sh; emit_event TASK_START' | grep -q 'timestamp=2026-04-10T00:00:00Z'`
- Unknown event type produces a SAFETY_WARNING companion event
  - Check: `bash -c '. scripts/lib/events.sh; emit_event FOOBAR' | grep -q '^EVENT:SAFETY_WARNING'`
- Library is idempotent under double-sourcing
  - Check: `bash -c '. scripts/lib/events.sh; . scripts/lib/events.sh; type emit_event >/dev/null'`

### Artifacts

- `scripts/lib/events.sh` (min 80 lines, contains "_EVENTS_SOURCED")

### Key Links

- `scripts/lib/events.sh` → `.specify/memory/constitution.md` (implements Principle II amendment and Principle IX deterministic timestamps)
- `scripts/lib/events.sh` → `scripts/lib/errors.sh` (error taxonomy is cross-referenced in comments; SAFETY_WARNING is the event counterpart to emit_result error)

## Verification

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
echo "=== T02 Verification ==="

test -f scripts/lib/events.sh && echo "PASS: file exists" || { echo "FAIL"; exit 1; }
lines=$(wc -l < scripts/lib/events.sh | tr -d ' ')
test "$lines" -ge 80 && echo "PASS: $lines lines" || echo "FAIL: only $lines"

head -5 scripts/lib/events.sh | grep -q '_EVENTS_SOURCED' && echo "PASS: guard" || echo "FAIL: no guard"

for t in SESSION_START TASK_START TASK_COMPLETE PHASE_COMPLETE GUARD_BLOCKED HOOK_BLOCKED HOOK_VIOLATION SAFETY_WARNING; do
  grep -q "$t" scripts/lib/events.sh && echo "PASS: $t in registry" || echo "FAIL: $t"
done

grep -q '^emit_event()' scripts/lib/events.sh && echo "PASS: emit_event defined" || echo "FAIL"
grep -q '^orch_is_event_type()' scripts/lib/events.sh && echo "PASS: orch_is_event_type defined" || echo "FAIL"

! grep -qE 'declare -A|readarray|mapfile' scripts/lib/events.sh && echo "PASS: Bash 3.2 compat" || echo "FAIL"
! grep -qE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/events.sh && echo "PASS: no proc sub" || echo "FAIL"

# Behavioral checks
out="$(bash -c 'ORCH_RUN_ID=rid ORCH_STARTED_AT=2026-04-10T00:00:00Z . scripts/lib/events.sh; emit_event TASK_START task=T02')"
echo "$out" | grep -q '^EVENT:TASK_START ' && echo "PASS: EVENT prefix" || echo "FAIL: $out"
echo "$out" | grep -q 'run_id=rid' && echo "PASS: run_id threaded" || echo "FAIL"
echo "$out" | grep -q 'timestamp=2026-04-10T00:00:00Z' && echo "PASS: deterministic ts" || echo "FAIL"

out="$(bash -c '. scripts/lib/events.sh; emit_event FOOBAR')"
echo "$out" | grep -q '^EVENT:SAFETY_WARNING' && echo "PASS: unknown type warns" || echo "FAIL: $out"

bash -c '. scripts/lib/events.sh; . scripts/lib/events.sh; type emit_event >/dev/null' && echo "PASS: idempotent" || echo "FAIL"

echo "=== T02 complete ==="
```

## Inputs

### From Previous Tasks

- `scripts/lib/errors.sh` (from T01)
  - Key API: `emit_result <status> [error_kind] [detail]` — single RESULT: line emitter, conceptually analogous to `emit_event`
  - Key types: `ORCH_ERR_CONFIG`, `ORCH_ERR_STATE`, `ORCH_ERR_DISPATCH`, `ORCH_ERR_VERIFY`, `ORCH_ERR_BUDGET`, `ORCH_ERR_IO`, `ORCH_ERR_KINDS`, `orch_is_error_kind()`
  - Behavioral contract: `emit_result` always produces exactly one `RESULT:{...}` line. `orch_is_error_kind` uses a case statement for O(1) validation. events.sh mirrors this pattern for events: the `orch_is_event_type` validator uses the same case structure.
  - Usage note: events.sh does NOT source errors.sh at runtime. The two libraries are independent siblings. Cross-reference is via comments only. This avoids circular dependency and keeps events.sh usable even if errors.sh is unavailable (edge case: agent just wants to emit events for observability).

### From Disk (Pre-existing)

- `.specify/memory/constitution.md` — Principle II amendment requires emit_event on engine-managed scripts. Principle IX requires `$ORCH_STARTED_AT` over inline `date`.
- `ANTIPATTERNS.md` — AP-001 (no process substitution as redirect target), AP-003 (double-sourcing guard required).
- `specs/004-engine-architecture/spec.md` — FR-221 (`emit_event` produces parseable `EVENT:{type}` lines), US4 acceptance scenarios, and event names referenced in US1 (SESSION_START, TASK_START, TASK_COMPLETE, PHASE_COMPLETE), US5 (HOOK_BLOCKED, HOOK_VIOLATION), US6 (GUARD_BLOCKED).
- `scripts/knowledge/lib/staleness.sh` — Reference double-sourcing guard pattern.

## Expected Output

The file `scripts/lib/events.sh` containing:
- Shebang and descriptive header comment referencing Principle II and IX
- Double-sourcing guard (`_EVENTS_SOURCED`)
- `ORCH_EVENT_TYPES` newline-separated canonical registry (at least 18 types covering lifecycle, dispatch, safety, hooks, checkpoints)
- `orch_is_event_type` validator using a case statement
- `_orch_events_timestamp` internal: prefers `$ORCH_STARTED_AT`, falls back to `date -u`
- `_orch_events_quote` internal: whitespace-sensitive value quoting
- `emit_event <TYPE> [key=value ...]` public function that prints exactly one `EVENT:` line per call, threads `$ORCH_RUN_ID` and `$ORCH_STARTED_AT`, and emits a `SAFETY_WARNING` companion when called with an unknown type
- `_orch_events_print` internal formatter
- File ≥ 80 lines, Bash 3.2 compatible, no `declare -A`/`readarray`/`mapfile`, no process substitution as redirection target
