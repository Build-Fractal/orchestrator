---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P02"
milestone: "M011"
provides:
  - "Full section classifiers in ingest-spec.sh: stories, requirements, constraints, non-goals, acceptance scenarios with relates_to edges"
requires:
  - "T01: ingest-spec.sh skeleton with section splitter and dispatch router"
affects:
  - "T03 content hash wiring, P03 re-ingest mode, P04 dispatch integration"
key_files:
  - "scripts/knowledge/ingest-spec.sh"
key_decisions:
  - "create_chunk helper wrapping create-entry.sh, AC numbering global not per-story, source_unit includes section anchor, local variable names per function to avoid heredoc variable collision"
patterns_established:
  - "classify_* function pattern with while-read section parsing, SPEC-XX-NNN ID derivation from spec content, unique loop variable names in nested function calls"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P02/tasks/T02-PLAN.md"
duration: "0"
verification_result: "pass"
completed_at: "2026-04-16T19:52:32Z"
---

Replaced all 4 stub classifiers in ingest-spec.sh with full implementations. Added create_chunk helper wrapping create-entry.sh, classify_stories_section (splits on h3 headings, extracts acceptance scenarios with relates_to edges), classify_requirements_section (parses FR-NNN items using source FR number in SPEC ID), classify_constraints_section, classify_nongoals_section, and classify_nfr_section with dispatch routing. Fixed a variable name collision bug where nested function while-read loops overwrote the outer loops line variable through heredoc-fed reads. Created 7 verification scripts under scripts/verify/m011-p02-*. All 8 verification scripts pass. Real-world test against specs/016-autonomous-hardening/spec.md produces 20 correct entries (3 stories, 10 ACs, 3 non-goals, 4 constraints).
