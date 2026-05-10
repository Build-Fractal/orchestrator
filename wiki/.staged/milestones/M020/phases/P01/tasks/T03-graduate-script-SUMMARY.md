---
schema_version: "1.0"
type: task-summary
id: "T03-graduate-script"
parent: "P01"
milestone: "M020"
provides:
  - "minimum-viable scripts/knowledge/graduate.sh single-entry candidate to graduated flip via T02 fm_write_status; two verifier scripts m020-p01-graduate-single-entry.sh and m020-p01-graduate-side-effect-scope.sh"
requires:
  - "from:M020/P01/T01 what:closed-enum candidate-graduated-archived (MEM031, D024); from:M020/P01/T02 what:fm_read_status + fm_write_status atomic helpers in lib/frontmatter.sh"
affects:
  - "P03 extends graduate.sh in-place with --cluster, --reject, decision_history append, archive sibling back-refs; T05 consumer of graduate.sh as demo-sentence; future on-touch migration of live MEM entries"
key_files:
  - "scripts/knowledge/graduate.sh;scripts/verify/m020-p01-graduate-single-entry.sh;scripts/verify/m020-p01-graduate-side-effect-scope.sh"
key_decisions:
  - "D024"
patterns_established:
  - "closed-enum case dispatch on fm_read_status with three branches (graduated NO-OP exit 0; archived FAIL exit 1; candidate flip+exit 0); idempotent re-invocation per MEM001; rationale stubbed to stdout RATIONALE line in P01 with FR-7 frontmatter append deferred to P03; PROJECT_ROOT env-var fixture-isolation strategy for verifier scripts because lib/index-utils.sh get_project_root honors PROJECT_ROOT not ORCHESTRATOR_ROOT"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P01/tasks/T03-graduate-script-PLAN.md;/tmp/T03-PAYLOAD.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-25T05:02:16Z"
---

Shipped scripts/knowledge/graduate.sh per A-1 minimum-viable scope: --rationale text required flag, single positional entry-id, sources lib/index-utils.sh + lib/detail-utils.sh + lib/frontmatter.sh, dispatches on fm_read_status output. Closed-enum branches: graduated -> stdout NO-OP exit 0 (idempotent per MEM001); archived -> stderr FAIL exit 1 with --reanimate-not-implemented breadcrumb; candidate -> fm_write_status atomic flip + RATIONALE stdout stub + GRADUATED success line. P03-deferred: --cluster, --reject, decision_history frontmatter append (FR-7 stub only), archive-sibling back-references. CON-1 operator-invoked and FR-7-deferred-stub documented in script header. Two verifier scripts both PASS: m020-p01-graduate-single-entry.sh covers 4 cases (flip, idempotency, missing --rationale rejected, missing entry rejected); m020-p01-graduate-side-effect-scope.sh hashes a sibling fixture before/after to assert single-file mutation bound. Verifier-fixture isolation deviates from PAYLOAD draft: task plan note flagged that get_project_root honors PROJECT_ROOT (not ORCHESTRATOR_ROOT per the 4-rule resolver) and authorized env-var substitution; both verifier scripts export PROJECT_ROOT=tempdir. No knowledge MEM mutations from T03 work. Bash 3.2 + AD-19 + MEM001/MEM003 prefix conventions throughout.
