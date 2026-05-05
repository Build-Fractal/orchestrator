---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "M033/P01"
milestone: "M033"
provides:
  - "PBJ acceptance fixture; SC-4 ground-truth README oracle; two T01 verifiers (shape + oracle)"
requires:
  - "from:none what:none"
affects:
  - "P04 (materials-intake drift detector consumes fixture); P01/SC-1 (FR-2 rule-2 branch detection probe target)"
key_files:
  - "tests/fixtures/m033-pbj-materials-fixture/PRODUCT-BRIEF.md;tests/fixtures/m033-pbj-materials-fixture/MVP-PLAN.md;tests/fixtures/m033-pbj-materials-fixture/DECISIONS.md;tests/fixtures/m033-pbj-materials-fixture/MILESTONE-AUDIT.md;tests/fixtures/m033-pbj-materials-fixture/README.md;tools/verify/m033-p01-pbj-fixture-shape.sh;tools/verify/m033-p01-pbj-fixture-readme-oracle.sh"
key_decisions:
  - "none"
patterns_established:
  - "deterministic curatorial fixture with README oracle; oracle parser uses markdown numbered-list shape (lines 1.-5.) + closed CON-4 enum tokens"
drill_down_paths:
  - ".orchestrator/milestones/M033/phases/P01/tasks/T01-pbj-fixture-and-oracle-PAYLOAD.md"
duration: "20m"
verification_result: "pass"
completed_at: "2026-05-04T02:48:21Z"
---

T01 ships the synthetic-PBJ-shape fixture under tests/fixtures/m033-pbj-materials-fixture/ plus the two T01 verifiers under tools/verify/. The fixture contains exactly five inconsistencies covering all three CON-4 categories (id-misalignment x2, scheme-contradiction x2, orphan-reference x1). The README is the SC-4 ground-truth oracle: numbered list of 5 entries, each naming its CON-4 category and affected document pair. Determinism: text-only, no timestamps, no platform paths. Verification: m033-p01-pbj-fixture-shape.sh (30 PASS / 0 FAIL) and m033-p01-pbj-fixture-readme-oracle.sh (20 PASS / 0 FAIL). The 5 inconsistencies (mirrored from the README oracle for cross-reference auditability): (1) id-misalignment PRODUCT-BRIEF.md <-> MVP-PLAN.md (US-3 referenced but not defined); (2) scheme-contradiction DECISIONS.md <-> MVP-PLAN.md (DR-002 Vercel vs Cloudflare Workers); (3) orphan-reference MILESTONE-AUDIT.md (M-3 Authentication referenced nowhere upstream); (4) id-misalignment PRODUCT-BRIEF.md <-> DECISIONS.md (DR-003 defined but uncited); (5) scheme-contradiction PRODUCT-BRIEF.md <-> MVP-PLAN.md (4 weeks vs 6 weeks). No deviations from plan; scope-fixture-only honored (no scripts/lifecycle, no commands, no references touched).
