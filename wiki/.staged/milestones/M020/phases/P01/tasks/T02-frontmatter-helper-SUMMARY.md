---
schema_version: "1.0"
type: task-summary
id: "T02-frontmatter-helper"
parent: "P01"
milestone: "M020"
provides:
  - "atomic frontmatter read/write helpers for M020 schema-evolution fields (status:, decision_history:, archived_into:); contract verifier m020-p01-frontmatter-helper-contract.sh"
requires:
  - "from:M020/P01/T01 what:closed-enum vocabulary candidate/graduated/archived plus companion-field schema (MEM031, D024)"
affects:
  - "P01/T03 (graduate.sh consumer); P03 (cluster-aware graduate + decision_history append); P05 (migration-incremental check); M024 + M019 Tier 2+3 (read-only consumers via fm_read_status FR-10 default)"
key_files:
  - "scripts/knowledge/lib/frontmatter.sh;scripts/verify/m020-p01-frontmatter-helper-contract.sh"
key_decisions:
  - "D024"
patterns_established:
  - "atomic frontmatter mutation via tempfile+rename(2); awk-based pure-passthrough writes preserving CON-4 byte-equivalence; closed-enum guard runs BEFORE tempfile creation so invalid values produce zero file I/O; FR-10 incremental-migration default (absent status: reads as graduated)"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P01/tasks/T02-frontmatter-helper-PLAN.md;/tmp/T02-PAYLOAD.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-25T04:57:09Z"
---

Shipped scripts/knowledge/lib/frontmatter.sh exposing five public functions per the T02 contract: fm_assert_closed_enum (rejects out-of-enum BEFORE tempfile), fm_read_status (FR-10 default = graduated), fm_write_status, fm_write_archived_into, fm_append_decision_history. Every mutation follows the write-tempfile-then-mv discipline (POSIX rename(2) atomicity); a crash mid-write leaves the original byte-identical. Bash 3.2 safe (no declare -A, no =~, no parameter-expansion case ops). Contract verifier scripts/verify/m020-p01-frontmatter-helper-contract.sh exercises 7 cases (default-graduated, insert, replace-not-duplicate, enum-rejection-with-prior-value-intact, archived_into write, decision_history create, no-tmp-debris) plus a bonus byte-equivalence assertion on body content. PASS. Smoke probe against [knowledge/patterns/MEM001.md](../../../../../knowledge/patterns/MEM001.md) (real pre-M020 entry, no status: line) returned 'graduated' as required by FR-10. No knowledge/**/MEM*.md mutations from T02 — git status of knowledge/ matches the pre-T02 baseline exactly (30 M + 1 ??, identical set). The T05-owned migration-incremental verifier does not yet exist, so the verification-step substitution was the equivalent direct check (git status of knowledge/ unchanged from baseline).
