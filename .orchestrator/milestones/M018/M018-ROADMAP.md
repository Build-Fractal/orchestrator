---
schema_version: "1.0"
type: roadmap
milestone: "M018"
feature_ref: "030-context-compression-layer"
feature_spec: "specs/030-context-compression-layer/spec.md"
vision: "Caveman-style token compression as a 4-tier pipeline (filter, T1 microcompact, T2 snip, T3 auto-compact) that ships measurable savings without quality regression and respects intensity + multi-runtime contracts."
tier: "C"
created_at: "2026-04-27T18:51:02Z"
updated_at: "2026-04-27T18:51:02Z"
---

## Phases

- [x] **P00**: Measurement Prerequisites — "Operator runs the patched dispatch_usage emitter against a 20-dispatch test sample and reports parity ≥ 95% with payload_breakdown; the section-distribution probe outputs per-section size + per-tier achievable-savings ceilings with confidence intervals; the spec is amended with an empirically-pinned SC-9 threshold."
  - Risk: high
  - Depends: none
  - Boundary Map:
    - Produces: patched `dispatch_usage` emitter (parity ≥ 95% with `payload_breakdown` across a 20-dispatch sample); `scripts/diagnostics/m018-section-distribution.sh` (per-section size distribution + per-tier achievable-savings ceilings with CIs); spec amendment pinning SC-9 threshold (`--amend` to `specs/030-context-compression-layer/spec.md`)
    - Consumes: existing M019 emitter extension point; existing telemetry probe report at `.orchestrator/scratch/m018-telemetry-probe-report.txt`

- [ ] **P01**: Grammar Contract + Conversus Gate — "Operator views `references/compression-grammar.md`; the lint script reports clean; the conversus `--strict` gate report under `.orchestrator/milestones/M018/phases/P01/conversus/` shows PASS verdict before phase close."
  - Risk: high
  - Depends: P00
  - Boundary Map:
    - Produces: `references/compression-grammar.md` (versioned tier-by-tier contract); `scripts/verify/compression-grammar-lint.sh`; `references/RUNTIME-ASSUMPTIONS.md` entries for compression-grammar runtime expectations; conversus gate report under `.orchestrator/milestones/M018/phases/P01/conversus/`
    - Consumes: SC-9 calibrated threshold from P00 spec amendment; conversus adapter `scripts/dispatch/adapters/tool/conversus.sh` (DEP-4)

- [ ] **P02**: Knowledge-Aware Filter — "A dispatched task receives a context payload that excludes knowledge entries marked `status: superseded` or `status: experimental`; a `payload_filter` JSONL record appears in `execution-log.jsonl`; the existing `payload_breakdown` record carries a new `filter_dropped_tokens` field."
  - Risk: medium
  - Depends: P01
  - Boundary Map:
    - Produces: filter implementation in `scripts/dispatch/build-context.sh` (knowledge-status read + drop-list filter before payload assembly); `compression.knowledge_filter.drop_list` config key in `.orchestrator/config.yml` (default `["superseded", "experimental"]`); `payload_filter` JSONL record schema (additive emitter extension); `payload_breakdown.filter_dropped_tokens` field (additive); preservation-contract self-check pattern (re-used by T1/T2/T3)
    - Consumes: M020 `status:` field on knowledge entries (read-only — A-1); `references/compression-grammar.md` filter-tier rules (P01)

- [ ] **P03**: Tier 1 Microcompact — "A dispatched task whose tool result exceeds the configured inline threshold receives an inline reference (`file_path + preview`) instead; the original persists to `.orchestrator/cache/tool-results/`; cache lookups key on SHA-256(command + input) and reuse references across dispatches; `tier1_savings_tokens` and `tier1_invocations` appear in `payload_breakdown`; `cache-prune.sh --max-age 7d` evicts entries past retention."
  - Risk: medium
  - Depends: P02
  - Boundary Map:
    - Produces: T1 implementation in `build-context.sh` (tool-result paging + cache lookup/reuse); `.orchestrator/cache/tool-results/` directory tree (SHA-256-keyed); `tier1_savings_tokens` + `tier1_invocations` fields in `payload_breakdown` (additive); `tier_preservation_violation` JSONL record schema (additive emitter extension, shared with T2/T3); `scripts/util/cache-prune.sh --max-age <duration>`
    - Consumes: `references/compression-grammar.md` tier-1 rules (P01); preservation-contract self-check pattern (P02); `payload_breakdown` schema (extend)

- [ ] **P04**: Tier 2 Snip — "A dispatched task whose section body exceeds the configured budget gets head-dropped while the configured tail ratio is preserved byte-identical; an in-band marker `<!-- compressed:tier2 ... -->` names the snip; preserved-pattern boundaries (e.g., code fences, JSON blocks) refuse the snip and pass through unmodified; `tier2_savings_tokens` appears in `payload_breakdown`."
  - Risk: medium
  - Depends: P03
  - Boundary Map:
    - Produces: T2 implementation in `build-context.sh` (section head-drop with tail-ratio preservation + boundary detection); `tier2_savings_tokens` field in `payload_breakdown` (additive); in-band marker emitter for tier-2 (`<!-- compressed:tier2 ... -->`)
    - Consumes: `references/compression-grammar.md` tier-2 rules (P01); preservation-contract self-check pattern (P02); cache-prune integration (P03 — T2 has no cache but reuses prune utility for any spillover artifacts); `payload_breakdown` schema

- [ ] **P05**: Surfaces + Eval Harness — "Operator runs `orchestrator:cost` and sees `filter_dropped_tokens`, `tier1_savings_tokens`, `tier2_savings_tokens` columns rolled up across the milestone. `orchestrator:status` efficiency footer shows compression savings inline. `orchestrator:doctor` anomaly check flags compression regressions against historical baseline. `scripts/diagnostics/compression-eval.sh` reads historical telemetry, segments compressed vs uncompressed cohorts, and reports outcome-rate deltas (verification pass rate, retry count, deviation count) with confidence intervals; `--tier <N>` filters by tier."
  - Risk: medium
  - Depends: P02, P03, P04
  - Boundary Map:
    - Produces: `dispatch_usage` and `unit_close` schema extensions (FR-10 additive savings + invocation fields); `orchestrator:cost` rollup extension (savings-field columns); `orchestrator:status` efficiency footer extension; `orchestrator:doctor` anomaly check extension (compression-regression detection vs baseline); `scripts/diagnostics/compression-eval.sh` (cohort segmentation + outcome-rate delta with CIs; `--tier <N>` filter)
    - Consumes: M019 emitter schema (DEP-3 extension point); M027 `orchestrator:cost`, `orchestrator:status`, `orchestrator:doctor` surfaces (DEP-2 extension points); P02 `payload_filter` + `filter_dropped_tokens`; P03 `tier1_savings_tokens` + `tier1_invocations`; P04 `tier2_savings_tokens`

- [ ] **P06**: Tier 3 Auto-Compact — "At Standard intensity, an oversized section gets routed through `dispatch-interface.sh` with `templates/compression-tier3-prompt.md`; the original persists to `.orchestrator/cache/tier3-originals/`; `tier3_compression_savings_tokens` and `tier3_invocations` appear in `payload_breakdown`. An LLM-call failure passes Tier 2's output through unchanged and emits a `tier3_failed` JSONL record (never crashes the dispatch). T3's `unit_close: pass` is gated by `compression-eval.sh` showing no statistically significant outcome-rate regression vs the uncompressed cohort."
  - Risk: high
  - Depends: P05
  - Boundary Map:
    - Produces: T3 implementation in `build-context.sh` (dispatch-interface.sh-routed summarization with intensity gate + failure-passthrough); `templates/compression-tier3-prompt.md`; `.orchestrator/cache/tier3-originals/` directory tree; `tier3_compression_savings_tokens` + `tier3_invocations` fields in `payload_breakdown` (additive); `tier3_failed` JSONL record schema (additive); intensity-gate wiring (Quick skips T3)
    - Consumes: `references/compression-grammar.md` tier-3 rules (P01); `scripts/dispatch/dispatch-interface.sh` (DEP-7); `scripts/engine/intensity-gate.sh` (DEP-5); `compression-eval.sh` from P05 (verification-ladder gate per RISK-3); cache-prune utility (P03)

- [ ] **P07**: Multi-Runtime Parity — "All zero-LLM tiers (filter, T1, T2) produce byte-identical compressed payloads under Claude Code, Codex CLI, and Cursor for a fixture corpus; the parity test fixture confirms this mechanically. T3 routes through `dispatch-interface.sh` correctly under each runtime. `references/RUNTIME-ASSUMPTIONS.md` records any unavoidable divergences with rationale."
  - Risk: low
  - Depends: P06
  - Boundary Map:
    - Produces: runtime parity test fixtures under `tests/compression-runtime-parity/`; updates to `references/RUNTIME-ASSUMPTIONS.md` (compression entries); multi-runtime CI integration (where applicable)
    - Consumes: filter (P02), T1 (P03), T2 (P04), T3 (P06), `dispatch-interface.sh` (DEP-7)

## Cross-Cutting Concerns

- **In-band marker contract (CON-4)** — affects P02, P03, P04, P06. P01 establishes the marker grammar (`<!-- compressed:tierN ... -->`); each downstream tier conforms. Tooling (eval harness, debug commands) reads markers without parsing JSONL.
- **Preservation contract (FR-2)** — affects P02, P03, P04, P06. P02 establishes the self-check pattern that rejects corrupted preserved-pattern bytes; subsequent tiers reuse it. Self-check failure passes payload through unmodified to the next tier and emits `tier_preservation_violation` JSONL.
- **Additive emitter schema (CON-5)** — affects P02, P03, P04, P05, P06. All M019 schema extensions are additive; pre-M018 records remain readable post-M018; post-M018 records readable by pre-M018 jq filters (missing fields → null). P05 verifies via the eval harness's historical-cohort segmentation.
- **Cache lifecycle (FR-16, FR-17)** — affects P03 (creates `.orchestrator/cache/tool-results/` + ships `cache-prune.sh`), P06 (creates `.orchestrator/cache/tier3-originals/` reusing the prune utility). Cache is disposable; canonical files (knowledge tree, spec/plan/roadmap files) are byte-identical to pre-M018 (Constitution Principle VI).
- **Intensity gating (FR-14)** — affects P06 primarily (Quick skips T3); P02–P04 always run; T4 is out of scope. `scripts/engine/intensity-gate.sh` consumption point lives in `build-context.sh`.
- **Bash-shape-guard compliance (AP-009)** — affects all phases. No compound chains > 2; no inline `$(...)`. Pre-bash-shape-guard hook rejects violations.
- **Conversus gate (FR-18, CON-6)** — affects P01 only. Other phases inherit no gate. Per AD-4, additional `--quick` gates can be added at plan-phase if a phase reveals subjective-quality risk.
- **AGENTS.md dual-write** — affects all phases that touch CLAUDE.md. Run `scripts/util/dual-write-runtime-md.sh` after any CLAUDE.md edit; never edit AGENTS.md directly.
- **`CONVERSUS_PROVIDER=claude-code` on OAuth** — affects P01. Default anthropic 429s are policy gates not transient; the gate run must export `CONVERSUS_PROVIDER=claude-code`.

## Dependency Graph

```
P00 ──► P01 ──► P02 ──► P03 ──► P04 ──► P05 ──► P06 ──► P07
```

Linear DAG. Two structural reasons P02–P04 do not parallelize despite each depending only on P01:

1. **`scripts/dispatch/build-context.sh` write contention** — P02 (filter), P03 (T1), and P04 (T2) all extend the same script. Sequential execution avoids merge conflicts and lets each phase consume the prior phase's preservation-contract self-check + cache-prune utility.
2. **Preservation-contract pattern reuse** — P02 establishes the self-check; P03/P04 import it. Sequential ordering keeps the contract definition single-sourced.

If a future re-decomposition isolates the touch-points (e.g., per-tier modules invoked from build-context.sh), P02–P04 could parallelize on their P01 satisfaction. That is a plan-phase optimization, not a roadmap concern.

## Execution Order

1. **P00** — foundation, no dependencies. Closes when probe parity ≥ 95% and SC-9 threshold is amended into the spec.
2. **P01** — grammar contract; conversus `--strict` gate close. Depends on P00 for SC-9 threshold reference.
3. **P02** — knowledge filter. Depends on P01.
4. **P03** — Tier 1 microcompact. Depends on P02 (build-context.sh contention; cache lifecycle introduction).
5. **P04** — Tier 2 snip. Depends on P03 (build-context.sh contention).
6. **P05** — surfaces + eval harness. Depends on P02+P03+P04 (consumes their savings fields; eval harness scores historical compressed records).
7. **P06** — Tier 3 auto-compact. Depends on P05 (eval harness must be operational before T3 `unit_close: pass` per RISK-3).
8. **P07** — multi-runtime parity. Depends on P06.

**Parallelization**: none. The linear chain is intentional given the build-context.sh contention through P02–P04 and the RISK-3 inversion that places P05 ahead of T3.

**Dogfood inflection** (per CONTEXT.md AD-3): once P03 closes, every M018 dispatch (P04 onwards) runs through filter + T1 at Quick intensity. P04+ phase plans assume compression is on for their own context payloads.

**Legitimate cut points** (per CONTEXT.md AD-5): if schedule pressure emerges mid-execution, P06 (T3) and P07 (multi-runtime) are the candidates — never the minimal slice. Cuts are explicit deviation events, not defaults.

## Validation

- **No conflicting producers**: PASS. Each phase produces distinct artifacts. The shared touch-point (`build-context.sh`) is extended sequentially by P02/P03/P04/P06 with each phase declaring its own functional scope; the file itself is not "produced" by any phase but extended.
- **All consumed items have producers**: PASS. Every `Consumes` entry maps to a `Produces` entry in an upstream phase or a declared external dependency (M019 emitter / M020 status field / M027 surfaces / `dispatch-interface.sh` / `intensity-gate.sh` / conversus adapter — all closed/shipped milestones per A-1, A-2, A-4, A-5, DEP-3, DEP-6, DEP-7).
- **DAG is acyclic**: PASS. Strict linear chain P00 → P07.
- **Demo sentence coverage**: PASS. Every phase has a concrete observable demo grounded in operator-visible commands, JSONL records, or generated artifacts.

### Reordering note (P05/P06 vs CONTEXT.md AD-1)

`M018-CONTEXT.md` AD-1 listed P05=T3 / P06=surfaces+eval (mirroring user-story numbering: US-5=T3, US-6=surfaces, US-7=eval). The roadmap **inverts P05/P06** so the dependency graph runs forward through phase IDs:

- **CONTEXT.md AD-1**: P05 (T3) → P06 (surfaces+eval). Would require P05 to declare a forward dependency on the higher-numbered P06 to honor RISK-3.
- **Roadmap**: P05 (surfaces+eval) → P06 (T3). RISK-3's eval-harness-before-T3-close ordering flows naturally through phase IDs.

The user-story → phase mapping otherwise matches AD-1: P00↔US-0, P01↔US-1, P02↔US-2, P03↔US-3, P04↔US-4, **P05↔US-6+US-7, P06↔US-5**, P07↔US-8. Downstream commands read this roadmap (not CONTEXT.md AD-1) as the authority on phase IDs.

### Risk-ordering note

FR-043 prefers high-risk phases first when dependencies allow. P00 and P01 are both high-risk and execute first naturally (P00 has no deps; P01 unblocks all subsequent phases). P06 (T3) is high-risk but is gated by P05 (RISK-3) — its risk is mitigated by the verification-ladder eval-harness gate, not by execution position. This is consistent with FR-043's intent: high-risk phases that can run early do; high-risk phases gated by quality-control infrastructure run when their gates are operational.
