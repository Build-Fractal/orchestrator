---
schema_version: "1.0"
type: task-summary
id: "T01"
parent: "P06"
milestone: "M018"
provides:
  - "_bc_apply_tier3 helper in scripts/dispatch/build-context.sh (intensity gate + density pre-check + dispatch-routed LLM call + originals persistence + preservation self-check + failure-passthrough on every error path; writes savings_tokens=0 invocations=0 to TMPDIR_BUILD/_tier3_stats.txt as first action; success path writes savings_tokens=<delta> invocations=1; emits tier3_skipped/tier3_failed/tier3_no_savings JSONL records via MEM004 carve-out _bc_emit_tier3_event); six kf_get_tier3_* config accessors in scripts/lib/knowledge-filter.sh (enabled/intensity_floor/section_budget_tokens/originals_dir/output_max_ratio/density_floor) mirroring the tier2 accessor shape with documented defaults; templates/compression-tier3-prompt.md (versioned frontmatter + input/output contract body naming preserved-pattern list verbatim from the compression-grammar v1.0.1); scripts/dispatch/lib/tier3-llm-call.sh shim (operator-binary | claude-code-claude | exit-1 ladder for runtime portability); pipeline wiring inserts _bc_apply_tier3 between _bc_apply_tier2 and _bc_emit_payload_breakdown with trailing || true (FR-9); templates/orchestrator-config-default.yml gains compression.tier3 stanza so orchestrator:init copies forward defaults"
requires:
  - "from:M018/P02 what:scripts/lib/preservation-check.sh (pres_check_section + pres_emit_violation cross-tier vocabulary); from:M018/P03/T01 what:_bc_apply_tier1 stats-file pattern + helper shape (canonical contract mirrored by tier3); from:M018/P04/T01 what:_bc_apply_tier2 helper shape + cross-tier preservation refusal pattern; from:M018/P01 what:references/compression-grammar.md v1.0.1 (preserved-pattern list named verbatim in prompt template)"
affects:
  - "P06/T02 (extends _bc_emit_payload_breakdown to read TMPDIR_BUILD/_tier3_stats.txt and emit tier3_compression_savings_tokens + tier3_invocations additive integer fields on payload_breakdown); P06/T03 (replaces compression-eval.sh --tier 3 reservation stub with a real cohort against tier3_compression_savings_tokens); P06/T04 (ships canonical truth verifiers m018-p06-tier3-helper-shape.sh + m018-p06-tier3-prompt-template.sh + dual-write recent-changes blocks); future P07 multi-runtime parity (tier3-llm-call.sh shim is the swap surface)"
key_files:
  - "scripts/dispatch/build-context.sh;scripts/lib/knowledge-filter.sh;scripts/dispatch/lib/tier3-llm-call.sh;templates/compression-tier3-prompt.md;templates/orchestrator-config-default.yml"
key_decisions:
  - "helper failure-passthrough is the default behavior when no LLM provider is wired (ORCH_TIER3_LLM_BIN unset AND claude not on PATH) — shim exits 1 → tier3_failed reason=llm-call-nonzero → stats stay at zero → dispatch proceeds without compaction; helper writes savings_tokens=0 invocations=0 to stats file BEFORE any short-circuit so the T02-widened emitter never reads a missing file; in-band marker substitution uses literal <MODEL>/<N>/<M> placeholders the LLM emits and the orchestrator post-substitutes (LLM does not need to know its own model name or token counts); originals persisted to .orchestrator/cache/tier3-originals/<sha256>.txt with sha256 keyed on header + body bytes (cache-prune.sh non-recursive so co-tenant under cache_dir is untouched); intensity-floor closed enum quick|standard|full → anything else falls through to standard (kf_get_tier3_intensity_floor); MIT-08 density pre-check (input_tokens/section_budget < density_floor → skip without paying LLM cost) emits tier3_skipped reason=density-floor; new JSONL record_type values tier3_skipped/tier3_failed/tier3_no_savings additive (CON-5 — pre-M018 readers ignore unknown record_type)"
patterns_established:
  - "Tier 3 helper mirrors the tier1/tier2 helper shape (stats-file write as first action, atomic mv-replace via temp file, in-place rewrite, MEM004 carve-out, preservation self-check + restore-on-violation); LLM-call shim isolates runtime-portability surface (operator-binary | backend-default | exit-1 ladder) so multi-runtime parity work swaps providers without touching the helper body; failure-passthrough audit invariant — every return-0 path that does NOT mutate the capture file MUST leave the stats file at savings_tokens=0 invocations=0 (defensive first-write enforces this); intensity gate honors INTENSITY_METADATA_FILE env var with grep+sed parser matching scripts/engine/intensity-gate.sh:50; six closed-enum accessors return documented defaults when config key absent (CON-5 absent-as-default)"
drill_down_paths:
  - ".orchestrator/milestones/M018/phases/P06/tasks/T01-tier3-helper-PAYLOAD.md;.orchestrator/milestones/M018/phases/P06/P06-PLAN.md;.orchestrator/milestones/M018/phases/P06/tasks/T01-tier3-helper-PLAN.md"
duration: "~3h"
verification_result: "pass"
completed_at: "2026-04-28T12:28:48Z"
---

T01 ships the production-code surface for Tier 3 auto-compact: the LLM-routed section-summarization helper, its config accessors, its prompt template, and its runtime-portability shim. Verifiers / fixtures / dual-write land in T04.

Verification (Tier 1 must-haves per task plan + smoke harness against the merged build-context.sh):

- bash -n scripts/dispatch/build-context.sh — clean exit 0.
- bash -n scripts/lib/knowledge-filter.sh — clean exit 0.
- bash -n scripts/dispatch/lib/tier3-llm-call.sh — clean exit 0.
- All six kf_get_tier3_* accessors return documented defaults against the orchestrator project config (which does not yet carry compression.tier3): enabled=true, intensity_floor=standard, section_budget_tokens=2500, originals_dir=.orchestrator/cache/tier3-originals/, output_max_ratio=0.80, density_floor=1.5.
- Helper smoke test (oversized section + no LLM provider wired): rc=0; stats file at savings_tokens=0 invocations=0; tier3_failed JSONL record emitted with reason=llm-call-nonzero; capture file unchanged.
- Helper density-floor short-circuit (density 105/50 = 2.1 < floor 5): rc=0; stats=0; tier3_skipped reason=density-floor density=105/50 floor=5.
- Helper master-toggle off (COMPRESSION_ENABLED=false): rc=0; stats=0; NO log emit (silent passthrough).
- grep -F "declare -A" across the three modified files: only matches a comment line in tier3-llm-call.sh — bash 3.2 clean (MEM001).
- build-context.sh entry-point smoke: standard CONFIG-error envelope unchanged.

Truths addressed (subset per the task plan): #1 (_bc_apply_tier3 + dispatch-interface routing + prompt template) and #2 (templates/compression-tier3-prompt.md frontmatter + body). Truths #3 (additivity), #4 (compression-eval cohort), #5 (dual-write recent-changes) are T02/T03/T04 scope.

Gotchas worth surfacing for downstream tasks:

1. dispatch-interface.sh CLI does NOT expose --prompt-file / --capture-output / --max-output-tokens / --timeout-seconds — it routes via --task-plan / --payload / --intensity-metadata / --backend to backend adapters. This is why the shim ships as Step 6 contingent. The helper auto-detects scripts/dispatch/lib/tier3-llm-call.sh as executable and prefers it over dispatch-interface.sh.

2. The shim is intentionally a no-op (exit 1) when no LLM provider is wired (ORCH_TIER3_LLM_BIN unset AND ORCH_BACKEND != claude-code OR claude not on PATH). This is the safe default — failure-passthrough fires, the dispatch proceeds without compaction, and operators opt in by setting ORCH_TIER3_LLM_BIN to a binary that honors the four-flag contract.

3. T02 reads $TMPDIR_BUILD/_tier3_stats.txt to populate the additive payload_breakdown fields. The defensive first-write of savings_tokens=0 invocations=0 means T02 never has to handle a missing file — every code path through _bc_apply_tier3 leaves the stats file in a known shape.

4. The originals dir defaults to .orchestrator/cache/tier3-originals/ (relative to PROJECT_ROOT). cache-prune.sh from P03 uses for f in "$CACHE_DIR"/* with no recursion, so tier3-originals/ co-tenants are untouched by tier1 prune passes — operator-driven prune only (originals-authoritative principle).

5. AD-19 / AP-009: every Check at task-plan level is a single-script-file invocation. The task-local Check is bash -n scripts/dispatch/build-context.sh; canonical truth verifiers ship in T04.

6. CON-5 additive-only: three new JSONL record_type values (tier3_skipped, tier3_failed, tier3_no_savings) are additive — pre-M018 readers ignore unknown record_type per the M018 carry-forward contract.
