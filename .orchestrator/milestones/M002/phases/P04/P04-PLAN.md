---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M002"
goal: "Ensure build-context.sh and compress-payload.sh correctly integrate with the M002 knowledge architecture (index-based filtering, graph traversal, entry resolution, hit tracking) and produce pre-inlined dispatch payloads with accurate manifest headers, static-first ordering, and working compression."
demo_sentence: "A dispatched agent receives a single markdown document containing an accurate manifest header with section line ranges and token estimates, all context inlined (static first, dynamic last), compressed to fit within the context budget — zero file-read tool calls needed for context."
risk: "high"
depends_on: [P01, P02, P03]
---

## Must-Haves

### Truths

- build-context.sh task-dispatch branch uses the knowledge index pipeline (scope-filter on KNOWLEDGE-INDEX.md, traverse-graph.sh for related entries, resolve-entries.sh for detail file content) rather than flat KNOWLEDGE.md when KNOWLEDGE-INDEX.md exists
  - Check: `bash scripts/verify/m002-p04-uses-index-pipeline.sh`
- build-context.sh planning branch uses the knowledge index pipeline (scope-filter on KNOWLEDGE-INDEX.md, traverse-graph.sh, resolve-entries.sh) when KNOWLEDGE-INDEX.md exists
  - Check: `bash scripts/verify/m002-p04-planning-uses-index.sh`
- build-context.sh produces a manifest header with Section, Lines, Est. Tokens, Priority columns for task-dispatch payloads
  - Check: `bash scripts/verify/m002-p04-manifest-header.sh`
- build-context.sh orders payload sections with static content first (knowledge, decisions, constraints) and dynamic content last (task plan, upstream summaries, state) for prompt caching optimization
  - Check: `bash scripts/verify/m002-p04-static-first-ordering.sh`
- build-context.sh increments hit_count (via increment-hits.sh) on every knowledge entry included in a dispatch payload
  - Check: `bash scripts/verify/m002-p04-increments-hits.sh`
- compress-payload.sh applies the 3-step compression cascade (drop optional, summarize upstream, drop lowest-confidence knowledge) and never truncates the task plan section
  - Check: `bash scripts/verify/m002-p04-compression-cascade.sh`
- compress-payload.sh rebuilds the manifest header after compression to reflect updated line ranges and token estimates
  - Check: `bash scripts/verify/m002-p04-manifest-rebuild.sh`
- build-context.sh accepts a --budget flag or reads context_budget from config-defaults and passes it to compress-payload.sh when the payload exceeds the budget
  - Check: `bash scripts/verify/m002-p04-budget-enforcement.sh`

### Artifacts

- scripts/dispatch/build-context.sh (min 200 lines, contains "KNOWLEDGE-INDEX")
- scripts/dispatch/compress-payload.sh (min 100 lines, contains "drop_optional")
- scripts/verify/m002-p04-uses-index-pipeline.sh (min 30 lines, contains "PASS")
- scripts/verify/m002-p04-planning-uses-index.sh (min 30 lines, contains "PASS")
- scripts/verify/m002-p04-manifest-header.sh (min 20 lines, contains "PASS")
- scripts/verify/m002-p04-static-first-ordering.sh (min 20 lines, contains "PASS")
- scripts/verify/m002-p04-increments-hits.sh (min 30 lines, contains "PASS")
- scripts/verify/m002-p04-compression-cascade.sh (min 40 lines, contains "PASS")
- scripts/verify/m002-p04-manifest-rebuild.sh (min 30 lines, contains "PASS")
- scripts/verify/m002-p04-budget-enforcement.sh (min 30 lines, contains "PASS")

### Key Links

- scripts/dispatch/build-context.sh → scripts/dispatch/scope-filter.sh (calls for knowledge index filtering)
- scripts/dispatch/build-context.sh → scripts/knowledge/traverse-graph.sh (calls for graph traversal)
- scripts/dispatch/build-context.sh → scripts/knowledge/resolve-entries.sh (calls for detail file content)
- scripts/dispatch/build-context.sh → scripts/knowledge/increment-hits.sh (calls for hit tracking)
- scripts/dispatch/build-context.sh → scripts/dispatch/compress-payload.sh (calls when payload exceeds budget)
- scripts/dispatch/compress-payload.sh → scripts/lib/payload-transforms.sh (sources for token estimation)
- scripts/dispatch/compress-payload.sh → scripts/lib/manifest-builder.sh (sources for manifest rebuild)

## Tasks

### T01: Create verification scripts for all P04 must-haves

Create 8 verification scripts under `scripts/verify/m002-p04-*.sh`. Each script creates an isolated temp directory with fixture data (knowledge detail files, KNOWLEDGE-INDEX.md, phase plans, task plans, roadmap, config), runs build-context.sh or compress-payload.sh, and asserts expected behavior. Scripts must use PROJECT_ROOT override for isolation and follow the single-script-file AD-19 shape.

### T02: Validate and fix build-context.sh knowledge index integration

Verify that both the task-dispatch branch (via section-handlers.sh handle_knowledge) and the planning branch correctly use the KNOWLEDGE-INDEX.md pipeline. Fix any bugs in the knowledge pipeline integration: index detection, scope filtering, graph traversal, entry resolution, hit count incrementing. Ensure the pipeline falls back gracefully when no index exists.

### T03: Validate and fix payload ordering and manifest accuracy

Verify that build-context.sh produces payloads with static content first and dynamic content last. Verify manifest header accurately reflects line ranges and token estimates. Fix any ordering or manifest calculation issues in both the task-dispatch (recipe-driven) and planning branches.

### T04: Validate and fix compress-payload.sh and budget enforcement

Verify compress-payload.sh correctly applies the 3-step compression cascade with the M002 knowledge architecture. Verify build-context.sh passes budget to compress-payload.sh when the payload exceeds the configured token budget. Fix any integration issues between the two scripts. Ensure the manifest is rebuilt after compression.

### T05: End-to-end integration test

Run a full E2E test: create knowledge entries, build a context payload, verify manifest accuracy, verify knowledge entries are included and hit counts incremented, compress the payload, verify compression works. Run all 8 verification scripts and confirm they pass.

## Task Dependencies

T01 → T02 → T03 → T04 → T05

T01 creates verification scripts first (they will initially fail for any truths that need fixes). T02 fixes knowledge integration. T03 fixes ordering and manifest. T04 fixes compression and budget. T05 runs all verifications end-to-end.

## Files Likely Touched

- scripts/dispatch/build-context.sh (modify)
- scripts/dispatch/compress-payload.sh (modify)
- scripts/dispatch/lib/section-handlers.sh (modify)
- scripts/verify/m002-p04-uses-index-pipeline.sh (create)
- scripts/verify/m002-p04-planning-uses-index.sh (create)
- scripts/verify/m002-p04-manifest-header.sh (create)
- scripts/verify/m002-p04-static-first-ordering.sh (create)
- scripts/verify/m002-p04-increments-hits.sh (create)
- scripts/verify/m002-p04-compression-cascade.sh (create)
- scripts/verify/m002-p04-manifest-rebuild.sh (create)
- scripts/verify/m002-p04-budget-enforcement.sh (create)
