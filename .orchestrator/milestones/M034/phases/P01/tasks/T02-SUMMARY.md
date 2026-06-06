---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M034"
provides:
  - "write-decisions.sh stdin-JSON packet writer with append-with-supersede-chain"
requires:
  - "from:T01 what:decisions-constants.sh SSOT + decisions-packet.md emit format"
affects:
  - "T03 T04"
key_files:
  - "scripts/knowledge/write-decisions.sh tools/verify/m034-p01-writer.sh"
key_decisions:
  - "PC-1 stdin-JSON; jq required fail-loud; Q1 content_hash supersede chain; shasum-256 first16"
patterns_established:
  - "jq -r per-field no-eval RISK-1 safe; base-id chain-tip find + in-place amend mirrors extract-supersede.sh"
drill_down_paths:
  - ".orchestrator/milestones/M034/phases/P01/tasks/T02-write-decisions-PLAN.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-06-06T23:37:48Z"
---

write-decisions.sh reads a decisions-array JSON doc on stdin, jq -r per field (never re-shell-interprets bodies), --milestone/--artifact/--out flags, --out=- to stdout, jq-required guard. SSOT defaults+validators for severity/type. Q1 append-with-supersede-chain via per-entry content_hash (shasum-256 first16): unchanged=no-op, changed=append base-vN with supersedes + prior superseded_by. Subagent verifier PASS; independent orchestrator probe confirmed fresh-2 / idempotent-noop / changed -v2 + supersede chain.
