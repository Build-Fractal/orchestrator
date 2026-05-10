---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P05"
milestone: "M020"
provides:
  - "scripts/knowledge/lib/jaccard.sh::_jaccard_extract_tokens extended in place with relates_to[] + source_unit frontmatter reads + body window widened from first-paragraph-50 to full-body-200; .orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md regenerated against the live tree under CON-5 v2 with H1 updated to M020/P05 and an appended P05 Vector Extension Notes section documenting v1->v2 deltas; scripts/verify/m020-p05-feature-vector-extension.sh contract verifier (six checks: lib mentions relates_to + source_unit, head -200 literal present, no printed=1 v1 sentinel, P05 report mentions relates_to + source_unit + M020/P05 token)"
requires:
  - "from:P01/T04-T05 what:pairwise_jaccard + _jaccard_extract_tokens + validate-subcommand-and-recommendation-logic"
affects:
  - "P05/T03,P05/T04"
key_files:
  - "scripts/knowledge/lib/jaccard.sh,.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md,scripts/verify/m020-p05-feature-vector-extension.sh"
key_decisions:
  - "none-new"
patterns_established:
  - "evidence-driven vector extension (P01 validate-subcommand recommended widening; P05/T02 implemented exactly the three sources P01 named -- relates_to[] + source_unit + body cap 200 -- nothing more); P01-deliverable byte-preservation via capture-validate-restore (cp P01 report to /tmp before validate; validate rewrites the canonical P01 path; copy v2-derived report to P05 path; /bin/cp restores P01 because cp is aliased to cp -i); tokenizer-stage cap as body-window bound (body block awk no longer terminates at first blank line; 200-token head cap prevents long bodies from saturating the vector); editing only _jaccard_extract_tokens preserves pairwise_jaccard's callable contract (same arity + similarity=N.NNNN stdout shape) so P01 contract verifier stays green without modification"
drill_down_paths:
  - ".orchestrator/milestones/M020/phases/P05/tasks/T02-feature-vector-extension-PLAN.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-25T15:13:59Z"
---

P05/T02 extended the CON-5 feature vector to v2 by adding two frontmatter sources (relates_to[], source_unit) and widening the body window from first-paragraph-50 to full-body-200 inside scripts/knowledge/lib/jaccard.sh::_jaccard_extract_tokens. The pairwise_jaccard callable contract is unchanged (same arity, same similarity=N.NNNN stdout shape) and the P01 contract verifier still passes. Re-running validate against the live tree under v2 produced top similarity 0.2308 (up from 0.2000 at v1) and threshold recommendation 0.17 (up from 0.15 at v1), both still lower-aggressive against the 0.7 default. The P05 validation report at [.orchestrator/milestones/M020/phases/P05/jaccard-validation-report.md](../../../../../milestones/M020/phases/P05/jaccard-validation-report.md) captures the regenerated data, an updated H1 (M020/P05 CON-5 v2), and an appended P05 Vector Extension Notes section documenting v1 to v2 deltas, the still-canonicalized live-tree shape, and the future-tree-growth rationale. The P01 report at [.orchestrator/milestones/M020/phases/P01/jaccard-validation-report.md](../../../../../milestones/M020/phases/P01/jaccard-validation-report.md) is preserved byte-equivalent (CON-4) via a capture-validate-restore sequence: backup the P01 report to /tmp, run validate (which overwrites the P01 path), copy the v2-derived report to the P05 path, restore the P01 backup. The verifier scripts/verify/m020-p05-feature-vector-extension.sh exercises six checks (lib mentions relates_to + source_unit, head -200 literal, no printed=1 v1 sentinel, P05 report mentions relates_to + source_unit + M020/P05) and prints PASS. Done-when criteria all green: m020-p05-feature-vector-extension.sh PASS; m020-p01-jaccard-pairwise-contract.sh PASS; git diff on the P01 report empty.
