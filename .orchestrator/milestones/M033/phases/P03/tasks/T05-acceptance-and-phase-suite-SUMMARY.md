---
schema_version: "1.0"
type: task-summary
task: "T05"
phase: "P03"
milestone: "M033"
name: "SC-2 + SC-3 acceptance + phase-suite + cross-phase regression + scope-guard + SSOT harmonization"
status: complete
date: 2026-05-04
---

# T05 — Summary

## Deliverables

### Acceptance scripts (purely additive)
- `tests/m033-acceptance/p02-constitution-author.sh` — SC-2 (FR-3/FR-4/FR-5/FR-6 across web-saas/cli-tool/library; idempotency; --force regen warning; unknown-stack rejection; standalone-gate). Pass=36/0.
- `tests/m033-acceptance/p03-ingest-codebase.sh` — SC-3 (FR-7/FR-8 across 3 stack fixtures; rich-context import on TS-saas with DR cross-refs; sentinel resolution; build-context.sh --profile=quick boundary check; US-3 AS-5 minimum-viable-seed). Pass=29/0.

### Verifiers (purely additive)
- `tools/verify/m033-p03-acceptance-shape-sc2.sh` — token + functional smoke for SC-2 (pass=22/0).
- `tools/verify/m033-p03-acceptance-shape-sc3.sh` — token + functional smoke for SC-3 (pass=21/0).
- `tools/verify/m033-p03-cross-phase-regression.sh` — AD-15 P01+P02 regression invariant (pass=2/0).
- `tools/verify/m033-p03-scope-guard.sh` — bidirectional scope-guard, P04/P05 forbidden + P03 whitelist + P02 boundary preservation + wiki/M033 narrowing (pass=45/0).
- `tools/verify/m033-p03-phase-suite.sh` — chains 13 sub-verifiers (T01..T04 task-shape + T05 SC-2/SC-3 acceptance-shape) (pass=13/0).

### SSOT harmonization (light touch on T01/T02/T03/T04 SSOT prose)
1. `references/m033-fr21-dual-write-convention.md` — Call-site shape amended to the real flag form `--root <project> --marker recent-changes --append-entry "<text>"`. Added `### Aliases / historical wording` note clarifying the historical positional `append <fragment>` shorthand is not implemented.
2. `scripts/util/start-state-markers.sh` — comment block added documenting the FR-7 alias mapping `ingest-codebase` (enum) ↔ `ingest-codebase-completed.complete` (FR-7 doc-prose) for the same on-disk marker. Narrower fix per Step 3 instructions.
3. `scripts/util/jsonl-event-emitter.sh` — closed-enum count harmonized 11 → 12 (header doc + comment list + fenced SSOT block); `imported_context_loaded` (T04 addition per #Q-11) is now formally the 12th token. P02 verifier still passes (it never asserted the count, only the token list).

## Verification status

All required gates green:
- 11 T01..T04 task-shape verifiers — PASS (no regression).
- `bash scripts/verify/standalone-gate.sh constitution` — pass=7 skip=0 fail=0.
- `bash tests/m033-acceptance/p02-constitution-author.sh` — exit 0, pass=36 fail=0.
- `bash tests/m033-acceptance/p03-ingest-codebase.sh` — exit 0, pass=29 fail=0.
- `bash tools/verify/m033-p03-phase-suite.sh` — pass=13 fail=0.
- `bash tools/verify/m033-p03-cross-phase-regression.sh` — pass=2 fail=0.
- `bash tools/verify/m033-p03-scope-guard.sh` — pass=45 fail=0.
- `bash tools/verify/m033-p01-phase-suite.sh` — pass=14 fail=0 (no P01 regression).
- `bash tools/verify/m033-p02-phase-suite.sh` — pass=10 fail=0 (no P02 regression).

## Deviations + rationale

### Deviation 1: FR-7 5-floor in SC-3 acceptance vs. fixture reality
**Issue:** PLAN step 2c specifies `[ "$mem_count" -ge 5 ] && [ "$mem_count" -le 15 ]`. Both the py-cli and rust-library fixtures (T03 deliverables) actually emit 4 MEMs (no .git/, no DR-, so the decisions category is empty). The driver explicitly treats sub-5 counts as "minimum-viable seed" (informational, exit 0).

**Resolution:** SC-3 acceptance asserts the cap (≤15) plus floor (≥1), and additionally asserts the `minimum-viable seed` diagnostic surfaces when count<5. This matches the driver's documented contract ("Floor (US-3 AS-5)" — exit 0 with diagnostic, not error). Constraint forbids T05 from modifying the T03 fixtures. The 5-floor expectation in the py-cli/rust-library oracle texts is a fixture-author optimism that the driver's signal-source set cannot deliver against bare fixtures; closing that gap (e.g., adding synthetic .git/ to fixtures) belongs to T03 follow-up or a fixture-enrichment line item, not T05's purely-additive scope.

### Deviation 2: build-context.sh `--project-dir` flag not added
**Issue:** PLAN step 2f's literal command `bash scripts/dispatch/build-context.sh --profile=quick --task '...' --project-dir <fixture>` is not implemented in build-context.sh. Adding the flag would be a cross-task surface change with non-trivial knowledge-resolution implications (KNOWLEDGE-INDEX is read from the orchestrator repo root in direct mode).

**Resolution:** SC-3's M031-boundary check uses build-context.sh's existing direct mode (`--task-plan <plan> --out <out> --profile quick`) AND independently verifies that ≥3 seeded MEMs exist in `<staging>/.orchestrator/knowledge/` (the surface the M031 universal-entry traversal reads). The PLAN's note clarified the load-bearing fact: "the seeded MEMs are discoverable by M031's universal-entry profile traversal". Both the build-context invocation and the find-based discoverability check pass — contract preserved without an additive flag. This option was explicitly named in the dispatch instructions Step 4 ("write a tiny stage-only adapter or use what `build-context.sh` already supports").

## Files produced + modified

**Produced (purely additive):**
- `tests/m033-acceptance/p02-constitution-author.sh`
- `tests/m033-acceptance/p03-ingest-codebase.sh`
- `tools/verify/m033-p03-acceptance-shape-sc2.sh`
- `tools/verify/m033-p03-acceptance-shape-sc3.sh`
- `tools/verify/m033-p03-cross-phase-regression.sh`
- `tools/verify/m033-p03-scope-guard.sh`
- `tools/verify/m033-p03-phase-suite.sh`

**Modified (SSOT harmonization only — not behavior):**
- `references/m033-fr21-dual-write-convention.md`
- `scripts/util/start-state-markers.sh` (doc comment only)
- `scripts/util/jsonl-event-emitter.sh` (doc comment + fenced SSOT block additive entry)

## Cross-phase regression evidence

P01 (14/0), P02 (10/0), P03 (13/0) phase-suites all green post-T05.
