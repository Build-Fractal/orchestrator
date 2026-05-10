---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M018"
goal: "Tier 1 microcompact — page oversized inline tool-result blocks to a SHA-256-keyed cache, reuse cache references across dispatches, and surface tier1_savings_tokens + tier1_invocations on payload_breakdown additively"
demo_sentence: "After P03, a build-context.sh dispatch whose payload contains a tool-result block above the configured inline threshold emits a `<tool-result file=\".orchestrator/cache/tool-results/<sha256>\" preview-lines=\"5\">` reference instead of the full body; the original persists at that path; a second dispatch with the same command+input reuses the same reference; payload_breakdown carries non-zero tier1_savings_tokens and tier1_invocations; cache-prune.sh --max-age 7d evicts old entries; compression.enabled: false leaves the P02 golden payload byte-identical"
risk: "medium"
depends_on: ["P02"]
---

## Must-Haves

### Truths

<!-- AD-19: every Check is a single-script-file invocation. No inline
     compound bash, no plain subshells, no $(...|...). One verifier per
     truth, parked under scripts/verify/m018-p03-*.sh. -->

- Tier 1 paging replaces oversized inline tool-result blocks with a `<tool-result file="..." preview-lines="...">` reference and persists the original to `.orchestrator/cache/tool-results/<sha256>`.
  - Check: `bash scripts/verify/m018-p03-tier1-paging.sh`
- Cache reuse: a second dispatch with an identical tool-call (matched on SHA-256 of command+input) reuses the same cache entry without rewriting the file (mtime preserved).
  - Check: `bash scripts/verify/m018-p03-cache-reuse.sh`
- `payload_breakdown` JSONL records carry additive `tier1_savings_tokens` and `tier1_invocations` integer fields; pre-T1 records remain valid JSON; missing fields default to 0 in rollups (CON-5).
  - Check: `bash scripts/verify/m018-p03-emitter-additivity.sh`
- `scripts/util/cache-prune.sh --max-age 7d` removes cache files older than 7d by mtime and leaves newer files alone; safe to invoke against an empty or missing cache directory.
  - Check: `bash scripts/verify/m018-p03-cache-prune.sh`
- `compression.enabled: false` short-circuits Tier 1 entirely; the P02 disable-flag golden payload (`tests/fixtures/m018-p02-baseline-payload.golden.txt`) remains byte-identical against the P03 build-context.sh; `compression.tier1.enabled: false` short-circuits only Tier 1 (filter still runs).
  - Check: `bash scripts/verify/m018-p03-disable-flag-honored.sh`
- Body-level preservation self-check: when Tier 1 modifies a section, `pres_check_section` (P02 library) is invoked over the post-paging body and any failure causes Tier 1 to pass the section through unmodified plus emit a `tier_preservation_violation` JSONL record (`record_type=tier_preservation_violation`, `tier=tier1`).
  - Check: `bash scripts/verify/m018-p03-preservation-self-check.sh`
- CLAUDE.md and AGENTS.md `recent-changes` blocks both name "M018/P03" or "tier1" — phase-close dual-write via `scripts/util/dual-write-runtime-md.sh`.
  - Check: `bash scripts/verify/m018-p03-dual-write-recent.sh`

### Artifacts

- `scripts/dispatch/build-context.sh` (min 1500 lines, contains "tier1")
- `scripts/util/cache-prune.sh` (min 60 lines, contains "--max-age")
- `scripts/verify/m018-p03-tier1-paging.sh` (min 30 lines, contains "tool-result file=")
- `scripts/verify/m018-p03-cache-reuse.sh` (min 30 lines, contains "cache-reuse")
- `scripts/verify/m018-p03-emitter-additivity.sh` (min 30 lines, contains "tier1_savings_tokens")
- `scripts/verify/m018-p03-cache-prune.sh` (min 30 lines, contains "--max-age")
- `scripts/verify/m018-p03-disable-flag-honored.sh` (min 30 lines, contains "compression.enabled")
- `scripts/verify/m018-p03-preservation-self-check.sh` (min 30 lines, contains "tier_preservation_violation")
- `scripts/verify/m018-p03-dual-write-recent.sh` (min 20 lines, contains "recent-changes")
- [`.orchestrator/milestones/M018/phases/P03/P03-SUMMARY.md`](../../../../milestones/M018/phases/P03/P03-SUMMARY.md) (min 40 lines, contains "tier1_savings_tokens")
- `.orchestrator/config.yml` (min 60 lines, contains "tier1")
- `tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md` (min 20 lines, contains "tool-result")

### Key Links

- `scripts/dispatch/build-context.sh` → `scripts/lib/preservation-check.sh` (sources the P02 library to invoke `pres_check_section` after Tier 1 paging)
- `scripts/util/cache-prune.sh` → `.orchestrator/cache/tool-results/` (prunes mtime-aged entries from the cache root)
- `CLAUDE.md` → `M018/P03` (recent-changes block names the phase)
- `AGENTS.md` → `M018/P03` (recent-changes block names the phase)

## Tasks

### T01: Tier 1 paging + cache lookup/reuse in build-context.sh

(Plan in `tasks/T01-tier1-paging-PLAN.md`.)

### T02: cache-prune.sh utility + cache lifecycle hardening

(Plan in `tasks/T02-cache-prune-PLAN.md`.)

### T03: Verifiers, fixture, preservation self-check wiring, P03-SUMMARY + dual-write

(Plan in `tasks/T03-verifiers-and-summary-PLAN.md`.)

## Task Dependencies

```
T01 → T03
T02 → T03
T01 ⟂ T02   (T01 and T02 have no shared edits; can run in parallel)
```

## Files Likely Touched

- `scripts/dispatch/build-context.sh` (modify) — add `compression.tier1.*` config reads, the paging + cache-lookup function, the additive `tier1_*` fields on `_bc_emit_payload_breakdown`, and the post-paging `pres_check_section` invocation
- `scripts/util/cache-prune.sh` (create) — new utility script
- `.orchestrator/config.yml` (modify) — append `compression.tier1.*` block under the existing `compression:` map
- `tests/fixtures/m018-p03-tool-result/dispatch-payload-fixture.md` (create) — fixture payload with one oversized inline tool-result block plus one undersized one
- `tests/fixtures/m018-p03-tool-result/README.md` (create) — fixture description
- `scripts/verify/m018-p03-tier1-paging.sh` (create)
- `scripts/verify/m018-p03-cache-reuse.sh` (create)
- `scripts/verify/m018-p03-emitter-additivity.sh` (create)
- `scripts/verify/m018-p03-cache-prune.sh` (create)
- `scripts/verify/m018-p03-disable-flag-honored.sh` (create)
- `scripts/verify/m018-p03-preservation-self-check.sh` (create)
- `scripts/verify/m018-p03-dual-write-recent.sh` (create)
- `scripts/verify/_helpers/m018-p03-build-fixture.sh` (create) — fixture-staging helper
- [`.orchestrator/milestones/M018/phases/P03/P03-SUMMARY.md`](../../../../milestones/M018/phases/P03/P03-SUMMARY.md) (create)
- `CLAUDE.md` (modify) — refresh `orchestrator:recent-changes` block to name M018/P03
- `AGENTS.md` (modify) — same content (dual-write via `scripts/util/dual-write-runtime-md.sh`)
