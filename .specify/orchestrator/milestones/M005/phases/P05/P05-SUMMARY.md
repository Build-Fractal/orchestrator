---
schema_version: "1.0"
type: phase-summary
id: "P05"
parent: "M005"
milestone: "M005"
provides:
  - "scripts/lib/verdicts.sh with emit_verdict, parse_verdict, orch_is_verdict, verdict constants; verification scripts, hooks.sh parses VERDICT lines from hook stdout and maps to block/warn/continue, references/provider-convention.md documenting provider shell interface, scripts/diagnostics/check-providers.sh validates providers against convention; run-doctor.sh wired"
requires:
  - "from:P05/T01 what:scripts/lib/verdicts.sh, from:P05/T03 what:references/provider-convention.md"
affects:
  - "P05, P05, P05, P05"
key_files:
  - "scripts/lib/verdicts.sh, scripts/lib/hooks.sh, references/provider-convention.md, scripts/diagnostics/check-providers.sh, scripts/diagnostics/run-doctor.sh"
key_decisions:
  - "AD-3, AD-3, AD-6, AD-6"
patterns_established:
  - "structured verdict protocol (PASS/BLOCK/WARN/NEEDS_REVIEW), emit_verdict output format, verdict parsing in hook execution, severity-based multi-verdict resolution, provider shell convention with verdict and cost integration, provider conformance checking via DOCTOR: protocol"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P05/tasks/T01-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P05/tasks/T02-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P05/tasks/T03-SUMMARY.md, .specify/orchestrator/milestones/M005/phases/P05/tasks/T04-SUMMARY.md"
duration: "45m"
verification_result: "pass"
completed_at: "2026-04-13T01:21:58Z"
observability_surfaces:
  - "none"
---

Phase P05 establishes the gate verdict protocol and provider convention. verdicts.sh provides emit_verdict, parse_verdict, orch_is_verdict and four verdict constants (PASS/BLOCK/WARN/NEEDS_REVIEW) per AD-3. hooks.sh updated to capture hook stdout, parse VERDICT lines, resolve multiple verdicts to most severe, and map to block/warn/continue behavior — backward compatible when no VERDICT present. provider-convention.md documents the shell interface for execution providers per AD-6 (required args, env vars, output format, exit codes, verdict/cost/hash integration). check-providers.sh validates providers against convention and emits DOCTOR:PROVIDERS structured output. All 5 phase truths verified passing.
