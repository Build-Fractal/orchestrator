---
schema_version: "1.0"
type: roadmap
milestone: "M030"
feature_ref: "032-adaptive-model-selection"
feature_spec: "specs/032-adaptive-model-selection/spec.md"
vision: "Task-character classifier routes each dispatch to the cheapest single model that can do the job correctly, with a two-layer safety story: pre-flip classifier-calibration evidence and post-flip regression-detection mesh (escalation + anomaly + kill switch)."
tier: "C"
created_at: "2026-04-29"
updated_at: "2026-04-29"
---

## Phases

- [x] **P00**: Fixture corpus + ground-truth labels — "A version-controlled fixture file at `tests/fixtures/m030-classifier-corpus/labels.yml` lists ≥30 PLAN.md files drawn from `specs/0NN-*/` with hand-applied character labels, committed BEFORE any P01 work begins."
  - Risk: medium
  - Depends: none
  - Boundary Map:
    - Produces: `tests/fixtures/m030-classifier-corpus/labels.yml` (version-controlled fixture file with ≥30 hand-labeled pre-M030 PLAN.md references); `tests/fixtures/m030-classifier-corpus/README.md` (labeling methodology + independence-constraint compliance per D-A4)
    - Consumes: nothing (foundational; the labeling MUST happen before `classify-task.sh` is authored to satisfy SC-10's mechanical independence constraint)

- [x] **P01**: Classifier + routing table + cost_rates — "Running `bash scripts/dispatch/classify-task.sh <plan-path>` against any P00 fixture plan emits deterministic `character=` + `confidence=` lines in <100ms with no network calls; `templates/model-routing.yml` declares the routing + cost_rates SSOT and `bash scripts/diagnostics/doctor.sh --config-check` validates its closure."
  - Risk: high
  - Depends: P00
  - Boundary Map:
    - Produces: `scripts/dispatch/classify-task.sh` (classifier interface, FR-1/FR-2); `templates/model-routing.yml` (routing table + per-runtime resolution table + `cost_rates:` section, FR-3/D-A6/CON-3); `references/model-routing.md` (operator docs + aggressive overlay + cost_rates update obligation); classifier-confidence stability metric definition (resolves spec #Q-3 — rolling variance threshold + minimum class-coverage count, consumed by P02's shadow-compare)
    - Consumes: P00 fixture corpus (for SC-1/SC-10 verification)

- [x] **P02**: Dispatch integration + shadow-mode JSONL + shadow-compare — "Running 50+ dispatches in `M030_SHADOW_MODE=1` produces `dispatch_usage` JSONL records with `model_routed` + `model_used` fields; `bash scripts/diagnostics/shadow-compare.sh` aggregates the corpus and emits a 4-verdict `flip_recommendation=ready|partially_ready|block|evidence_insufficient` line; SC-3a passes (every shadow record's `model_routed` matches an independent classifier run on the same plan)."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: amended `scripts/dispatch/dispatch-interface.sh` (classifier invocation hook + shadow-mode JSONL recording, FR-5/FR-7); `scripts/diagnostics/shadow-compare.sh` (4-verdict output + classifier-confidence stability check + `partial_flip` enumeration, FR-8/D-A1/D-A3); JSONL schema additions: `model_routed`, `model_used`, `partial_flip_active`, `withheld_classes` (FR-19 additive)
    - Consumes: P01 classifier (`classify-task.sh`); P01 routing table (`templates/model-routing.yml`); P01 stability metric definition

- [x] **P03**: Operator overrides + kill switch — "Three fixture plans dispatched against `.orchestrator/config.yml` variants (`model_override: smart` in plan frontmatter, `min_tier: smart` in milestone config, `model_routing_enabled: false`) each emit JSONL with the correct `override_source` value; SC-7a's compound (kill-switch + min_tier) test passes — kill switch wins, stderr names the bypassed `min_tier`."
  - Risk: medium
  - Depends: P02
  - Boundary Map:
    - Produces: amended `dispatch-interface.sh` override-resolution path (FR-4/FR-11/FR-12/FR-13/FR-14); CON-4-amended kill-switch precedence semantics (D-A5); JSONL schema additions: `override_source` (with values `plan_frontmatter|milestone_floor|disabled|shadow_gate_blocked`); `.orchestrator/config.yml` `model_routing:` block schema (documented in `references/model-routing.md`)
    - Consumes: P02 dispatch-interface hook points; P02 JSONL schema

- [x] **P04**: Live routing + verifier-fail escalation + flip-gate enforcement — "With `model_routing.live: true` set and a fixture corpus passing the flip-readiness check, dispatching a `mechanical`-classified plan results in `model_used=<fast-tier-id>`. With `live: true` and corpus=0, `dispatch-interface.sh` refuses to call any adapter and writes `override_source=shadow_gate_blocked`. A plan engineered to fail verifier twice then pass produces three records with `model_used` sequence `<fast> <balanced> <smart>`; the third carries `escalation_count=2`. A plan engineered to fail verifier three times produces exactly three records (no fourth) plus an `escalation_cap_hit` record."
  - Risk: high
  - Depends: P02, P03
  - Boundary Map:
    - Produces: amended `dispatch-interface.sh` live-routing branch (FR-9 with programmatic shadow-compare invocation per D-A2; per-class partial-flip authorization per D-A3); amended `dispatch-interface.sh` escalation logic (FR-10 with CON-5 hard-cap); JSONL schema additions: `escalation_count`, `escalation_reason`, `shadow_gate_blocked` verdict; `escalation_cap_hit` JSONL record type
    - Consumes: P02 shadow-compare verdicts; P02 dispatch-interface; P03 kill switch (must exist before live flip is operationally safe); P03 override_source schema

- [x] **P05**: M027 surface integration — "Running `bash scripts/diagnostics/metrics-rollup.sh --by-model` against a corpus of 10+ live-routed dispatches outputs per-tier dispatch counts + an aggregated cost line + an all-`smart` counterfactual line (when `cost_rates:` is defined) or a 'cost rates not configured' warning + zero-savings line (when absent). The efficiency-footer renders a `model_mix:` line at the close of an `orchestrator:auto` run. `bash scripts/diagnostics/doctor.sh --config-check` exits 1 with file+line on a malformed `templates/model-routing.yml`. SC-11 passes (pre-M030 JSONL fixtures produce byte-identical output through unflagged `metrics-rollup.sh` and `efficiency-footer.sh`)."
  - Risk: low
  - Depends: P02
  - Boundary Map:
    - Produces: amended `scripts/diagnostics/metrics-rollup.sh` (`--by-model` flag, FR-15/SC-8); amended `scripts/diagnostics/efficiency-footer.sh` (`model_mix:` line, FR-16); amended `scripts/diagnostics/doctor.sh` (`--config-check` flag for routing-table syntax, FR-17/SC-9); `references/observability.md` schema documentation update (FR-19/CON-5 additive verification)
    - Consumes: P02 JSONL schema (`model_routed`, `model_used`); P01 `cost_rates:` SSOT; P01 routing-table syntax conventions

- [ ] **P06**: Anomaly-driven regression detection — "Synthesizing 20 fixture dispatches per class with engineered verifier-fail rates and running `bash scripts/diagnostics/check-anomalies.sh` produces a `model_routing_regression` anomaly record when a class crosses the configured threshold; the anomaly surfaces through `orchestrator:doctor` per existing M027 conventions; existing anomaly checks are byte-identical when the new records are absent."
  - Risk: low
  - Depends: P02, P04
  - Boundary Map:
    - Produces: amended `scripts/diagnostics/check-anomalies.sh` (rolling-window per-class verifier-fail check, FR-18); JSONL anomaly record type `model_routing_regression` with `class=` + threshold-crossing metadata; `references/observability.md` documentation of the new anomaly record
    - Consumes: P02 JSONL schema (`model_used`, dispatch records); P04 escalation/verifier-fail records (live mode required to produce the signal at scale)

- [ ] **P07**: End-to-end shadow-corpus + flip-gate validation — "Synthesizing a fixture corpus of 50 records per class plus a 0-record corpus plus a 2-class-only corpus exercises all four `shadow-compare.sh` verdicts (`ready`, `partially_ready`, `block`, `evidence_insufficient`); SC-2 + SC-2a + SC-3a all pass; the partially_ready path correctly enumerates flippable classes and JSONL records carry `partial_flip_active=true` + `withheld_classes=<list>`; `metrics-rollup.sh --by-model` and the efficiency-footer produce coherent output across the full corpus; the M030 acceptance battery (all SCs from spec.md) runs to green."
  - Risk: medium
  - Depends: P02, P03, P04, P05, P06
  - Boundary Map:
    - Produces: `tests/m030-acceptance/shadow-corpus-fixtures.sh` (corpus synthesizer, idempotent); `tests/m030-acceptance/run-acceptance-battery.sh` (end-to-end SC runner: SC-1 through SC-11 inclusive of SC-2a/SC-3a/SC-7a); `.orchestrator/milestones/M030/M030-ACCEPTANCE-EVIDENCE.md` (one-shot evidence ledger of the green run, used by milestone validate)
    - Consumes: every M030 deliverable (P00 fixture corpus, P01 classifier + routing table, P02 dispatch + shadow-compare, P03 overrides + kill switch, P04 live routing + escalation, P05 surfaces, P06 anomaly check)

## Cross-Cutting Concerns

- **Additive JSONL schema (CON-2/FR-19/SC-11)** — affects P02, P03, P04, P05, P06. P02 establishes the additive-only pattern with `model_routed`/`model_used`; subsequent phases (P03's `override_source`, P04's `escalation_count`/`escalation_reason`/`shadow_gate_blocked`, P06's `model_routing_regression`) must each verify SC-11 byte-equality on pre-M030 fixtures before merge. Plan-phase for each consuming phase MUST include SC-11 in its verifier set.
- **Symbolic-tier closure (CON-3)** — affects P01, P02, P03, P04. P01 establishes the routing-table interface (symbolic names only); P02-P04 MUST resolve through the per-runtime resolution table at the adapter boundary, never hardcode model IDs. Plan-phase for P02/P03/P04 MUST grep for hardcoded model IDs in the diff as a pre-merge check.
- **Append-only shadow corpus (CON-6)** — affects P02, P04. P02 establishes the write path; P04's escalation logic MUST NOT retroactively rewrite prior records — escalation produces NEW records with new timestamps. Plan-phase for P04 MUST include a verifier that prior records remain bit-identical after escalation runs.
- **Kill-switch precedence (CON-4 amended per D-A5)** — affects P03, P04. P03 establishes that `model_routing_enabled: false` supersedes `min_tier` and emits the bypass warning; P04's live-routing branch MUST short-circuit at the same kill-switch check before invoking the flip-gate or escalation logic. Plan-phase for P04 MUST verify SC-7a-style compound test cases pass.
- **Pre-implementation fixture corpus independence (D-A4/SC-10)** — affects P00, P01. P00's commit timestamp MUST precede P01's first commit of `classify-task.sh`. Plan-phase for P01 MUST confirm timeline compliance as a SC-10 verification prerequisite (gates the phase from starting until `git log` shows the P00 fixture commit landed).
- **CC-only launch posture** — affects P02, P04, P06. Codex CLI / Cursor adapters resolve to `inherit` for any symbolic tier (per FR-6). Plan-phase MUST NOT add Codex or Cursor adapter logic beyond the existing `inherit` fallback; multi-runtime parity is M009 post-launch.
- **Classifier-confidence stability metric definition** — affects P01, P02. P01 owns defining the metric (rolling variance threshold + minimum class-coverage count) since it owns the classifier; P02 consumes the definition in `shadow-compare.sh`. The two phases MUST agree on the metric's exact form before P02 starts; any deferral is a P01 plan-phase blocker.

## Dependency Graph

```
P00 ──→ P01 ──→ P02 ──┬──→ P03 ──→ P04 ──┬──→ P06 ──→ P07
                      │                  │
                      ├──→ P05 ──────────┴───────────→ │
                      │                                │
                      └────────────────────────────────┘
```

Edges:
- `P00 → P01` — fixture corpus must commit before classifier (D-A4)
- `P01 → P02` — classifier + routing-table feed dispatch integration
- `P02 → P03` — overrides extend dispatch-interface hook points
- `P02 → P05` — M027 surfaces consume the JSONL schema
- `P03 → P04` — kill switch must exist before live flip ships
- `P02 → P04` — live routing reads shadow-compare verdicts
- `P02 → P06` — anomaly check reads JSONL dispatch records
- `P04 → P06` — live routing produces the verifier-fail-rate signal anomaly check operates on
- `{P02, P03, P04, P05, P06} → P07` — E2E validation consumes every deliverable

## Execution Order

1. **P00** — foundation, no dependencies. Hard prerequisite by SC-10 timestamp constraint.
2. **P01** — classifier + routing table. High-risk core primitive; ships only after P00 is committed.
3. **P02** — dispatch integration + shadow-mode JSONL + shadow-compare. High-risk; the load-bearing hook into dispatch and the SSOT for the shadow corpus.
4. **P03 and P05 can execute concurrently** — both depend only on P02. P03 is medium-risk (overrides + kill switch); P05 is low-risk (additive M027 surfaces). Concurrency wins ~1 phase of wall time if dispatched in parallel. (P05 produces no new state P03 reads, and vice versa.)
5. **P04** — live routing + escalation + flip-gate enforcement. High-risk; depends on P02 (shadow-compare) AND P03 (kill switch as panic button). Cannot start until P03 closes.
6. **P06** — anomaly-driven regression detection. Low-risk; depends on P02 (JSONL schema) AND P04 (live verifier-fail signal).
7. **P07** — end-to-end shadow-corpus + flip-gate validation + M030 acceptance battery. Medium-risk; depends on every prior phase. Milestone-close gate.

For `orchestrator:auto`: schedule P03 and P05 in parallel after P02's SUMMARY lands. P04 starts when both P03 and P05 are complete (P05's completion is not strictly needed for P04, but the auto scheduler treats sibling phases as a wave). P06 follows P04. P07 follows everything.

## Validation

- **No conflicting producers**: PASS. Each phase produces a disjoint set of files/interfaces — `classify-task.sh` (P01), `model-routing.yml` (P01), `dispatch-interface.sh` is amended additively across P02/P03/P04 (each phase adds non-overlapping branches: shadow-record write in P02, override resolution in P03, live-routing+escalation in P04 — plan-phase will define exact section boundaries within the file), `shadow-compare.sh` (P02), `metrics-rollup.sh`/`efficiency-footer.sh`/`doctor.sh` (P05), `check-anomalies.sh` (P06), test-fixture scripts (P07). The `references/model-routing.md` and `references/observability.md` docs are written-once-by-P01-then-extended pattern; plan-phase for each consuming phase MUST mark its documentation additions as additive.
- **All consumed items have producers**: PASS. Every Consumes entry resolves to a Produces entry in an upstream phase. P00 has no Consumes (foundation); P01 consumes P00; P02 consumes P01; P03/P04/P05/P06 consume P02 (and P04 also P03; P06 also P04); P07 consumes all.
- **DAG is acyclic**: PASS. The graph is a strict partial order rooted at P00, terminating at P07. No back-edges.
- **Demo sentence coverage**: PASS. Each phase has a concrete, testable demo sentence naming a specific script invocation, fixture corpus, or JSONL field that an operator can mechanically verify.
