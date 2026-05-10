---
schema_version: "1.0"
type: context-draft
milestone: "M030"
status: finalized
created_at: "2026-04-29"
finalized_at: "2026-04-29"
---

## Architectural Decisions

These decisions resolve the 8 conversus advisory findings (`#Q-A1`–`#Q-A8`) appended to `spec.md`'s Open Questions. Each decision is binding on plan-phase and triggers a corresponding spec amendment captured under "Spec Amendments Required" below. The conversus deliberation that produced these findings is at `specs/032-adaptive-model-selection/conversus/` (`red-advocate/disputes.md` + `arbiter/resolution.md`).

### D-A1 (CRITICAL, load-bearing) — Shadow mode is a classifier-calibration gate, not a model-equivalence gate (Option A)

**Decision**: Adopt **Option A**. Shadow mode is recharacterized as a classifier-calibration gate. FR-7 and FR-8 are rewritten so the shadow corpus measures classifier confidence and class-distribution stability, not cheaper-model equivalence. Live-routing flip rests on classifier calibration; quality regression is caught post-flip via three independent mechanisms already in scope: verifier-fail escalation (FR-10 / CON-5, ≤2 tier-jumps per task), per-class anomaly detection (FR-18 `model_routing_regression`), and the operator kill switch (CON-4).

**Rationale**: Option B (5% live canary on cheap model) was rejected on cost-vs-safety-gain grounds. Its operational implementation cost — a parallel real-dispatch path with stitched JSONL records and per-class verifier comparison — is disproportionate to the safety it adds beyond A's escalation + anomaly + kill-switch mesh. The first verifier-fail on a wrongly-routed mechanical task pays for itself with one tier-jump; FR-18 catches sustained class-level regression before milestone-scale damage. Option A also makes the Constitution Check Principle II claim honest: the spec stops claiming pre-flip empirical model-equivalence (which the spec as written cannot produce, per RISK-01/02 conceded by Blue) and instead claims pre-flip classifier-confidence calibration (which it can produce) plus post-flip empirical regression detection (which the existing FR-10/FR-18/CON-4 chain delivers). The Constitution Check section must be rewritten to reflect this two-layer story.

**Implications for downstream work**:
- `shadow-compare.sh` outputs `flip_recommendation` based on classifier-confidence stability + class-distribution coverage, not on cross-model verifier-pass-rate degradation.
- US-2 acceptance scenarios are rewritten to reflect calibration semantics (no "routed model versus actual model" pass-rate phrasing).
- Plan-phase must define the classifier-confidence stability metric concretely (suggested: rolling per-class confidence-score variance below a configured threshold, plus minimum coverage per class — see #Q-3 below for related cross-link).
- The post-flip safety story (escalation + anomaly + kill switch) becomes load-bearing for Principle II compliance and must be auditable end-to-end before flip.

### D-A2 (HIGH) — Live-routing flip activation is programmatically enforced

**Decision**: FR-9 is amended to specify a programmatically enforced flip gate. `dispatch-interface.sh` MUST invoke `shadow-compare.sh` before the first live-routed dispatch in any session where `model_routing.live: true`. If `shadow-compare.sh` returns `evidence_insufficient`, `dispatch-interface.sh` MUST refuse to proceed with live routing and write `override_source=shadow_gate_blocked` to JSONL. A negative SC accompanies the amendment: with `model_routing.live: true` and a corpus of 0 dispatches, dispatch refuses and writes the `shadow_gate_blocked` record before any adapter call.

**Rationale**: Closes RISK-03. Pure mechanical hardening; no design tradeoff.

### D-A3 (HIGH) — `partially_ready` flip path so M030 isn't permanently locked in shadow

**Decision**: FR-8's flip-readiness output adds a `partially_ready` verdict. Logic: if ≥2 of the 3 classes meet the per-class evidence threshold AND the under-threshold class's routing-table default is `smart` (i.e., no model downgrade would occur for that class under live routing), `shadow-compare.sh` returns `flip_recommendation=partially_ready` with an enumerated list of flippable classes. The operator may activate live routing for the ready classes; the under-threshold class continues to dispatch at its conservative default. JSONL records `partial_flip_active=true` and `withheld_classes=<list>` for dispatches in withheld classes. FR-9 gains a corresponding per-class flip-activation path.

**Rationale**: Closes RISK-04. Pre-launch dispatch volume across 7 milestones × 4-6 phases ≈ 28-42 dispatches; the `novel` class is structurally rare. Without `partially_ready`, the binary all-or-nothing flip permanently locks the routing layer in shadow regardless of evidence quality on the validated classes — defeating M030's launch value. Because the only safe partial-flip case is "the under-threshold class's default is already `smart`" (no downgrade), the partial flip is conservative by construction.

### D-A4 (HIGH, ARBITER-RULED) — SC-10 ground-truth corpus independence is a spec constraint, not a plan-phase question

**Decision**: SC-10 is amended to add the independence constraint quoted in the arbiter ruling. The fixture corpus MUST be drawn from pre-existing PLAN.md files in `specs/0NN-*/` with hand-applied labels recorded in a version-controlled fixture file. The fixture file's commit timestamp MUST precede the first commit of `classify-task.sh`. The labeling party MUST NOT have access to the classifier implementation at time of labeling; if the corpus is drawn from pre-M030 milestone history and labeled before implementation begins, this constraint is satisfied by construction. Q-1 (in the spec's Open Questions) is promoted from open question to spec constraint with the same wording: the corpus SHALL be drawn from pre-M030 `specs/0NN-*/` PLAN.md files, labeled against the FR-2 character definitions, and committed as a fixture file before `classify-task.sh` is authored. Plan-phase MUST confirm timeline compliance as a SC-10 verification prerequisite.

**Rationale**: Arbiter ruling (Phase 6, RISK-05) — an acceptance criterion whose mechanically checkable property rests on an unstated convention is incomplete per Principle II's mechanical-gate requirement, and a spec relying on implied constraints violates Principle III's uncertainty-surfacing requirement. Plan-phase delegation is insufficient for verification gates.

**Operationalization (P00)**: The corpus lives at `tests/fixtures/m030-classifier-corpus/labels.yml`; the methodology and D-A4 compliance audit live at `tests/fixtures/m030-classifier-corpus/README.md`. The mechanical proxy for the timeline constraint is `tools/verify/p00-d-a4-independence.sh` (absence-during-P00 check; graduates to git-log ordering check post-P01).

### D-A5 (MEDIUM) — Kill switch supersedes `min_tier`

**Decision**: CON-4 is amended to make the precedence explicit: when `model_routing_enabled: false` is active alongside an active `min_tier` setting, `override_source=disabled` is recorded in JSONL and a one-line stderr warning names the bypassed `min_tier` value (e.g., `model_routing_enabled=false: min_tier: smart is inactive`). SC-7 gains a compound test case: with both `model_routing_enabled: false` and `min_tier: smart` set, dispatch records `override_source=disabled` and stderr contains the bypass warning.

**Rationale**: Closes RISK-06. Resolves the latent CON-4 / US-4 AS-2 contradiction before runtimes diversify (today CC-only launch hides the divergence because the runtime default IS `smart`).

### D-A6 (MEDIUM) — `cost_rates:` section is named in `templates/model-routing.yml`

**Decision**: FR-3 is amended to require `templates/model-routing.yml` to include a `cost_rates:` section with per-symbolic-tier input/output token costs (per million tokens). `references/model-routing.md` documents the operator update obligation when provider pricing changes. SC-8 is extended to verify the savings line appears when `cost_rates` is defined, and that a documented fallback (warning + zero-savings line) appears when it is not.

**Rationale**: Closes RISK-08. The US-5 cost-counterfactual claim ("$0.42 vs $1.89 if all-smart") needs a named SSOT for the rates.

### D-A7 (MEDIUM) — Shadow corpus write-path correctness has a dedicated SC

**Decision**: Add SC-3a: for each record in the shadow-mode fixture corpus, `jq -r '.model_routed'` matches the stdout of `bash scripts/dispatch/classify-task.sh <plan-path>` run independently on the same plan, where `<plan-path>` is the plan referenced in the JSONL record.

**Rationale**: Closes RISK-09. CON-6 guarantees append-only/immutability but not initial-write correctness; SC-3a is the missing initial-write verification.

### D-A8 (MEDIUM) — `min_tier` is documented as distinct from partial-flip authorization

**Decision**: FR-12 gains a documentation note: `min_tier` is not a substitute for an unvalidated class in a partial flip — it routes unconditionally at the floor without engaging the shadow corpus or the flip-readiness check. Future planners reading conversus revision briefs (and Blue's THREAT-06 informal mitigation in particular) MUST NOT interpret `min_tier: smart` on the under-threshold class as a partial-flip mechanism.

**Rationale**: Closes RISK-10. Eliminates the spec-incompatible interpretation that survived the deliberation as an undefended attack surface.

### D-A9 (accepted-with-monitoring) — Anomaly JSONL snapshot convention documented in FR-2 prose

**Decision**: FR-2 prose is amended to document the consistency property: classifier output for the same PLAN.md is consistent within a single `orchestrator:auto` run because anomaly JSONL state is snapshotted at the start of each run (or, alternatively, the classifier reads anomaly JSONL once at startup rather than per-dispatch). If implementation chooses not to snapshot, FR-2 explicitly disclaims per-run consistency and notes that shadow-corpus records sharing a PLAN.md path but differing in `model_routed` are expected behavior, not corpus corruption. No SC change required; this is a documentation requirement.

**Rationale**: Closes RISK-07. The deliberation accepted this risk under monitoring; the binding form is "the spec must say one of two things", not silence.

## Scope Boundaries

**In scope (unchanged from spec)**: Task-character classifier (3-class taxonomy: mechanical / standard / novel), declarative routing table, dispatch-layer integration, escalation on verifier failure (cap 2), shadow-mode classifier-calibration validation, per-task and per-milestone overrides plus `min_tier` floor, kill switch, [M027](../../milestones/M027/index.md) surface integration (rollup `--by-model`, footer `model_mix:`, doctor `--config-check`), per-class anomaly detection.

**In scope (added by this discussion)**:
- Programmatic flip-gate enforcement in `dispatch-interface.sh` (D-A2).
- `partially_ready` flip verdict + per-class flip-activation path (D-A3).
- Pre-implementation fixture corpus + version-controlled fixture file (D-A4).
- Compound kill-switch-plus-floor SC (D-A5).
- `cost_rates:` section in `templates/model-routing.yml` (D-A6).
- SC-3a shadow-record correctness (D-A7).

**Out of scope (unchanged)**: NG-1 (multi-model deliberation per dispatch), NG-2 (per-step model selection), NG-3 (cross-provider cost optimization), NG-4 (auto-tuning routing table), NG-5 (Codex Cloud model selection), NG-6 (process-intensity selection), NG-7 (conversus deliberation model selection), NG-8 (constitutional principle for cost-sensitivity).

**Out of scope (decided in this discussion)**:
- **Option B (5% canary live cheap-model dispatch in shadow mode)** is rejected on cost-vs-safety-gain grounds (see D-A1). Implementation cost is disproportionate to the safety it adds beyond the existing escalation + anomaly + kill-switch mesh.
- **Pre-flip empirical model-equivalence validation** is rejected as a design goal. Pre-flip evidence is classifier calibration; cross-model equivalence is asserted post-flip via the regression-detection mesh, not pre-flip via empirical comparison.

## Design Constraints

- **CON-1 through CON-6 (existing)**: classifier-LLM-prohibition, additive-JSONL-schema, per-runtime symbolic resolution, kill-switch-always-available, escalation-hard-cap, shadow-corpus-immutability — all unchanged.
- **CON-4 (amended per D-A5)**: kill switch supersedes `min_tier` with documented stderr warning + JSONL `override_source=disabled`.
- **Pre-launch CC-only posture**: M030 ships against Claude Code only. Codex CLI / Cursor adapters resolve any symbolic tier to `inherit`; multi-runtime parity is M009 post-launch (per CLAUDE.md forward roadmap, demand-driven).
- **No M030 scope expansion beyond the 8 findings**: [M032](../../milestones/M032/index.md) just absorbed wiki-distribution scope; pre-launch work is growing. Plan-phase MUST resist adding work beyond what these decisions require. Specifically: no per-task LLM-driven re-classification, no auto-tuning of `cost_rates`, no second runtime adapter beyond CC.
- **Sequencing assumption**: [M028](../../milestones/M028/index.md) (autonomous hardening v3) ships before M030 — M028 stabilizes autonomous runs that M030's shadow corpus depends on for clean signal (A-5 in spec). Plan-phase MUST verify M028 closure before authoring P01.
- **Constitution Check rewrite is a hard plan-phase task**: D-A1 changes the Principle II claim materially. The Constitution Check section in the spec must be rewritten before plan-phase consumes it; the rewrite is captured as Spec Amendment 1 below.

## Open Questions

These questions are explicitly carried into plan-phase. Plan-phase resolves them; they do not block discuss-finalization.

- **#Q-1 (RESOLVED by D-A4 — promoted to spec constraint)**: Originally "fixture-source choice deferred to plan-phase". Now: fixture corpus drawn from pre-M030 `specs/0NN-*/` PLAN.md files, labeled before `classify-task.sh` is authored. Plan-phase MUST confirm timeline compliance.
- **#Q-2 (deferred — no change)**: shadow corpus storage shape (additive fields in `dispatch_usage` vs separate `.orchestrator/shadow-corpus.jsonl`). Recommendation stands: additive route in unified stream.
- **#Q-3 (deferred — augmented by D-A1)**: escalation-from-floor semantics (`balanced → smart` step-by-step vs skip directly to `smart`). Now augmented: plan-phase must also define the **classifier-confidence stability metric** that replaces the model-equivalence comparison in FR-8 (suggested: rolling per-class confidence-score variance below a configured threshold, plus minimum coverage per class).
- **#Q-4 (deferred — no change)**: anomaly threshold default for `model_routing_regression` — fixed pass-rate delta vs relative-to-baseline. Plan-phase decides with M027-team input.
- **#Q-5 (deferred — no change)**: kill-switch rollback grace — in-flight dispatches honor new state immediately or complete under prior state. Recommendation stands: complete under prior state.

## Spec Amendments Required (before plan-phase opens)

After this draft is finalized, `spec.md` MUST be amended to reflect the binding decisions before `orchestrator:plan-phase` is invoked. The amendments are:

1. **FR-7 + FR-8 + Constitution Check Principle II + US-2 AS-2/AS-3** — rewrite to reflect classifier-calibration semantics (D-A1). The Principle II claim shifts from "shadow mode produces empirical model-equivalence" to "shadow mode produces empirical classifier-confidence calibration; cross-model regression is detected post-flip via FR-10 escalation + FR-18 anomaly + CON-4 kill switch."
2. **FR-9** — add the programmatic enforcement clause (D-A2) plus a negative SC verifying `shadow_gate_blocked` JSONL on insufficient evidence.
3. **FR-8 + FR-9** — add `partially_ready` verdict + per-class flip-activation path + JSONL fields `partial_flip_active`, `withheld_classes` (D-A3).
4. **SC-10 + Q-1** — add the independence constraint quoted in the arbiter ruling; promote Q-1 from open question to spec constraint (D-A4).
5. **CON-4 + SC-7** — explicit kill-switch-supersedes-min_tier precedence + compound test case (D-A5).
6. **FR-3 + SC-8 + `references/model-routing.md`** — name the `cost_rates:` section + fallback semantics (D-A6).
7. **SC-3a (new)** — shadow-record write-path correctness (D-A7).
8. **FR-12 documentation note** — distinguish `min_tier` from partial-flip authorization (D-A8).
9. **FR-2 prose** — anomaly JSONL snapshot convention OR explicit per-run-consistency disclaimer (D-A9).

Spec amendment is a prose-and-logic exercise, not an architectural redesign — every change traces directly to a quoted finding or arbiter ruling. Once the amendments land, `orchestrator:plan-phase` consumes the amended spec.
