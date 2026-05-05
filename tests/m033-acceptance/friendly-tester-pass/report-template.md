---
schema_version: "1.0"
type: friendly-tester-report
report_date: "YYYY-MM-DD"
eligible_testers: 0
friction_blockers: 0
friction_warnings: 0
tester_attestations:
  - tester_id: "T1"
    not_familiar_with_orchestrator: "yes"
tested_branches:
  - greenfield-empty
  - greenfield-with-materials
  - existing-codebase
  - migrating
---

# M033 Friendly-Tester Report

<!--
  Fill in this template after running the protocol at protocol.md.
  Replace YYYY-MM-DD with the report date. Update the four scalar
  counters in the frontmatter to reflect aggregate observations.
  Each tester_id MUST have a corresponding not_familiar_with_orchestrator
  line; only "yes" attestations count toward eligible_testers.
  Submit the filled report to:
    tests/m033-acceptance/friendly-tester-pass/reports/<DATE>.md
  Then run:
    bash tests/m033-acceptance/friendly-tester-pass/validate-report.sh \
      tests/m033-acceptance/friendly-tester-pass/reports/<DATE>.md
-->

## Tester(s)
- T1 — <self-described background, e.g. "5yr full-stack dev, never seen this repo">

## Branch: greenfield-empty
### Friction (Blockers)
<list one per blocker, or "(none)">
### Friction (Warnings)
<list one per warning, or "(none)">
### Notes
<free-form observations>

## Branch: greenfield-with-materials
### Friction (Blockers)
<list one per blocker, or "(none)">
### Friction (Warnings)
<list one per warning, or "(none)">
### Notes
<free-form observations>

## Branch: existing-codebase
### Friction (Blockers)
<list one per blocker, or "(none)">
### Friction (Warnings)
<list one per warning, or "(none)">
### Notes
<free-form observations>

## Branch: migrating
### Friction (Blockers)
<list one per blocker, or "(none)">
### Friction (Warnings)
<list one per warning, or "(none)">
### Notes
<free-form observations>

## Aggregate
- Eligible testers: <int -- must match count of not_familiar_with_orchestrator: yes lines>
- Total friction blockers: <int -- must match friction_blockers: in frontmatter>
- Total friction warnings: <int -- must match friction_warnings: in frontmatter>

## Maintainer Sign-Off
- Recorded by: <maintainer handle>
- Walkthrough date: <YYYY-MM-DD>
- Time spent: <minutes>
- Follow-ups created: <list of issue/proposal links, or "(none)">
