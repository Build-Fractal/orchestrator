---
schema_version: "1.0"
type: phase-summary
phase: "P01"
milestone: "M044"
status: complete
---

# M044/P01 Summary — Fail-Loud Activation Floor

The fail-loud, index-free-capable activation floor every downstream M044 phase
builds on. Five tasks, all verified; phase-suite `BATTERY: pass=7 fail=0`.

## What shipped

- **T01 — Canonical index/db path resolver (FR-11/SC-12).** `build-context.sh`'s
  two vestigial hardcoded `KNOWLEDGE-INDEX.md` joins (the M031 direct-mode site +
  the full-mode planning-payload site) now route through the single
  `get_index_path()` resolver (`scripts/knowledge/lib/index-utils.sh`), which
  honors exported `PROJECT_ROOT`. Literal joins survive only as guarded
  fallbacks. Canonical location documented in `docs/knowledge-management.md`.
- **T02 — Fail-loud consumer + index-free grep fallback + provenance (FR-5/SC-5/SC-6).**
  New `scripts/dispatch/lib/knowledge-provenance.sh` (`kp_index_state`,
  `kp_index_age`, `kp_grep_fallback`, `kp_is_mature`, `kp_emit_header`). An
  empty/missing/stale index (mtime detection, #Q-2) now triggers a deterministic
  `LC_ALL=C` grep over the raw corpus (budget-bounded via the M036a
  `reference_apply_budget` governor, CON-2) plus a loud WARNING (payload +
  stderr) instead of a silent first-N. A `knowledge_provenance:` header
  (`provenance_version: 1` pinned, #Q-4) is stamped into every payload, even on a
  healthy `source: index`.
- **T03 — Inject-size surface + 0-MEM-on-mature warning (FR-15/SC-10).**
  `knowledge: N MEMs / X tokens` in every Quick payload; a 0-MEM inject WARNs on a
  mature project (milestone SUMMARY or decisions row on disk) but stays silent on
  greenfield.
- **T04 — Consolidated doctor check (FR-15/FR-9/SC-11/CON-5).**
  `scripts/diagnostics/check-knowledge-activation.sh` emits one
  `DOCTOR:KNOWLEDGE_ACTIVATION status=ok|warn|fail symptoms=...` covering
  0-mem-on-mature (fail) / vestigial-index (warn) / runtime-memory-divergence
  (warn). Registered in `run-doctor.sh` (advisory), documented in `doctor.md`.
  `papercut-doctor-knowledge-gap-surface.md` annotated "reconciled into
  M044/FR-15" (#Q-3) — no second overlapping surface.
- **T05 — Determinism/budget regression + phase suite.**
  `m044-p01-t02-determinism-budget.sh` (byte-identical reruns + strict-subset
  budget enforcement + at-least-one) and `m044-p01-phase-suite.sh` aggregator.

## Verification

- Phase suite: `bash tools/verify/m044-p01-phase-suite.sh` → `BATTERY: pass=7 fail=0`.
- Framework must-haves: `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M044/phases/P01` → all truths/artifacts/key-links PASS.
- Live evidence (the repo's own index is genuinely stale): a Quick dispatch
  payload carries `source: grep-fallback`, `provenance_version: 1`,
  `entries_considered: 18`, `knowledge: 18 MEMs / 1902 tokens`, and the WARNING
  on both payload and stderr; 18 entries resolved index-free; exit 0. Full
  `run-doctor.sh` reports `DOCTOR:KNOWLEDGE_ACTIVATION status=ok`.

## Plan-time open questions resolved here

- **#Q-2** stale detection → mtime (cheap; content-hash deferred to FR-10/P1).
- **#Q-3** doctor reconciliation → single `DOCTOR:KNOWLEDGE_ACTIVATION` surface; papercut annotated, not duplicated.
- **#Q-4** provenance byte-contract → `provenance_version: 1` pinned now.

## Carried forward

- #Q-1 (canonical column order, consumer-order wins, forward-only) is a P02 (FR-1) deliverable.
- The repo's own `KNOWLEDGE-INDEX.md` is currently stale (index_age ~6.7h at build) — a real, now-surfaced signal; `rebuild-index.sh` clears it. The resilient rebuild itself is P03 (FR-3).
