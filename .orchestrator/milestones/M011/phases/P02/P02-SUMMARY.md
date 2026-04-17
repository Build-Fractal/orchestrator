---
schema_version: "1.0"
type: phase-summary
id: "P02"
parent: "M011"
milestone: "M011"
provides:
  - "scripts/knowledge/ingest-spec.sh skeleton with section splitter and classification router, Full section classifiers in ingest-spec.sh: stories, requirements, constraints, non-goals, acceptance scenarios with relates_to edges, Content hash population in spec chunks, first-ingest idempotency, rebuild-index validation"
requires:
  - "P01: create-entry.sh SPEC- ID support, rebuild-index.sh nested scanning, knowledge/spec/ tree, T01: ingest-spec.sh skeleton with section splitter and dispatch router, T02: full classifier implementations in ingest-spec.sh"
affects:
  - "T02 classifier implementation, T03 hash/idempotency wiring, T03 content hash wiring, P03 re-ingest mode, P04 dispatch integration, P03 re-ingest change detection (compares content hashes), P04 dispatch payload integrity"
key_files:
  - "scripts/knowledge/ingest-spec.sh, scripts/knowledge/ingest-spec.sh, scripts/knowledge/ingest-spec.sh"
key_decisions:
  - "H2-heading section split, dispatch_section router pattern, stub classifiers for T02, create_chunk helper wrapping create-entry.sh, AC numbering global not per-story, source_unit includes section anchor, local variable names per function to avoid heredoc variable collision, AD-4: SHA-256 content hash via hash.sh, sed_i patching after create, normalize_for_hash strips whitespace"
patterns_established:
  - "Section-level markdown parsing with while-read loop, classify_* function naming, classify_* function pattern with while-read section parsing, SPEC-XX-NNN ID derivation from spec content, unique loop variable names in nested function calls, Post-creation hash patching pattern, SKIPPED output for idempotent re-runs"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P02/tasks/T01-SUMMARY.md, .orchestrator/milestones/M011/phases/P02/tasks/T02-SUMMARY.md, .orchestrator/milestones/M011/phases/P02/tasks/T03-SUMMARY.md"
duration: "0m"
verification_result: "pass"
completed_at: "2026-04-16T19:58:14Z"
observability_surfaces:
  - "none"
---

P02 delivered the core ingest pipeline: scripts/knowledge/ingest-spec.sh parses markdown specs into structured knowledge chunks. Three tasks:

T01 created the script skeleton with H2-heading section splitter and dispatch_section router. Tested against specs/016-autonomous-hardening/spec.md to validate section routing.

T02 replaced stub classifiers with full implementations. classify_stories_section splits on User Story headings, extracts acceptance scenarios as separate chunks with relates_to edges to parent stories. classify_requirements_section parses FR-NNN items. classify_constraints_section and classify_nongoals_section handle bullet lists. AC numbering is global (not per-story). Real-world test on 016-autonomous-hardening produced 20 correct entries (3 stories, 10 ACs, 3 non-goals, 4 constraints). Fixed a variable name collision in nested while-read loops.

T03 wired content hash computation via hash.sh compute_content_hash(). normalize_for_hash strips trailing whitespace and blank lines for stable hashing. Post-creation sed_i patching writes SHA-256 hash to the content_hash frontmatter field. First-ingest idempotency confirmed: re-running on unchanged spec produces only SKIPPED lines with zero CREATED.

All 11 verification scripts pass across classification accuracy, content hashing, idempotency, and Bash 3.2 compatibility.
