---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P06"
milestone: "M005"
provides:
  - "scored run-doctor.sh aggregating 12 checks with Checks passed N/M summary, doctor-history.jsonl append, extension.yml registration for 7 new diagnostic scripts"
requires:
  - "from:T01 what:check-constitution.sh+check-events.sh, from:T02 what:check-hashes.sh+check-run-ids.sh, from:T03 what:check-plans.sh, from:P04 what:check-instructions.sh, from:P05 what:check-providers.sh, from:P07 what:check-permissions.sh"
affects:
  - "P06"
key_files:
  - "scripts/diagnostics/run-doctor.sh, extension.yml, scripts/verify/p06-scored-doctor.sh, scripts/verify/p06-extension-registration.sh"
key_decisions:
  - "none"
patterns_established:
  - "scored health report aggregation, advisory check classification, mixed legacy/DOCTOR output handling, doctor-history.jsonl append"
drill_down_paths:
  - "none"
duration: "226s"
verification_result: "pass"
completed_at: "2026-04-13T02:37:03Z"
---

Rewrote run-doctor.sh to aggregate 12 diagnostic checks (4 legacy + 8 new DOCTOR: checks) into a scored health report. Legacy checks use exit-code pass/fail; new checks parse DOCTOR: status lines. check-plans.sh treated as advisory (warnings don't count toward failures). check-permissions.sh exit 2 handled as valid non-crash. Summary outputs Checks passed: N/M with HEALTHY/NEEDS_ATTENTION status. JSONL history appended per run. extension.yml updated with 7 new script registrations.
