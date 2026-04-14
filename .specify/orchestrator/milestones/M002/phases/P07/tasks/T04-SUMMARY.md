---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P07"
milestone: "M002"
provides:
  - "scripts/verify/m002-p07-e2e.sh (E2E diagnostics pipeline verification with 9 assertions covering orphaned/unscoped/cost-spike detection and doctor-history.jsonl recording)"
requires:
  - "scripts/diagnostics/run-doctor.sh, scripts/diagnostics/check-orphaned.sh, scripts/diagnostics/check-stale.sh, scripts/diagnostics/check-scope.sh, scripts/diagnostics/check-cost-spikes.sh, scripts/knowledge/lib/index-utils.sh (P01), scripts/knowledge/lib/staleness.sh (P01), scripts/verify/m002-p07-*.sh (T01-T03)"
affects:
  - "P07 phase completion gate, M002 milestone completion gate"
key_files:
  - "scripts/verify/m002-p07-e2e.sh"
key_decisions:
  - "Copied supporting library files (errors.sh, events.sh, generate-permissions.sh) into temp directory so non-core check scripts can source dependencies without crashing; used r=0 then ||r=1 pattern for grep assertions under set -eu to avoid pipe subshell exit issues; index file placed at tmpdir/KNOWLEDGE-INDEX.md matching get_index_path() default"
patterns_established:
  - "E2E diagnostic test pattern: create isolated temp project with deliberate anomalies (orphaned index entry, stale/unscoped detail file, cost spike log), run full run-doctor.sh pipeline, verify warning output contains expected anomaly identifiers, verify doctor-history.jsonl written with required JSON fields; cleanup via trap"
drill_down_paths:
  - "scripts/verify/m002-p07-e2e.sh"
duration: "8"
verification_result: "pass"
completed_at: "2026-04-13T17:50:51Z"
---

Created E2E diagnostics pipeline verification script. The test creates an isolated temp project with 4 deliberate anomalies: (1) orphaned index entry MEM900 with no detail file, (2) stale entry MEM901 verified >90 days ago with low hits, (3) unscoped entry MEM901 with empty scope tag, (4) cost spike in execution log (M002-P02-T01 at 2.50 vs 0.05 average = 50x spike). Runs the full run-doctor.sh pipeline against the isolated environment and verifies all anomalies appear in output plus doctor-history.jsonl is written with correct JSON fields. All 9 E2E assertions pass. All 9 must-have verification scripts from T01-T03 also confirmed passing (10/10 total). No permanent file changes to diagnostics scripts were needed.
