---
schema_version: "1.0"
type: task-summary
id: "T04"
parent: "P07"
milestone: "M005"
provides:
  - "auto.md permission pre-flight rewrite, evaluate.md generate_on_init trigger, Known Limitations subsection"
requires:
  - "from:P07/T02 what:generate-permissions.sh,from:P07/T03 what:write-permissions.sh,check-permissions.sh"
affects:
  - "P06"
key_files:
  - "commands/auto.md,commands/evaluate.md"
key_decisions:
  - "AD-19,AD-10,FR-6,FR-7"
patterns_established:
  - "three-state permission detection (MISSING/ORCHESTRATOR/USER_AUTHORED), Known Limitations documentation pattern"
drill_down_paths:
  - ".specify/orchestrator/milestones/M005/phases/P07/tasks/T04-PLAN.md"
duration: "45s"
verification_result: "pass"
completed_at: "2026-04-12T22:47:12Z"
---

Rewrote auto.md Permission Pre-Flight section with full FR-6 flow: read autonomy config, detect settings state (MISSING/ORCHESTRATOR/USER_AUTHORED), branch on state (generate fresh, regenerate+drift-check, or additive merge). Added Known Limitations: Harness Safety Heuristics subsection per AD-19 naming the residual prompt class, the allow-list gap, and the script-file shape remedy. Updated evaluate.md to trigger generate-permissions.sh during scaffold when autonomy.generate_on_init is true (FR-7).
