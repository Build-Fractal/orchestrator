---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M041"
goal: "Wire cross-command recommendation hooks into doctor/verify/auto/dispatch using $ORCHESTRATOR_ROOT prefix comparison, and deliver the full acceptance battery covering SC-1 through SC-7"
demo_sentence: "Running run-doctor.sh against a fixture with an orchestrator-side orphan emits RECOMMEND: orchestrator:detective on stderr; the full acceptance battery passes SC-1 through SC-7."
risk: "low"
depends_on: ["P02"]
---

## Must-Haves

### Truths

- `run-doctor.sh` emits `RECOMMEND: orchestrator:detective` on stderr when it detects an orchestrator-side orphan (a reference to a non-existent script under `$ORCHESTRATOR_ROOT`)
  - Check: `bash tools/verify/m041-p03-doctor-recommendation.sh`
- The recommendation hook uses `$ORCHESTRATOR_ROOT` prefix comparison (via `scripts/state/resolve-root.sh`) to distinguish orchestrator-side errors from user-project errors
  - Check: `bash tools/verify/m041-p03-path-disambiguation.sh`
- The full acceptance battery covering SC-1 through SC-7 passes
  - Check: `bash tools/verify/m041-p03-acceptance-battery.sh`

### Artifacts

- `tools/verify/m041-p03-acceptance-battery.sh` (min 30 lines, contains "SC-")
- `scripts/diagnostics/detective-recommend.sh` (min 10 lines, contains "RECOMMEND")

### Key Links

- `scripts/diagnostics/run-doctor.sh` → `scripts/diagnostics/detective-recommend.sh` (doctor calls recommendation helper)

## Tasks

### T01: detective-recommend.sh — recommendation helper + doctor hook

Create the shared recommendation helper and wire it into run-doctor.sh.

### T02: Acceptance battery + phase suite

Create the acceptance battery covering SC-1 through SC-7 and the P03 verifiers.

## Task Dependencies

T01 → T02

## Files Likely Touched

- `scripts/diagnostics/detective-recommend.sh` (create)
- `scripts/diagnostics/run-doctor.sh` (modify — add recommendation hook call)
- `tools/verify/m041-p03-doctor-recommendation.sh` (create)
- `tools/verify/m041-p03-path-disambiguation.sh` (create)
- `tools/verify/m041-p03-acceptance-battery.sh` (create)
- `tools/verify/m041-p03-phase-suite.sh` (create)
