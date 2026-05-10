---
schema_version: "1.0"
type: evaluation
milestone: "M027"
feature_ref: "029-m019b-cost-rollup-tier2"
feature_spec: "specs/029-m019b-cost-rollup-tier2/spec.md"
tier: "C"
tier_source: "auto"
created_at: "2026-04-26T00:00:00Z"
metrics_source: "raw_spec"
lineage: "M019 Tier 2 / 'M019b' follow-on (label preserved in slug)"
---

# M027 Evaluation

## Classification

- **Tier**: C
- **Source**: auto
- **Next command**: `orchestrator:discuss` (Tier C requires finalized context draft before roadmap)

## Metrics

| Metric | Count |
|--------|-------|
| User stories | 5 |
| Acceptance scenarios | 25 |
| Functional requirements | 24 |
| Success criteria | 19 |
| Estimated SDD flows | 3–4 |

(Counts reflect the 2026-04-26 amend that pinned context-draft AD-1/2/3 into the spec body and added US-5 / FR-16 through FR-24 / SC-13 through SC-19 covering the predictive cost surface.)

## Reasoning

M027 (lineage: M019b) extends the [M019](../../milestones/M019/index.md) Tier 1 emitter with four additive surfaces: a rollup engine (US-1), a user-facing `orchestrator:cost` command (US-2), an opt-in `orchestrator:status` efficiency footer (US-3), and an `orchestrator:doctor` anomaly check (US-4). Each surface ships a non-trivial unit of work: US-1 is the engine that everything else consumes; US-2 wires the engine to a runtime-portable command surface; US-3 hooks an existing command without breaking byte-identity for `--quiet` callers; US-4 adds a baseline-driven anomaly detector with sample-floor logic.

The 15 functional requirements span four cooperating but separable surfaces with cross-cutting verification (FR-15 verifier covering FR-3, FR-4, FR-6, FR-7, FR-12). The minimal slice (US-1 + US-2) is itself two coordinated phases — engine first, command on top — and US-3 / US-4 ride in subsequent phases each. That puts this milestone at 2–3 SDD flows rather than one inline.

Additionally, the advisory red-blue conversus gate (Standard intensity, run 2026-04-26) returned **BLOCK** with three P0 mitigations and folded six new Open Questions into the spec (#Q-6 through #Q-13). Tier C's mandatory `orchestrator:discuss` gate is the natural place to resolve those before roadmap fires.

This is squarely Tier C: roadmap decomposition is required, autonomous dispatch is warranted across phases, conversus findings need a discuss-driven resolution path, and the cross-phase verifier (FR-15) plus engine-then-consumer ordering need explicit phase dependencies.

## Complexity Factors

- **Multi-surface engine + consumer pattern**: One engine (US-1) feeds three independent consumers (US-2 command, US-3 footer, US-4 anomaly check). Each consumer requires its own phase to keep verification scope tight.
- **Runtime portability for the new command**: `orchestrator:cost` must register cleanly on Claude Code, Codex CLI, and Cursor via the existing packaging adapters from [M015](../../milestones/M015/index.md) + [M025](../../milestones/M025/index.md). The command is new but the adapter surface is established; still warrants its own dispatch.
- **Goodhart pairing at output surface (CON-4)**: A new contract — every cost column must carry a quality column on the same row — that the verifier (FR-15) enforces. New verifier surface = its own dispatch.
- **Back-compat byte-identity (CON-3)**: `orchestrator:status --quiet` must remain byte-identical to pre-M027 output. Mirrors the M019 SC-6 pattern (zero-token instrumentation) and requires a regression gate.
- **Conversus advisory BLOCK with 8 deferred-to-discuss findings (#Q-6 through #Q-13)**: Three P0 mitigations (evidence-before-claims pattern, aggregation semantics pin, performance bounds), one P1 (FS race conditions), four P2/advisory (anomaly baseline, mixed-source UX, doctor config-check, input schema validation). All routed to `orchestrator:discuss` before roadmap.
- **Read-only invariant across new code paths (CON-1, FR-12)**: Every M027 surface is a read-only consumer of `execution-log.jsonl`. SC-9 enforces via `git diff --quiet` post-fixture. Cross-phase verification, not single-phase.
- **bash 3.2 + never-abort (CON-5, CON-7, SC-11)**: Standard for this project; mirrors M019.
