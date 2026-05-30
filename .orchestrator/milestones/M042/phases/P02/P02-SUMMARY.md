---
schema_version: "1.0"
type: phase-summary
id: "M042/P02"
parent: "M042"
milestone: "M042"
phase: "P02"
verification_result: "pass"
completed_at: "2026-05-30T00:00:00Z"
---

# M042 / P02 — Caller pre-finalize hooks + doctor bypass lint

Wired the P01 gate into the question-emitting commands and added the lint:

- Full pre-finalize gate steps in `commands/discuss.md` (Finalize Context),
  `commands/specify.md` (Pass 3 / Open Questions), `commands/roadmap.md` +
  `commands/plan-phase.md` (pre-write), `commands/materials-intake.md`
  (conflict-question branch). Each maps gate exit `2` (BLOCK) to a
  read-citations-then-disposition pause; exit `0` proceeds.
- `commands/comments.md` — lighter pointer (classifies inbound comments; its
  question emission is conditional/rare).
- `scripts/diagnostics/check-corpus-exhaustion.sh` + a `run_check` registration
  in `scripts/diagnostics/run-doctor.sh` (advisory). Low-noise:
  `DOCTOR:CORPUS_EXHAUSTION status=warn` only on an unresolved BLOCK artifact;
  `status=ok` otherwise (zero artifacts → ok). Spec FR-11/SC-8 refined from
  "missing sidecar" to "unresolved BLOCK" (missing-sidecar detection needs a
  should-be-gated registry — deferred).

Verification: `tools/verify/m042-p02-acceptance-battery.sh` — SC-7 ×6 + SC-8 ×3
+ shape, `pass=10 skip=0 fail=0`.

P03 (LLM judge) + P04 (telemetry) deferred to a future demand-driven slice
pending the #Q-1 M040 absorption decision.
