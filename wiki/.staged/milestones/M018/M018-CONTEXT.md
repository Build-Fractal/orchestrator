---
schema_version: "1.0"
type: context-draft
milestone: "M018"
status: finalized
created_at: "2026-04-27T18:45:00Z"
finalized_at: "2026-04-27T18:47:25Z"
---

## Architectural Decisions

### AD-1 — Phase decomposition follows the spec's tier-by-tier slice (resolves shape question pre-discuss)

Phase mapping is dictated by the spec's user-story → priority → tier alignment, with A-6 explicitly pre-shaping the runtime-scope axis. The roadmap will codify:

- **P00 — Measurement prerequisites** (US-0). Closes the `dispatch_usage` emitter-coverage gap (FR-0a, RISK-1) and ships the section-distribution probe (FR-0b, RISK-2). Hard prerequisite — no tier code starts until P00 closes with parity ≥ 95% across a 20-dispatch test sample.
- **P01 — Grammar contract** (US-1). Ships `references/compression-grammar.md`. Conversus `--strict` gate is the close criterion (FR-18, CON-6). No code touches a payload until the contract gates clean.
- **P02 — Knowledge-aware filter** (US-2). First production code: extends `scripts/dispatch/build-context.sh` to read [M020](../../milestones/M020/index.md) `status:` and apply the configured drop-list. Zero-LLM. Emits `payload_filter` JSONL.
- **P03 — Tier 1 microcompact** (US-3). Cache-keyed tool-result paging. Zero-LLM.
- **P04 — Tier 2 snip** (US-4). Head-drop with protected tail. Zero-LLM.
- **P05 — Tier 3 auto-compact** (US-5). LLM-routed via `dispatch-interface.sh`; intensity-gated; failure-passthrough. Eval harness participates in P05 verification ladder per RISK-3 (US-7 was promoted P3 → P2 specifically to gate T3 ship).
- **P06 — Surfaces + eval harness** (US-6 + US-7). FR-10 emitter schema additions and FR-11 cost/status/doctor surface extensions ship as a unit. Eval harness `compression-eval.sh` (FR-12) is the operational outcome signal.
- **P07 — Multi-runtime parity** (US-8). Codex CLI + Cursor verification. Zero-LLM tiers (filter, T1, T2) checked byte-identical; T3 routed through dispatch adapter.

### AD-2 — Surface/emitter integration is bundled into P06, not incrementally per tier

FR-10 (additive `dispatch_usage` / `unit_close` fields) and FR-11 ([M027](../../milestones/M027/index.md) surface extensions) are bundled into one phase rather than threaded incrementally into P02–P05. Rationale:

- The fields are additive and back-compat (CON-5), so per-tier emission can land as instrumentation-only without surface integration. Each tier's phase emits its own savings field; P06 wires those fields into rollups, footer, and doctor.
- Bundling avoids re-touching `scripts/cost/rollup.sh`, the status footer, and `orchestrator:doctor` four times.
- The eval harness (FR-12) consumes the same instrumentation, so co-locating its build with the surface-extension work keeps the consumer + emitter contracts in the same plan.

### AD-3 — Dogfood inflection: M018 starts compressing its own dispatches at P03 close

Once filter + T1 ship (P03 close), every subsequent M018 dispatch (P04 onwards) runs through the compression pipeline at Quick intensity. The minimal slice (US-1 + US-2 + US-3) is the close-the-loop boundary the spec defines as the dogfood cut. P04+ phase plans assume compression is on for their own context payloads.

### AD-4 — Conversus gates fire only at P01

The spec's CON-6 mandates the `--strict` gate at P01 (grammar contract) only. We do NOT gate P05 (T3) or P06 (eval harness) through conversus. Rationale:

- P05's quality risk is captured by the eval harness (FR-12) participating in its verification ladder per RISK-3 — that's the empirical gate, not an adversarial one.
- P06 is mostly schema + plumbing; the surfaces inherit their gates from M027's existing verification.
- Adding extra conversus gates increases token cost without clear THREAT-coverage gains. If a phase reveals genuinely subjective-quality risk during planning, the gate can be added at plan-phase as a `--quick` cycle.

### AD-5 — M018 close criterion = full milestone (P00 → P07), not minimal slice

The minimal slice (US-1 + US-2 + US-3 = P01 → P03) closes the dogfood-loop boundary, but M018 does not mark `milestone_close: pass` until P07 ships. Rationale:

- T2 + T3 are committed in spec scope (P2 priority, not P3 deferred).
- Multi-runtime parity is committed (P3 priority — the launch gate in CLAUDE.md's forward sequence consumes M018's outputs).
- The eval harness exists specifically to keep T3 honest; closing the milestone before T3 + eval harness lands defeats the purpose.

If schedule pressure emerges mid-execution, P05 (T3) and P07 (multi-runtime) are the legitimate-cut candidates, not the minimal slice — but the cut should be an explicit deviation event, not a default close.

## Scope Boundaries

### In scope (committed)

- 4-tier compression pipeline (filter, T1 microcompact, T2 snip, T3 auto-compact) with per-tier preservation contracts.
- P00 measurement prerequisites: emitter-coverage closure + section-distribution probe + SC-9 threshold calibration.
- P01 grammar contract document (`references/compression-grammar.md`) + conversus `--strict` gate.
- [M019](../../milestones/M019/index.md) emitter schema extensions (additive, back-compat) for filter savings, T1/T2/T3 savings, T1/T3 invocation counts.
- M027 surface extensions: `orchestrator:cost`, `orchestrator:status` efficiency footer, `orchestrator:doctor` anomaly check all read the new savings fields.
- Cache directory tree (`.orchestrator/cache/tool-results/`, `.orchestrator/cache/tier3-originals/`) + `cache-prune.sh --max-age` utility.
- Eval harness (`scripts/diagnostics/compression-eval.sh`) gating T3 ship.
- Multi-runtime parity (CC + Codex CLI + Cursor) — zero-LLM tiers byte-identical; T3 dispatch-adapter-routed.
- Intensity gating (Quick = filter + T1 + T2; Standard/Full = adds T3).
- `compression.enabled: false` config short-circuit (byte-identical to pre-M018) + per-tier disable flags.

### Out of scope (Non-Goals — codified in spec NG-1 through NG-7)

- **NG-1 — Tier 4 (staged collapse)**: deferred to demand-driven follow-up. Telemetry probe (p95 = 24k tokens) does not justify the complexity.
- **NG-2 — Cross-dispatch context state**: M018 does not change the fresh-context-per-unit contract.
- **NG-3 — Compression of canonical files on disk**: knowledge tree, spec files, plan files, roadmap files remain byte-identical (Constitution Principle VI / FR-17).
- **NG-4 — Auto-prune of cache directories**: manual `cache-prune.sh` only; auto-prune is a post-M018 follow-up gated by observed cache growth.
- **NG-5 — Compression as security/privacy boundary**: not redaction; cached originals are present on disk.
- **NG-6 — Compression of execution-log.jsonl**: append-only logs are not compressed; FR-16 cache-prune does not touch them.
- **NG-7 — Beyond-grammar payload modifications**: any tier modifying a payload section MUST emit an in-band marker (CON-4) and remain within its grammar tier.

### Scope edges to watch (potential creep)

- **Per-class T3 prompts** (#Q-5): if eval harness reveals knowledge-summarization vs tool-result-summarization need separate prompts, P05 may need to ship multiple `templates/compression-tier3-prompt.md` variants. Plan-phase for P05 should sample fixture sections before committing to a single prompt.
- **Drop-list expansion** (#Q-4): if M020 added vocabulary post-2026-04-25 (`archived`, `deprecated`, etc.), the default drop-list may need to widen. Plan-phase for P02 confirms the current vocabulary first.
- **Cache TTL header** (#Q-6): if doctor surfaces a cache-size advisory and operators ignore it, an in-cache TTL becomes harder to retrofit. Defer per NG-4 but flag for post-M018 review at the first cache-growth doctor warning.

## Design Constraints

### Inherited from D008 + D010 (binding)

- **D008** — Compression is the next milestone after M027; minimal slice is filter + T1 ship together; surfaces gain savings visibility; T4 is deferred per Constitution XV.
- **D010** — Compression is a pipeline of tiers each with its own grammar; intensity-gated; conversus gates the grammar contract.

### Inherited from constitution (binding)

- **Principle II (Evidence Before Claims)** — eval harness gates T3 quality; SC-9 calibrated against probe; no narrative wins.
- **Principle VI (State On Disk Is Truth)** — FR-17 originals authoritative; cache is disposable.
- **Principle XII (Measure Costs, Spend Selectively)** — CON-3 zero-LLM-default for minimal slice + T2; T3 is the only LLM cost surface.
- **Principle XIV (Don't Plan Speculatively)** — NG-1 (T4 deferral) honors this directly.
- **Principle XV (Deliver Less, Ship Sooner)** — minimal slice closes the dogfood loop; tiers 2/3 + eval + multi-runtime are sequenced not bundled.

### Empirical constraints (telemetry-grounded)

- **Probe anchor**: n=169 dispatches, mean=16,797 tok, p95=24,534 tok. Knowledge=45.9% / Task Plan=24.0% / Upstream Context=18.1% of payload tokens. The probe lives at `.orchestrator/scratch/m018-telemetry-probe-report.txt`.
- **SC-9 threshold**: NOT pinned at this stage. P00 (FR-0b) calibrates the threshold against per-section distribution + per-tier achievable-savings ceilings with confidence intervals. The threshold is amended into the spec via `--amend` before P01 closes.
- **Emitter parity bar**: ≥ 95% across a 20-dispatch test sample (FR-0a). P00 doesn't close until this is met.

### Operational constraints

- **CON-1 (read-mostly)**: M018 only writes to `.orchestrator/cache/`, the M019 emitter schema (additive), `references/compression-grammar.md`, and `references/RUNTIME-ASSUMPTIONS.md`. Existing scripts in non-compression code paths are untouched.
- **CON-5 (back-compat-emitters)**: All M019 schema additions are additive. Pre-M018 records readable post-M018; post-M018 records readable by pre-M018 jq filters (missing → null).
- **A-6 (single-runtime through P05)**: P01–P05 develop + verify under Claude Code only. P06 (eval harness) and P07 (multi-runtime) extend to Codex CLI + Cursor. Multi-runtime work does not gate the minimal slice close.

### Anti-patterns (encoded in pre-bash-shape-guard hook)

- No compound bash chains > 2 (AP-009). All dispatched scripts are single-script-file invocations.
- No `$(...)` in inline commands.
- AGENTS.md is dual-written from CLAUDE.md via `scripts/util/dual-write-runtime-md.sh` — never edited directly.
- `CONVERSUS_PROVIDER=claude-code` always on OAuth; default anthropic 429s as policy gate not transient (M018 conversus gate at P01 must export this).

## Open Questions

### Resolved by spec/probe (no plan-phase action)

- **#Q-1 (SC-9 threshold)** — RESOLVED: P00 calibrates empirically.
- **#Q-2 (emitter coverage)** — RESOLVED: P00 hard prerequisite.

### Deferred to phase plan-phase

- **#Q-3 (eval-harness scope)** — P06 plan-phase decision: replay-based (option i, expensive, real signal) vs. hold-out comparison (option ii, observational, cheap). Spec hints that M027's anomaly detection may make (ii) sufficient. Decision rests on a fixture run of both during P06 plan-phase.
- **#Q-4 (drop-list defaults)** — P02 plan-phase: re-read M020's graduated `status:` vocabulary (M020 closed 2026-04-25); confirm `["superseded", "experimental"]` is complete and consider `archived` / `deprecated` if M020 added them.
- **#Q-5 (T3 prompt-per-class)** — P05 plan-phase: sample fixture summarizations (knowledge entry vs task plan vs tool result) against a single prompt; if quality diverges materially, ship per-class variants.

### Deferred to post-M018 (operational follow-up)

- **#Q-6 (cache TTL vs doctor advisory)** — observe cache directory growth post-ship; if operators ignore the doctor warning, retrofit TTL header. NG-4 governs.

### Discuss-stage decisions for the operator (LISTED — non-blocking, but cleaner if confirmed before roadmap)

- **DQ-1 — P06 bundling vs. tier-incremental surface integration**: AD-2 commits to bundled P06. Alternative is to ship FR-11 surface extensions per-tier (P02 ships filter savings to surfaces, P03 adds T1, etc.). Bundled is the recommendation for the rationale in AD-2; if the operator prefers staggered visibility (each tier's wins land in surfaces immediately), reverse AD-2 and accept the surface-rewriting cost. **Recommendation: keep AD-2 as drafted.**
- **DQ-2 — Conversus-gate scope**: AD-4 limits gates to P01. Alternative is to also `--quick` gate the eval harness build (P06) since the harness's measurement methodology is itself a quality risk. **Recommendation: keep AD-4 as drafted; revisit at P06 plan-phase if methodology questions surface.**
- **DQ-3 — Cache retention default**: FR-16 specifies the `--max-age` flag but no default. Reasonable defaults: `--max-age 7d` (matches typical milestone span), `--max-age 30d` (full milestone retention), or no default (operator must specify). **Recommendation: 7d default with `orchestrator:doctor` advisory if cache > 1GB. Confirm at P02 plan-phase.**
- **DQ-4 — Milestone close at minimal slice vs. full P07**: AD-5 commits to full P07. If schedule pressure emerges, P05 + P07 are the legitimate cut candidates. **Recommendation: keep AD-5 as drafted; cuts become explicit deviation events at execution time.**
- **DQ-5 — Single-context vs. zero-context phase plans**: M018's phase plans should follow the project's standard zero-context contract (Constitution Principle IV). Plan-phase needs the telemetry probe report, the compression grammar contract (once P01 ships), and the M019/M027 emitter schemas in the plan substrate. **Recommendation: standard zero-context plans; the probe report is referenced but not duplicated into plan bodies.**
