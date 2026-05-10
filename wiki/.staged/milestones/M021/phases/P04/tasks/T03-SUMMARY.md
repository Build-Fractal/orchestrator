---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P04"
milestone: "M021"
provides:
  - "scripts/verify/m021-p04-dogfood-attestation.sh — AD-8 dogfood attestation gate asserting M021's own auto-execution of P01-P04 observed zero user_prompt / safety_prompt / hook_reject_unexpected events, the auto-loop marker is present+non-empty, and every closed P*-SUMMARY.md records verification_result: pass; tolerant of hook_reject_recovered events (AD-6 designed recovery path) and missing phase summaries (in-flight phases do not fail the gate)"
requires:
  - "from:P04/T01 what:tests/fixtures/m021-prompt-corpus.txt landmark; from-disk:.orchestrator/milestones/M021/auto-loop-result.txt + execution-log.jsonl + phases/P*/P*-SUMMARY.md"
affects:
  - "P04"
key_files:
  - "scripts/verify/m021-p04-dogfood-attestation.sh"
key_decisions:
  - "AD-8"
patterns_established:
  - "Dogfood attestation gate reads state-on-disk landmarks (auto-loop marker + execution-log.jsonl + phase summaries) without mutation; prompt-event detection uses grep -qF against three fixed-string needles ('"event":"user_prompt"', '"event":"safety_prompt"', '"event":"hook_reject_unexpected"') with hook_reject_recovered deliberately omitted from needles (AD-6 recovery events are the success signal); phase-summary sweep uses glob with -f guard for bash-3.2 nullglob portability; gate is self-referential-safe — runs during P04/T03 and correctly reports PASS for closed P01/P02/P03 while skipping in-flight P04 (no summary yet)"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P04/tasks/T03-PAYLOAD.md"
duration: "10m"
verification_result: "pass"
completed_at: "2026-04-17T21:34:06Z"
---

Authored scripts/verify/m021-p04-dogfood-attestation.sh per payload scaffold with three must-have checks plus a corpus-fixture landmark. Gate exits 0 with 8 PASS lines under current M021 state (P01/P02/P03 closed with verification_result: pass, P04 in progress, no prompt events in execution-log.jsonl, auto-loop marker non-empty). No deviations from the payload scaffold — pass/fail helpers, three independent grep -qF needles for prompt-class events, glob-with-[-f]-guard phase summary sweep, and bash-3.2-safe arithmetic increments kept verbatim. Minor addition: added a _c_found counter so check-c's summary PASS line only prints when at least one phase summary was seen (defensive — the payload did not require this but it prevents a spurious PASS if phases/P* is empty). All four execution invariants satisfied: gate is read-only, REPO_ROOT resolves from BASH_SOURCE[0], uses only -qF / -qE grep flags, tolerant of missing summaries and of hook_reject_recovered events.
