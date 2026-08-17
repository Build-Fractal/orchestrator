---
schema_version: "1.0"
type: roadmap
milestone: MFIX
tier: C
---

# MFIX Roadmap — M046/P02 exit-battery `budget` fixture (throwaway)

Synthetic 1-phase milestone for the SC-9 exit battery. Executing state:
P01 unchecked, P01-PLAN.md present, tasks/T01-PLAN.md with no T01-SUMMARY.md.
execution-log.jsonl carries ONE dispatch record. The battery invokes the
real auto-loop.sh with SPECKIT_ORCHESTRATOR_DISPATCH_BUDGET=1 (read-config's
layer-1 env override — auto-loop passes no config files to read-config.sh,
so the env layer is the only live config source for dispatch_budget), so
budget-checker.sh reports BUDGET:EXCEEDED type=dispatch current=1 limit=1
→ exit 2 → marker `budget`. Verifiers ALWAYS run against scratch copies.

## Phases

- [ ] **P01**: Fixture phase — "fixture demo"
  - Risk: low
  - Depends: none
