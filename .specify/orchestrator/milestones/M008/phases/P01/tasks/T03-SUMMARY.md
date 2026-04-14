---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P01"
milestone: "M008"
provides:
  - "intensity-recommend.sh — recommendation engine combining scope analysis + capability profile into final intensity with confidence and reasoning"
requires:
  - "from:P01/T01 what:detect-capabilities.sh --profile; from:P01/T02 what:intensity-analyze.sh output"
affects:
  - "P03/all"
key_files:
  - "scripts/engine/intensity-recommend.sh"
key_decisions:
  - "none"
patterns_established:
  - "pipeline composition — upstream script outputs consumed via --flag file-or-text inputs for testability"
drill_down_paths:
  - ".specify/orchestrator/milestones/M008/phases/P01/tasks/T03-PLAN.md"
duration: "~10m"
verification_result: "pass"
completed_at: "2026-04-14T14:35:09Z"
---

Created intensity-recommend.sh combining T01's capability profile and T02's scope analysis into final intensity recommendation with confidence and reasoning. Decision matrix: scope × risk × complexity × capabilities → Quick/Standard/Full. Risk escalation rule prevents downgrades; risk_level=high Quick→Standard, risk_level=high+complexity=complex→Full, auth/security/migration signals→at least Standard. Confidence reduced to medium only when intensity=Full and cap_score≤1. Flags accept either file paths or inline text. Both verification scripts PASS; end-to-end pipeline smoke test returns intensity=Quick for a readme-typo task as expected.
