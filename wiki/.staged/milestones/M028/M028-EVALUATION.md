---
schema_version: "1.0"
type: evaluation
milestone: "M028"
feature_ref: "031-autonomous-hardening-v3"
feature_spec: "specs/031-autonomous-hardening-v3/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-29T00:00:00Z"
metrics_source: "raw_spec"
---

# M028 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: `orchestrator:discuss` (Tier C requires a discussion gate before roadmap)

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 5 |
| Acceptance scenarios | 21 |
| Functional requirements | 22 |
| Estimated SDD flows | 5 (P01 → P02 → P03 → P04 → P05; P01 gates whether P03–P05 ship) |

## Reasoning

M028 is multi-flow autonomous-orchestration work. The spec defines five phases (P01 baseline → P02 hook portability + adapter+installer dedup → P03 classifier extension → P04 investigation-pattern wrappers → P05 cross-project verifier suite) with a load-bearing P01 → P02 boundary plus a documented cross-phase collapse condition (if P01 evidence shows Finding A alone resolves 6 of 7 screenshots, P03–P05 stand down and the milestone reduces to 2 PRs). That branching outcome alone — a planning decision gated on phase-level empirical evidence — exceeds Tier B's "single SDD flow, multiple contexts" envelope.

The work touches eight distinct surfaces (`scripts/hooks/pre-bash-shape-guard.sh`, `scripts/dispatch/adapters/runtime/claude-code.sh`, `scripts/util/settings-merge.sh`, `packaging/install/install-claude-code.sh`, `scripts/verify/lib/shape-classifier.sh`, four new `scripts/util/*.sh` wrappers, `tests/fixtures/m021-prompt-corpus.txt`, and a new permanent fixture at `tests/fixtures/downstream-project/`) and produces seven per-finding verifiers under a new `scripts/verify/m028/` tree. Findings A and F are explicitly siblings folded into one phase because they share the installer + adapter surface — that kind of cross-finding integration constraint is the canonical reason to use full orchestration rather than ad-hoc dispatch.

22 FRs across 5 user stories with 21 acceptance scenarios, plus a closed knowledge-layer boundary (M025-owned vs. M028-owned), put the artifact set squarely in Tier C — autonomous dispatch, per-task verification, knowledge consolidation, and crash recovery all earn their keep here.

## Complexity Factors

- **Cross-phase collapse condition**: P01 baseline output gates whether P03–P05 ship full-shape or collapse to 2 PRs. This is an in-flight planning decision, not a static estimate; the planner must consume P01 evidence before finalizing the P02–P05 plan.
- **Sibling-finding fold**: Findings A (hook portability) and F ([M025](../../milestones/M025/index.md) hook-shim follow-up) share the installer + adapter surface and ship together in P02. Splitting them creates an integration gap (bare-name commands pointing at runtime-stable paths, or hook portability without working lifecycle scripts) — verification only closes when both ship in the same PR.
- **Self-conformance constraint**: The shape-guard hook itself must lint clean against AP-009 (its own classifier rule). FR-21 + SC-9 + CON-3 enforce this, requiring authoring discipline that the planner needs to surface as a pre-merge gate.
- **AP-014 body-descent classifier rule**: The most subtle of the five new antipatterns — the classifier descends one level into `sh -c '<body>'` token streams and sums in-body connectors with top-level pipe count. CON-5 + Edge Cases pin the recursion bound; this is real classifier logic beyond pattern-matching.
- **Install-roundtrip pinned-sha gate**: SC-2 + FR-6 + CON-4 demand byte-level reversibility (install → install → uninstall = pre-install canonical bytes). Extends M025/P01's reversibility pattern to M028's expanded entry set.
- **Permanent downstream fixture**: `tests/fixtures/downstream-project/` is permanent in-tree (CON-10) and must fail noisily if its `.claude/settings.json` schema drifts from the runtime adapter's emission shape.
- **bash 3.2 + POSIX sh constraint**: CON-2 applies to every new script (verifiers, wrappers, lifecycle scripts, classifier additions). No bash 4+ associative arrays, no `mapfile`/`readarray`, no unguarded here-strings.
- **Knowledge-layer boundary with M025**: The spec explicitly enumerates what M028 owns vs. what M028 consumes from M025 — the planner must respect this boundary so install-coexistence invariants stay stable.
- **Strict-superset classifier guarantee**: SC-8 + FR-22 + CON-7 require zero regressions on [M021](../../milestones/M021/index.md)'s 21 corpus entries. Every classifier change must preserve prior verdicts.
- **Two pre-resolved Open Questions remain**: #Q-5 (constitution-principle numerals) and #Q-6 (P01 empirical verdict for collapse condition) are owned by the planning agent; #Q-1 through #Q-4 were pre-resolved at spec-authoring time.
