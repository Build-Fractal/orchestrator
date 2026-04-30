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

## Operator Overrides

M030/P03 ships three operator-facing override knobs plus a kill switch.
This section documents the precedence chain mechanically: knobs evaluate
in the order below, the first match wins, downstream knobs are bypassed.
The chain is implemented in `scripts/dispatch/dispatch-interface.sh`'s
`_di_emit_dispatch_usage` body and is gated by the same `M030_SHADOW_MODE=1
AND CLAUDECODE=1` envelope as the rest of the M030 shadow path.

### Precedence Chain

1. **Kill switch** (`.orchestrator/config.yml` top-level
   `model_routing_enabled: false`) — disables the entire routing layer.
   Records `override_source=disabled`. The classifier still runs and
   `model_routed`/`classifier_confidence` are still emitted (the shadow
   corpus continues to grow), but the dispatched model falls back to the
   runtime default. **Kill switch supersedes `min_tier`** (CON-4/D-A5).
   When both are active, `override_source=disabled` is recorded and a
   one-line stderr warning names the bypassed value:

   ```
   model_routing_enabled=false: min_tier: smart is inactive
   ```

2. **Plan frontmatter** (`PLAN.md` frontmatter
   `model_override: <symbolic-tier>`) — short-circuits classification.
   Records `override_source=plan_frontmatter`. The override value MUST be
   a closed-enum symbolic tier (`fast | balanced | smart`) — concrete
   model IDs in the override field are accepted but discouraged
   (operators pinning to a dated snapshot like `claude-haiku-4-5-20260101`
   should override under `model_routing.resolution_override:` in
   `.orchestrator/config.yml`, not in the plan).

3. **Milestone floor** (`.orchestrator/config.yml`
   `model_routing.min_tier: <symbolic-tier>`) — raises the effective
   floor for every dispatch in the active milestone. Records
   `override_source=milestone_floor`. **Floor wins over plan
   frontmatter** when the floor is higher than the plan's override
   (FR-14). When this conflict fires, a one-line stderr warning names
   both knobs:

   ```
   model_override=fast overridden by min_tier=smart (floor wins)
   ```

4. **Plain routed** (no overrides active) — the routing table runs as
   documented in the `## Routing Table` section above. Records
   `override_source=none`.

### override_source closed enum

The JSONL `override_source` field is drawn from the closed set:

| value                | trigger                                   |
|----------------------|-------------------------------------------|
| `disabled`           | kill switch active                        |
| `plan_frontmatter`   | plan frontmatter `model_override:` set    |
| `milestone_floor`    | `min_tier:` set (or floor-wins conflict)  |
| `none`               | plain routed (no overrides)               |
| `shadow_gate_blocked`| reserved for FR-9 live-flip refusal (P05) |

`shadow_gate_blocked` is the FR-9 flip-readiness gate value emitted when
`model_routing.live: true` is set without sufficient shadow corpus —
M030/P05 ships the live-flip path; the value is reserved here so the
closed enum is locked at P03 close.

### CC-only launch posture

Override resolution requires `CLAUDECODE=1`. On Codex CLI / Cursor the
override path short-circuits and `override_source` is not emitted (the
shadow path itself is bypassed; record is byte-identical to pre-M030
shape). M009 ships per-runtime override semantics demand-driven post-
launch.

## Live Routing

M030/P04 ships the live-routing flip-gate plus the verifier-fail
auto-escalation loop. This section documents how `model_routing.live:
true` activates the routing layer end-to-end, the four-verdict gate that
guards the flip, and the bounded escalation chain that runs when an
adapter fails verification. The path is gated CC-only (`CLAUDECODE=1
AND M030_SHADOW_MODE=1`) for the same reason the rest of M030's shadow
path is — non-CC runtimes (Codex CLI / Cursor) defer to M009.

### Activation

Live routing is opt-in via `.orchestrator/config.yml`:

```yaml
model_routing:
  live: true
```

When set, every dispatch through `scripts/dispatch/dispatch-interface.sh`
runs the programmatic flip-gate (D-A2). The gate invokes
`scripts/diagnostics/shadow-compare.sh` against the in-flight execution
log (or a corpus path explicitly provided via
`M030_SHADOW_COMPARE_CORPUS`) and reads exactly one
`flip_recommendation=` line from its output. The closed enum is the
same four-verdict set defined in `## Classifier-Confidence Stability
Metric` above (D-A1).

### Verdict-to-action table

| Verdict                | Action                                                                                                                                             |
|------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| `ready`                | All classes flip live. The classifier's symbolic tier resolves to a concrete model id via `templates/model-routing.yml`'s `resolution:` block; that id is passed to the backend adapter via `--model <id>`. JSONL records `partial_flip_active=false`, `withheld_classes=""`. |
| `partially_ready`      | Per-class authorization (D-A3): only classes whose routing-table default is `smart` may be enumerated in `withheld_classes`. Flippable classes route live (`--model <id>`); withheld classes fall back to the runtime default model. JSONL records `partial_flip_active=true`, `withheld_classes=<list>`. |
| `evidence_insufficient`| Adapter is NOT invoked. Dispatcher emits a `dispatch-error.md` with `error_type=shadow_gate_blocked` and appends a `dispatch_usage` record with `override_source=shadow_gate_blocked`. Exit code 7. |
| `block`                | Same as `evidence_insufficient` — adapter not invoked, `override_source=shadow_gate_blocked`, exit 7. The two verdicts collapse at the gate; the distinction is preserved upstream in `shadow-compare.sh` for operator-facing diagnostics. |

### Escalation chain (CON-5)

When live routing IS active and the adapter exits non-zero (the
verifier-fail signal), `dispatch-interface.sh` retries with a higher-tier
model. The progression is `fast → balanced → smart`, computed via the
`_di_tier_at_rank` helper (the inverse of the `_di_tier_rank` rank used
by floor-comparison). Each retry re-resolves
`resolution.<tier>.claude-code` from `templates/model-routing.yml` —
zero hardcoded model IDs — and re-invokes the adapter with the new
`--model` value.

The cap is **2 escalations** (CON-5 hard-cap) — equivalently 3
adapter invocations total. After the third invocation also exits
non-zero, the dispatcher MUST stop:

1. Emit the third `dispatch_usage` record with
   `escalation_count=2` + `escalation_reason=verifier_fail`.
2. Emit ONE `escalation_cap_hit` record (`record_type=escalation_cap_hit`,
   `final_count=2`, `unitId`, `timestamp`).
3. Emit `dispatch-error.md` with `error_type=backend_crashed` on stderr.
4. Exit 5.

A fourth adapter invocation is forbidden. The hard-cap is enforced at
the invocation site, not just the JSONL emit site —
`tools/verify/p04-con5-no-fourth-record.sh` asserts both the
3-dispatch_usage-records contract AND the 3-adapter-invocations contract
(via the `STUB_FAIL_COUNTER_INVOCATIONS_FILE` side-channel).

### Escalation JSONL fields

Two additive fields appear on every shadow-on `dispatch_usage` record
post-M030/P04:

| field               | type    | semantics                                                                                                  |
|---------------------|---------|------------------------------------------------------------------------------------------------------------|
| `escalation_count`  | integer | Number of preceding failed attempts before this record's dispatch. `0` on the initial dispatch, `1` on the first escalation, `2` on the second escalation. Capped at `2`. |
| `escalation_reason` | string  | `"verifier_fail"` when the recorded attempt itself failed (rc != 0); `""` (empty) on the success record. The cap-hit record carries `verifier_fail`. |

**Emit-vs-increment ordering**: the increment of `escalation_count`
happens AFTER the failed attempt's record is emitted, BEFORE the next
attempt is invoked. This means the success record on the Nth attempt
reads `escalation_count=N-1` (N-1 preceding failures); a fail-twice-then-pass
sequence emits `(0/verifier_fail) (1/verifier_fail) (2/"")`. A
fail-three-times sequence emits `(0/verifier_fail) (1/verifier_fail)
(2/verifier_fail)` plus the `escalation_cap_hit` record.

### Override precedence (extended)

The full precedence chain, evaluated in order (first match wins,
downstream knobs bypassed):

1. **Kill switch** (`model_routing_enabled: false`) — supersedes
   everything, including `live: true`. CON-4/D-A5. The
   `live: true is inactive` warning is emitted on stderr alongside any
   `min_tier is inactive` warning.
2. **Plan frontmatter** (`model_override:`) — short-circuits routing.
3. **Milestone floor** (`min_tier:`) — raises the effective floor.
   Floor wins over plan frontmatter when the floor is higher (FR-14).
4. **Live routing** (`live: true` AND no override above) — runs the
   programmatic flip-gate; on `ready` / `partially_ready` (flippable
   class) the resolved model is passed to the adapter. The escalation
   loop wraps THIS path only.
5. **Plain routed** — no overrides, no `live: true`. Shadow path
   continues to record `model_routed` / `model_used` / `override_source=none`
   without passing `--model` to the adapter.

The closed `override_source` enum from `## Operator Overrides` is
unchanged. `shadow_gate_blocked` is the value emitted on the
`evidence_insufficient` / `block` verdicts at the live-routing gate.

### Operator workflow: shadow → live

To flip a project from shadow to live:

1. **Validate corpus readiness.** Ensure the shadow corpus has ≥50
   records per class (per the per-class coverage threshold in
   `## Classifier-Confidence Stability Metric`) and the
   classifier-confidence variance is ≤ 0.10 over the rolling N=20 window.
2. **Run shadow-compare.** `bash scripts/diagnostics/shadow-compare.sh
   --corpus <path>` returns a `flip_recommendation=` line. Verify it is
   `ready` (all classes flip) or an acceptable `partially_ready` (with
   the `withheld_classes` list documented in your operations runbook).
3. **Edit config.** Set `model_routing.live: true` in
   `.orchestrator/config.yml`.
4. **Verify on the next dispatch.** The dispatch-interface re-runs the
   programmatic flip-gate against the in-flight log. If the verdict is
   still acceptable, the adapter is invoked with `--model <resolution>`;
   otherwise the dispatch refuses with exit 7 and `override_source=shadow_gate_blocked`
   in the appended JSONL record.

To roll back: revert `live: true` to `live: false` (or remove the line)
— the next dispatch re-enters shadow-only mode without flipping. To
disable routing entirely (kill switch), set `model_routing_enabled:
false`; this supersedes any `live:` value per CON-4/D-A5.

### CC-only launch posture

The live-routing path requires `CLAUDECODE=1` AND `M030_SHADOW_MODE=1`,
the same gates that scope the rest of the M030 shadow surface. Codex
CLI and Cursor cannot reach the live-routing branch or the escalation
loop; they continue to dispatch with the runtime default model. M009
ships per-runtime live-routing semantics demand-driven post-launch.

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
- `tools/verify/p03-override-source-enum.sh` (M030/P03/T01) — the closed-
  enum gate verifying every shadow-on dispatch_usage record carries
  exactly one override_source field whose value is in the closed set.
- `.orchestrator/milestones/M030/M030-CONTEXT.md` D-A5 — the binding
  decision establishing the kill-switch-supersedes-min_tier compound
  resolution amended into CON-4.
- `tools/verify/p04-sc4-escalation-sequence.sh`,
  `tools/verify/p04-sc5-escalation-cap.sh`,
  `tools/verify/p04-con5-no-fourth-record.sh`,
  `tools/verify/p04-con6-prior-records-bit-identical.sh`,
  `tools/verify/p04-escalation-fields-enum.sh` (M030/P04/T03) — the
  five gate verifiers for the live-routing escalation loop, CON-5 hard-
  cap, CON-6 append-only, and the `escalation_count` / `escalation_reason`
  field enum documented in `## Live Routing` above.
- `scripts/dispatch/adapters/backend/stub-fail-n.sh` (M030/P04/T01) —
  the programmable fail-counter fixture adapter consumed by the SC-4 /
  SC-5 / CON-5 verifiers.
