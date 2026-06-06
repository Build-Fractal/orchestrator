---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M034"
provides:
  - "decisions-from-conversus.sh — conversus gate-result to packet-entry producer, strict-when-declared"
requires:
  - "from:T02 what:write-decisions.sh stdin-JSON writer"
affects:
  - "P02"
key_files:
  - "scripts/knowledge/decisions-from-conversus.sh tools/verify/m034-p01-producer.sh"
key_decisions:
  - "FR-12 --strict load-bearing; missing binary exit 3 + pipx pointer never SKIP; jq --arg mapping never string-concat; CON-8 verdict-is-content"
patterns_established:
  - "DECISIONS_CONV_STUB_MISSING test seam; dispute line to CONV-n entry; pipe mapped JSON into write-decisions.sh"
drill_down_paths:
  - ".orchestrator/milestones/M034/phases/P01/tasks/T03-conversus-producer-PLAN.md"
duration: "18m"
verification_result: "pass"
completed_at: "2026-06-06T23:43:47Z"
---

decisions-from-conversus.sh runs conversus.sh gate --strict, maps gate-result.md verdict/disputes/rationale/deliberation-link into a decisions-array via jq --arg per field, pipes into write-decisions.sh. gate_rc 0/2 map; 1/other block. Missing binary exits 3 with pipx install conversus-oss + conversus login pointer, packet untouched (FR-12, no silent SKIP). Independent probe: BLOCK stub -> 2 CONV- entries severity block + verdict in packet; missing seam -> rc3 + pointer + packet-not-created.
