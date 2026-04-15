---
schema_version: "1.0"
type: evaluation
milestone: "M008"
feature_ref: "008-standalone-orchestrator"
feature_spec: "specs/008-standalone-orchestrator/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-14T00:00:00Z"
---

# M008 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: speckit.orchestrator.discuss

## Metrics

| Metric                   | Count |
|--------------------------|-------|
| User stories             | 6     |
| Acceptance scenarios     | 24    |
| Functional requirements  | 26    |
| Estimated SDD flows      | 4–6   |

## Reasoning

This feature transforms the orchestrator from a spec-kit extension into a standalone, multi-runtime tool with an adaptive intensity engine — a fundamental architectural shift across six phases. The work spans multiple distinct domains (intensity engine, process scaling, adapter abstraction, namespace independence, packaging, onboarding), each requiring its own full planning → task decomposition → implementation cycle.

Key factors driving Tier C classification:

1. **Multiple SDD flows**: At minimum 4 distinct planning cycles are needed — the intensity engine alone (P01+P02) is one full cycle, the adapter layer (P03) is another, namespace + packaging (P04+P05) is a third, and onboarding (P06) is a fourth. Each has its own design constraints and verification criteria.

2. **Complex dependency graph**: The critical path P01→P02→P04→P05 is sequential, while P03 (adapters) can run in parallel with P02. P06 depends on P04+P05. This is not a linear flow — it requires boundary maps and cross-phase coordination.

3. **High risk on critical path**: P01 (intensity engine) and P02 (process scaling) are both HIGH RISK phases that touch every pipeline stage. A misstep in intensity calibration cascades through all downstream behavior.

4. **Cross-cutting concerns**: Runtime adapter changes (P03) affect dispatch (P03 backend adapters), state management (P04), packaging (P05), and onboarding (P06). These interfaces must be designed together even if implemented separately.

5. **Scale**: 26 functional requirements across 6 user stories with 24 acceptance scenarios. This is not deliverable in a single pass — it needs the full orchestrator with autonomous dispatch, crash recovery, and knowledge consolidation.

## Complexity Factors

- **Architectural risk**: Decoupling from spec-kit while maintaining backward compatibility is a fundamental structural change, not a feature addition.
- **Multi-runtime surface area**: Each supported runtime (Claude Code, Codex CLI, Cursor, Gemini CLI) has different conventions for skill discovery, project instructions, and hooks — the adapter layer must abstract these differences.
- **Intensity engine novelty**: No prior art exists in the codebase for scope/risk auto-classification. P01 introduces a new subsystem from scratch.
- **Dispatch interface is M010 seam**: The backend-agnostic dispatch interface designed in P03 must accommodate future cloud backends without breaking changes — getting this wrong blocks the M010 milestone.
- **Backward compatibility**: Existing orchestrator users must be able to migrate without losing state, and the spec-kit integration mode must work alongside standalone mode.
