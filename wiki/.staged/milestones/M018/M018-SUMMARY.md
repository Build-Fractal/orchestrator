---
schema_version: "1.0"
type: milestone-summary
id: "M018"
parent: "030-context-compression-layer"
milestone: "M018"
provides:
  - "knowledge-aware injection filter; Tier 1 microcompact (tool-result paging + SHA-256 disposable cache); Tier 2 snip (head-drop + protected tail + boundary-refusal walker); Tier 3 auto-compact (dispatch-routed LLM summarization with intensity gate + density pre-check + failure-passthrough); operator surfaces (cost rollup compression columns, efficiency-footer compression line, doctor compression-regression flag); compression-eval.sh cohort-segmentation diagnostic; multi-runtime parity diagnostics (zero-LLM byte-equality + Tier 3 routing); references/RUNTIME-ASSUMPTIONS.md registry; references/compression-grammar.md v1.0.1 (Reviewed via conversus); preservation-check library; cache-prune.sh utility"
requires:
  - "M019 emitter (Tier 1 — co-located dispatch_usage emit); M020 status: field on knowledge entries; conversus adapter (scripts/dispatch/adapters/tool/conversus.sh); scripts/dispatch/dispatch-interface.sh (DEP-7); scripts/engine/intensity-gate.sh (DEP-5); M027 metrics-rollup.sh / efficiency-footer.sh / check-anomalies.sh extension targets (DEP-2)"
affects:
  - "M027 cost + efficiency surfaces gain compression rollup columns + footer line + doctor regression flag (no further M027 work required); M009 launch-gate runtime-parity audit consumes references/RUNTIME-ASSUMPTIONS.md RA-M018-NN rows; downstream milestones inherit byte-identical pre-M018 payload when compression.enabled=false (FR-15 / SC-8); M019 future cost+token transparency surfaces read the additive savings fields"
key_files:
  - "scripts/dispatch/build-context.sh; scripts/lib/knowledge-filter.sh; scripts/lib/preservation-check.sh; scripts/dispatch/lib/tier3-llm-call.sh; scripts/util/cache-prune.sh; scripts/diagnostics/compression-eval.sh; scripts/diagnostics/m018-runtime-parity.sh; scripts/diagnostics/m018-runtime-parity-tier3.sh; scripts/diagnostics/m018-section-distribution.sh; scripts/diagnostics/metrics-rollup.sh; scripts/diagnostics/efficiency-footer.sh; scripts/diagnostics/check-anomalies.sh; references/compression-grammar.md; references/RUNTIME-ASSUMPTIONS.md; templates/compression-tier3-prompt.md; templates/orchestrator-config-default.yml"
key_decisions:
  - "SC-9 calibrated to 34.7% mean payload-token reduction floor (P00 probe-derived 80% CI lower bound replaces unbacked 25% placeholder); CON-5 additive-only emitter schema (cols 1-12 stable; 13-16 P05; 17-18 P06); phase-transition.sh --write canonical close path (write-summary.sh phase retired after P05/T04 SYNC:MISMATCH); P05/P06 inversion vs CONTEXT.md AD-1 (eval harness gates T3 close per RISK-3); Tier 3 master enabled:true but operator-binary-required to engage (provider-resolution ladder takes failure-passthrough without ORCH_TIER3_LLM_BIN or claude on PATH); CONVERSUS_PROVIDER=claude-code mandatory on OAuth (anthropic 429s are policy gates not transient); SHA-256 full-digest cache key with mtime-only prune (no reference counting needed when key is content-addressed); MEM004 emitter-internal carve-out extends to JSONL rollup helpers and diagnostic CLI bodies; documented-divergence carve-out on P07 verifiers (accepts regression_flag: divergence iff RA-M018-NN row documents it)"
patterns_established:
  - "Sourceable lib pattern under scripts/lib/ for cross-tier reuse (preservation-check shared by T1/T2/T3); preservation-check failure-passthrough (restore pre-tier capture byte-identical + emit tier_preservation_violation); SHA-256 keyed disposable cache (FR-16 / FR-17) with cache-reuse short-circuit-on-write (mtime preserved); intensity-gate consumed exclusively in build-context.sh via INTENSITY_METADATA_FILE; in-band tier-marker grammar (CON-4) — uniform <!-- compressed:tierN <kvpairs> --> shape; additive emitter schema discipline (CON-5) with rollup column-index contract pinned over time; MEM004 emitter-internal carve-out for awk pipes inside dispatch / diagnostic / rollup helpers; LLM-call shim isolates runtime-portability surface (operator-binary | backend-default | exit-1 ladder); RUNTIME-ASSUMPTIONS.md registry pattern for M009 launch-gate audit consumption; hermetic-fixture-with-knowledge-snapshot parity-runner pattern; awk-driven entry-boundary detection in bash 3.2 stream filters; documented-divergence carve-out (verifier asserts documentation discipline rather than suppressing observations)"
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P00/P00-SUMMARY.md,.orchestrator/milestones/M018/phases/P01/P01-SUMMARY.md,.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md,.orchestrator/milestones/M018/phases/P03/P03-SUMMARY.md,.orchestrator/milestones/M018/phases/P04/P04-SUMMARY.md,.orchestrator/milestones/M018/phases/P05/P05-SUMMARY.md,.orchestrator/milestones/M018/phases/P06/P06-SUMMARY.md,.orchestrator/milestones/M018/phases/P07/P07-SUMMARY.md"
duration: "~30h"
verification_result: "pass"
completed_at: "2026-04-28T16:19:17Z"
observability_surfaces:
  - "execution-log.jsonl record_types: payload_filter, payload_breakdown (additive filter_dropped_tokens / tier1_savings_tokens / tier2_savings_tokens / tier1_invocations / tier3_compression_savings_tokens / tier3_invocations), dispatch_usage (additive same six fields, rolled up), unit_close (additive same six fields, granularity-aware roll-up), compression_underperformance, tier_preservation_violation, tier3_skipped, tier3_failed, tier3_no_savings, runtime_parity; metrics-rollup.sh stdout: FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS / TIER3_SAVINGS / TIER3_INVOCS columns at indices 13-18; efficiency-footer.sh stdout: compression: <pct>% reduction over baseline (filter+tier1+tier2+tier3 / payload_tokens) tail; check-anomalies.sh stdout: FLAGGED ... reasons=compression-regression; compression-eval.sh stdout: cohort + delta block with 95% CIs and regression_flag advisory; m018-runtime-parity.sh / m018-runtime-parity-tier3.sh stdout: per-runtime SHA-256 / routing lines + parity summaries + regression_flag advisory; references/RUNTIME-ASSUMPTIONS.md: # Compression (M018) block with RA-M018-NN divergence rows"
---

# Milestone Summary: M018 — Context Compression Layer

## What was built

M018 lands a four-tier "caveman-style" context compression pipeline plus its
observability and runtime-parity surfaces, executed in eight phases (P00–P07,
all closed PASS). Compression is default-on (`compression.enabled: true`) but
every tier is independently togglable; with the master flag off the dispatch
payload is byte-identical to pre-M018.

- **P00 — Measurement prerequisites.** Co-located the [M019](../../milestones/M019/index.md) `dispatch_usage`
  emitter inside `scripts/dispatch/build-context.sh` so every payload_breakdown
  carries a sibling dispatch_usage record (parity gap RISK-1 closed via
  fixture-replay at 100% over 20 dispatches). Shipped
  `scripts/diagnostics/m018-section-distribution.sh` with bootstrap CIs and
  amended SC-9 to a probe-derived 34.7% mean payload-token reduction floor
  (RISK-2 closed; aggregate 80% CI low_pct=34.73%).
- **P01 — Grammar contract + conversus gate.**
  `references/compression-grammar.md` v1.0.1 (Reviewed) names per-tier
  `applies-to` artifact classes, `preserves` byte-pattern regexes, savings
  ceilings, and FR-2 failure semantics. Conversus `--strict` red/blue gate
  ran twice — first BLOCK (two P0 grammar bugs: nested 4+-backtick fences and
  JSONL-in-fenced-code), second PASS after single-line MIT-01 / MIT-02 fixes.
  Gate ran with `CONVERSUS_PROVIDER=claude-code` per OAuth policy memory.
- **P02 — Knowledge-aware filter.** Awk-driven entry filter drops
  `status: superseded` / `status: experimental` knowledge entries before
  payload assembly, sourced from both planning and dispatch branches via
  `scripts/lib/knowledge-filter.sh`. Shipped the reusable
  `scripts/lib/preservation-check.sh` library (3 functions —
  `pres_check_section`, `pres_emit_violation`, `pres_density_pre_check`) that
  P03/P04/P06 inherit, plus the `compression_underperformance` operational
  signal emitter (running-mean savings vs SC-9 floor, never blocks dispatch).
- **P03 — Tier 1 microcompact.** `_bc_apply_tier1` pages oversized inline
  tool-result blocks (>1500 tokens default) into `<tool-result file=...
  preview-lines=5 ...>` references; originals persist to
  `.orchestrator/cache/tool-results/<sha256>.txt` keyed by SHA-256(command +
  0x1F + input); cache reuse short-circuits writes (mtime preserved). Shipped
  `scripts/util/cache-prune.sh --max-age <N>{d|h|m}` mtime-based eviction
  utility. First cache-bearing tier; first dogfood inflection — every dispatch
  from P03 onward runs through filter + T1.
- **P04 — Tier 2 snip.** `_bc_apply_tier2` head-drops in-scope section bodies
  (Knowledge / Task Plan / Upstream Context) above
  `compression.tier2.section_budget_tokens` while preserving
  `compression.tier2.protected_tail_ratio` of bytes byte-identical at the
  tail. Boundary-refusal walker tracks 4+-backtick fences by tick-count
  (MIT-01) and frontmatter `---` delimiters; on no-safe-boundary, section
  passes through unmodified plus a `tier_preservation_violation` JSONL.
  In-band marker `<!-- compressed:tier2 head_dropped=N protected_tail_ratio=R -->`
  named immediately after the section heading (CON-4 grammar).
- **P05 — Surfaces + eval harness.** Schema extensions on `dispatch_usage`
  and `unit_close` (additive `filter_dropped_tokens` / `tier1_savings_tokens`
  / `tier2_savings_tokens` / `tier1_invocations`, rolled up at emit-time
  from in-scope payload_breakdown rows; granularity-aware scope match for
  `unit_close`). `metrics-rollup.sh` gains four new columns at indices 13–16;
  `efficiency-footer.sh` gains a `compression: <pct>% reduction` tail line;
  `check-anomalies.sh` gains a `compression-regression` reason gated by
  sav_total > 0 AND ratio < SC-9 floor (configurable via
  `compression.regression_floor`, default 0.347).
  `scripts/diagnostics/compression-eval.sh` is the new sourceable + CLI
  cohort-segmentation diagnostic (Wilson 95% CI for proportions,
  pooled-SE for retry/deviation deltas, sample-floor default 30, `--tier <N>`
  filter, always-exit-0 per FR-12).
- **P06 — Tier 3 auto-compact.** `_bc_apply_tier3` routes oversized
  post-Tier-2 sections through `scripts/dispatch/dispatch-interface.sh`
  (or `scripts/dispatch/lib/tier3-llm-call.sh` shim) against
  `templates/compression-tier3-prompt.md`; originals persist to
  `.orchestrator/cache/tier3-originals/<sha256>.txt`. Failure-passthrough
  (FR-9) on every error path: LLM non-zero, empty output, output-too-large,
  preservation breach all leave Tier 2's bytes untouched and emit
  `tier3_failed` (or `tier3_no_savings`) JSONL. MIT-08 density pre-check
  short-circuits before paying LLM cost (`tier3_skipped reason=density-floor`).
  FR-14 intensity gate: Quick skips T3 (`tier3_skipped reason=intensity-gate`).
  Additive `tier3_compression_savings_tokens` / `tier3_invocations` fields on
  `payload_breakdown` / `dispatch_usage` / `unit_close`; rollup columns
  appended at indices 17–18; efficiency-footer numerator widens to
  `filter+tier1+tier2+tier3`; `compression-eval.sh --tier 3` replaces the P05
  reservation stub with real cohort logic.
- **P07 — Multi-runtime parity.** Hermetic byte-equality proof for the
  zero-LLM tiers (filter / T1 / T2) under claude-code, codex, and cursor
  via `scripts/diagnostics/m018-runtime-parity.sh` against the
  `tests/compression-runtime-parity/` fixture corpus. Tier 3 routing parity
  proved via `scripts/diagnostics/m018-runtime-parity-tier3.sh` driving a
  deterministic `_stubs/tier3-stub-llm.sh` through the operator-binary path
  of `tier3-llm-call.sh`. Inherent runtime divergences (Tier 3 native model +
  pricing per runtime; `claude` CLI PATH presence) are documented in
  `references/RUNTIME-ASSUMPTIONS.md` `# Compression (M018)` block as
  RA-M018-01 / RA-M018-02 with M009 launch-gate audit-row link placeholders.
  Knowledge-snapshot + restore pattern works around `build-context.sh`'s
  hardcoded `PROJECT_ROOT` so `increment-hits.sh` side-effects do not
  perturb cross-runtime byte-equality.

## Cross-cutting patterns

- **Additive emitter schema (CON-5).** Every M019 schema extension is
  additive — pre-M018 records remain valid JSON; rollups treat absent fields
  as zero. The rollup column-index contract is now pinned: cols 1–12 stable
  ([M027](../../milestones/M027/index.md)), 13–16 are M018/P05 (filter + tier1 + tier2 fields), 17–18 are
  M018/P06 (tier3 fields). Verified by historical-log diff in every
  emitter-additivity verifier across P02/P03/P04/P05/P06.
- **Preservation contract (FR-2).** `pres_check_section` regex pattern
  walker runs over the cross-tier preserved-pattern vocabulary
  (frontmatter, code fences, JSONL, MEM identifiers, paths, scaffold-placeholder
  markers, URLs, command names, in-band markers) before/after each tier
  transformation. Byte-mismatch on any preserved span triggers passthrough
  (restore pre-tier capture file byte-identical) plus a
  `tier_preservation_violation` JSONL emit (tier=tier1 / tier2 / tier3).
- **In-band marker grammar (CON-4).** Each tier emits its marker on its own
  line in a uniform `<!-- compressed:tierN <kvpairs> -->` shape so tooling
  can scan the payload without parsing JSONL. Downstream tiers wrap, never
  mutate, upstream tier markers.
- **Cache lifecycle (FR-16, FR-17).** Two disposable cache trees under
  `.orchestrator/cache/`: `tool-results/` (T1, SHA-256 of command + input)
  and `tier3-originals/` (T3, SHA-256 of header + body). Both are co-tenants
  under a single non-recursive `cache-prune.sh` utility (single-level glob;
  Constitution VI: canonical files on disk byte-identical to pre-M018).
- **Intensity gating (FR-14).** Consumed exclusively in `build-context.sh`
  via `INTENSITY_METADATA_FILE` (parsed by
  `scripts/lib/knowledge-filter.sh:kf_resolve_intensity`). Quick skips T3;
  Standard / Full run T3 per `compression.tier3.intensity_floor`. P02–P04
  always run.
- **MEM004 emitter-internal carve-out.** AD-19 single-script-file invocation
  shape constrains agent-facing tool invocations only; emitter-internal
  helper bodies (the four `_bc_apply_*` helpers, the
  `_di_rollup_savings_fields` / `_ws_rollup_savings_fields` rollups, and the
  diagnostic CLI bodies) use awk pipes / single-pass extraction freely.

## Verification posture

`bash scripts/lifecycle/validate-milestone.sh M018` PASS 75/75. Every phase
closed via `bash scripts/lifecycle/phase-transition.sh --write` (the
canonical roadmap+disk atomic-transition path; `write-summary.sh phase`
hit a SYNC:MISMATCH at P05/T04 and was retired in favor of the lifecycle
helper for closing tasks). Per-phase verifier counts: P00 — 2 truths,
P01 — 6 truths, P02 — 6 truths, P03 — 7 truths, P04 — 7 truths, P05 — 8
truths, P06 — 5 truths, P07 — 3 truths. All green; documented-divergence
carve-out on the P07 zero-LLM verifier accepts `regression_flag: divergence`
iff a corresponding `RA-M018-NN` row exists in
`references/RUNTIME-ASSUMPTIONS.md`.

## Operator-visible surfaces

- `metrics-rollup.sh --milestone <M>` — six new compression columns
  (FILTER_DROPPED / TIER1_SAVINGS / TIER2_SAVINGS / TIER1_INVOCS at 13–16;
  TIER3_SAVINGS / TIER3_INVOCS at 17–18).
- `efficiency-footer.sh --milestone <M>` — `compression: <pct>% reduction
  over baseline (filter+tier1+tier2+tier3 / payload_tokens)` tail line.
- `check-anomalies.sh` — composes `compression-regression` reason
  additively with cost-spike / retry-spike / low-pass-rate.
- `compression-eval.sh --milestone <M> --tier <N>` — cohort segmentation
  (compressed vs uncompressed) with 95% CIs and regression-flag advisory.
- `m018-runtime-parity.sh` / `m018-runtime-parity-tier3.sh` — hermetic
  cross-runtime byte-equality and routing-parity diagnostics; both always
  exit 0 (FR-12), divergence surfaces via `regression_flag:` advisory.
- `references/RUNTIME-ASSUMPTIONS.md` — registry document for the M009
  launch-gate runtime-parity audit; `# Compression (M018)` block names
  the two inherent divergences with M009 audit-row link placeholders.

## Key non-obvious decisions

- **P05/P06 inversion vs CONTEXT.md AD-1.** `M018-CONTEXT.md` AD-1 listed
  P05=T3 / P06=surfaces+eval (mirroring user-story numbering); the roadmap
  inverted to P05=surfaces+eval / P06=T3 so RISK-3's
  eval-harness-before-T3-close ordering flows naturally through phase IDs
  without forward dependencies.
- **`phase-transition.sh --write` as canonical close path.**
  `write-summary.sh phase` was the original convention but hit a
  SYNC:MISMATCH at P05/T04 (roadmap and on-disk summary updated
  non-atomically). The lifecycle helper is the right surface — it writes
  the summary and the roadmap-checkbox in one atomic transition. Adopted
  verbatim by P06/T04 and P07/T03.
- **Tier 3 default-on master gate, operator-binary-required to engage.**
  `compression.tier3.enabled: true` is the M018 default, but the helper's
  provider-resolution ladder (`ORCH_TIER3_LLM_BIN` →
  `claude-code-claude` → `exit 1`) means without an operator-installed
  binary the helper takes the failure-passthrough path on every fire
  (`tier3_failed reason=llm-call-nonzero`). Stats stay at zero;
  dispatch proceeds with Tier 2's bytes. This is intentional — the
  routing surface is on, the LLM trust boundary is operator-opt-in.
- **CONVERSUS_PROVIDER=claude-code on OAuth.** P01 conversus gate runs
  hit anthropic 429s as a policy gate (not transient); the gate must
  export `CONVERSUS_PROVIDER=claude-code` to traverse the OAuth path.
  Captured in user memory; reused by every future conversus gate.
- **SHA-256 keyed disposable cache, mtime-only prune.** Cache key full
  digest (no truncation; collision domain dominated by hash space) keeps
  the prune utility correct without reference counting. Future
  reference-aware preservation deferred — the current cache lifecycle
  is mtime-correct because the key is fully content-addressed and
  cache files are physically valid bodies even when their on-payload
  delta later fails preservation self-check.

## Downstream effects

- **M027 cost + efficiency surfaces** consume the additive savings
  fields with no further changes required; the rollup column-index
  contract is pinned through P06 (cols 1–18 stable).
- **M009 launch-gate runtime-parity audit** consumes
  `references/RUNTIME-ASSUMPTIONS.md` — RA-M018-NN rows carry M009
  audit-row link placeholders the audit will replace with real IDs.
- **Future milestones** running with `compression.enabled: false` see
  byte-identical pre-M018 dispatch payloads (FR-15 / SC-8 verifiable
  against the P02 golden-payload fixture).
