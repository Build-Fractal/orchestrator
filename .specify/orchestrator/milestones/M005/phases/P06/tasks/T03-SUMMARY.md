---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P06"
milestone: "M005"
provides:
  - "scripts/diagnostics/check-plans.sh scanning task plan Check: commands and inline bash blocks for 10 AD-19 trigger patterns emitting DOCTOR:PLANS advisory output"
requires:
  - "from:P07 what:AD-19 shape guidance in plan-phase.md and templates"
affects:
  - "P06"
key_files:
  - "scripts/diagnostics/check-plans.sh, scripts/verify/p06-check-plans.sh"
key_decisions:
  - "AD-19"
patterns_established:
  - "advisory-only diagnostic (always exit 0), multi-pattern trigger classification, Check: line and verification block extraction from markdown"
drill_down_paths:
  - "none"
duration: "168s"
verification_result: "pass"
completed_at: "2026-04-13T02:31:24Z"
---

Created check-plans.sh that scans task plan Check: commands and inline bash verification blocks for 10 AD-19 trigger pattern classes (bash-c, chain, heredoc, subshell-source, subshell-pipe, cmdsub-pipe, procsub, redirect-in-cmdsub, compound-semi, inline-loop). Advisory only — always exits 0. Reports structured DOCTOR:PLANS output with heuristic_risk count and most common trigger class. Found 146 triggers in existing plan corpus (expected — older plans pre-date AD-19 guidance). Template canaries pass clean.
