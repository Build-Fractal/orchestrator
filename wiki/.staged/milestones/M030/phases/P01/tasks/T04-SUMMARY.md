---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01"
milestone: "M030"
provides:
  - "scripts/diagnostics/run-doctor.sh --config-check extension wired to tools/verify/p01-routing-table-shape.sh (file:line emission per FR-17 + SC-9); tools/verify/p01-doctor-config-check.sh exercises both well-formed-pass and malformed-fail paths; tools/verify/p01-phase-suite.sh straight-line aggregator over all 7 P01 sub-gates"
requires:
  - "from:T03 what:templates/model-routing.yml + tools/verify/p01-routing-table-shape.sh + references/model-routing.md; from:T02 what:scripts/dispatch/classify-task.sh + 3 classifier verifiers; from:T01 what:tools/verify/p01-d-a4-timeline.sh"
affects:
  - "M030/P02,M030/P03,M030/P04,M030/P05"
key_files:
  - "scripts/diagnostics/run-doctor.sh,tools/verify/p01-routing-table-shape.sh,tools/verify/p01-doctor-config-check.sh,tools/verify/p01-phase-suite.sh,CLAUDE.md,AGENTS.md"
key_decisions:
  - "FR-17-file-line-diagnostic-emission-via-grep-n-lookup-during-closure-walk; doctor-config-check-additive-not-replacement-existing-doctor-pipeline-preserved; phase-suite-straight-line-no-loops-AD-19-shape-discipline-mirrored-from-P00"
patterns_established:
  - "config-check-flag-as-thin-wrapper-around-shape-verifier-with-file-line-passthrough; verifier-stages-malformed-fixture-in-tmp-with-trap-cleanup; phase-suite-aggregator-pattern-extends-from-5-to-7-gates-without-shape-change"
drill_down_paths:
  - ".orchestrator/milestones/M030/phases/P01/tasks/T04-doctor-config-check-and-suite-PLAN.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-30T12:35:55Z"
---

T04 closed M030/P01 by extending scripts/diagnostics/run-doctor.sh's --config-check flag to invoke tools/verify/p01-routing-table-shape.sh against templates/model-routing.yml (overridable via --routing-table flag or ROUTING_TABLE_PATH env var) and propagating exit 1 with the verifier's <file>:<lineno> diagnostic on malformation. The shape verifier was amended to emit file:line prefixes (note_fail_at helper + lineno_of_pattern lookup via grep -n) on every closure-violation FAIL line; well-formed input still produces pass=8 fail=0. tools/verify/p01-doctor-config-check.sh exercises both Scenario A (well-formed exits 0) and Scenario B (malformed fixture at /tmp/p01-malformed-routing.yml introducing claude-code: turbo under routing.standard exits 1 with stdout containing both /tmp/... and :[0-9]+) with trap-based cleanup. tools/verify/p01-phase-suite.sh aggregates all 7 P01 sub-gates in literal sequence (mirrors P00 pattern, no loops). Self-checks: SUMMARY: p01-doctor-config-check.sh pass=4 fail=0; SUMMARY: p01-phase-suite.sh pass=7 fail=0; check-must-haves.sh exit 0 with all 8 truths + 34 artifacts + 8 key-links pass. Recent-changes dual-write applied to CLAUDE.md and AGENTS.md.
