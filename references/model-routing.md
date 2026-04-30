# Adaptive Model Routing — Operator Reference

This document is the operator-facing reference for `templates/model-routing.yml`,
the M030 declarative routing-table SSOT. It explains how the routing table
maps task character to a symbolic tier, how each runtime resolves a tier
to a concrete model ID, the cost-rate SSOT contract, the opt-in aggressive
overlay shape, and the load-bearing classifier-confidence stability metric
that gates the M030 shadow-mode flip.

The routing-table file itself is the single source of truth — this document
explains it. When the two disagree, the YAML wins; this document is updated
to match.

Authoring discipline: changing the numeric thresholds in the
`## Classifier-Confidence Stability Metric` section is a doc edit plus a
DECISIONS.md row, not a code change. P02's `shadow-compare.sh` reads the
values declared here at runtime via the same YAML/markdown parser used
elsewhere in the codebase.

## Routing Table

The routing-table maps `(character × runtime) -> symbolic-tier`. The
classifier (`scripts/dispatch/classify-task.sh`, M030/P01/T02) emits
`character ∈ {mechanical, standard, novel}` for every plan. The routing
table resolves the pair `(character, runtime)` to a symbolic tier name.

Conservative shipping defaults at M030 launch:

| character  | claude-code | codex-cli | cursor   |
|------------|-------------|-----------|----------|
| mechanical | fast        | inherit   | inherit  |
| standard   | balanced    | inherit   | inherit  |
| novel      | smart       | inherit   | inherit  |

The CC-only launch posture (FR-6, M009 deferred) means codex-cli and cursor
resolve to `inherit` — at runtime the adapter layer falls back to the
claude-code resolution. M009 (post-launch, demand-driven) will add per-
runtime symbolic mappings for non-CC runtimes when real users arrive on
those runtimes.

Symbolic tier semantics:

- `fast` — cheapest tier; routed to for surgical mechanical tasks where
  the dispatch shape is highly templated.
- `balanced` — middle tier; the default for standard tasks where the
  classifier signal is unambiguous but the work is substantive.
- `smart` — top tier; reserved for novel/exploratory work where the
  classifier flagged the plan as outside the established pattern set.

The character vocabulary is the closed enum `{mechanical, standard, novel}`;
adding a fourth character is a schema-version bump (D-A4 closure
invariant). The symbolic-tier vocabulary is the closed enum `{fast,
balanced, smart}`; adding a fourth tier is also a schema-version bump.
`inherit` is a reserved sentinel that means "fall back to the
claude-code value at adapter resolution time" — it is NOT a tier.

## Per-Runtime Resolution

The resolution section maps `(symbolic-tier × runtime) -> concrete model ID`.
This is the **only** section in `templates/model-routing.yml` where
hardcoded model IDs appear (CON-3 closure invariant — the routing table
shape verifier `tools/verify/p01-routing-table-shape.sh` enforces this).

Default resolution at M030 launch:

| symbolic-tier | claude-code         | codex-cli | cursor   |
|---------------|---------------------|-----------|----------|
| fast          | claude-haiku-4-5    | inherit   | inherit  |
| balanced      | claude-sonnet-4-7   | inherit   | inherit  |
| smart         | claude-opus-4-7     | inherit   | inherit  |

Operators update this section when providers release new models. Renaming
a model is a single-file edit here — the `routing:` section above does
not change, and downstream callers (the metrics rollup, the classifier,
the dispatch adapters) consume the resolved value via the YAML parser.

For consumer projects that pin to dated snapshots (`claude-haiku-4-5-20260101`),
override the value in `.orchestrator/config.yml` under `model_routing.resolution_override:`
rather than editing the bundled template — this preserves the upstream
template at install time and survives `orchestrator:update` cleanly.

## Cost Rates SSOT

The `cost_rates:` section in `templates/model-routing.yml` is the per-
symbolic-tier USD-per-million-tokens SSOT (D-A6). Every entry has two
required keys: `input_per_mtok` and `output_per_mtok`.

Default rates as of 2026-04-30, claude-code runtime tier:

| symbolic-tier | input_per_mtok | output_per_mtok |
|---------------|----------------|-----------------|
| fast          | 1.00           | 5.00            |
| balanced      | 3.00           | 15.00           |
| smart         | 15.00          | 75.00           |

Consumer: `scripts/observability/metrics-rollup.sh --by-model` (M030/P05).
The rollup reads `cost_rates:` and computes the all-smart counterfactual
savings — the load-bearing observability surface for the M030 thrift case.

**Operator obligation: update `cost_rates:` when provider pricing changes.**
The values are pinned to the SSOT here so rollup output is internally
consistent; if you forget to update them, the rollup numbers will
silently drift from invoice reality.

Failure semantics (FR-3 + FR-15 + SC-8): when `cost_rates:` is absent
entirely or a referenced tier is missing, `metrics-rollup.sh --by-model`
emits a `WARN: cost_rates not configured for tier=<tier>` line and a
zero-savings line for that tier. This is a soft failure — the rollup
continues running. The shape verifier `p01-routing-table-shape.sh`
checks that every `cost_rates:` tier entry that IS present has both
`input_per_mtok` and `output_per_mtok`; it does NOT require all three
tiers to be populated (matches FR-15 graceful-degradation semantics).

## Aggressive Overlay

The aggressive overlay is an opt-in operator overlay for users who want
to push more dispatches down the cost curve than the conservative
shipping defaults. It lives in the consumer project's
`.orchestrator/config.yml` under:

```yaml
model_routing:
  overlay: aggressive
```

When `overlay: aggressive` is set, the routing table's `standard ->
balanced` mapping is replaced with `standard -> fast`, and `novel ->
smart` is replaced with `novel -> balanced`. `mechanical -> fast`
remains unchanged. This matches the M030 thrift-as-default proposal's
aspirational endpoint — it is NOT the default at launch.

Documented but not enabled at launch. Operators who flip the overlay
take on the calibration burden: shadow-compare.sh's `partially_ready`
verdict (D-A3) is the safe path to flipping just one class to the
aggressive routing without flipping the others.

The overlay does NOT modify `resolution:` or `cost_rates:` — those
remain the SSOT for tier-to-model and tier-to-USD mappings regardless
of overlay state.

## Classifier-Confidence Stability Metric

This section is the load-bearing P02 contract — it pins the concrete
numeric thresholds that `scripts/dispatch/shadow-compare.sh` (M030/P02)
consumes when computing `flip_recommendation`. The values are version-
controlled here; changing them is a documentation edit + a
`references/model-routing.md` D-row in `.orchestrator/DECISIONS.md`,
not a code change.

The metric has two components — both MUST be met for a class to be
considered stable:

- **Rolling per-class confidence-score variance threshold = 0.10.**
  The classifier's `confidence` output is mapped to numeric scores at
  consumption time: `high=1.0`, `medium=0.5`, `low=0.0`. For each class
  `c ∈ {mechanical, standard, novel}`, the rolling variance of the
  confidence-score sequence over the last N=20 dispatches in that class
  MUST be **below 0.10** for class `c` to be stable. Variance of a
  sequence stuck at one value is 0; variance of a sequence flipping
  between high (1.0) and low (0.0) is ~0.25; the 0.10 threshold accepts
  modest medium↔high oscillation but rejects high↔low instability.

- **Minimum class-coverage count = 50 dispatches.** Each class `c` MUST
  have at least 50 dispatches in the shadow corpus before a stability
  claim can be made for that class. This matches FR-8's per-class
  evidence threshold for the `ready` verdict — the same number anchors
  both the agreement-rate gate and the stability gate, so operators
  reading the rollup do not see two competing sample-size floors.

Rolling-window definition: `N=20` is the sliding-window width over which
variance is computed. Implementations MUST take the last 20 dispatches
in chronological order for class `c` (excluding any with `confidence=low`
mapped to 0.0 entries that themselves are still counted as data points
— the threshold accepts up-to-low oscillation as instability, not
selective filtering).

Verdict logic (consumed by P02 `shadow-compare.sh`):

- All three classes meet both thresholds (variance < 0.10 AND count
  ≥ 50): `flip_recommendation=ready`.
- ≥2 of 3 classes meet both thresholds AND the under-threshold class's
  routing-table default is `smart`: `flip_recommendation=partially_ready`
  per D-A3 (the smart-default class is the safe one to leave on the
  conservative routing while flipping the others).
- Any other shape: `flip_recommendation=hold`.

Threshold rationale: the 0.10 variance value is a conservative shipping
default. Empirical classifier dogfood data was not yet available when
T03 shipped these defaults; the threshold is set to reject sequences
whose confidence-score range spans more than ~0.5 units within the
rolling window. Operators may relax this to 0.15 in the aggressive
overlay (or globally via a routing-table D-row) if dogfood data shows
the conservative threshold rejects acceptably-stable sequences.

The 50-per-class floor matches FR-8's `ready` agreement-rate threshold
deliberately — using a single sample-size floor across both stability
and agreement keeps the rollup output internally consistent. If FR-8's
threshold ever moves, this floor moves with it.

The N=20 window width is chosen to be large enough to dampen single-
dispatch oscillation while small enough to react to a real shift in
classifier behaviour within ~one working-day of dogfood traffic. Larger
windows smooth more aggressively at the cost of slower drift detection;
operators may widen to 40 in the aggressive overlay if dogfood shows
20-window variance over-rejects.

## See Also

- `templates/model-routing.yml` — the SSOT this document describes.
- `scripts/dispatch/classify-task.sh` (M030/P01/T02) — the upstream
  classifier whose output drives the routing table.
- `scripts/dispatch/shadow-compare.sh` (M030/P02) — the downstream
  consumer that reads the stability-metric thresholds defined above.
- `scripts/observability/metrics-rollup.sh --by-model` (M030/P05) —
  the cost-rate SSOT consumer.
- `.orchestrator/milestones/M030/M030-CONTEXT.md` — D-A1, D-A3, D-A6,
  CON-3 (the constraints this document operationalizes).
- `specs/032-adaptive-model-selection/spec.md` — FR-3, FR-6, FR-8,
  FR-12, CON-3.
