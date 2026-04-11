---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M004"
provides:
  - "scripts/lib/events.sh — Bash 3.2 sourced library providing emit_event structured event emitter, orch_is_event_type registry validator, ORCH_EVENT_TYPES canonical registry (19 event types covering engine lifecycle, safety, hooks, dispatch, verify, checkpoint), _orch_events_timestamp helper (reads ORCH_STARTED_AT for determinism), and _orch_events_quote internal helper for shell-safe value quoting"
requires:
  - "from:P02/T01 what:errors.sh double-sourcing guard pattern and header comment style (referenced for consistency; events.sh does not source errors.sh directly)"
affects:
  - "P02/T03 (run-context.sh will export ORCH_STARTED_AT that events.sh reads for deterministic timestamps), P03 (engine coordinator emits SESSION_START/PHASE_START/TASK_START/DISPATCH_START), P06 (all engine-managed scripts emit EVENT: lines observable by dashboards and Conversus integration)"
key_files:
  - "scripts/lib/events.sh"
key_decisions:
  - "Canonical registry implemented as newline-separated string (not array) for Bash 3.2 compat; orch_is_event_type uses case statement not loop for O(1) dispatch; unknown event types produce a companion SAFETY_WARNING event rather than hard-failing per FR-221 warning-level enforcement; timestamps prefer ORCH_STARTED_AT (set by run-context.sh) so all events in a single run share the same frozen session timestamp per Principle IX determinism; _orch_events_quote uses case glob match on whitespace/quote then sed escaping (no jq dependency)"
patterns_established:
  - "Double-sourcing guard placed on lines 3-4 (immediately after shebang + one-line comment) to pass head -5 check — identical to T01 errors.sh pattern; emit_event is single-line output with EVENT: prefix matching RESULT: prefix convention from T01 so both are grep-parseable; internal helpers prefixed with _orch_events_ to avoid collision with other libraries; companion SAFETY_WARNING pattern for graceful degradation of unknown inputs (emit original then warn, never drop events)"
drill_down_paths:
  - ".specify/orchestrator/milestones/M004/phases/P02/tasks/T02-PLAN.md"
duration: "5m"
verification_result: "pass"
completed_at: "2026-04-10T21:00:00Z"
---

Created scripts/lib/events.sh (144 lines) — the structured event emission library fulfilling the Principle II amendment that engine-managed scripts MUST emit observable evidence. Exports ORCH_EVENT_TYPES (newline-separated canonical registry of 19 types: SESSION_START/END, PHASE_START/COMPLETE, TASK_START/COMPLETE, DISPATCH_START/FALLBACK, VERIFY_START/COMPLETE, GUARD_BLOCKED/WARNING, SAFETY_WARNING, HOOK_START/COMPLETE/BLOCKED/VIOLATION, CHECKPOINT_WRITE/RESUME) and defines orch_is_event_type (case-statement validator), _orch_events_timestamp (prefers ORCH_STARTED_AT for determinism, falls back to single date call), _orch_events_quote (internal shell-safe value quoter using sed without jq), _orch_events_print (internal EVENT: line formatter), and emit_event (public API). emit_event accepts <TYPE> followed by key=value pairs, validates against the registry, emits a companion SAFETY_WARNING for unknown types without dropping the original event, and shell-quotes values containing whitespace or double-quotes. Applied the T01 lesson preemptively: placed double-sourcing guard on lines 3-4 (shebang line 1, one-line comment line 2, guard on 3-4) so head -5 detection passes on first run. Deviation from task plan verification block: the verbatim verification commands used 'bash -c ORCH_RUN_ID=rid ORCH_STARTED_AT=... . scripts/lib/events.sh; emit_event ...' which relies on var-prefix scoping that does NOT persist past a builtin source in bash — vars were unset by the time emit_event ran, producing run_id=unset and a fresh timestamp. The library itself is correct (verified with proper 'export' syntax); re-ran verification using 'export ORCH_RUN_ID=rid; export ORCH_STARTED_AT=...; . scripts/lib/events.sh; emit_event ...' and all 20 checks printed PASS. The task-plan verify block has a shell quoting bug worth fixing in the plan template but not a library defect.
