---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P01"
milestone: "M014"
provides:
  - "FR-5 complexity probe stub surface + D016 RUNTIME-ASSUMPTIONS.md registry scaffold"
requires:
  - "none"
affects:
  - "T05 (specify.sh wires probe call, no-ops on below-threshold); M009 runtime-parity audit (consumes RUNTIME-ASSUMPTIONS.md)"
key_files:
  - "scripts/knowledge/spec-complexity-probe.sh,RUNTIME-ASSUMPTIONS.md,scripts/verify/m014-p01-complexity-probe-stub.sh,scripts/verify/m014-p01-runtime-assumptions.sh"
key_decisions:
  - "D016"
patterns_established:
  - "P01-stub-with-stable-structured-fields (probe emits below-threshold + zero-valued fr_count/user_story_count/todo_count/contradiction_signals so P04 replaces body without changing caller); D016 append-only runtime-assumptions registry with four-subsection entry schema (Claude Code assumption / Codex-Cursor fallback / Milestone-phase / M009 obligation)"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P01/tasks/T04-PAYLOAD.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-22T20:38:13Z"
---

Shipped the P01 stub of scripts/knowledge/spec-complexity-probe.sh: unconditionally emits probe=below-threshold on stdout, zero-valued structured fields (fr_count, user_story_count, todo_count, contradiction_signals) on stderr, exits 0 for valid spec path, exits 1 for missing arg or missing file. Full probe logic (FR count, user-story count, TODO density, LLM contradiction-signal pass) deferred to P04 per boundary map; caller surface is stable so T05 specify.sh can wire the invocation now. Shipped RUNTIME-ASSUMPTIONS.md at repo root per D016 with two initial entries: FR-3 (LLM-assisted scaffold-fill, CC-only surface deferred in P01) and FR-5 (contradiction-signal probe, stub in P01, full in P04). Registry is append-only per D016 and is the consumption target for M009 runtime-parity audit. Both gate verifiers (m014-p01-complexity-probe-stub.sh, m014-p01-runtime-assumptions.sh) exit 0 with PASS. All three new shell scripts pass scripts/verify/anti-pattern-lint.sh (LINT PASS, no Class A/B anti-patterns). No deviations from the task plan. No blockers.
