---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M018"
goal: "Land the Knowledge-Aware Filter — the first tier consumer of the P01 grammar contract — and ship the reusable preservation-contract self-check library + aggregate-savings underperformance emitter that P03/P04/P06 will reuse. After P02, every dispatch's Knowledge section drops `status: superseded` / `status: experimental` entries before payload assembly, emits a `payload_filter` JSONL record, and carries a new additive `filter_dropped_tokens` field on the existing `payload_breakdown` record."
demo_sentence: "Operator runs `bash scripts/dispatch/build-context.sh ...` against a fixture milestone whose knowledge tree contains entries marked `status: superseded`; the resulting payload's Knowledge section omits those entries; `execution-log.jsonl` carries a new `payload_filter` record naming the dropped IDs and tokens; the `payload_breakdown` record carries a new `filter_dropped_tokens` field; pre-M018 records still parse cleanly under back-compat (CON-5)."
risk: "medium"
depends_on: ["P01"]
---

## Must-Haves

### Truths

<!-- Per AD-19, every Check is a single-script-file invocation. No inline
     compound bash, no plain subshells, no $(... | ...) containing pipes.
     See commands/plan-phase.md for the full forbidden-shape enumeration. -->

- `scripts/dispatch/build-context.sh` reads each knowledge entry's `status:` field and excludes entries whose value matches the configured drop-list (`compression.knowledge_filter.drop_list`, default `["superseded", "experimental"]`) before payload assembly. Entries without a `status:` field default to `stable` and are never dropped (FR-3 back-compat per A-1).
  - Check: `bash scripts/verify/m018-p02-filter-drops.sh`

- When the filter drops at least one entry, a `payload_filter` JSONL record is appended to `execution-log.jsonl` naming `{filter, drop_list, dropped_count, dropped_tokens, dropped_ids, source: runtime}`; the existing `payload_breakdown` record carries an additive `filter_dropped_tokens` field. Pre-M018 records remain valid JSON (CON-5 — additive emitter).
  - Check: `bash scripts/verify/m018-p02-emitter-additivity.sh`

- The preservation-contract self-check library `scripts/lib/preservation-check.sh` exposes `pres_check_section` (regex-driven pattern walker that compares pre- and post-transform byte spans for every preserved-pattern row from `references/compression-grammar.md` `## Preserved-Pattern Vocabulary`), `pres_emit_violation` (writes `tier_preservation_violation` JSONL), and `pres_density_pre_check` (refuses tier3 invocation when input density exceeds the configured threshold per MIT-08). Library is bash 3.2 compatible, sourceable, and pure (no global writes other than the named emitter).
  - Check: `bash scripts/verify/m018-p02-preservation-check-api.sh`

- The aggregate-savings self-check emits a `compression_underperformance` JSONL record when the running mean payload-token reduction across the last N dispatches falls below the SC-9 calibrated 34.7% floor (MIT-09). The check is operational signal — never blocks dispatch. The threshold and window are config-driven (`compression.underperformance.window_size`, `compression.underperformance.floor_pct`).
  - Check: `bash scripts/verify/m018-p02-underperformance-emit.sh`

- `compression.enabled: false` in `.orchestrator/config.yml` short-circuits the entire filter path; the resulting payload's Knowledge bytes are byte-identical to a pre-M018 baseline run captured against the same fixture (FR-15 / SC-8 regression test against a checked-in golden fixture).
  - Check: `bash scripts/verify/m018-p02-disable-flag-honored.sh`

- CLAUDE.md and AGENTS.md `orchestrator:recent-changes` blocks both name M018/P02 close (dual-write produced via `scripts/util/dual-write-runtime-md.sh` — never edit AGENTS.md directly).
  - Check: `bash scripts/verify/m018-p02-dual-write-recent.sh`

### Artifacts

- `scripts/lib/preservation-check.sh` (min 80 lines, contains "pres_check_section")
- `scripts/dispatch/build-context.sh` (modified — must contain "filter_dropped_tokens", "payload_filter", "knowledge_filter.drop_list")
- `.orchestrator/config.yml` (modified — must contain "compression:")
- `templates/orchestrator-config-default.yml` (modified — must contain "knowledge_filter")
- `tests/fixtures/m018-p02-knowledge-status/README.md` (min 20 lines, contains "status: superseded")
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` (min 5 lines, contains "Knowledge")
- `scripts/verify/m018-p02-filter-drops.sh` (min 40 lines, contains "status: superseded")
- `scripts/verify/m018-p02-emitter-additivity.sh` (min 40 lines, contains "payload_filter")
- `scripts/verify/m018-p02-preservation-check-api.sh` (min 30 lines, contains "pres_check_section")
- `scripts/verify/m018-p02-underperformance-emit.sh` (min 30 lines, contains "compression_underperformance")
- `scripts/verify/m018-p02-disable-flag-honored.sh` (min 30 lines, contains "compression.enabled")
- `scripts/verify/m018-p02-dual-write-recent.sh` (min 20 lines, contains "M018/P02")
- `.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md` (min 40 lines, contains "PASS")

### Key Links

- `.orchestrator/milestones/M018/phases/P02/P02-PLAN.md` → `.orchestrator/milestones/M018/M018-ROADMAP.md`
- `.orchestrator/milestones/M018/phases/P02/P02-PLAN.md` → `specs/030-context-compression-layer/spec.md`
- `scripts/lib/preservation-check.sh` → `references/compression-grammar.md`
- `scripts/dispatch/build-context.sh` → `scripts/lib/preservation-check.sh`
- `scripts/dispatch/build-context.sh` → `references/compression-grammar.md`
- `scripts/verify/m018-p02-filter-drops.sh` → `tests/fixtures/m018-p02-knowledge-status`

## Tasks

### T01: Preservation-contract self-check library + density pre-check API

See `.orchestrator/milestones/M018/phases/P02/tasks/T01-preservation-check-lib-PLAN.md`.

### T02: Knowledge-aware filter in build-context.sh + config key + payload_filter emitter + filter_dropped_tokens field

See `.orchestrator/milestones/M018/phases/P02/tasks/T02-knowledge-filter-PLAN.md`.

### T03: Aggregate-savings underperformance self-check + compression_underperformance emitter

See `.orchestrator/milestones/M018/phases/P02/tasks/T03-underperformance-emitter-PLAN.md`.

### T04: Phase verifiers + dual-write recent-changes + P02-SUMMARY

See `.orchestrator/milestones/M018/phases/P02/tasks/T04-verifiers-and-summary-PLAN.md`.

## Task Dependencies

```
T01 ──► T02 ──► T03 ──► T04
```

T01 ships the reusable preservation-check library + density pre-check API (MIT-10 + MIT-08 groundwork) — no callers yet, but P03/P04/P06 will source it. T02 wires the Knowledge-aware filter into `build-context.sh`, lands the config key, and extends the emitter schema additively (FR-3, FR-4, MIT-10 caller wires `pres_check_section` defensively even though the filter operates on whole-entry granularity per the grammar contract `## Tier: filter` failure semantics — the wiring exists so the same hook covers tier1/tier2/tier3 by the time those phases land). T03 adds the aggregate-savings self-check that emits `compression_underperformance` records (MIT-09). T04 ships every phase-truth verifier, the dual-write recent-changes refresh, and the P02-SUMMARY.

T02 cannot start until T01's library is sourceable. T03 reads the `payload_breakdown` record schema T02 establishes. T04 verifies the union of T01–T03 outputs.

## Files Likely Touched

- `scripts/lib/preservation-check.sh` (create — T01)
- `scripts/dispatch/build-context.sh` (modify — T02 adds knowledge filter + emitter extension; T03 adds aggregate self-check)
- `.orchestrator/config.yml` (modify — T02 adds `compression:` block; T03 adds `compression.underperformance:` keys)
- `templates/config-defaults.yml` (modify — T02 + T03 mirror new defaults)
- `tests/fixtures/m018-p02-knowledge-status/` (create — T02 fixture milestone with mixed-status MEMs)
- `tests/fixtures/m018-p02-knowledge-status/README.md` (create — T02)
- `tests/fixtures/m018-p02-baseline-payload.golden.txt` (create — T02 golden capture)
- `scripts/verify/m018-p02-filter-drops.sh` (create — T04)
- `scripts/verify/m018-p02-emitter-additivity.sh` (create — T04)
- `scripts/verify/m018-p02-preservation-check-api.sh` (create — T04)
- `scripts/verify/m018-p02-underperformance-emit.sh` (create — T04)
- `scripts/verify/m018-p02-disable-flag-honored.sh` (create — T04)
- `scripts/verify/m018-p02-dual-write-recent.sh` (create — T04)
- `CLAUDE.md` (modify — T04 refreshes `orchestrator:recent-changes` block)
- `AGENTS.md` (modify — T04 via `scripts/util/dual-write-runtime-md.sh`; never edited directly)
- `.orchestrator/milestones/M018/phases/P02/P02-SUMMARY.md` (create — T04)
