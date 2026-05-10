---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M031"
provides:
  - "build-context.sh new --profile and --meta-out flags (FR-2 + AD-11),direct-mode --task-plan/--out invocation,AD-11 5-key JSON sidecar,additive payload_breakdown JSONL fields,3 m031-p01 verifiers under tools/verify/"
requires:
  - "P00: 3 config knobs pinned in templates/orchestrator-config-default.yml,P00: 20-task corpus + pre-m031-baseline.jsonl,P00: empirical-baseline.sh harness with --post-m031-emitter seam"
affects:
  - "P01/T02,P01/T03,P01/T04,M029 orchestrator:where (sidecar consumer),M036 reference-corpus-ingest (sidecar consumer)"
key_files:
  - "scripts/dispatch/build-context.sh,tools/verify/m031-p01-build-context-profile-shape.sh,tools/verify/m031-p01-quick-no-skip-branch.sh,tools/verify/m031-p01-config-knobs-stable.sh"
key_decisions:
  - "AD-11 5-key sidecar schema landed verbatim,AD-14 single-window preserved (commands/dispatch.md untouched),AD-19 single-script Truth Check shape for all 3 verifiers,direct-mode bypasses milestone/phase/task derivation when --task-plan supplied,positional-mode meta-out emit wired into both planning branch and payload_breakdown emitter so AD-11 fires on every code path,token-estimator reuse via chars_to_tokens_quartile from scripts/lib/pricing.sh"
patterns_established:
  - "additive flag-stacking on legacy positional CLIs,direct-mode short-circuit pattern,inverted-polarity verifier guarding CON-1 invariant,sidecar emission at two call sites for forked exit paths"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P01/tasks/T01-build-context-profile-PLAN.md"
duration: "120m"
verification_result: "pass"
completed_at: "2026-05-01T17:08:58Z"
---

T01 extends scripts/dispatch/build-context.sh with two additive flags per FR-2 and AD-11: --profile (quick or standard or full) and --meta-out FILE. A new direct-mode invocation (--task-plan FILE --out FILE) bypasses the milestone/phase/task positional derivation and produces a minimal Quick payload plus AD-11 5-key JSON sidecar from the named task plan. The legacy positional invocation form is preserved byte-equal when no new flags are supplied.

Three verifiers shipped under tools/verify/ with m031-p01- prefix per AD-19 plus [M032](../../../../../milestones/M032/index.md) Finding A namespacing: build-context-profile-shape (10 checks: literal substrings plus integration smoke plus 5-key sidecar plus profile equals quick), quick-no-skip-branch (3 checks asserting CON-1 invariant from build-context perspective), config-knobs-stable (4 checks asserting each of 3 P00 knobs occurs exactly once).

Direct mode emits one payload_breakdown JSONL record to .orchestrator/direct-mode-execution-log.jsonl so CON-1 holds. Positional mode adds 4 additive fields to existing payload_breakdown printf (profile, knowledge_section_tokens, tier1_replacements, tier2_snips); existing fields kept byte-equal upstream. AD-11 sidecar emission wired at two call sites because the planning branch exits early at line 1729 and never flows through _bc_emit_payload_breakdown.

AD-14 single-window discipline preserved: commands/dispatch.md is byte-identical to pre-T01 state (verified via git diff --stat). The live Quick-skip branch in commands/dispatch.md and the new --profile=quick path COEXIST until T02 closes the window.

Verification: build-context-profile-shape pass=10 fail=0; quick-no-skip-branch pass=3 fail=0; config-knobs-stable pass=4 fail=0. Integration smoke against tests/m031-acceptance/fixtures/empirical-baseline/task-01.txt exits 0; sidecar contains mem_count=31 total_tokens=10248 profile=quick compression_applied=false snip_applied=false; payload contains a Knowledge section and the Decisions section is correctly absent under the quick profile.
