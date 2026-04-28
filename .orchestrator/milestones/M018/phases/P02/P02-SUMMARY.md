---
schema_version: "1.0"
type: phase-summary
id: P02
parent: M018
milestone: M018
provides: "knowledge-aware injection filter live in scripts/dispatch/build-context.sh + scripts/dispatch/lib/section-handlers.sh; preservation-contract self-check library scripts/lib/preservation-check.sh (sourceable: pres_check_section / pres_emit_violation / pres_density_pre_check); payload_filter JSONL record schema (record_type=payload_filter; fields: filter, drop_list, dropped_count, dropped_tokens, dropped_ids, source); payload_breakdown.filter_dropped_tokens additive field; compression_underperformance JSONL record (operational signal — never blocks); compression.knowledge_filter.* + compression.underperformance.* config keys + ORCH_OVERRIDE_COMPRESSION_ENABLED env override; six P02-private truth verifiers + tests/fixtures/m018-p02-knowledge-status fixture + golden baseline; CLAUDE.md/AGENTS.md recent-changes refresh"
requires: "P01 grammar contract Reviewed (references/compression-grammar.md v1.0.1); P00 SC-9 calibrated 34.7% floor; M020 status: field on knowledge entries (DEP-1)"
affects: "P03 (T1 microcompact — sources scripts/lib/preservation-check.sh; reuses tier_preservation_violation + payload_breakdown schema; consumes filter savings via additive filter_dropped_tokens field); P04 (T2 snip — same lib + per-tier savings field, MIT-01 nested-fence regex load-bearing); P05 (eval harness — reads compression_underperformance + payload_filter + future tier_preservation_violation records); P06 (T3 auto-compact — wires pres_density_pre_check before LLM call per MIT-08; tier-3-savings field additive)"
key_files: "scripts/lib/preservation-check.sh;scripts/lib/knowledge-filter.sh;scripts/dispatch/build-context.sh;scripts/dispatch/lib/section-handlers.sh;.orchestrator/config.yml;templates/config-defaults.yml;tests/fixtures/m018-p02-knowledge-status/knowledge-stream.md;tests/fixtures/m018-p02-knowledge-status/README.md;tests/fixtures/m018-p02-baseline-payload.golden.txt;scripts/verify/m018-p02-filter-drops.sh;scripts/verify/m018-p02-emitter-additivity.sh;scripts/verify/m018-p02-preservation-check-api.sh;scripts/verify/m018-p02-underperformance-emit.sh;scripts/verify/m018-p02-disable-flag-honored.sh;scripts/verify/m018-p02-dual-write-recent.sh;scripts/verify/_helpers/m018-p02-build-fixture.sh"
key_decisions: "Filter operates on whole-entry granularity per grammar contract `## Tier: filter` failure semantics — no interior preservation check at the entry level; preservation-check library sourced defensively in build-context.sh + section-handlers.sh so P03/P04/P06 inherit a working source path; filter is awk-driven for speed + AP-009 compliance; underperformance check is operational signal (never blocks dispatch); P02-stage logs may legitimately fall below the floor (tier1/2/3 not yet shipped) — handled via min_sample_size guard (default 10); ORCH_OVERRIDE_COMPRESSION_ENABLED env beats config (test seam, FR-15 SC-8); fail-open on missing status field (FR-3 / A-1 back-compat)"
patterns_established: "Sourceable lib pattern under scripts/lib/ for cross-tier reuse (T01 — preservation-check); pure-library pattern with optional config-aware accessors (T02 — knowledge-filter); awk-driven entry-boundary detection in bash 3.2 stream filters (T02); additive JSONL emitter pattern with stats-file handoff between collector and emitter (T02); operational-signal JSONL records that never block dispatch (T03 — compression_underperformance); fixture milestone + golden-payload diff pattern for compression-disabled regression (T04 — disable-flag-honored)"
drill_down_paths: ".orchestrator/milestones/M018/phases/P02/tasks/T01-preservation-check-lib-SUMMARY.md;.orchestrator/milestones/M018/phases/P02/tasks/T02-knowledge-filter-SUMMARY.md;.orchestrator/milestones/M018/phases/P02/tasks/T03-underperformance-emitter-SUMMARY.md;.orchestrator/milestones/M018/phases/P02/tasks/T04-verifiers-and-summary-SUMMARY.md"
duration: "~6h"
verification_result: pass
observability_surfaces: "execution-log.jsonl: payload_filter record_type, payload_breakdown.filter_dropped_tokens additive field, compression_underperformance record_type, tier_preservation_violation record_type (emitter library shipped, callers wired in P03+)"
completed_at: "2026-04-27T00:00:00Z"
---

# Phase Summary: M018/P02 — Knowledge-Aware Filter + Preservation-Check Library + Underperformance Emitter

## Closure summary

P02 lands the **foundation tier** of the M018 compression pipeline: the knowledge-aware status filter, the reusable preservation-contract self-check library, and the aggregate-savings underperformance emitter. After P02, every dispatch's `## Knowledge` section drops `status: superseded` and `status: experimental` entries before payload assembly. The filter is awk-driven, bash 3.2 compatible, and runs through `scripts/lib/knowledge-filter.sh` from both the planning branch (`build-context.sh _bc_apply_knowledge_filter`) and the task-dispatch branch (`section-handlers.sh _sh_apply_knowledge_filter`).

The phase also ships:

- **Reusable preservation-contract self-check library** (`scripts/lib/preservation-check.sh`) that P03 (tier1), P04 (tier2), and P06 (tier3) source. Three exported functions: `pres_check_section` (regex pattern walker over the cross-tier vocabulary), `pres_emit_violation` (writes `tier_preservation_violation` JSONL), `pres_density_pre_check` (MIT-08 groundwork — refuses tier3 invocation when input density exceeds threshold).
- **Aggregate-savings underperformance signal emitter** (`_bc_emit_compression_underperformance` in `build-context.sh`) — operational signal, never blocks dispatch. Awk-driven running mean over the last N `payload_breakdown` records' filter+tier savings ratio; emits `compression_underperformance` JSONL record when below the SC-9 calibrated 34.7% floor (gated by `min_sample_size` to prevent spurious early-stage emission).
- **MIT-08 density-pre-check API surface** — caller wired in P06.
- **Disable-flag golden-payload regression contract** — `compression.enabled: false` short-circuits the entire filter path; output is byte-identical to the checked-in golden baseline (FR-15 / SC-8 verifiable from now on).

**Dogfood inflection**: P03 onward, every M018 dispatch (and every other orchestrator dispatch in this repo) runs through the knowledge-aware filter. Subsequent M018 task payloads will start carrying live `payload_filter` records once knowledge entries with retired statuses accumulate.

## Risk-mitigation traceability

- **MIT-08 (P02 entry gate from P01 conversus deliberation)** — LLM preservation trust boundary: `pres_density_pre_check` ships in `scripts/lib/preservation-check.sh` (T01). The function exists as an API surface here; P06 plumbs it in front of tier3's LLM call. Density-x100 integer math (no floats — bash 3.2) returns refuse when matches/total_bytes exceeds the configured threshold.
- **MIT-09 (P02 entry gate from P01 conversus deliberation)** — SC-9 threshold operational fragility: `_bc_emit_compression_underperformance` in `scripts/dispatch/build-context.sh` (T03) emits `compression_underperformance` JSONL when running-mean savings falls below the 34.7% floor. Window size, floor pct, min sample size, and enabled flag all config-driven via `compression.underperformance.*`.
- **MIT-10 (P02, THREAT-09 from P01 conversus deliberation)** — preservation-contract self-check algorithmic specification: `pres_check_section` in `scripts/lib/preservation-check.sh` (T01) is the regex-driven pattern walker (one pass per preserved-pattern row from grammar `## Preserved-Pattern Vocabulary`); byte-mismatch on any preserved span triggers passthrough plus `tier_preservation_violation` emission via `pres_emit_violation`.

## Followups for downstream phases

- **P03 (tier1 microcompact)** — sources `scripts/lib/preservation-check.sh` and reuses the cache-prune utility pattern; consumes filter savings via the additive `filter_dropped_tokens` field on `payload_breakdown`. The `payload_breakdown` schema P02 established carries forward unchanged.
- **P04 (tier2 snip)** — same library; the MIT-01 nested-fence regex (`^\`{3,}[a-zA-Z0-9_-]*$`) is load-bearing for P04's head-drop boundary detection.
- **P05 (eval harness)** — reads `compression_underperformance` + `payload_filter` + future `tier_preservation_violation` records from `execution-log.jsonl` per the additive-emitter invariants section of the grammar contract.
- **P06 (tier3 auto-compact)** — wires `pres_density_pre_check` before the LLM call per MIT-08; tier-3-savings field additive on `payload_breakdown`. MIT-08 LLM-preservation enforcement is a P06 unit_close gate, not a P02 gate.

## Verification result

All P02 truths PASS via `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M018/phases/P02/`. All artifacts present, all key links resolve, all six private verifiers green:

- `m018-p02-filter-drops.sh` — PASS (MEM901+MEM903 dropped, MEM900/902/904 retained, fail-open MEM902 honored).
- `m018-p02-emitter-additivity.sh` — PASS (emitter source + live filter_dropped_tokens + pre/post-T02 JSON shape).
- `m018-p02-preservation-check-api.sh` — PASS (3 functions sourceable; selftest green).
- `m018-p02-underperformance-emit.sh` — PASS (running_mean_pct < 34.7 floor; sample_size >= 10).
- `m018-p02-disable-flag-honored.sh` — PASS (override→false reported; baseline byte-identical to fixture; short-circuit guard present in build-context.sh).
- `m018-p02-dual-write-recent.sh` — PASS (M018/P02 named in CLAUDE.md + AGENTS.md recent-changes blocks).

P02 closed. M018 advances to P03.
