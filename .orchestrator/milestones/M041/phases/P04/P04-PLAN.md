---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M041"
goal: "Complete FR-8 by wiring the auto/dispatch/verify recommendation hooks that P03 deferred, and make doctor's hook name the specific failing checks instead of a generic count"
demo_sentence: "Feeding auto-loop.sh an unexpected state emits RECOMMEND: orchestrator:detective on stderr; verify.md and dispatch.md carry detective-recommendation guidance in their Error Handling sections; doctor's hook names the specific failing checks."
risk: "low"
depends_on: ["P03"]
---

## Must-Haves

### Truths

- `auto-loop.sh` emits a `RECOMMEND: orchestrator:detective` line when `derive-phase.sh` returns an unrecognized state (the unexpected-state exit-12 seam)
  - Check: `bash tools/verify/m041-p04-auto-hook.sh`
- `commands/verify.md` Error Handling section carries detective-recommendation guidance scoped to orchestrator-internal failures (missing/broken verifier scripts, not user-code check failures)
  - Check: `bash tools/verify/m041-p04-verify-guidance.sh`
- `commands/dispatch.md` Error Handling section carries detective-recommendation guidance scoped to internal dispatch errors (not user-fixable missing prerequisites)
  - Check: `bash tools/verify/m041-p04-dispatch-guidance.sh`
- `run-doctor.sh`'s recommendation symptom names the specific failing check names, not a generic count
  - Check: `bash tools/verify/m041-p04-doctor-specific-symptom.sh`

### Artifacts

- `scripts/lifecycle/auto-loop.sh` (modify — add hook at unexpected-state seam)
- `commands/verify.md` (modify — Error Handling guidance)
- `commands/dispatch.md` (modify — Error Handling guidance)
- `scripts/diagnostics/run-doctor.sh` (modify — specific-symptom emission)

### Key Links

- `scripts/lifecycle/auto-loop.sh` → `scripts/diagnostics/detective-recommend.sh` (auto calls the shared helper)

## Tasks

### T01: Wire auto/dispatch/verify hooks + doctor symptom specificity

Single cohesive task — all four edits plus verifiers and the phase suite.

## Task Dependencies

T01 (single task)

## Files Likely Touched

- `scripts/lifecycle/auto-loop.sh` (modify)
- `commands/verify.md` (modify)
- `commands/dispatch.md` (modify)
- `scripts/diagnostics/run-doctor.sh` (modify)
- `tools/verify/m041-p04-auto-hook.sh` (create)
- `tools/verify/m041-p04-verify-guidance.sh` (create)
- `tools/verify/m041-p04-dispatch-guidance.sh` (create)
- `tools/verify/m041-p04-doctor-specific-symptom.sh` (create)
- `tools/verify/m041-p04-phase-suite.sh` (create)

## Design Notes

**Why selective, not blanket** (NG-1 discipline): detective is for orchestrator-internal bugs, not user-project issues. The hook fires only on signals that genuinely indicate orchestrator malfunction:

- **auto** (mechanical): only the unexpected-state seam (`derive-phase.sh` returned an unknown state — the state machine should never do this). NOT task verify-fail (usually user code) and NOT no-active-phase (often user-sequencing).
- **dispatch / verify** (LLM-driven command docs): guidance instructs the LLM to call `detective-recommend.sh` only when the error originates in an orchestrator script (verifier missing/broken, internal dispatch failure) — not when the user can fix it by running an earlier command or fixing their own code.
- **doctor** (already wired): improve the symptom string to name the specific failing checks (`DOCTOR:<NAME> status=fail` lines) so the resulting triage report's keyword search is actionable (addresses review finding B5).
