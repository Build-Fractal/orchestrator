---
schema_version: "1.0"
type: task-summary
id: "T02"
parent: "P01"
milestone: "M014"
provides:
  - "spec-shape-lint-surface,m014-p01-gate-verifier"
requires:
  - "T01"
affects:
  - "scripts/verify"
key_files:
  - "scripts/verify/spec-shape-lint.sh,scripts/verify/m014-p01-spec-shape-lint.sh"
key_decisions:
  - "order-check-advisory,top-level-section-presence-only"
patterns_established:
  - "template-derived-required-section-list,loose-heading-presence-match"
drill_down_paths:
  - ".orchestrator/milestones/M014/phases/P01/tasks/T02-PLAN.md"
duration: "25m"
verification_result: "pass"
completed_at: "2026-04-22T20:30:44Z"
---

Shipped scripts/verify/spec-shape-lint.sh (FR-4) deriving its required top-level section list from templates/spec-template.md at runtime. Linter checks: (1) presence of every template-derived ## heading, (2) five frontmatter fields, (3) three mandatory ### subsections (Minimal Slice, Knowledge-Layer Boundary, User Story N). Emits checks=/passed=/failed= and advisory todo_count= lines. Also shipped scripts/verify/m014-p01-spec-shape-lint.sh gate exercising three fixtures: template-itself (pass+todos>0), synthetic missing-section (exit 1), authored specs/024-spec-management-extended/spec.md (pass). Two deviations from verbatim body: (a) narrowed Check 1 heading derivation to ^## rather than ^#+ — avoided fragile substring match against ### User Story 1 — <TODO...> (Priority: P1) template lines; ### subsection presence covered by Check 3. (b) Converted strict out-of-order detection to stderr WARN + record_pass — authored spec orders Constraints before Non-Goals while template does the reverse; presence is the hard contract, ordering is advisory and binding order-gate lives in scripts/verify/m014-p01-template-ssot.sh against the template itself. Both scripts Bash 3.2 compatible, pass anti-pattern-lint, gate exits 0.
