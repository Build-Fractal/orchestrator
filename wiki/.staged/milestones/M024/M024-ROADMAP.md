---
schema_version: "1.0"
type: roadmap
milestone: "M024"
feature_ref: "028-universal-intake-routing"
feature_spec: "specs/028-universal-intake-routing/spec.md"
vision: "Extend `orchestrator:evaluate` so any input shape — idea, paragraph, fragment, spec, or empty + Q&A — produces a single reviewable six-axis proposal that gates dispatch on Constitution III."
tier: "C"
created_at: "2026-04-25T17:26:30Z"
updated_at: "2026-04-25T17:26:30Z"
---

## Phases

- [x] **P01**: Foundation — input-shape detector + 6-axis proposal artifact schema — "On any input, `evaluate` emits `.orchestrator/intake/<id>/proposal.md` with all six axes populated and frontmatter passing the M014-manifest superset assertion."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces: `scripts/intake/shape-detect.sh`, `scripts/intake/proposal-emit.sh`, `scripts/intake/intake-id-allocate.sh`, `templates/intake-proposal.md`, `tests/test-intake-proposal-shape.sh`, `tests/test-intake-manifest-superset.sh`, `.orchestrator/intake/<id>/` directory layout (writes confined here per SB-3), six-axis frontmatter contract pinned at `schema_version: "1.0"` (AD-3)
    - Consumes: spec FR-1 / FR-2 / FR-11 / FR-13 / FR-15; AD-2 counter-allocation; AD-3 schema-version pin; DC-5 strict-superset commitment; [M020](../../milestones/M020/index.md) knowledge-query surface for FR-13 evidence citations; [M014](../../milestones/M014/index.md) interim-manifest key set for the superset assertion

- [x] **P02**: Spec-path backward compat + M014→M024 manifest read direction — "Running `evaluate <existing-spec-path>` produces both the legacy evaluation output (byte-compatible) AND a `proposal.md` with `input_shape: spec`; an M014 interim manifest reads identically."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces: `scripts/intake/spec-shape-classify.sh` (input_shape=spec branch), `scripts/intake/m014-manifest-read.sh` (M014 → M024 handshake reader), `tests/test-evaluate-spec-backcompat.sh` (byte-compat regression vs pre-M024 baseline fixture), `tests/test-m014-manifest-read.sh`, captured baseline fixture at `tests/fixtures/evaluate-pre-m024-baseline.txt`
    - Consumes: P01 proposal schema (`templates/intake-proposal.md`), P01 `proposal-emit.sh`, P01 strict-superset assertion; existing `commands/evaluate.md` chunks-first/raw-spec metric paths (consumed read-only — no behavior change to legacy path); M014 interim-manifest schema (per AD-4 handshake direction `a`)

- [x] **P03**: Paragraph intake + approval gate + M024→M014 route to specify — "An operator pasting a paragraph gets a proposal plus an approve/revise/cancel prompt; `approve` invokes the recommended downstream command (`orchestrator:specify` for non-trivial paragraphs, `dispatch` for trivial)."
  - Risk: high
  - Depends: P01
  - Boundary Map:
    - Produces: `scripts/intake/paragraph-classify.sh` (input_shape=paragraph branch), `scripts/intake/approval-gate.sh` (writes `approved_at` / `cancelled_at` / `pending_approval` to proposal frontmatter), `scripts/intake/route-to-specify.sh` (M024 → M014 handshake — non-trivial paragraph routes to `orchestrator:specify`), `scripts/intake/route-to-dispatch.sh` (trivial inputs route directly), updates to `commands/evaluate.md` covering all five input shapes, `tests/test-paragraph-intake.sh`, `tests/test-approval-gate.sh`
    - Consumes: P01 proposal schema, P01 emitter, P01 `intake-id-allocate.sh`, P01 frontmatter contract; M014/extended `commands/specify.md` three-pass entry point (the M024→M014 handoff target — read-only consumption per AD-4 direction `b`)

- [x] **P04**: Fast-path auto-proceed — "A four-condition-eligible proposal (Tier A + Quick + no-conversus + no-design) auto-proceeds to dispatch with `auto_proceeded: true` recorded; any condition-violation halts at the approval prompt."
  - Risk: medium
  - Depends: P01, P03
  - Boundary Map:
    - Produces: four-condition check function in `scripts/intake/approval-gate.sh` (extends, does not replace P03's gate), `evaluate.auto_proceed` config key in `templates/config.yml` defaulting to `true` (AD-1: project-config-only knob, no CLI flag), updates to `scripts/state/read-config.sh` to expose the new key, `tests/test-fast-path-auto-proceed.sh`, `tests/test-fast-path-condition-violation.sh`
    - Consumes: P01 proposal schema (axes drive condition check), P03 approval-gate (the bypass path); existing `scripts/state/read-config.sh` valid-keys list; spec FR-3, NG-6 (no auto-bypass beyond degenerate path)

- [x] **P05**: Empty input + bounded Q&A — "`evaluate` with no argument runs at most 5 Q&A turns and emits a proposal with `input_shape: empty_qa`, the transcript embedded under `## Q&A`, and `low_confidence: true` flag if short-circuited."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces: `scripts/intake/qa-loop.sh` (≤5 turns; `enough` short-circuit; transcript captured), `templates/intake-qa-questions.md` (static template per the plan-phase resolution of #Q-3 — first cut), Q&A transcript embedding rule for proposal body, `tests/test-empty-qa-loop.sh`, `tests/test-qa-short-circuit.sh`
    - Consumes: P01 proposal schema (`input_shape=empty_qa` branch + transcript section), P01 emitter; spec FR-5, #Q-3 (plan-phase decides static-template first; conversus-loop deferred unless dogfood demands)

- [x] **P06**: Revision flow — "`revise tier=C` on an existing proposal re-emits with the override applied, dependent axes re-derived, and preserves the prior version as `proposal-v1.md`."
  - Risk: low
  - Depends: P01, P03
  - Boundary Map:
    - Produces: `scripts/intake/revise.sh` (axis override + version-suffix scheme `proposal-v<N>.md`), `scripts/intake/axis-rederive.sh` (recomputes dependent axes when one is overridden), validation rule for unsupported-axis errors, `tests/test-revision-flow.sh`, `tests/test-revision-version-preservation.sh`
    - Consumes: P01 proposal schema, P01 emitter, P03 approval-gate (revision re-prompts after re-emit); spec FR-12, #Q-6 (plan-phase confirms in-place mutation + version-suffix scheme)

- [x] **P07**: Pre-M023 design-gate graceful degradation — "On a pre-M023 checkout, a design-gated proposal emits the exact byte-pinned message and offers `manual` / `skip` branches; both record their disposition in proposal frontmatter."
  - Risk: low
  - Depends: P01, P03
  - Boundary Map:
    - Produces: `scripts/intake/design-gate-degradation.sh` (M023-shipped probe + branch logic), pinned graceful-degradation string `"design walkthrough lands in M023; author DESIGN.md manually or skip"` (FR-7 byte-stable for grep), `manual` / `skip` branch handlers, `design_skipped` / `design_authored_manually` frontmatter flags, `tests/test-design-gate-degradation.sh` (asserts exact string via `grep -F`), `tests/test-design-gate-skip.sh`, `tests/test-design-gate-manual.sh`
    - Consumes: P01 proposal schema, P03 approval-gate; spec FR-7, US-6, AD-5 (M023 not shipped at plan-phase entry per A5)

## Cross-Cutting Concerns

- **M020 query surface readiness** — All phases. SB-1 commits to a hard pre-flight on M020 stability before each phase dispatches; the readiness check rule (`scripts/knowledge/query.sh --topic <test>` exits 0, plus the six previously-missing files committed and non-empty) is one of the resolutions plan-phase produces for #DQ-1. P01 establishes the verification step; P02–P07 inherit it as a precondition.
- **M014/extended shipping status** — P02 (M014 → M024 read), P03 (M024 → M014 route to specify). #DQ-2 is unresolved at plan-phase entry: plan-phase MUST verify M014/extended has shipped (`commands/specify.md` three-pass contract live + `scripts/specify/specify.sh` shell impl per D019 (5)) before P02 or P03 dispatch. If M014/extended has not shipped, P02 and P03 either block or carry a clearly-marked "M014 not yet shipped" stub on the handshake direction (per #DQ-2 option `b`). P01, P04, P05, P06, P07 are unaffected — they do not exercise the handshake.
- **D017 manifest-superset assertion (DC-5)** — P01 establishes the assertion (`tests/test-intake-manifest-superset.sh`); P02/P03/P04/P05/P06/P07 each include the assertion in their phase verify-step. Drift on either side breaks the M014↔M024 handshake; the assertion is the canary.
- **D019 universal TODO pre-flight discipline (DC-3)** — All phases that emit proposal body text. P01 builds proposal-emit with no `<TODO:` markers in the authored sections (axis rationale text). P02/P03/P05/P06/P07 must produce TODO-free body content before any conversus-gate invocation. The adapter at `scripts/dispatch/adapters/tool/conversus.sh:150-169` is the universal enforcer per D019.
- **Constitution III audit trail (DC-4)** — P03 establishes the approval-gate frontmatter contract (`approved_at` / `cancelled_at` / `pending_approval`); P04 extends with `auto_proceeded` / `proceeded_at`; P06 extends with `revised_at` / version history; P07 extends with `design_skipped` / `design_authored_manually`. The invariant: every dispatch is provably preceded by either operator approval or the four-condition fast-path; plan-phase encodes this as a verification check.
- **Runtime portability (DC-1)** — All phases. POSIX sh + bash 3.2+ floor; any CC-specific assumption logged to `RUNTIME-ASSUMPTIONS.md` per D016 (7). Bash 4+ features are rejected unless plan-phase demonstrates no portable alternative.
- **M011/P07 conversus adapter consumed read-only (DC-2)** — P01 (conversus-gate axis decision wires up the adapter call), any subsequent phase that invokes the gate. Adapter at `scripts/dispatch/adapters/tool/conversus.sh` is consumed read-only — M024 adds a caller, never a new code path. Inherits the M026/D022 OSS-edition diagnostic shape and the 0/1/2 exit-code contract.
- **`schema_version: "1.0"` aligned with spec frontmatter (AD-3)** — P01 pins; P02–P07 conform. Any divergence breaks DC-5 superset and FR-15 handshake simultaneously.

## Dependency Graph

```
                        ┌──→ P02 (spec-path backcompat + M014 read)
                        │
P01 (foundation) ───────┼──→ P03 (paragraph + approval + route-to-specify) ──┬──→ P04 (fast-path)
                        │                                                     │
                        └──→ P05 (empty + Q&A)                                ├──→ P06 (revision)
                                                                              │
                                                                              └──→ P07 (design degradation)
```

P01 is the universal upstream. P02 / P03 / P05 fan out from P01 (no inter-dependencies among them). P04 / P06 / P07 fan out from P03 (each adds an orthogonal capability on top of the approval gate). The graph is a DAG with two fan-out tiers.

## Execution Order

1. **Wave 1 — P01** (high risk, no dependencies): foundation must land first. Schema choices made here are forward-binding for every other phase; D017 superset assertion built here is the canary that protects every downstream phase.
2. **Wave 2 — P03 (high), P02 (medium), P05 (medium)** can execute concurrently — all three depend only on P01 and have no inter-dependencies. P03 is the highest-risk in this wave (headline UX + approval-gate semantics + M024→M014 handoff) and should be the autonomous-dispatch priority pick when both P03 and P02 are eligible. P05's `static-template-first` posture (#Q-3 plan-phase resolution) keeps its risk bounded; if conversus-loop becomes necessary, that scope expansion is reviewed before P05 dispatch.
3. **Wave 3 — P04 (medium), P06 (low), P07 (low)** can execute concurrently — all three depend on P01 + P03 with no inter-dependencies. P04 (fast-path) is the load-bearing closer of the spec's Minimal Slice (US-1 + US-2 + US-3 are operationally complete only after P04). P06 and P07 are post-Minimal-Slice ergonomic wins.

**Minimal Slice closure**: P01 + P02 + P03 + P04 (spec's `## Minimal Slice` declaration). After Wave 3 P04, the dogfood loop closes — paragraph intake, spec backward-compat, and fast-path all work end-to-end. P05 / P06 / P07 ride on subsequent dispatch waves.

**Concurrency hint for `orchestrator:auto`**: M020's query surface and the `intake/` directory writes are the only shared mutable state across waves. Wave-2 and Wave-3 fan-outs are otherwise file-disjoint and can dispatch in parallel without serialization beyond P01.

## Validation

- **No conflicting producers**: PASS — every produced artifact is owned by exactly one phase. `scripts/intake/approval-gate.sh` is created by P03; P04 *extends* it (adds the four-condition function inside the same file) but does not redeclare ownership — plan-phase will encode the extension as an in-file edit, not a re-create. No two phases produce the same file.
- **All consumed items have producers**: PASS — every `Consumes` entry maps to either an upstream phase's `Produces` (P02→P01 schema; P03→P01 schema; P04→P01+P03; P05→P01; P06→P01+P03; P07→P01+P03) or to a stable external dependency declared upstream (M020 query surface, M014 interim-manifest schema, M011/P07 conversus adapter, existing `read-config.sh`, existing `commands/evaluate.md`). External consumes are gated by the M020 / M014 readiness pre-flights tracked in Cross-Cutting Concerns.
- **DAG is acyclic**: PASS — verified by inspection of the dependency graph above. Two fan-out tiers (Wave-1→Wave-2 and Wave-2-P03→Wave-3) with no back-edges. No phase depends on a downstream phase.
- **Demo sentence coverage**: PASS — every phase has a concrete observable demo sentence naming the artifact and the operator-visible behavior. Each demo sentence ties to a specific Success Criterion in the spec (P01 → SC-7; P02 → SC-4 + SC-8; P03 → SC-2; P04 → SC-1; P05 → SC-3; P06 → byte-stability of `proposal-v<N>.md`; P07 → SC-5).
