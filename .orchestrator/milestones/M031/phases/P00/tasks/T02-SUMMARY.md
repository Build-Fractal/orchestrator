---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P00"
milestone: "M031"
provides:
  - "20-task AD-15 corpus + manifest + AD-14 pre-M031 stub + AD-17 RUNTIME-ASSUMPTIONS fold-in + 3 M031 config defaults + 5 P00 verifiers"
requires:
  - "from:P00/T01 what:specs/034-right-sized-entry/spec.md folded SC vocabulary; from:disk what:.orchestrator/milestones/M*/execution-log.jsonl unit_close records"
affects:
  - "P00/T03 (harness invokes pre-m031-stub.sh once across 20 fixtures to freeze pre-m031-baseline.jsonl); P01 (post-merge, the live Quick-skip branch in commands/dispatch.md:21 + scripts/dispatch/build-context.sh changes -- pre-M031 baseline must be on disk first)"
key_files:
  - "tests/m031-acceptance/fixtures/empirical-baseline/CORPUS-MANIFEST.md,tests/m031-acceptance/fixtures/empirical-baseline/pre-m031-stub.sh,references/RUNTIME-ASSUMPTIONS.md,templates/orchestrator-config-default.yml,tools/verify/p00-corpus-manifest-shape.sh,tools/verify/p00-corpus-population.sh,tools/verify/p00-pre-stub-shape.sh,tools/verify/p00-runtime-assumptions-foldin.sh,tools/verify/p00-config-defaults-pinned.sh"
key_decisions:
  - "cost_class derived from duration_s (total_tokens/re_dispatch_count absent from live records, manifest documents the substitution); 3 new knobs added at top level not folded into compression: block (matches auto_proceed shape); auto_proceed left at line 27 (P04 ratification job, not a P00 knob-flip)"
patterns_established:
  - "AD-14 single-window stub pattern (frozen pre-state capture before destructive surface modification, stub MUST NOT call the surface it captures); inverted-grep verifier with comment-vs-code distinction (allow header-comment references to a path while rejecting non-comment invocations)"
drill_down_paths:
  - ".orchestrator/milestones/M031/phases/P00/tasks/T02-corpus-and-defaults-PLAN.md"
duration: "80m"
verification_result: "pass"
completed_at: "2026-05-01T16:37:08Z"
---

Authored the AD-15-stratified 20-task fixture corpus + AD-14-frozen pre-M031 stub + AD-17 RUNTIME-ASSUMPTIONS fold-in + three M031 config defaults at templates/orchestrator-config-default.yml. CORPUS-MANIFEST.md declares 20 entries: 5 historical (M028/P03/T05 high, M027/P02/T04 high, M020/P04/T02 medium, M013/P04/T05 medium, M026/P01/T03 low) drawn from on-disk execution-log.jsonl unit_close records with cost_class derived from observed duration_s (the AD-15 plan named total_tokens / re_dispatch_count fields are absent from live records, documented in the manifest); 5 synthetic edge-cases (empty / 1-file / 5-file / 10-file / doc-only); 10 category-coverage fillers spread across bugfix/doc/feature. 20 task-NN.txt fixtures populated under tests/m031-acceptance/fixtures/empirical-baseline/. pre-m031-stub.sh (94 lines, bash 3.2, executable, AD-14 single-window discipline enforced — references scripts/dispatch/build-context.sh only in header comments) emits one JSONL line per fixture with deterministic cost-model constants (PER_FILE_REDISCOVERY_TOKENS=1500, PLAN_DELIVERY_OVERHEAD_TOKENS=500). references/RUNTIME-ASSUMPTIONS.md gained the M018 Tier-1 inline_threshold_tokens section (1500-token default, citation to templates/orchestrator-config-default.yml:87, SC-3 + AD-17 references) appended after the existing Shape-Guard Carve-Outs section. templates/orchestrator-config-default.yml gained three top-level M031 knobs (quick_knowledge_token_budget: 800, entry_routing_confidence_floor: 0.7, tier_a_plus_prompt_summary_lines: 8) each with FR/AD comment references, leaving auto_proceed at line 27 untouched (P04 ratification job per plan note). Authored five verifiers under tools/verify/ (p00-corpus-manifest-shape.sh 104 lines / 4 checks, p00-corpus-population.sh 63 lines / 2 checks, p00-pre-stub-shape.sh 123 lines / 5 checks, p00-runtime-assumptions-foldin.sh 81 lines / 5 checks, p00-config-defaults-pinned.sh 95 lines / 5 checks) all bash 3.2 compatible single-script-file shape per AD-19. All five verifiers exit 0 against the T02-close disk state. NO P01 surfaces touched (scripts/dispatch/build-context.sh, commands/dispatch.md preserved per AD-14 single-window discipline). T03 can now invoke pre-m031-stub.sh across the 20 fixtures to materialize pre-m031-baseline.jsonl before any P01 work modifies the live skip branch.
