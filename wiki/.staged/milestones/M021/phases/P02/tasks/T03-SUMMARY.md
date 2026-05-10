---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P02"
milestone: "M021"
provides:
  - "scripts/verify/m021-p02-linter-v2.sh gate + 10 fixture seeds under tests/fixtures/m021-p02/ asserting Class A (AP-004) + Class B (AP-005..AP-009) coverage, suppression preservation, and ANTIPATTERNS.md wrapper-citation structure"
requires:
  - "from:T01 what:scripts/verify/anti-pattern-lint.sh --fixture flag + AP-004..AP-009 tagged output; from:T02 what:ANTIPATTERNS.md AP-005..AP-009 headings each naming scripts/util/*.sh"
affects:
  - "P02,P03,P04"
key_files:
  - "scripts/verify/m021-p02-linter-v2.sh,tests/fixtures/m021-p02/class-a-cmd-sub.md,tests/fixtures/m021-p02/class-a-backtick.md,tests/fixtures/m021-p02/class-a-brace.md,tests/fixtures/m021-p02/class-b-simple-expansion.md,tests/fixtures/m021-p02/class-b-redirect-cmd-sub.md,tests/fixtures/m021-p02/class-b-quoted-brace.md,tests/fixtures/m021-p02/class-b-heredoc-expansion.md,tests/fixtures/m021-p02/class-b-task-plan-compound-PAYLOAD.md,tests/fixtures/m021-p02/suppressed.md,tests/fixtures/m021-p02/clean.md"
key_decisions:
  - "AD-19"
patterns_established:
  - "Fixture seed per detector under tests/fixtures/<milestone>-<phase>/; gate stages task-plan-compound fixture via tempdir with literal tasks/ segment so */tasks/*-PAYLOAD.md scope predicate fires; gate internals use $() and pipes freely (MEM004, AP-004 scope-of-enforcement note) because enforcement applies to inline tool-call sites, not verification-script internals; fixtures live outside linter default scan roots so main-repo sweep remains unaffected"
drill_down_paths:
  - ".orchestrator/milestones/M021/phases/P02/tasks/T03-PLAN.md,scripts/verify/m021-p02-linter-v2.sh,tests/fixtures/m021-p02/"
duration: "20m"
verification_result: "pass"
completed_at: "2026-04-17T18:46:47Z"
---

Shipped scripts/verify/m021-p02-linter-v2.sh and ten fixture seeds under tests/fixtures/m021-p02/ per plan. Gate exits 0 with 22 PASS assertions and final 'PASS: m021-p02-linter-v2.sh' line. Three Class A fixtures (class-a-cmd-sub.md, class-a-backtick.md, class-a-brace.md) trip [AP-004]. Five Class B fixtures trip [AP-005]..[AP-009] respectively; class-b-simple-expansion.md and class-b-heredoc-expansion.md additionally assert their remediation-hint substrings name scripts/util/with-env.sh and scripts/util/run-probe.sh. The task-plan-compound fixture requires */tasks/*-PAYLOAD.md scope; the gate copies it into a mktemp-d tempdir with a literal tasks/ segment, invokes the linter against the staged T99-PAYLOAD.md, then cleans up. suppressed.md (uses # FORBIDDEN) and clean.md yield zero violations, preserving [M016](../../../../../milestones/M016/index.md) suppression semantics. Gate also asserts ANTIPATTERNS.md has AP-005..AP-009 headings and each section names a scripts/util/ wrapper path, using awk section-capture + grep. Fixture isolation verified: bash scripts/verify/anti-pattern-lint.sh produces zero violations originating from tests/fixtures/m021-p02/ (confirmed via grep). Pre-existing violations remain only in the active T03-PAYLOAD.md itself, which the linter auto-skips once this SUMMARY lands (active-task predicate in anti-pattern-lint.sh lines 80-92). No deviations from plan. No scope gate shipped (T04's territory).
