---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M004"
goal: "Implement 5 shared Bash libraries (errors, events, run-context, guards, hooks) that provide emit_result, emit_event, deterministic run context, safety rails, and hook dispatch — all Bash 3.2 compatible with double-sourcing guards"
demo_sentence: "A developer can `source scripts/lib/errors.sh` to get `emit_result` with typed error kinds, `source scripts/lib/events.sh` to get `emit_event` with structured output, `source scripts/lib/run-context.sh` to initialize a deterministic run context with ORCH_RUN_ID and ORCH_STARTED_AT, `source scripts/lib/guards.sh` to call `guard_payload_sanity` / `guard_budget` / `guard_output_sanity` / `guard_phase_complete`, and `source scripts/lib/hooks.sh` to `run_hooks` at a lifecycle point with a chmod 444 frozen state snapshot — all 5 libraries are Bash 3.2 compatible with double-sourcing guards."
risk: "medium"
depends_on: [P01]
---

## Must-Haves

### Truths

- `scripts/lib/errors.sh` exists with a double-sourcing guard as one of the first executable lines
  - Check: `head -5 scripts/lib/errors.sh | grep -q '_ERRORS_SOURCED'`
- `scripts/lib/errors.sh` defines the closed error taxonomy (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO)
  - Check: `for k in CONFIG STATE DISPATCH VERIFY BUDGET IO; do grep -q "ORCH_ERR_${k}" scripts/lib/errors.sh || exit 1; done && echo PASS`
- `scripts/lib/errors.sh` defines `emit_result` function
  - Check: `grep -q '^emit_result()' scripts/lib/errors.sh`
- `scripts/lib/events.sh` has a double-sourcing guard
  - Check: `head -5 scripts/lib/events.sh | grep -q '_EVENTS_SOURCED'`
- `scripts/lib/events.sh` defines `emit_event` function producing `EVENT:` prefixed lines
  - Check: `grep -q '^emit_event()' scripts/lib/events.sh && grep -q 'EVENT:' scripts/lib/events.sh`
- `scripts/lib/events.sh` declares the canonical event type registry including SESSION_START, TASK_START, TASK_COMPLETE, PHASE_COMPLETE, GUARD_BLOCKED, HOOK_BLOCKED, HOOK_VIOLATION
  - Check: `for t in SESSION_START TASK_START TASK_COMPLETE PHASE_COMPLETE GUARD_BLOCKED HOOK_BLOCKED HOOK_VIOLATION; do grep -q "$t" scripts/lib/events.sh || exit 1; done && echo PASS`
- `scripts/lib/run-context.sh` has a double-sourcing guard
  - Check: `head -5 scripts/lib/run-context.sh | grep -q '_RUN_CONTEXT_SOURCED'`
- `scripts/lib/run-context.sh` defines `init_run_context` function that exports ORCH_RUN_ID, ORCH_STARTED_AT, ORCH_FORCE, ORCH_DRY_RUN
  - Check: `grep -q '^init_run_context()' scripts/lib/run-context.sh && grep -q 'export ORCH_RUN_ID' scripts/lib/run-context.sh && grep -q 'export ORCH_STARTED_AT' scripts/lib/run-context.sh && grep -q 'export ORCH_FORCE' scripts/lib/run-context.sh && grep -q 'export ORCH_DRY_RUN' scripts/lib/run-context.sh`
- `init_run_context` is deterministic when seeded via `ORCH_RUN_SEED` — two invocations with the same seed produce the same ORCH_RUN_ID and ORCH_STARTED_AT
  - Check: `bash -c 'set -e; . scripts/lib/run-context.sh; ORCH_RUN_SEED=abc init_run_context; a="$ORCH_RUN_ID:$ORCH_STARTED_AT"; unset _RUN_CONTEXT_SOURCED ORCH_RUN_ID ORCH_STARTED_AT ORCH_FORCE ORCH_DRY_RUN; . scripts/lib/run-context.sh; ORCH_RUN_SEED=abc init_run_context; b="$ORCH_RUN_ID:$ORCH_STARTED_AT"; test "$a" = "$b"'`
- `scripts/lib/guards.sh` has a double-sourcing guard
  - Check: `head -5 scripts/lib/guards.sh | grep -q '_GUARDS_SOURCED'`
- `scripts/lib/guards.sh` defines `guard_payload_sanity`, `guard_budget`, `guard_output_sanity`, `guard_phase_complete`
  - Check: `for fn in guard_payload_sanity guard_budget guard_output_sanity guard_phase_complete; do grep -q "^${fn}()" scripts/lib/guards.sh || exit 1; done && echo PASS`
- `guard_payload_sanity` blocks empty or sub-100-char payloads per spec AS1
  - Check: `bash -c 'set -e; . scripts/lib/errors.sh; . scripts/lib/events.sh; . scripts/lib/run-context.sh; init_run_context; . scripts/lib/guards.sh; tmp=$(mktemp); printf short > "$tmp"; if guard_payload_sanity "$tmp" 2>/dev/null; then rm -f "$tmp"; exit 1; fi; rm -f "$tmp"'`
- All guards are overridable via `ORCH_FORCE=1` per spec US6 AS6
  - Check: `grep -q 'ORCH_FORCE' scripts/lib/guards.sh`
- `scripts/lib/hooks.sh` has a double-sourcing guard
  - Check: `head -5 scripts/lib/hooks.sh | grep -q '_HOOKS_SOURCED'`
- `scripts/lib/hooks.sh` defines `run_hooks` function
  - Check: `grep -q '^run_hooks()' scripts/lib/hooks.sh`
- `scripts/lib/hooks.sh` creates frozen snapshots via `chmod 444` per Principle XII
  - Check: `grep -q 'chmod 444' scripts/lib/hooks.sh`
- `scripts/lib/hooks.sh` enforces a hook timeout and emits HOOK_BLOCKED on failure
  - Check: `grep -q 'HOOK_BLOCKED' scripts/lib/hooks.sh && grep -qE 'timeout|TIMEOUT' scripts/lib/hooks.sh`
- No library uses Bash 4+ syntax (associative arrays, readarray, mapfile) — NFR-200
  - Check: `! grep -rqE 'declare -A|readarray|mapfile' scripts/lib/errors.sh scripts/lib/events.sh scripts/lib/run-context.sh scripts/lib/guards.sh scripts/lib/hooks.sh`
- No library uses process substitution as a redirection target — AP-001
  - Check: `! grep -rqE 'done[[:space:]]*<[[:space:]]*<\(' scripts/lib/errors.sh scripts/lib/events.sh scripts/lib/run-context.sh scripts/lib/guards.sh scripts/lib/hooks.sh`
- No library uses `sed -i` without a portable wrapper — AP-002
  - Check: `! grep -rnE 'sed -i[^A-Za-z_]' scripts/lib/errors.sh scripts/lib/events.sh scripts/lib/run-context.sh scripts/lib/guards.sh scripts/lib/hooks.sh`
- No library calls `date` inline outside of run-context.sh — Principle IX
  - Check: `! grep -lE '\bdate[[:space:]]' scripts/lib/errors.sh scripts/lib/events.sh scripts/lib/guards.sh scripts/lib/hooks.sh`
- All 5 libraries can be sourced twice without error and without re-executing body code
  - Check: `bash -c 'set -e; for f in errors events run-context guards hooks; do . "scripts/lib/${f}.sh"; . "scripts/lib/${f}.sh"; done'`
- All 5 libraries can be sourced in any order (errors first, then others in dependency order) without undefined function errors
  - Check: `bash -c 'set -e; . scripts/lib/errors.sh; . scripts/lib/events.sh; . scripts/lib/run-context.sh; . scripts/lib/guards.sh; . scripts/lib/hooks.sh; type emit_result >/dev/null && type emit_event >/dev/null && type init_run_context >/dev/null && type guard_payload_sanity >/dev/null && type run_hooks >/dev/null'`

### Artifacts

- `scripts/lib/errors.sh` (min 60 lines, contains "_ERRORS_SOURCED")
- `scripts/lib/events.sh` (min 80 lines, contains "_EVENTS_SOURCED")
- `scripts/lib/run-context.sh` (min 70 lines, contains "_RUN_CONTEXT_SOURCED")
- `scripts/lib/guards.sh` (min 120 lines, contains "_GUARDS_SOURCED")
- `scripts/lib/hooks.sh` (min 140 lines, contains "_HOOKS_SOURCED")

### Key Links

- `scripts/lib/errors.sh` → `.specify/memory/constitution.md` (implements Principle II amendment requiring emit_result)
- `scripts/lib/events.sh` → `.specify/memory/constitution.md` (implements Principle II amendment requiring emit_event)
- `scripts/lib/events.sh` → `scripts/lib/errors.sh` (events uses ORCH_ERR_* taxonomy via comments/references)
- `scripts/lib/run-context.sh` → `.specify/memory/constitution.md` (implements Principle IX — deterministic timestamps, no inline date)
- `scripts/lib/guards.sh` → `scripts/lib/errors.sh` (guards call emit_result on failure)
- `scripts/lib/guards.sh` → `scripts/lib/events.sh` (guards call emit_event with GUARD_BLOCKED on failure)
- `scripts/lib/hooks.sh` → `scripts/lib/errors.sh` (hooks call emit_result)
- `scripts/lib/hooks.sh` → `scripts/lib/events.sh` (hooks call emit_event with HOOK_BLOCKED / HOOK_VIOLATION)
- `scripts/lib/hooks.sh` → `.specify/memory/constitution.md` (implements Principle XII Hook Isolation — chmod 444 snapshot, timeout)
- `ANTIPATTERNS.md` → `scripts/lib/errors.sh` (AP-003 double-sourcing guard pattern applied here)

## Tasks

### T01: errors.sh — Error Taxonomy and emit_result

Implement `scripts/lib/errors.sh` with the closed error taxonomy (CONFIG, STATE, DISPATCH, VERIFY, BUDGET, IO) as `ORCH_ERR_*` constants and an `emit_result` function producing a single `RESULT:{json}` line with status, error_kind, and detail fields. Standalone library — depends only on POSIX utilities.

### T02: events.sh — Structured Event Emission

Implement `scripts/lib/events.sh` with `emit_event` function producing parseable `EVENT:{type} timestamp=<iso> key=value ...` lines, plus a declared event type registry including SESSION_START, TASK_START, TASK_COMPLETE, PHASE_COMPLETE, GUARD_BLOCKED, HOOK_BLOCKED, HOOK_VIOLATION, SAFETY_WARNING. Uses `$ORCH_STARTED_AT` when set (Principle IX), falls back to a single `date -u` call only if run-context is not loaded. References errors.sh via comments; does not hard-require it.

### T03: run-context.sh — Deterministic Run Context

Implement `scripts/lib/run-context.sh` with `init_run_context` exporting ORCH_RUN_ID, ORCH_STARTED_AT, ORCH_FORCE, ORCH_DRY_RUN. Deterministic when seeded via `ORCH_RUN_SEED` (same seed → same ORCH_RUN_ID and ORCH_STARTED_AT). Also defines `orch_now` helper returning the frozen ORCH_STARTED_AT so other libraries never call `date` inline.

### T04: guards.sh — Safety Rails

Implement `scripts/lib/guards.sh` with `guard_payload_sanity` (blocks empty / sub-100-char payloads), `guard_budget` (blocks when cumulative cost exceeds declared budget), `guard_output_sanity` (blocks on empty / sub-100-char agent output), `guard_phase_complete` (blocks phase advance when SUMMARY.md exists but has no content sections). All guards emit GUARD_BLOCKED events with guard name + reason and return non-zero. All guards overridable via `ORCH_FORCE=1`. Sources errors.sh, events.sh, run-context.sh.

### T05: hooks.sh — Hook Lifecycle Dispatch

Implement `scripts/lib/hooks.sh` with `run_hooks <lifecycle_point> <state_snapshot_source>` that creates a chmod 444 frozen snapshot in a temp file, executes hook scripts declared in `templates/hooks.yaml` at the given lifecycle point with a timeout (default 30s), detects snapshot modification (HOOK_VIOLATION), handles block vs warn behavior per-hook, and emits HOOK_BLOCKED on blocking failures. Hooks are discovered via `scripts/lib/recipe-parser.sh::parse_recipe_hooks` when available; if recipe-parser is absent (e.g., during P02 bootstrap when P04 has not run), `run_hooks` is a no-op that emits a SAFETY_WARNING. Sources errors.sh, events.sh, run-context.sh.

## Task Dependencies

```
T01 (errors.sh)  ─┐
                  ├──→ T04 (guards.sh) ──→ T05 (hooks.sh)
T03 (run-context) ┤
                  │
T02 (events.sh) ──┘
```

Expanded:

- T01, T02, T03 are independent foundation libraries. T01 must exist before T02 and T04 because event/guard result emission references the error taxonomy. T03 must exist before T02 so that events.sh can consume `$ORCH_STARTED_AT` for deterministic timestamps (though T02 falls back when run-context is absent).
- T04 (guards) sources T01, T02, T03 — cannot be written before they exist.
- T05 (hooks) sources T01, T02, T03 and shares the sandboxing conventions with T04 — planned last so hook isolation behavior can reference guard emit_event / emit_result patterns directly.

Execution order: T01 → T02 → T03 → T04 → T05 (linear chain chosen over a parallel DAG to keep the context minimal for each task; any agent running T02 can assume T01 exists, any agent running T04 can assume T01/T02/T03 exist, etc.).

## Files Likely Touched

- `scripts/lib/errors.sh` (create)
- `scripts/lib/events.sh` (create)
- `scripts/lib/run-context.sh` (create)
- `scripts/lib/guards.sh` (create)
- `scripts/lib/hooks.sh` (create)
