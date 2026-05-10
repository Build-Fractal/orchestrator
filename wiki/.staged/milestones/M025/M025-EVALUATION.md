---
schema_version: "1.0"
type: evaluation
milestone: "M025"
feature_ref: "021-github-installer-coexistence"
feature_spec: "specs/021-github-installer-coexistence/spec.md"
tier: "B"
tier_source: "override"
created_at: "2026-04-23"
metrics_source: "raw_spec"
---

# M025 Evaluation

## Classification

- **Tier**: B
- **Source**: override (user-directed during pre-specify discussion; confirmed by metrics)
- **Next command**: `orchestrator:roadmap`

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 4 |
| Acceptance scenarios | 11 |
| Functional requirements | 10 |
| Estimated SDD flows | 1 |

## Reasoning

Single SDD flow suffices: one spec → one phase (P01) → ~3–4 dispatch-sized tasks → one verification pass → consolidate. No cross-phase coordination, no ambiguous architecture, no dependency chain that would require the overhead of Tier C autonomous mode.

Scope is tightly bounded by FR-9 (Claude Code runtime only; Codex/Cursor untouched) and reinforced by CON-5 (negative-grep gate). Every FR names a concrete script or artifact. Every SC is a mechanical check.

Tier B manual per-phase flow (`plan-phase` → `dispatch`/`verify` loop) keeps the human in the decision on #Q-1 (event-mapping policy), which is the one genuinely judgment-requiring step — auto mode would burn that decision in whatever the first agent picked.

## Complexity Factors

- **Narrow blast radius**: 2 files change behavior (`scripts/dispatch/adapters/runtime/claude-code.sh`, `packaging/install/install-claude-code.sh`); 4 new gate scripts + 1 fixture + 2 doc updates.
- **Known-shape inputs**: the bug is fully diagnosed (schema wrapper metadata + unconditional overwrite) with commit-level evidence (`d33b8a7`). No investigation phase needed.
- **Bash-3.2 + optional-jq constraint** (CON-1, CON-2): adds implementation friction but no scope — same constraint M013/P04 already navigated successfully.
- **One real design decision** (#Q-1 event-mapping): bounded to "assign 6 orchestrator events to CC events or mark deferred" — resolved in one planner pass, not an architecture discussion.
- **Regression-remediation posture**: tests are the primary deliverable alongside the fix; lesson-layer entry (Principle VII) captures why M013/P04/T04 gate coverage missed this.
