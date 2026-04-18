---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M019"
provides:
  - "scripts/dispatch/build-context.sh payload_breakdown JSONL emitter appended to .orchestrator/milestones/<Mxxx>/execution-log.jsonl; _bc_emit_payload_breakdown helper; PAYLOAD_CAPTURE tempfile + cat pattern preserving byte-identical stdout (SC-6)"
requires:
  - "from:P01/T01 what:scripts/lib/pricing.sh (chars_to_tokens_quartile); from:P01/T01 what:scripts/verify/m019-schema.sh (payload_breakdown record_type validation); from:M019/P00/T01 what:post-payload-assembly hook point in build-context.sh"
affects:
  - "T03,T04,T05,T06,P01"
key_files:
  - "scripts/dispatch/build-context.sh"
key_decisions:
  - "AD-1 char-quartile token estimate; SC-6 byte-identical stdout; C5 bash 3.2 compatibility; MEM004 carve-out for dispatch-internal emitter code"
patterns_established:
  - "PAYLOAD_CAPTURE tempfile + cat emission pattern — capture via stdout redirection, replay via cat, measure via wc -c; fixture-mode log-path carve-out (ORCH_ROOT IS milestone dir); bail-safe emitter (mkdir/append failures stderr-noted, never abort dispatch); JSON double-quote escape in section_tokens display-name keys via sed"
drill_down_paths:
  - ".orchestrator/milestones/M019/phases/P01/tasks/T02-PAYLOAD.md, .orchestrator/milestones/M019/phases/P01/tasks/T02-PLAN.md, scripts/dispatch/build-context.sh"
duration: "30m"
verification_result: "pass"
completed_at: "2026-04-18T03:13:37Z"
---

T02 wires the first Tier 1 emitter: scripts/dispatch/build-context.sh now writes exactly one payload_breakdown JSONL record to .orchestrator/milestones/<Mxxx>/execution-log.jsonl per invocation, appended AFTER payload assembly via a PAYLOAD_CAPTURE tempfile + cat pattern so the stdout payload stays byte-identical (SC-6).

The record carries all ten fields: record_type, unitId (Mxxx/Pxx/Txx, or /PHASE_PLAN for planning), milestone, phase, task, payload_chars, payload_tokens_estimate (via chars_to_tokens_quartile from scripts/lib/pricing.sh, AD-1), token_estimate_method (char-quartile), section_tokens (display-name-keyed JSON object over every TMPDIR_BUILD/s<i>.txt, including stable+volatile sections), model (ORCH_MODEL env or empty), source (estimate), and timestamp (ISO-8601 UTC).

Emitter is bail-safe: mkdir and append failures emit a single stderr note and return 0 — dispatch never aborts on log-write failure. Fixture carve-out: if ORCH_ROOT already contains a phases/ dir (fixture mode), the log lands at <ORCH_ROOT>/execution-log.jsonl instead of <ORCH_ROOT>/milestones/<Mxxx>/.

Verification evidence: live build-context.sh invocation on M019/P01/T02 appends exactly one new payload_breakdown line (diffed against a pre-run snapshot); a baseline-vs-instrumented diff shows identical byte counts (44690 == 44690) with only hit_count ticks (side effect of increment-hits.sh on each dispatch, not instrumentation growth); scripts/verify/m019-schema.sh validates all 9 records in the log as PASS; anti-pattern-lint.sh reports LINT PASS (no agent-facing content changed).
