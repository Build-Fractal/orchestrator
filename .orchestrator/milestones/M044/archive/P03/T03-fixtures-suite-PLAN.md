---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M044"
---

# T03 — Fixtures + phase suite + clear the repo's own stale index

## Zero-context summary

The T01/T02 verifiers each build their own ephemeral `mktemp -d` corpus (the proven
P01 lib-fixture pattern — `rebuild-index.sh` honors `--root`/exported `PROJECT_ROOT`,
so it CAN be fixture-tested). This task adds the phase-suite aggregator and clears
the repo's own genuinely-stale index that P01 surfaced loud.

## Steps

1. `tools/verify/m044-p03-phase-suite.sh` — copy `m044-p01-phase-suite.sh`, retarget
   the glob to `tools/verify/m044-p03-*.sh`. Emits `BATTERY: pass=N fail=0`.
2. Run `bash scripts/knowledge/rebuild-index.sh` against this repo to regenerate
   `KNOWLEDGE-INDEX.md` + `knowledge.db` now that FR-3 makes the rebuild resilient
   (the repo's index was ~6.7h stale at P01 build; P01's consumer grep-falls-back
   loud on it). Confirm the rebuild reports a sane `INDEXED: N / SKIPPED: M` and the
   doctor check (`scripts/diagnostics/check-knowledge-activation.sh`) returns to a
   non-stale state.

## Done when

- `bash tools/verify/m044-p03-phase-suite.sh` → `BATTERY: pass=N fail=0`
- `KNOWLEDGE-INDEX.md` regenerated (repo index no longer stale).
