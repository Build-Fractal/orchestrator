---
schema_version: "1.0"
type: evaluation
milestone: "M014"
feature_ref: "024-spec-management-extended"
feature_spec: "specs/024-spec-management-extended/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-22T15:50:38Z"
---

# M014 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: speckit.orchestrator.discuss

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 5 |
| Acceptance scenarios | 33 |
| Functional requirements | 20 |
| Estimated SDD flows | 4 |

## Reasoning

The M014 Spec Management Extended spec (`specs/024-spec-management-extended/spec.md`) bundles four clusters of work — native `orchestrator:specify` (US-2), conversus auto-propose for complex specs (US-3), `AGENTS.md` dual-write parity (US-4), and wiki+GitHub comment→workflow classification (US-1, US-5) — across 5 user stories, 33 acceptance scenarios, 20 FRs, 19 SCs, and a pre-scoped 4-phase execution table. Each of the four clusters is its own SDD flow (specify→clarify→plan→tasks→implement) with distinct boundaries, distinct verify surfaces, and a cross-phase ordering contract (P1 US-2+minimal US-4 is load-bearing for every downstream spec; P2 extends dual-write + ships drift detector; P3 depends on M013/P04 closure for GitHub Issue comment fetch; P4 adds conversus auto-propose + closes remaining SCs). Roadmap decomposition + cross-phase coordination + external milestone dependencies (M011/P07 conversus adapter, [M012](../../milestones/M012/index.md) wiki-giscus-remap, M013/P04 UAT ingestion path) place this squarely in Tier C — the same shape as [M013](../../milestones/M013/index.md) (which also ran Tier C with pre-discuss conversus pressure-test and multi-phase dependency graph).

## Complexity Factors

- **Bundled multi-cluster scope**: Four distinct user-facing surfaces (spec authoring, conversus gating, runtime-instruction dual-write, comment classification) share substrate but have independent verify contracts. Roadmap will decompose into ≥4 phases.
- **Load-bearing dogfood**: P1 (US-2 `orchestrator:specify`) is the authoring surface every subsequent orchestrator-authored spec consumes; P1 exit criteria gate M013→[M024](../../milestones/M024/index.md)→[M020](../../milestones/M020/index.md) future-spec authorship (SC-13). Cross-milestone dependency.
- **External milestone dependencies**: P3 comment-classifier consumes M013/P04's post-verify sync cycle + UAT comment surface — hard sequencing gate (P3 cannot start before M013/P04 closes). Conversus integration via the M011/P07 reusable adapter (shipped).
- **Human-gated spec mutation (Constitution XV)**: FR for spec-amendment auto-apply is explicitly human-gated — adds a review-queue surface (`.orchestrator/comments/review-queue/`) with approve/reject commands.
- **Runtime posture (CC-first v1)**: Dual-write surface must emit both `CLAUDE.md` and `AGENTS.md` for Codex parity even though `orchestrator:specify` is CC-first for v1 (Codex/Cursor parity is fast-follow via M009 runtime-parity audit).
- **Pre-discuss conversus already applied**: 14 MITs + arbitrated rulings from `specs/024-*/conversus/summary/final.md` are baked into the spec (Status: Ready-for-discuss). Discussion can focus on planning-shape decisions (phase sequencing, complexity thresholds for FR-5 probe, classifier-scope sizing heuristics) rather than re-litigating scope.
- **Threshold and heuristic ambiguity**: US-3 conversus auto-propose threshold, FR-5 complexity probe signal set, and FR-9 classifier class boundary are explicit open questions for planning — discussion gate adds value here.
