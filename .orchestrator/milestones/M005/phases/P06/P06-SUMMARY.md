---
schema_version: "1.0"
type: phase-summary
id: "P06"
parent: "M005"
milestone: "M005"
provides:
  - "scripts/diagnostics/check-constitution.sh scanning phase plans for principle I-XIII references emitting DOCTOR:CONSTITUTION; scripts/diagnostics/check-events.sh scanning engine-path scripts for emit_event emitting DOCTOR:EVENTS, scripts/diagnostics/check-hashes.sh scanning knowledge entries for valid content_hash fields emitting DOCTOR:HASHES; scripts/diagnostics/check-run-ids.sh scanning JSONL entries for run_id presence emitting DOCTOR:RUNIDS, scripts/diagnostics/check-plans.sh scanning task plan Check: commands and inline bash blocks for 10 AD-19 trigger patterns emitting DOCTOR:PLANS advisory output, scored run-doctor.sh aggregating 12 checks with Checks passed N/M summary, doctor-history.jsonl append, extension.yml registration for 7 new diagnostic scripts"
requires:
  - "from:P01 what:sha256:{hex} format convention from scripts/lib/hash.sh, from:P07 what:AD-19 shape guidance in plan-phase.md and templates, from:T01 what:check-constitution.sh+check-events.sh, from:T02 what:check-hashes.sh+check-run-ids.sh, from:T03 what:check-plans.sh, from:P04 what:check-instructions.sh, from:P05 what:check-providers.sh, from:P07 what:check-permissions.sh"
affects:
  - "P06, P06, P06, P06"
key_files:
  - "scripts/diagnostics/check-constitution.sh, scripts/diagnostics/check-events.sh, scripts/verify/p06-check-constitution.sh, scripts/verify/p06-check-events.sh, scripts/diagnostics/check-hashes.sh, scripts/diagnostics/check-run-ids.sh, scripts/verify/p06-check-hashes.sh, scripts/verify/p06-check-run-ids.sh, scripts/diagnostics/check-plans.sh, scripts/verify/p06-check-plans.sh, scripts/diagnostics/run-doctor.sh, extension.yml, scripts/verify/p06-scored-doctor.sh, scripts/verify/p06-extension-registration.sh"
key_decisions:
  - "AD-19"
patterns_established:
  - "DOCTOR: structured output protocol for diagnostic scripts, principle coverage scanning, engine-path compliance checking, YAML frontmatter content_hash validation, JSONL field presence checking via string match, vacuous truth for empty datasets, advisory-only diagnostic (always exit 0), multi-pattern trigger classification, Check: line and verification block extraction from markdown, scored health report aggregation, advisory check classification, mixed legacy/DOCTOR output handling, doctor-history.jsonl append"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P06/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P06/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P06/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P06/tasks/T04-SUMMARY.md"
duration: "604m"
verification_result: "pass"
completed_at: "2026-04-13T02:38:33Z"
observability_surfaces:
  - "DOCTOR:CONSTITUTION, DOCTOR:EVENTS, DOCTOR:HASHES, DOCTOR:RUNIDS, DOCTOR:PLANS, Checks passed: N/M, doctor-history.jsonl"
---

Phase P06 delivers the complete diagnostic suite for run-doctor.sh. Five new checks added: check-constitution.sh (principle coverage I-XIII), check-events.sh (engine-path emit_event compliance), check-hashes.sh (knowledge entry content_hash validation), check-run-ids.sh (JSONL run_id presence), and check-plans.sh (AD-19 task plan shape lint, advisory only). run-doctor.sh rewritten to aggregate all 12 checks (4 legacy + 8 DOCTOR:) into a scored health report with Checks passed: N/M format. check-plans.sh treated as advisory — warnings counted separately. extension.yml updated with 7 new script registrations. All 7 phase truths verified passing.
