---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P03"
milestone: "M011"
provides:
  - "Phase demo-scenario verify script, provenance traversal verify script, re-ingest idempotency verify script (chain-tip hash comparison check)"
requires:
  - "T01: classify_chunk_decision; T02: supersession wiring and REMOVED pass; traverse-graph.sh; rebuild-index.sh"
affects:
  - "P03 phase verification completeness, P04 dispatch integration"
key_files:
  - "scripts/verify/m011-p03-demo-scenario.sh, scripts/verify/m011-p03-provenance-traversable.sh, scripts/verify/m011-p03-reingest-idempotent.sh"
key_decisions:
  - "Sandbox PROJECT_ROOT=mktemp -d with EXIT trap; verify scripts internally allowed any bash (AD-19 applies only to plan Check: lines); no ingest-spec.sh modification needed — T02 already walks superseded_by chain to tip"
patterns_established:
  - "Demo-scenario verify reproduces roadmap sentence literally; triple-ingest idempotency check surfaces chain-tip hash comparison edge case; provenance chain-length-2 assertion"
drill_down_paths:
  - ".orchestrator/milestones/M011/phases/P03/tasks/T03-PAYLOAD.md"
duration: "0m"
verification_result: "pass"
completed_at: "2026-04-17T00:53:14Z"
---

T03 delivers the phase demo-scenario, provenance-traversal, and re-ingest-idempotency verify scripts that close out P03 must-haves. m011-p03-demo-scenario.sh reproduces the roadmap demo sentence exactly: ingests a spec with FR-001, FR-003, FR-005, then re-ingests with FR-003 modified and FR-005 deleted, and asserts the stdout contains SUPERSEDED SPEC-FR-003 to SPEC-FR-003-v2, SKIPPED SPEC-FR-001, and REMOVED SPEC-FR-005. m011-p03-provenance-traversable.sh asserts that after one supersession, traverse-graph.sh --provenance emits PROVENANCE SPEC-FR-003 chain length 2 and labels members correctly. m011-p03-reingest-idempotent.sh confirms a third ingest on a twice-ingested spec is a no-op: zero CREATED, zero SUPERSEDED, zero REMOVED, two SKIPPED. The chain-tip hash comparison in classify_chunk_decision is exercised here — the test passes without reopening scope into ingest-spec.sh, indicating T02 walks the chain correctly. All 10 P03 verify scripts PASS. ingest-spec.sh was not modified in T03.
