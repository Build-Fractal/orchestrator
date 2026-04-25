---
schema_version: "1.0"
type: task-summary
id: "T06"
parent: "P01"
milestone: "M014"
provides:
  - "FR-18 byte-compat fixture test; SC-11 partial spec-management reference doc"
requires:
  - "from:P01/T01 what:spec-template.md+expected-section-headings.txt+specify-fixture-prose.txt; from:P01/T02 what:spec-shape-lint.sh; from:P01/T05 what:specify.sh"
affects:
  - "tests,references,scripts/verify"
key_files:
  - "tests/test-specify-shape.sh,references/spec-management.md,references/README.md,scripts/verify/m014-p01-specify-shape-test.sh,scripts/verify/m014-p01-spec-management-reference.sh"
key_decisions:
  - "none"
patterns_established:
  - "__PLACEHOLDER__ normalization for heading byte-match across scaffolded substitutions; BSD-vs-GNU sed no-i portability pattern; hermetic scratch test pattern for specify.sh dispatch"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P01/tasks/T06-PAYLOAD.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-22T20:51:53Z"
---

Shipped FR-18 byte-compat fixture test and the SC-11 partial spec-management reference. test-specify-shape.sh runs specify.sh against a hermetic scratch project, asserts (a) section-heading byte-match after __PLACEHOLDER__ normalization, (b) spec-shape-lint.sh PASS, (c) detect-spec-shape.sh reports shape=speckit (SC-2 I/O contract). Covers both --dry-run (asserts scaffold-spec manifest record) and live paths. references/spec-management.md ships Section Contract SSOT pointer, Dual-Write Marker Convention, and --dry-run Manifest Shape sections, with the partial-P04 HTML sentinel. references/README.md gains one additive row for the new doc. Two gate verifiers green; anti-pattern lint green on all three new shell scripts.
