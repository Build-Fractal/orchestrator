---
schema_version: "1.0"
type: evaluation
milestone: "M004"
feature_ref: "004-engine-architecture"
feature_spec: "specs/004-engine-architecture/spec.md"
tier: "C"
tier_source: "manual"
created_at: "2026-04-10T22:00:00Z"
---

# M004 Evaluation

## Classification

- **Tier**: C
- **Source**: manual
- **Next command**: speckit.orchestrator.discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 10 |
| Acceptance scenarios | 37 |
| Functional requirements | 18 |
| Estimated SDD flows | 5 |

## Reasoning

This spec defines a foundational architectural shift: introducing an engine coordination layer, YAML-driven configuration, shared libraries, hook system, safety rails, and constitution evolution. The work spans 10 user stories across 6 functional domains: engine core (US1), YAML recipes (US2-US3), events/results protocol (US4, US8), hooks (US5), safety rails (US6), constitution (US7), run context (US9), and model routing (US10). Each domain requires its own design, implementation, and integration cycle. The shared libraries must be built before the engine can use them. The YAML recipe system must be designed before scripts can be refactored to consume it. The constitution must be updated before new code can be verified against it. This clearly requires full Tier C orchestration.

## Complexity Factors

- **Cross-cutting shared libraries** — lib/errors.sh, lib/events.sh, lib/run-context.sh, lib/hooks.sh, lib/guards.sh must be consumed by both new engine code and retrofitted into existing scripts. Coordination required across all phases.
- **YAML recipe parser in Bash 3.2** — Parsing structured YAML (nested sections, arrays, variable interpolation) without jq is non-trivial. Requires careful design of the recipe schema to stay parseable with grep/sed/awk.
- **Existing script compatibility** — NFR-204 requires all existing scripts to continue working standalone. The engine is additive. This means scripts must support both engine-managed and standalone invocation.
- **Constitution amendment** — 5 new principles, 2 amendments, new antipattern register. Requires consistency propagation across templates and verification workflows.
- **Hook isolation contract** — Frozen state snapshots, chmod protections, violation detection. Novel pattern for the orchestrator.
- **Two-track dependency** — Shared libraries (foundation) feed both the engine track and the recipe track, which converge at the refactored scripts.

## Prior Art

Patterns drawn from analysis of:
- **Conversus v2.2.0** — Event emission protocol, plugin lifecycle hooks, frozen state models, error taxonomy, constitution principles (especially VII, VIII, XI, XII, XV)
- **index-pipeline** — Result objects with typed errors, RunContext threading, staleness protection, conformance test kit, pure transform / effectful orchestration split, ScrapePolicy configuration pattern
