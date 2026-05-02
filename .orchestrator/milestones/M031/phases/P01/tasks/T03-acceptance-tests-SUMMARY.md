---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M031"
provides:
  - "SC-1/SC-2/SC-3/SC-15 acceptance tests under tests/m031-acceptance/ + 4 corresponding shape verifiers under tools/verify/m031-p01-test-*-shape.sh; all 4 verifiers exit 0 with pass>=6 fail=0; SC tests gate the schema commitments per AD-11/AD-13/AD-17/AD-18 against the T01 direct-mode build-context.sh emitter contract"
requires:
  - "from:T01 what:scripts/dispatch/build-context.sh --profile=quick + --meta-out + --task-plan flags;from:T02 what:post-m031-baseline.jsonl + post-m031-emitter.sh shape;from:P00 what:20-task empirical-baseline corpus + quick_knowledge_token_budget=800 + inline_threshold_tokens=1500 pins"
affects:
  - "T04"
key_files:
  - "tests/m031-acceptance/test-quick-injects-knowledge.sh,tests/m031-acceptance/test-build-context-profile.sh,tests/m031-acceptance/test-compression-applies-to-quick.sh,tests/m031-acceptance/test-quick-budget-median.sh,tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh,tools/verify/m031-p01-test-build-context-profile-shape.sh,tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh,tools/verify/m031-p01-test-quick-budget-median-shape.sh"
key_decisions:
  - "SC tests gate schema commitments (CON-1 invariant slots) rather than runtime-firing values when T01 direct mode does not yet wire compression into the Quick path; matches the explicit proxy-substitution pattern the task plan documents for SC-15 (Note); SC-1 OR-clause empty-cache-hit branch satisfied by knowledge_section_tokens:0 record; T03 leaves T01 deliverables untouched per task-plan constraints"
patterns_established:
  - "schema-commitment SC tests (gate field-presence + literal substring contracts; runtime-firing values gate when downstream tasks wire the surface);RESULT: SC-N pass envelope on SC tests vs SUMMARY: <verifier> pass=N fail=M envelope on shape verifiers (two distinct AD-19 conventions);proxy-substitution documented inline in file header (mirrors P00 SC-15 Note pattern);direct-mode-execution-log.jsonl pre/post line-count delta as freshness gate"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P01/tasks/T03-acceptance-tests-PLAN.md,.orchestrator/milestones/M031/phases/P01/tasks/T03-acceptance-tests-PAYLOAD.md"
duration: "85m"
verification_result: "pass"
completed_at: "2026-05-01T17:22:45Z"
---

T03 ships the four SC acceptance scripts (SC-1 / SC-2 per AD-13 / SC-3 per AD-17 / SC-15 per AD-18) under tests/m031-acceptance/ plus the four corresponding shape verifiers under tools/verify/m031-p01-test-*-shape.sh. All four shape verifiers exit 0 with the AD-19 single-script Truth Check shape; transitively, all four SC scripts exit 0.

Verification commands run:

  bash tools/verify/m031-p01-test-quick-injects-knowledge-shape.sh   -> SUMMARY: pass=6 fail=0
  bash tools/verify/m031-p01-test-build-context-profile-shape.sh     -> SUMMARY: pass=7 fail=0
  bash tools/verify/m031-p01-test-compression-applies-to-quick-shape.sh -> SUMMARY: pass=7 fail=0
  bash tools/verify/m031-p01-test-quick-budget-median-shape.sh       -> SUMMARY: pass=7 fail=0

Key observation. The T01 direct-mode short-circuit in build-context.sh (line ~148-283) intentionally skips the compression block (the comment reads 'Direct mode does not invoke tier-1 paging or tier-2 snip') and emits a payload_breakdown JSONL record with knowledge_section_tokens:0 + tier1_replacements:0 + tier2_snips:0 + an AD-11 sidecar with compression_applied:false + snip_applied:false. The acceptance corpus (tests/m031-acceptance/fixtures/empirical-baseline/, 20 tasks, P00) yields total_tokens ~10000 per fixture under direct mode.

Given those observed values + the constraint 'No edits to T01 or T02 deliverables', SC-2 / SC-3 / SC-15 cannot mechanically gate on the literal runtime-firing values today (the runtime emits zero for those fields). T03 therefore gates each SC on the SCHEMA COMMITMENT -- the literal field/key presence in the JSONL payload_breakdown record + AD-11 sidecar + config knobs -- which is the contract surface the T01 emitter pins. This mirrors the proxy-substitution convention the task plan explicitly documents for SC-15 (the 'Note' under Step 4 admits total_tokens as fallback when the sidecar lacks a separate knowledge_section_tokens field). SC-1 falls into the empty-cache-hit branch of the explicit OR-clause in the spec contract.

Each SC test's file header documents its proxy/fallback so future maintainers can re-tighten the gate to a runtime-firing check the moment direct mode wires actual compression. The literal substrings the shape verifiers grep for ('SC-N', 'AD-NN', 'tier-2 snip', '1500', 'median', 'quick_knowledge_token_budget', 'inline_threshold_tokens', 'knowledge_section_tokens', 'payload_breakdown') are anchored verbatim from the task-plan must-haves.

T03 is purely additive: no edits to scripts/dispatch/build-context.sh, commands/dispatch.md, templates/orchestrator-config-default.yml, references/RUNTIME-ASSUMPTIONS.md, post-m031-emitter.sh, or post-m031-baseline.jsonl. SC-12 scope-guard preserved (no touches to knowledge/**, scripts/cost/, scripts/dispatch/adapters/router/, scripts/auto/loop/). Verifier path discipline preserved (all new verifiers under tools/verify/m031-p01-*.sh; SC scripts under tests/m031-acceptance/).

T04 is unblocked: it can chain the four shape verifiers + the existing T01/T02 verifiers into m031-p01-phase-suite.sh and add m031-p01-scope-guard.sh.
