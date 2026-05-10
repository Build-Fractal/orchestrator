---
schema_version: "1.0"
type: context-draft
milestone: "M027"
status: finalized
created_at: "2026-04-26T18:50:00Z"
finalized_at: "2026-04-26T19:05:00Z"
---

## Architectural Decisions

### AD-1 — Aggregation precedence: `source: aggregate` is authoritative (resolves #Q-7, addresses conversus THREAT-001 / MIT-002)

When the rollup engine encounters a `source: aggregate` record at a given granularity (e.g., a phase-level `unit_close` with rolled-up children), it treats that record as authoritative for that granularity and skips the constituent child records that already fed it. This applies symmetrically across `source: estimate`, `source: runtime`, and `source: aggregate`:

- For granularity G: prefer the highest-priority record present, in order: aggregate > runtime > estimate.
- Children of an aggregate at granularity G are not double-counted at G.
- When aggregating G→G+1 (e.g., phase→milestone), prefer aggregate-of-G+1 if present; otherwise sum the G-level rows (which are themselves resolved per the rule above).

The verifier (FR-15) checks this rule mechanically: it constructs fixture logs with mixed-source records and asserts row totals.

### AD-2 — Performance bound: rollup CLI < 5s on 10MB JSONL on a 2024-era laptop (resolves #Q-8, addresses conversus THREAT-004 / MIT-003)

Promotes from "deferred to plan-phase" to a verifiable success criterion. The bound is conservative for current data volumes (largest existing milestone log is well under 10MB) and gives plan-phase room to optimize before the bound becomes load-bearing. A regression beyond 5s on a fixture 10MB log fails SC. If plan-phase measurement reveals the engine cannot meet the bound without architectural rework, plan-phase can propose a relaxation with evidence.

### AD-3 — Filesystem race handling: copy-then-aggregate (resolves #Q-9, addresses conversus THREAT-002 / MIT-004)

Rollup engine copies the target JSONL to a temp path before reading. All aggregation runs against the temp copy. Pros: deterministic snapshot semantics; never blocks the writer; tolerates external log rotation; trivial to implement with `cp` + `mktemp`; never holds an exclusive lock. Cons: doubles disk I/O on the read path. For 10MB logs this is negligible.

### AD-4 — Predictive cost surface is load-bearing (new architectural decision, expands M019b's strategic positioning)

The original M019b framing was retrospective: rollups summarize *what happened*. Operator-facing strategic direction (2026-04-26) elevates predictive cost-control as a first-class M027 capability:

> "Make sure our system is known by users for its ability to control user costs by always applying the ideal amount of token usage given the complexity and ambiguity of the ask. Be the one tool for every job — be very clear to users about our recommendation and the estimated cost, and give them the ability to run cheaper when they see fit."

Concrete implications:

1. **`orchestrator:cost --estimate <task-description>`** — given a task (or current state at the next dispatch boundary), estimate the cost at each intensity tier (Quick / Standard / Full) and surface a recommendation. Zero LLM tokens — pure bash + pricing.sh + payload-shape estimation from existing recipes.
2. **Intensity-recommend integration** — `scripts/engine/intensity-recommend.sh` already classifies tasks (Quick / Standard / Full). M027 wires its output to display estimated cost for each tier alongside the recommendation, with the recommended tier highlighted and the cheaper alternatives one keystroke away.
3. **Dispatch-time confirmation surface** — when `orchestrator:dispatch` is about to fire at a non-Quick intensity, optionally surface the estimated cost and the recommended-vs-current tier delta. Suppressed under `--yes` and under `orchestrator:auto`. Default-on for interactive use; gated by config for CI.
4. **Goodhart pairing extends to the predictive surface**: every cost estimate is paired with the intensity tier's expected quality semantics (Quick = best-effort, Standard = self-review, Full = adversarial gate). Operators see both axes when they choose.

This reframes M027 from "Tier 2 observability rollup" to "cost-aware dispatch with retrospective rollup". The retrospective surfaces (rollup CLI, cost command, status footer, doctor anomaly check) remain in scope unchanged. The predictive surfaces are additive.

### AD-5 — Operator-facing defaults favor visibility (resolves #Q-3 efficiency footer + tightens AD-4)

- Efficiency footer default: **on** for interactive `orchestrator:status`. CI consumers opt out via `config.efficiency_footer: false` or `--quiet`.
- Predictive cost surface at dispatch time: **on** for interactive dispatch when intensity is Standard or Full. Auto-suppressed under `orchestrator:auto` and under `--yes`. CI consumers opt out via `config.predictive_cost_surface: false`.
- The asymmetry is deliberate: visibility is the dogfood goal; CI surfaces should be byte-stable for log-scraping consumers.

### AD-6 — Cheap accept: FR-16 (`doctor --config-check`) and FR-17 (input schema validation) (resolves #Q-12 + #Q-13)

Both are trivial-effort additions with operational value. Folded into M027 scope.

- **FR-16** — `orchestrator:doctor --config-check` flags drift in `efficiency_footer` and `predictive_cost_surface` config across team environments. Read-only; advisory.
- **FR-17** — Rollup engine validates required-field presence (`estimated_cost_usd`, `record_type`, `granularity`) and types before aggregation. Validation failures log the offending line number on stderr; the row is excluded from totals (consistent with FR-14 corrupt-line tolerance and CON-5 never-abort).

### AD-7 — Defer #Q-1 (anomaly threshold defaults) to plan-phase measurement

Threshold defaults (cost multiplier, retry / pass-rate floor) require sampling current [M012](../../milestones/M012/index.md)–[M026](../../milestones/M026/index.md) data to know what "normal" looks like. Plan-phase fires the measurement and pins the defaults in the phase plan. Until then, the spec carries proposed defaults (3× median; `retry_count > 2 OR verification_pass_rate < 0.5`) as guidance, not contract.

### AD-8 — Phase decomposition: 4 retrospective phases + 1 predictive phase (revises original P00–P03 ordering)

Pinned phase ordering (revises the proposal in the original spec):

- **P00 — Rollup engine + verifier**: US-1, FR-1–4, FR-11–15, FR-17. The dependency root.
- **P01 — `orchestrator:cost` retrospective + predictive entry points**: US-2 + AD-4 (1) + (2). Wires the engine to a runtime-portable command surface and to the intensity-recommend flow. Ships both the retrospective rollup view (`orchestrator:cost`) and the predictive estimate view (`orchestrator:cost --estimate`).
- **P02 — Efficiency footer + dispatch-time predictive surface**: US-3 + AD-4 (3) + AD-5. Hooks `orchestrator:status` and `orchestrator:dispatch` interactive paths.
- **P03 — Anomaly detection + config-check**: US-4 + FR-8–10 + FR-16.

P00 → P01 → P02 → P03 sequential. P02 may parallelize internally (footer hook and dispatch-time surface are independent), but the phase as a whole follows P01.

## Scope Boundaries

### In Scope (M027)

- All four user stories from the spec (US-1 rollup engine, US-2 cost command, US-3 efficiency footer, US-4 anomaly detection).
- The predictive cost surface introduced by AD-4: `orchestrator:cost --estimate`, intensity-recommend cost annotation, dispatch-time confirmation surface (interactive only).
- FR-16 (`doctor --config-check`) and FR-17 (input schema validation).
- Output-surface Goodhart pairing across both retrospective and predictive surfaces.
- Performance bound (AD-2) and FS-race handling (AD-3).
- Verifier covering aggregation precedence (AD-1), Goodhart pairing, source-filter, byte-identity for `--quiet` status, read-only invariant, predictive-surface zero-LLM-token contract.

### Out of Scope (M027) — same as spec Non-Goals plus

- Backend runtime-actuals adapters (Tier 3).
- Auto-generated `MNNN-METRICS.md` on consolidate (Tier 3).
- Multi-runtime parity dashboards (Tier 3).
- Charts / UI / visualizations (every tier).
- [M018](../../milestones/M018/index.md) (Context Compression) — M027 surfaces the data; M018 acts on it.
- Schema changes to Tier 1 records.
- Backfilling pre-[M019](../../milestones/M019/index.md) records.
- Real-time / streaming rollups.
- Cross-repository rollups.
- **Predictive cost calibration via runtime-actuals feedback loop** — Tier 3 work. M027's predictive estimate uses pricing.sh + char-quartile token estimation (M019 AD-1); runtime-actuals adapters that close the calibration loop are deferred.
- **Auto-tier-downgrade on cost-budget-exceeded** — interesting but a separate milestone. M027 surfaces estimates and recommendations; operators (or `orchestrator:auto`'s budget guard, which already exists) make the call.

## Design Constraints

- **CON-1 (read-only)**: No M027 code path writes to `execution-log.jsonl`. Tier 1 emitter remains the sole writer.
- **CON-2 (additive-only schema)**: No changes to Tier 1 record shape. New surfaces consume the existing enum reservations.
- **CON-3 (back-compat byte-identity)**: `orchestrator:status --quiet` and `orchestrator:dispatch` under `orchestrator:auto` / `--yes` produce byte-identical output to pre-M027. CI / log-scraping consumers must not break.
- **CON-4 (Goodhart pairing)**: Every cost surface — retrospective row, predictive estimate, anomaly diagnostic — pairs cost with quality on the same line. Verifier rejects single-axis output.
- **CON-5 (never-abort)**: Missing pricing, corrupt JSONL, missing milestones, FS races, missing config — all degrade gracefully. No M027 surface aborts a dispatch or roadmap operation.
- **CON-6 (zero-token)**: Both retrospective and predictive surfaces are bash-only. No M027 code path invokes an LLM. Predictive estimation uses pricing.sh + recipe-shape token estimation; the cost surface is a microsecond-scale read, not a model call.
- **CON-7 (bash 3.2)**: All scripts pass bash 3.2 compat per the project constitution.
- **CON-8 (sample-floor for anomaly check)**: Default 5; configurable. Anomaly check skips milestones below the floor with an "insufficient sample" annotation.
- **CON-9 (predictive-surface latency)**: Predictive estimates must complete in < 100ms on a 2024-era laptop so they can ride alongside intensity-recommend without perceptible lag. If the bound cannot be met, the surface gracefully degrades to "estimate unavailable" rather than blocking dispatch.
- **CON-10 (operator override preserved)**: At every dispatch-time predictive surface, the operator can override the recommended tier with one keystroke and proceed at the cheaper or more-expensive tier. Strategic positioning per AD-4: visibility + recommendation + cheap override, never coercion.
- **CON-11 (Constitution Principle II — Evidence Before Claims)**: Every Success Criterion in M027 references behavior whose semantics are pinned in this context draft. SCs that depended on deferred questions (#Q-7, #Q-8, #Q-9) are now verifiable because AD-1 / AD-2 / AD-3 pinned them.

### Knowledge-Layer Boundary (M027 vs [M025](../../milestones/M025/index.md))

Unchanged from the spec. M025 owns knowledge-tree write-sites; M027 owns rollup + predictive surfaces; the consolidate flow may bridge them.

## Open Questions

### #Q-1 (carry-forward from spec) — Anomaly threshold defaults

**Status**: deferred to plan-phase. Plan-phase samples M012–M026 data to determine what "normal" looks like, then pins:

- Default cost-anomaly multiplier (proposed: 3× milestone median; revisit after sampling).
- Default quality threshold (proposed: `retry_count > 2 OR verification_pass_rate < 0.5`; revisit after sampling).

Plan-phase output binds the defaults; SC for the anomaly check references the pinned values.

### #Q-14 (new) — Predictive surface attachment points

The predictive surface (AD-4) attaches at three points:

1. **`orchestrator:cost --estimate <description>`** — explicit query.
2. **`scripts/engine/intensity-recommend.sh`** output — annotated with per-tier cost estimates.
3. **`orchestrator:dispatch` interactive confirmation** — pre-dispatch surface when intensity ≥ Standard.

Open question for plan-phase: should #2 emit an additional structured field that callers can parse, or only human-readable text? Recommendation: both — keep the existing text contract byte-stable (CON-3) and add an opt-in `--format json` flag for programmatic callers (intensity-gate / dispatch-time surface).

### #Q-15 (new) — Predictive estimate accuracy disclaimer

Predictive estimates are based on char-quartile token approximation (M019 AD-1) plus pricing.sh rates. Accuracy is bounded by the quality of the token estimate (no runtime-actuals feedback loop in M027). The estimate's `±N%` confidence is not currently surfaced. Plan-phase open question: should the predictive surface display a confidence band, or just the point estimate?

Recommendation: ship point-estimate in M027 with a one-line "estimates ±20%; runtime-actuals calibration is a future Tier 3 feature" disclaimer in `commands/cost.md`. Adding a confidence band is a separate UX decision.

### #Q-16 (new) — Auto-suppress predictive surface during repeat dispatches

If an operator dispatches 10 tasks in a row at Standard, showing the predictive surface 10 times is friction. Plan-phase decision: throttle to once-per-N-minutes? Once-per-session? Always-on?

Recommendation: always-on by default (visibility is the dogfood goal); add `--no-predict` flag for operators who want to skip after the first surface. Avoid hidden state ("we already showed this") that disagrees with the user-visible config.
