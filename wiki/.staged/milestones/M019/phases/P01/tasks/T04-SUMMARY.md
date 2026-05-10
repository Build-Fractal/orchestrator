---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01"
milestone: "M019"
provides:
  - "unit_close JSONL emitter in write-summary.sh across task/phase/milestone granularities; Goodhart-paired cost+quality blocks per record; validator source-enum extended to accept aggregate"
requires:
  - "from:P01/T01 what:scripts/verify/m019-schema.sh (record_type + unit_close shape validator); from:P01/T02 what:payload_breakdown records keyed by unitId; from:P01/T03 what:dispatch_usage records carrying estimated_cost_usd+pricing_version"
affects:
  - "T05,T06,P01,M019"
key_files:
  - "scripts/knowledge/write-summary.sh,scripts/verify/m019-schema.sh"
key_decisions:
  - "C2 Goodhart pairing mandatory; SC-2 exactly-one unit_close per write-summary; SC-3 cost+quality pairing; SC-4 granularity enum + source enum extended to estimate|runtime|aggregate; AD-3 quality-from-existing-fields no new event surface; C3/SC-10 additive to existing summary output byte-for-byte"
patterns_established:
  - "child-granularity filter in pass_rate awk — phase counts child tasks, milestone counts child phases (strict Must-Haves interpretation over generic unit_close child match); duration-suffix parser _ws_parse_duration_seconds supports m/h/s suffix and bare integers; prefix-match any-null propagation — null estimated_cost_usd in any contributing record propagates null up the aggregation chain (Tier 1 degradation signal preserved across rollup); fixture-mode log-path carve-out reuses T02/T03 pattern (orch_root/phases marker)"
drill_down_paths:
  - ".orchestrator/milestones/M019/phases/P01/tasks/T04-PAYLOAD.md,.orchestrator/milestones/M019/phases/P01/tasks/T04-PLAN.md,scripts/knowledge/write-summary.sh,scripts/verify/m019-schema.sh"
duration: "40m"
verification_result: "pass"
completed_at: "2026-04-18T03:27:15Z"
---

T04 wires the Goodhart-paired unit_close emitter into scripts/knowledge/write-summary.sh. After each successful summary write (task/phase/milestone), one JSONL record is appended to .orchestrator/milestones/<Mxxx>/execution-log.jsonl carrying fifteen fields: record_type=unit_close, granularity (task|phase|milestone enum — SC-4), unitId (Mxxx/Pxx/Txx for tasks, shorter for rollups), milestone/phase/task (empty-string placeholders on rollups), duration_s (parsed from 25m|2h|90s via _ws_parse_duration_seconds), outcome (echoed from verification_result), completed_at (echoed), estimated_cost_usd + pricing_version (cost block — prefix-match awk sum over payload_breakdown + dispatch_usage records; null propagates up the chain per Tier 1 degradation signal), verification_pass_rate + deviation_count + retry_count (quality block — AD-3 derivation: task 1.0/0.0 on own outcome, phase counts child tasks, milestone counts child phases), source (estimate on task, aggregate on phase/milestone per AS-2), timestamp (ISO-8601 UTC). Schema validator source-enum extended to estimate|runtime|aggregate. MEM004 carve-out permits awk/pipes inside the emitter (dispatch-internal, not agent-facing; anti-pattern-lint.sh PASS). Never-abort contract honored: all log-write failures degrade silently via || true; summary file write output is unchanged (C3/SC-10 additivity). Verification evidence: live 3-granularity probe produces T01 pass_rate=1.0, T02 pass_rate=0.0, P01 pass_rate=0.50 (1 pass / 2 tasks), M999 pass_rate=1.00 (1 pass / 1 phase); m019-schema.sh PASS on the 4-record log; Goodhart guard probe rejects records missing cost or quality block; pre-M019 (record_type-less) records still validate (additivity); source=fabricated still rejected; source=aggregate now accepted. Regression suite: test-s06 57/57, test-s05 100/100, m019-p00-phase-suite 4/4 gates PASS, anti-pattern-lint clean, m019-schema.sh PASS on real M019/execution-log.jsonl (13 records validated).
