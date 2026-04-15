---
schema_version: "1.0"
type: milestone-summary
id: "M005"
parent: "001-speckit-orchestrator"
milestone: "M005"
provides:
  - "P01: content-hash idempotency (hash.sh, create/update/rebuild hash support); P02: cost transparency (record-telemetry.sh cost_source, aggregate-metrics.sh grouping); P03: payload transform extraction (payload-transforms.sh, manifest-builder.sh pure functions); P04: agent instruction schema (instruction-schema.md, check-instructions.sh); P05: gate verdict protocol (verdicts.sh, hooks.sh verdict parsing, provider-convention.md, check-providers.sh); P06: diagnostic suite (5 new checks, scored run-doctor.sh, extension.yml registration); P07: autonomy permission pipeline (generate/write/check-permissions.sh, AD-19 shape guidance)"
requires:
  - "spec-kit >=0.1.0, bash 3.2+, git"
affects:
  - "M006 downstream phases"
key_files:
  - "scripts/lib/hash.sh, scripts/lib/payload-transforms.sh, scripts/lib/manifest-builder.sh, scripts/lib/verdicts.sh, scripts/lib/hooks.sh, scripts/diagnostics/run-doctor.sh, scripts/diagnostics/check-constitution.sh, scripts/diagnostics/check-events.sh, scripts/diagnostics/check-hashes.sh, scripts/diagnostics/check-run-ids.sh, scripts/diagnostics/check-plans.sh, scripts/diagnostics/check-instructions.sh, scripts/diagnostics/check-providers.sh, scripts/diagnostics/check-permissions.sh, scripts/lifecycle/generate-permissions.sh, scripts/lifecycle/write-permissions.sh, templates/instruction-schema.md, references/provider-convention.md, extension.yml"
key_decisions:
  - "AD-1 sha256 format, AD-2 cost_source enum, AD-3 verdict protocol, AD-4 instruction schema, AD-5 pure functions, AD-6 provider convention, AD-19 AD-19 plan shape"
patterns_established:
  - "content-hash idempotency, cost_source closed enum, pure lib functions with no I/O, DOCTOR: structured output protocol, instruction schema conformance, verdict protocol (PASS/BLOCK/WARN/NEEDS_REVIEW), provider shell convention, advisory diagnostic classification, scored health reporting, AD-19 script-file verification shape"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P01/P01-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P02/P02-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P03/P03-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P04/P04-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P05/P05-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P06/P06-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P07/P07-SUMMARY.md"
duration: "604m"
verification_result: "pass"
completed_at: "2026-04-13T02:43:58Z"
observability_surfaces:
  - "DOCTOR: protocol (CONSTITUTION, EVENTS, HASHES, RUNIDS, PLANS, PERMISSIONS, PROVIDERS, INSTRUCTIONS), Checks passed: N/M, doctor-history.jsonl"
---

Milestone M005 delivers foundational infrastructure hardening across 7 phases and 28 tasks. P01 establishes content-hash idempotency for the knowledge layer. P02 adds cost transparency to telemetry. P03 extracts pure transform functions from dispatch scripts. P04 creates the agent instruction schema with conformance checking. P05 establishes the gate verdict protocol and provider shell convention. P06 delivers 5 new diagnostic checks and a scored run-doctor.sh health report. P07 builds the autonomy permission pipeline with AD-19 plan shape guidance. All phases verified passing. Cross-phase boundary validation clean.
