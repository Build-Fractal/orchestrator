---
schema_version: "1.0"
type: evaluation
milestone: "M041"
feature_ref: "041-detective"
feature_spec: "specs/041-detective/spec.md"
tier: "B"
tier_source: "auto"
created_at: "2026-05-25T01:30:00Z"
metrics_source: "raw_spec"
---

# M041 Evaluation

## Classification

- **Tier**: B
- **Source**: auto (analysis)
- **Next command**: /orchestrator-roadmap

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 4 |
| Acceptance scenarios | 10 |
| Functional requirements | 10 |
| Estimated SDD flows | 1 |

## Reasoning

The detective command is a single new command with three supporting scripts and cross-command recommendation hooks in ~4 existing commands. The work requires one complete SDD flow where each step fits in its own context window: the command definition, the three diagnostic scripts, the mock harness and fixtures, and the cross-command hooks are distinct implementation units that dispatch separately. The scope is bounded — no new state-machine states, no new knowledge-graph node types, no autonomous mode or crash recovery needed. Developer drives phase transitions manually.

Estimated 3-4 phases: (1) core triage engine + command definition, (2) GitHub integration scripts + mock harness, (3) cross-command recommendation hooks + PR suggestion heuristic, (4) acceptance battery + verification. This is textbook Tier B — one SDD flow, multiple contexts, sequential execution.

## Complexity Factors

- **External integration**: `gh` CLI for GitHub Issues search/create/comment — mature tool, well-documented API, but requires mock harness for offline testing (addressed in spec FR-2/FR-3, SC-2/SC-3)
- **Cross-command modification**: ~4 existing commands modified to add recommendation hooks — each is a single stderr line addition, low risk
- **TTY/pipe interaction**: FR-9/FR-10 interaction requires careful stdin handling — addressed by TTY-detection amendment from conversus gate
- **Path disambiguation**: FR-8 requires `$ORCHESTRATOR_ROOT` prefix comparison rather than bare directory-name matching — addressed by conversus advisory folded into #Q-6
- **Match-score calibration**: Keyword-overlap threshold requires empirical validation against real issue corpus — addressed by conversus advisory folded into #Q-1
