---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P01"
milestone: "M011"
provides:
  - "knowledge/spec/ directory tree with 6 subdirs, create-entry.sh SPEC- ID support with namespace validation"
requires:
  - "none"
affects:
  - "rebuild-index.sh, scope-filter.sh, ingest-spec.sh (downstream P02-P04)"
key_files:
  - "scripts/knowledge/create-entry.sh, .orchestrator/knowledge/spec/"
key_decisions:
  - "AD-1: SPEC-prefixed natural IDs, AD-2: nested spec/ category dirs"
patterns_established:
  - "case/esac namespace validation for SPEC- prefix"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P01/tasks/T01-PLAN.md"
duration: "0"
verification_result: "pass"
completed_at: "2026-04-16T11:48:48Z"
---

Scaffolded 6 spec subdirectories under knowledge/spec/ (story, requirement, constraint, nfr, acceptance, non-goal) with .gitkeep files. Extended create-entry.sh to accept SPEC-prefixed IDs and validate they are only used with spec/ category prefixes via Bash 3.2 compatible case/esac. All 4 verification scripts pass.
