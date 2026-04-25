---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P02"
milestone: "M014"
provides:
  - "FR-13 runtime-instruction drift detection in check-docs.sh --check drift mode; run-doctor.sh Runtime Instruction Drift advisory section; commands/doctor.md documentation; three gate verifiers (m014-p02-check-docs-drift.sh, m014-p02-run-doctor-drift-section.sh, m014-p02-doctor-md.sh)"
requires:
  - "from:P02/T01 what:WRITE-SITES.md marker regions; from:disk what:scripts/diagnostics/check-docs.sh (M006), scripts/diagnostics/run-doctor.sh, commands/doctor.md"
affects:
  - "P02/T07 phase-suite (consumes three new gate verifiers), M014/P03-P04 (dual-write sites surfaced via drift findings)"
key_files:
  - "scripts/diagnostics/check-docs.sh,scripts/diagnostics/run-doctor.sh,commands/doctor.md,scripts/verify/m014-p02-check-docs-drift.sh,scripts/verify/m014-p02-run-doctor-drift-section.sh,scripts/verify/m014-p02-doctor-md.sh"
key_decisions:
  - "FR-13 v1 advisory stance (exit 0 even on warn); set -eu preserved (no -e drop needed with if-grep idiom); awk variable rename close->close_mk to avoid awk reserved-word collision; extended verifier with unmatched_marker scenario not in verbatim plan"
patterns_established:
  - "mode-router-with-preserved-default-branch (default --check docs runs pre-existing M006 body; new --check drift opt-in, byte-identical default path), shasum-normalized-region-byte-compare (extract_region awk helper + shasum -a 256 hash compare handles newline edge cases), advisory-check-with-dotted-exit-zero (drift emits warn but exits 0; run-doctor advisory flag surfaces in advisory_warnings counter not checks_total)"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P02/tasks/T04-PAYLOAD.md"
duration: "35m"
verification_result: "pass"
completed_at: "2026-04-22T23:53:00Z"
---

Extended scripts/diagnostics/check-docs.sh with --check drift mode per FR-13. Three drift kinds detected: missing_region, byte_divergence, unmatched_marker. Default --check docs preserves M006 byte-for-byte behavior (tested: status=ok found=19 total=19 unchanged). Wired run-doctor.sh with advisory Runtime Instruction Drift section (flag 1). Updated commands/doctor.md with new bullet + Runtime Instruction Drift explanation subsection + Referenced Scripts. Three gate verifiers all PASS. Anti-pattern lint clean on all six files. Live repo drift scan: status=ok regions=1 divergences=0 (recent-changes region byte-identical). One deviation from verbatim plan: renamed awk variable 'close' to 'close_mk' (awk reserved word collision caused syntax error in matching-regions scenario).
