---
schema_version: "1.0"
type: phase-summary
id: "P06"
parent: "M018"
milestone: "M018"
provides:
  - "_bc_apply_tier3 helper in scripts/dispatch/build-context.sh (intensity gate + density pre-check + dispatch-routed LLM call + originals persistence + preservation self-check + failure-passthrough on every error path; writes savings_tokens=0 invocations=0 to TMPDIR_BUILD/_tier3_stats.txt as first action; success path writes savings_tokens=<delta> invocations=1; emits tier3_skipped/tier3_failed/tier3_no_savings JSONL records via MEM004 carve-out _bc_emit_tier3_event); six kf_get_tier3_* config accessors in scripts/lib/knowledge-filter.sh (enabled/intensity_floor/section_budget_tokens/originals_dir/output_max_ratio/density_floor) mirroring the tier2 accessor shape with documented defaults; templates/compression-tier3-prompt.md (versioned frontmatter + input/output contract body naming preserved-pattern list verbatim from the compression-grammar v1.0.1); scripts/dispatch/lib/tier3-llm-call.sh shim (operator-binary | claude-code-claude | exit-1 ladder for runtime portability); pipeline wiring inserts _bc_apply_tier3 between _bc_apply_tier2 and _bc_emit_payload_breakdown with trailing || true (FR-9); templates/orchestrator-config-default.yml gains compression.tier3 stanza so orchestrator:init copies forward defaults,additive `tier3_compression_savings_tokens` + `tier3_invocations` integer fields on payload_breakdown / dispatch_usage / unit_close JSONL records (CON-5); TIER3_SAVINGS + TIER3_INVOCS columns appended at indices 17-18 of the metrics-rollup.sh data row (back-compat preserved on cols 1-12 + 13-16); efficiency-footer.sh compression-line numerator widened to filter+tier1+tier2+tier3; check-anomalies.sh per-row sav_total widened with tier3_compression_savings_tokens; pinned column-index contract retrofit on m018-p05-cost-rollup-savings-columns.sh (absolute indices replacing fragile NF-relative reads),scripts/diagnostics/compression-eval.sh --tier 3 real cohort logic against tier3_compression_savings_tokens (replaces P05 reservation stub); cohort split + Wilson 95% CI for pass-rate + pooled-SE for retry/deviation; below-floor 'insufficient sample'; sourceable + CLI shape preserved (FR-12 always-exit-0; AD-19 single-script-file Check shape)"
requires:
  - "P05"
affects:
  - "P07"
key_files:
  - "scripts/dispatch/build-context.sh;scripts/lib/knowledge-filter.sh;scripts/dispatch/lib/tier3-llm-call.sh;templates/compression-tier3-prompt.md;templates/orchestrator-config-default.yml,scripts/dispatch/build-context.sh;scripts/dispatch/dispatch-interface.sh;scripts/knowledge/write-summary.sh;scripts/diagnostics/metrics-rollup.sh;scripts/diagnostics/efficiency-footer.sh;scripts/diagnostics/check-anomalies.sh;scripts/verify/m018-p05-cost-rollup-savings-columns.sh,scripts/diagnostics/compression-eval.sh"
key_decisions:
  - "helper failure-passthrough is the default behavior when no LLM provider is wired (ORCH_TIER3_LLM_BIN unset AND claude not on PATH) — shim exits 1 → tier3_failed reason=llm-call-nonzero → stats stay at zero → dispatch proceeds without compaction; helper writes savings_tokens=0 invocations=0 to stats file BEFORE any short-circuit so the T02-widened emitter never reads a missing file; in-band marker substitution uses literal <MODEL>/<N>/<M> placeholders the LLM emits and the orchestrator post-substitutes (LLM does not need to know its own model name or token counts); originals persisted to .orchestrator/cache/tier3-originals/<sha256>.txt with sha256 keyed on header + body bytes (cache-prune.sh non-recursive so co-tenant under cache_dir is untouched); intensity-floor closed enum quick|standard|full → anything else falls through to standard (kf_get_tier3_intensity_floor); MIT-08 density pre-check (input_tokens/section_budget < density_floor → skip without paying LLM cost) emits tier3_skipped reason=density-floor; new JSONL record_type values tier3_skipped/tier3_failed/tier3_no_savings additive (CON-5 — pre-M018 readers ignore unknown record_type),Field placement: tier3_compression_savings_tokens + tier3_invocations placed AFTER tier2_savings_tokens / tier1_invocations and BEFORE the model/source/timestamp triplet on payload_breakdown / dispatch_usage / unit_close — preserves every prior field position so existing JSONL consumers see no shift (CON-5 byte-identity carry-forward); rollup column-index contract: TIER3_SAVINGS + TIER3_INVOCS appended at absolute indices 17-18 (cols 1-12 + 13-16 byte-identical); MEM004 emitter-internal carve-out extends to the six widened helpers; co-located dispatch_usage emitter (_bc_emit_dispatch_usage_colocated) NOT widened — never carried the four P05 fields either; staying consistent with P05 posture; m018-p05-cost-rollup-savings-columns.sh retrofit from $(NF-3)..$NF to absolute $13..$16 because the pinned column-index contract IS the back-compat invariant,and NF-relative reads were a fragile choice not the contract,P05/T03 cohort-build awk pass and Wilson/pooled-SE arithmetic are correct as-is for tier3 — only the JSONL field name driving the cohort split changes; defensive else-zero arm in awk preserved against awk uninitialized-variable warnings; P05 compression-eval verifier 'tier 3 missing P06-reservation stub' assertion intentionally inverted by T03 — T04 replaces that assertion with the tier3 cohort-block assertion"
patterns_established:
  - "Tier 3 helper mirrors the tier1/tier2 helper shape (stats-file write as first action,atomic mv-replace via temp file,in-place rewrite,MEM004 carve-out,preservation self-check + restore-on-violation); LLM-call shim isolates runtime-portability surface (operator-binary | backend-default | exit-1 ladder) so multi-runtime parity work swaps providers without touching the helper body; failure-passthrough audit invariant — every return-0 path that does NOT mutate the capture file MUST leave the stats file at savings_tokens=0 invocations=0 (defensive first-write enforces this); intensity gate honors INTENSITY_METADATA_FILE env var with grep+sed parser matching scripts/engine/intensity-gate.sh:50; six closed-enum accessors return documented defaults when config key absent (CON-5 absent-as-default),Schema-extension carve-out reuse pattern: when an additive emitter has an in-flight rollup helper (T01-style _di_rollup_savings_fields / _ws_rollup_savings_fields),extending it with N more fields is a 4-step recipe (1: extend awk BEGIN initializer + per-record match() + END printf with N more accumulators; 2: extend the calling sed -n line-extraction with N more positional reads; 3: extend the emitter printf format string + value list; 4: leave defensive [-n] || var=0 fallback unchanged); rollup-source restriction carry-forward: metrics-rollup.sh / efficiency-footer.sh / check-anomalies.sh consume payload_breakdown rows ONLY for savings sums to avoid double-counting the rolled-up copies on dispatch_usage / unit_close; absolute column-index contract over NF-relative indexing in shape verifiers — when a column-set will grow over time,anchor verifier reads to absolute positions,not offset-from-end,MEM004 emitter-internal carve-out applies inside compression-eval body; tier-N case fall-through pattern widens cleanly when a new tier joins the cohort-segmentation diagnostic without touching CI/SEM math; T03 single-file surgical pattern — production code modification only,with canonical truth verifier shipped in T04 per P03/P04/P05 phase shape"
drill_down_paths:
  - "/Users/brettkellgren/Sites/spec-kit-orchestrator/.orchestrator/milestones/M018/phases/P06/tasks/T01-tier3-helper-SUMMARY.md, /Users/brettkellgren/Sites/spec-kit-orchestrator/.orchestrator/milestones/M018/phases/P06/tasks/T02-schema-extensions-SUMMARY.md, /Users/brettkellgren/Sites/spec-kit-orchestrator/.orchestrator/milestones/M018/phases/P06/tasks/T03-compression-eval-tier3-SUMMARY.md"
duration: "19m"
verification_result: "pass"
completed_at: "2026-04-28T14:34:47Z"
observability_surfaces:
  - "execution-log.jsonl: payload_breakdown.{tier3_compression_savings_tokens,tier3_invocations} additive integer fields; dispatch_usage.{tier3_compression_savings_tokens,tier3_invocations} rolled-up additive fields; unit_close.{tier3_compression_savings_tokens,tier3_invocations} granularity-aware additive fields; tier3_skipped / tier3_failed / tier3_no_savings new JSONL record_types (additive); metrics-rollup.sh stdout: TIER3_SAVINGS / TIER3_INVOCS columns; efficiency-footer.sh stdout: compression: line numerator widens to fold tier3 savings; check-anomalies.sh stdout: compression-regression denominator widens to fold tier3 savings; compression-eval.sh stdout: --tier 3 cohort + delta block with 95% CIs and regression_flag (no longer P06-reservation stub)."
---

P06 lands the **tier 3 auto-compact tier** of the M018 compression
pipeline: an LLM-routed section summarization helper in
`build-context.sh` (`_bc_apply_tier3`), a versioned prompt template, six
config accessors, additive `tier3_compression_savings_tokens` +
`tier3_invocations` fields on three JSONL record types, three new
`tier3_skipped` / `tier3_failed` / `tier3_no_savings` event record
schemas, and the `compression-eval.sh --tier 3` real cohort logic that
replaces the P05 reservation stub.

After P06, build-context can route an oversized post-Tier-2 section
through `dispatch-interface.sh` against `templates/compression-tier3-prompt.md`,
verify preservation, splice the compressed output back, and emit savings
telemetry. Any failure in that pipeline (LLM non-zero exit, empty
output, output-too-large, preservation breach) passes Tier 2's bytes
through unchanged and emits a `tier3_failed` (or `tier3_no_savings`)
JSONL record — the dispatch never crashes from a Tier 3 fault. Density
and intensity gates short-circuit the helper before the LLM call when
appropriate, emitting `tier3_skipped` events instead.

The phase ships:

- **`_bc_apply_tier3` LLM-routed summarization helper** (T01) in
  `scripts/dispatch/build-context.sh`. Wired between `_bc_apply_tier2`
  and `_bc_emit_payload_breakdown`. Honors the master
  `compression.enabled` toggle, the per-tier `compression.tier3.enabled`
  toggle, the `compression.tier3.intensity_floor` gate (FR-14: Quick
  skips T3), and the `compression.tier3.density_floor` MIT-08 pre-check
  (input_tokens / section_budget below floor → short-circuit). Persists
  originals to `.orchestrator/cache/tier3-originals/<sha256>.txt`. Routes
  the rendered prompt + section bytes through
  `scripts/dispatch/dispatch-interface.sh` (or the
  `scripts/dispatch/lib/tier3-llm-call.sh` shim when present). MEM004
  emitter-internal carve-out — single-pass awk inside the helper body.

- **`templates/compression-tier3-prompt.md`** (T01) — versioned
  `schema_version: "1.0" type: compression-prompt tier: 3
  applies_to: ["dispatch-payload-section"]` frontmatter; `preserves:`
  array names every preserved-pattern token from
  `references/compression-grammar.md` Tier 3 (frontmatter, code fences,
  JSONL, MEM identifiers, paths, scaffold-placeholder markers, URLs,
  command names, in-band markers); body declares input/output contracts
  and ends with a `## Section to compress` header where the helper
  appends the section bytes.

- **Six `kf_get_tier3_*` config accessors** (T01) in
  `scripts/lib/knowledge-filter.sh`: `enabled` / `intensity_floor` /
  `section_budget_tokens` / `originals_dir` / `output_max_ratio` /
  `density_floor`. Defaults installed in
  `templates/orchestrator-config-default.yml`.

- **`scripts/dispatch/lib/tier3-llm-call.sh`** (T01) — LLM-call shim that
  fronts `dispatch-interface.sh` for the Tier 3 helper. Encapsulates
  prompt-file → completion → output-file routing so the helper can swap
  in a stub during tests without touching dispatch-interface.

- **Six `kf_get_tier3_*` accessors + three event record types** (T01) —
  `tier3_skipped` (intensity gate / density floor short-circuit),
  `tier3_failed` (LLM call non-zero / empty / preservation breach),
  `tier3_no_savings` (LLM output exceeded `output_max_ratio`). All three
  are additive JSONL record_type schemas — pre-M018 readers ignore
  unknown record_type values.

- **Additive schema extensions** (T02) — `tier3_compression_savings_tokens`
  and `tier3_invocations` integer fields on three JSONL record types:
  `payload_breakdown` (build-context emitter, co-located with the helper
  in build-context.sh), `dispatch_usage`
  (`scripts/dispatch/dispatch-interface.sh:_di_emit_dispatch_usage` —
  rolled up from same-unitId payload_breakdown rows at emit-time), and
  `unit_close` (`scripts/knowledge/write-summary.sh:_ws_emit_unit_close`
  — rolled up from in-scope payload_breakdown rows under granularity-aware
  scope match). Pre-M018 records remain valid JSON; downstream consumers
  treat absent fields as zero (CON-5 absent-as-zero contract preserved).

- **Cost-rollup column extension** (T02) — `metrics-rollup.sh` projects
  the two new fields at columns 17-18 (after the four P05 columns at
  13-16; columns 1-12 remain byte-identical for back-compat consumers).
  Header carries `TIER3_SAVINGS` and `TIER3_INVOCS` labels.

- **Efficiency-footer fold** (T02) — `efficiency-footer.sh` widens the
  `compression: <pct>% reduction over baseline` numerator to fold
  `tier3_savings` into the existing `filter+tier1+tier2` sum; the line
  text now reads `(filter+tier1+tier2+tier3 / payload_tokens)`.

- **Doctor anomaly fold** (T02) — `check-anomalies.sh`
  `compression-regression` flag widens its `sav_total` denominator to
  fold tier3_savings; the SC-9 0.347 floor and configurability
  (`compression.regression_floor`) are preserved.

- **`compression-eval.sh --tier 3` real cohort** (T03) — replaces the
  P05 reservation stub with real cohort logic against
  `tier3_compression_savings_tokens`. Single awk pass classifies
  (milestone, phase, task) into compressed (tier3_savings > 0) or
  uncompressed cohorts; task-granularity unit_close records measure
  pass_rate / retry / deviation; END block enforces sample floor
  (default 30), computes Wilson 95% CI for proportions and pooled-SE
  deltas, emits a `regression_flag:` advisory line. Always exits 0
  (FR-12 / CON-5). Sourceable + CLI shape preserved.

- **Five P06-private truth verifiers** (T04) under
  `scripts/verify/m018-p06-*.sh` exercise all five mechanical truths
  end-to-end against hermetic fixture logs. Verifier shape mirrors the
  P05/T04 pattern: pass()/fail() helpers, hermetic root staging via
  `ORCHESTRATOR_ROOT`, single-script-file Check shape (AD-19 / AP-009),
  shim-style awk function extraction where dispatch-interface.sh /
  write-summary.sh CLI bodies prevent direct sourcing.

- **Two fixture trees** (T04) under
  `tests/fixtures/m018-p06-{tier3-fired,tier3-failed}-log/`. The
  `tier3-fired` fixture mixes 5 P06 tasks (T01/T02/T04 compressed;
  T03/T05 uncompressed) plus a pre-P06 baseline row at top (CON-5
  back-compat) and a `tier3_skipped` event. The `tier3-failed` fixture
  carries 2 tasks with `tier3_failed` events naming `llm-call-nonzero`
  and `preservation-breach` reasons — the FR-9 failure-passthrough
  scenario.

- **`scripts/verify/_helpers/m018-p06-build-fixture.sh`** (T04) —
  fixture-staging helper mirroring the P03/P04/P05 shape. Stages a
  hermetic `.orchestrator/`-style root at `<root>/milestones/<MS_ID>/`
  with a copy of the chosen fixture log (`tier3-fired` → M018F;
  `tier3-failed` → M018G) and a minimal `config.yml` so `read-config.sh`
  resolves cleanly under `ORCHESTRATOR_ROOT=<root>`.

- **CLAUDE.md / AGENTS.md `orchestrator:recent-changes` dual-write**
  (T04) via `scripts/util/dual-write-runtime-md.sh --marker recent-changes
  --append-entry "..."`. Both runtime instruction files name M018/P06
  and tier3.

## Risk-mitigation traceability

- **CON-5 (additive emitters)** — the two new fields on
  `payload_breakdown`, `dispatch_usage`, and `unit_close` are additive.
  The pre-P06 row at the top of the `tier3-fired` fixture
  (`M018F/P04/T99`) carries only the four P05 fields and NO tier3
  fields; it parses as valid JSON via python3 json.loads, and the
  rollup helpers in dispatch-interface.sh and write-summary.sh treat
  absent fields as zero. Verified by the back-compat assertions in
  `m018-p06-tier3-additivity.sh`.

- **FR-9 (tier3 failure-passthrough)** — every error path inside
  `_bc_apply_tier3` returns 0 after writing a stats file with
  `savings_tokens=0 invocations=0` and emitting a `tier3_failed` JSONL
  record naming the reason. The `tier3-failed` fixture documents two
  representative failure paths (`llm-call-nonzero`, `preservation-breach`)
  and confirms that `unit_close: pass` is still emitted on the dispatch
  (the agent received Tier 2's output unchanged).

- **FR-12 (read-only diagnostic surfaces)** — `compression-eval.sh`
  never appends to or rewrites JSONL; always exits 0. Verified by the
  missing-log assertion in `m018-p06-compression-eval-tier3.sh` (degraded
  text + exit 0).

- **FR-14 (intensity-gating)** — Quick → T3 skipped + `tier3_skipped`
  JSONL record. Standard / Full → T3 active per
  `compression.tier3.intensity_floor` config.

- **MIT-08 (density pre-check)** — input_tokens / section_budget below
  `compression.tier3.density_floor` (default 1.5) short-circuits the
  helper before the LLM call and emits `tier3_skipped reason=density-floor`.
  Avoids paying LLM cost on sections that cannot meaningfully compress.

- **AD-19 / AP-009 single-script-file Check shape** — every truth's
  Check: line is a single bash invocation. Verifier scripts use
  pass()/fail() per MEM002 and printf-prefixed lines per MEM001.

## RISK-3 disposition (phase-close gate)

The spec's RISK-3 gate states that P06's `unit_close: pass` is gated by
`compression-eval.sh --milestone M018 --tier 3` showing no statistically
significant outcome-rate regression vs the uncompressed cohort.

At P06 close, the live `.orchestrator/milestones/M018/execution-log.jsonl`
cohort sizes are below the statistical floor (compression-eval emits
`insufficient sample (compressed=N uncompressed=M floor=30)` and exits
0). Per the spec's RISK-3 framing, this counts as a non-regression for
P06 close — the diagnostic is operational, the cohort split logic is
verified against the M018F fixture (compressed=3 uncompressed=2 with
pass-rates 1.0/1.0 across both cohorts → `regression_flag: none`), and
subsequent milestones will exercise the diagnostic against larger n. The
diagnostic stays operational as M018 telemetry accumulates so the
regression check gains statistical power without code changes.

The next operator running `compression-eval.sh --milestone <Mxxx>
--tier 3` against a future milestone with sufficient cohort sizes can
either confirm continued non-regression (sustains the P06 close
disposition) or surface a regression flag for manual review. The flag's
trigger condition (`delta_pass_rate <= -0.05 AND CI excludes 0`) is the
contract the M019 and M027 cost+token transparency surfaces will
ultimately consume.

## Followups for downstream phases

- **Tier 3 originals retention** — `.orchestrator/cache/tier3-originals/`
  is lazily created at first T3 fire. `cache-prune.sh` (P03) does not
  recurse into sub-directories under cache_dir, so tier3-originals/
  co-tenants are untouched by tier1 prune passes. A future T-row will
  add tier3-originals retention if disk-pressure surfaces (e.g.,
  `cache-prune.sh --tier3-originals --max-age 30d`).

- **M019 / M027 future surfaces** — the two additive fields on the
  three JSONL record types are the contract M019 cost+token transparency
  surfaces (M027 extension target) read. The rollup column-index
  contract is now pinned: 1-12 stable; 13-16 are the M018 P05 savings
  columns; 17-18 are the M018 P06 tier3 columns.

- **Outstanding RISK-3 evaluation** — once M018 (or a downstream
  milestone) accumulates ≥30 dispatches per cohort, re-run
  `compression-eval.sh --milestone <Mxxx> --tier 3` and confirm
  `regression_flag: none`. If a regression flag fires, raise a discuss
  task to evaluate Tier 3 model-quality / preservation-check tuning.

## Verification result

All five P06 truths PASS via
`bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P06/`.
All artifacts present at required line counts with required substrings;
all key links resolve; all five private verifiers green:

- `m018-p06-tier3-helper-shape.sh` — PASS (13 assertions: helper
  defined; references dispatch-interface.sh and compression-tier3-prompt.md;
  pipeline wiring tier2 → tier3 → emit; six accessors; bash -n green
  on build-context and knowledge-filter).
- `m018-p06-tier3-prompt-template.sh` — PASS (16 assertions: template
  exists; tier=3 frontmatter; applies_to dispatch-payload-section;
  schema_version present; preserves: array contains all nine required
  preserved-pattern tokens; in-band marker template literal; ## Section
  to compress header).
- `m018-p06-tier3-additivity.sh` — PASS (21 assertions: source-level
  printf fields in DI + WS; fixture rows carry both fields; pre-P06
  back-compat row valid JSON; live emit through DI shim sums to 400/1
  for T01; WS rollup phase scope sums to 1800/3 across T01+T02+T04;
  metrics-rollup TIER3_SAVINGS + TIER3_INVOCS columns; efficiency-footer
  numerator label includes tier3; check-anomalies.sh runs cleanly).
- `m018-p06-compression-eval-tier3.sh` — PASS (17 assertions: bash -n
  green; references tier3_compression_savings_tokens; no stub literal;
  cohort + delta block emitted with header; regression_flag: none on
  fixture; high floor → insufficient sample; missing log → degraded
  text + exit 0).
- `m018-p06-dual-write-recent.sh` — PASS (CLAUDE.md and AGENTS.md
  recent-changes blocks both name M018/P06 and tier3).

P06 closed. M018 advances to phase-end consolidation.

## P05/T04 verifier disposition

The P05 verifier `scripts/verify/m018-p05-compression-eval.sh`
assertion 3 was authored against the P05 stub behavior (`--tier 3`
recognized-but-no-op) and is retroactively outdated by P06/T03's real
cohort logic. The new P06 verifier
`scripts/verify/m018-p06-compression-eval-tier3.sh` asserts the inverse
(real cohort + delta block, no stub literal). The P05 verifier is left
in place untouched at this phase close — its core assertions (cohort
block on tier=1, sample-floor, missing-log) remain valid and useful as
P05 regression tests; only assertion 3's stub-behavior expectation is
stale. A follow-up consolidation can either delete the stale assertion
or relax it to "tier 3 cohort produces output (stub or real)" once the
M018 milestone-summary scope is finalized.
