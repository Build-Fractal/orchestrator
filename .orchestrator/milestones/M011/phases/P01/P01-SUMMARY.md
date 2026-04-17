---
schema_version: "1.0"
type: phase-summary
id: "P01"
parent: "M011"
milestone: "M011"
provides:
  - "knowledge/spec/ directory tree with 6 subdirs, create-entry.sh SPEC- ID support with namespace validation, rebuild-index.sh nested directory scanning for spec/* categories, SPEC- basename acceptance, next_entry_id() robustness against SPEC- prefixed files in nested directories, scope-filter.sh non-goal exclusion (AD-7), --include-non-goals flag, SPEC- data line recognition"
requires:
  - "T01: knowledge/spec/ directory tree, create-entry.sh SPEC- ID support, T01: create-entry.sh SPEC- ID support, knowledge/spec/non-goal/ directory"
affects:
  - "rebuild-index.sh, scope-filter.sh, ingest-spec.sh (downstream P02-P04), ingest-spec.sh (P02), knowledge.db graph queries, create-entry.sh auto-ID generation when spec chunks coexist with MEM entries, build-context.sh dispatch payloads (P04), verify command non-goal checking"
key_files:
  - "scripts/knowledge/create-entry.sh, knowledge/spec/, scripts/knowledge/rebuild-index.sh, scripts/knowledge/create-entry.sh, scripts/knowledge/lib/index-utils.sh, scripts/dispatch/scope-filter.sh"
key_decisions:
  - "AD-1: SPEC-prefixed natural IDs, AD-2: nested spec/ category dirs, Two-pass glob approach for nested scanning; content_hash field added to create-entry.sh heredoc for fm_field compatibility, MEM*.md glob inherently excludes SPEC- files, nested glob added for robustness, AD-7: category-based non-goal exclusion with --include-non-goals override"
patterns_established:
  - "case/esac namespace validation for SPEC- prefix, MEM*|SPEC-* basename filter pattern; two-depth glob scan for knowledge/*/*.md and knowledge/*/*/*.md, Comment-documented SPEC- exclusion rationale in next_entry_id(), SQL nongoal_clause pattern for graph mode, pre-category-filter exclusion for index mode"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P01/tasks/T01-SUMMARY.md, .orchestrator/milestones/M011/phases/P01/tasks/T02-SUMMARY.md, .orchestrator/milestones/M011/phases/P01/tasks/T03-SUMMARY.md, .orchestrator/milestones/M011/phases/P01/tasks/T04-SUMMARY.md"
duration: "0m"
verification_result: "pass"
completed_at: "2026-04-16T15:34:01Z"
observability_surfaces:
  - "none"
---

P01 bootstrapped the knowledge infrastructure for spec chunk storage. Four tasks across four scripts:

T01 created the knowledge/spec/ directory tree (6 subdirectories with .gitkeep) and extended create-entry.sh to accept SPEC-prefixed natural IDs (SPEC-FR-001, SPEC-US-002, etc.) with case/esac namespace validation ensuring SPEC- IDs require spec/ category prefixes.

T02 extended rebuild-index.sh with a two-pass glob (knowledge/*/*.md + knowledge/*/*/*.md) to scan nested spec directories, and updated the basename filter to accept both MEM* and SPEC-* prefixed entries. Also fixed a latent gap: create-entry.sh was not emitting the content_hash field in frontmatter, causing rebuild-index.sh to fail under set -euo pipefail when fm_field() returned empty.

T03 updated next_entry_id() in index-utils.sh to include the nested directory glob for robustness, with clarifying comments documenting that SPEC- files are inherently excluded by the MEM*.md glob pattern.

T04 added category-based non-goal exclusion to scope-filter.sh (AD-7): spec/non-goal entries are excluded by default in both index and graph modes, with --include-non-goals flag override for verification contexts. Also extended the data line regex to recognize SPEC-prefixed entries.

All 9 verification scripts pass. The foundation is ready for P02 (ingest pipeline) and P04 (dispatch integration).
