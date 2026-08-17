---
schema_version: "1.0"
type: roadmap
milestone: MFIX
tier: C
---

# MFIX Roadmap — M046/P02 exit-battery `planning-ok` fixture (throwaway)

Synthetic 1-phase milestone for the SC-9 exit battery. The active phase P01
is unchecked and has NO phases/P01/P01-PLAN.md, so derive-phase.sh yields
`planning` and the real auto-loop.sh runs build-context.sh in PHASE_PLAN
mode. The tree is nested as root/milestones/MFIX so auto-loop's
ORCH_ROOT (= milestone-dir/../..) resolves to a root containing
milestones/ — the P01 "fixture root doubles as ORCHESTRATOR_ROOT" pattern.
build-context's planning branch degrades gracefully on missing optional
inputs (knowledge index, context draft, feature spec) so the payload
assembly succeeds: exit 0 + `AUTO:PLANNING phase=P01` + marker
`planning P01`. Verifiers ALWAYS run against scratch copies of this tree.

## Phases

- [ ] **P01**: Fixture phase — "fixture demo"
  - Risk: low
  - Depends: none
