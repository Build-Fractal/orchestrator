---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P04"
milestone: "M014"
provides:
  - "templates/conversus-presets/spec-pressure-test.yml FR-6 red-blue preset; templates/spec-complexity-contradiction-prompt.md FR-5 LLM prompt; templates/spec-splitter-prompt.md FR-7 LLM prompt; scripts/verify/m014-p04-pressure-test-preset.sh T03 gate verifier"
requires:
  - "from:P01/T04 what:spec-complexity-probe stub (P04/T02 consumes FR-5 prompt); from:M011/P07 what:scripts/dispatch/adapters/tool/conversus.sh (unmodified by T03); from:disk what:templates/conversus-presets/normalize-fidelity.yml (schema reference), .orchestrator/memory/constitution.md (arbiter grounding), templates/gate-result.md (conversus output template)"
affects:
  - "P04/T02 (complexity probe consumes contradiction prompt); P04/T05 (splitter subcommand consumes splitter prompt); M014/P04 phase-suite gate orchestrator"
key_files:
  - "templates/conversus-presets/spec-pressure-test.yml,templates/spec-complexity-contradiction-prompt.md,templates/spec-splitter-prompt.md,scripts/verify/m014-p04-pressure-test-preset.sh"
key_decisions:
  - "D007 reuse discipline — zero conversus adapter modifications; grep-only YAML shape verification per MEM001 (no python3/jq hard dependency); CC-only prompt invocation — Codex/Cursor runtime-gate before dispatch"
patterns_established:
  - "authored-content-only task (no executable code added beyond gate); preset-file reuse of existing adapter under D007; LLM-prompt template shape with schema_version+type+consumer frontmatter; grep-based YAML structural validation for presets"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P04/tasks/T03-PAYLOAD.md"
duration: "12m"
verification_result: "pass"
completed_at: "2026-04-23T00:45:50Z"
---

T03 ships three authored templates and one gate verifier. Zero modifications to scripts/dispatch/adapters/tool/conversus.sh (pre/post shasum identical: dff201ea7e6e09d26320791c5e09386cee99c100520f4cb10a04c52ecc085a39). Gate verifier passes. Anti-pattern lint clean. The preset is red-blue mode with blue-advocate + red-advocate + constitution-grounded arbiter emitting PASS|BLOCK; if the M011/P07 adapter does not natively support red-blue, it degrades to cooperative single-round per D007 reuse contract — acceptable for P04 because T04 tests use CONVERSUS_STUB=1 short-circuit rather than exercising the real adapter end-to-end. Contradiction prompt (57 lines) instructs the LLM to emit exactly one line contradictions=<N>; splitter prompt (65 lines) instructs emission of a YAML decomposition-manifest capped at N=4.
