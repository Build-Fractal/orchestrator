---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P03"
milestone: "M016"
provides:
  - "scripts/verify/anti-pattern-lint.sh linter detecting Class A patterns in agent-facing content"
requires:
  - "from:P01/T03 what:ANTIPATTERNS.md AP-004 catalog"
affects:
  - "P04"
key_files:
  - "scripts/verify/anti-pattern-lint.sh"
key_decisions:
  - "code-block-only scanning scope; FORBIDDEN-region suppression covers subsequent lines until blank/heading; BSD sed compat via bracket-class escaping instead of literal braces"
patterns_established:
  - "code-block-only scanning, self-exclusion via resolved absolute paths, fixture mode for testing, FORBIDDEN-region multi-line suppression"
drill_down_paths:
  - ".orchestrator/milestones/M016/phases/P03/tasks/T01-PLAN.md"
duration: "1"
verification_result: "pass"
completed_at: "2026-04-16T03:47:40Z"
---

Created anti-pattern-lint.sh that scans commands/*.md and templates/*.md for Class A harness triggers (command substitution, backtick substitution, brace expansion). Detects violations only inside fenced code blocks. Self-excludes and excludes ANTIPATTERNS.md. Supports --fixture mode for testing and lint-ignore/FORBIDDEN suppression markers. Found 1 real violation in consolidate.md:42. All 5 must-haves verified: exits non-zero on each pattern class, exits 0 on self-scan, passes bash -n. BSD sed compatibility achieved by using bracket-class escaping for brace characters.
