---
schema_version: "1.0"
type: friendly-tester-report
report_date: "2026-05-04"
eligible_testers: 1
friction_blockers: 1
friction_warnings: 0
tester_attestations:
  - tester_id: "T1"
    not_familiar_with_orchestrator: "yes"
tested_branches:
  - existing-codebase
---

# Friendly Tester Report (Fail Fixture)

<!--
  This fixture is consumed by tools/verify/m033-p01-validate-report-fixtures-shape.sh.
  It is shaped to FAIL validate-report.sh:
    friction_blockers: 1  (any value >0 fails SC-15)
  The verifier additionally asserts the validator's stderr contains the
  substring "friction_blockers=1".
-->

## Tester(s)
- T1 -- 5yr full-stack dev, never seen this repo

## Branch: existing-codebase
### Friction (Blockers)
- Could not figure out which --branch flag corresponds to "I have an existing codebase but no specs."
### Friction (Warnings)
(none)
### Notes
- Tester worried the tool would mutate their working tree.
