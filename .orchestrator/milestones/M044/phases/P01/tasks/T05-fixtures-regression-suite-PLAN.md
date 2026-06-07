---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M044"
name: "Fixtures + determinism/budget regression + phase suite (SC-5/SC-6/SC-10/SC-11/SC-12)"
depends_on: ["T02", "T03", "T04"]
---

## Prerequisites

- T02/T03/T04 complete: provenance lib, inject-size/0-MEM surface, and doctor check on disk.

## Description

Build the integration fixtures and the cross-task regressions, and aggregate every P01 verifier into one phase-suite. The determinism/budget regression (`m044-p01-t02-determinism-budget.sh`) is co-located here because it needs the fixtures.

## Steps

1. Create fixtures under `.orchestrator/milestones/M044/fixtures/`:
   - `corpus-populated/` — a minimal project tree with `knowledge/<cat>/MEM###.md` raw entries (≥3 valid) and a `KNOWLEDGE-INDEX.md` that can be deleted/staled/emptied per-test.
   - `mature-empty/` — `.orchestrator/milestones/M001/M001-SUMMARY.md` + a non-empty `DECISIONS.md` + an EMPTY `KNOWLEDGE-INDEX.md` (drives the 0-MEM-on-mature warning + doctor `fail`).
   - `fresh-empty/` — no milestones, empty index (drives the no-warning-on-greenfield assertion).
2. Author `tools/verify/m044-p01-t02-determinism-budget.sh`: run `kp_grep_fallback` (or `build-context.sh` degraded) twice against `corpus-populated/` with the index removed; `diff` the two provenance/fallback artifacts ⇒ byte-identical (SC-6); assert the emitted token total ≤ the budget passed (CON-2). Emit `PASS:`/`FAIL:`.
3. Author `tools/verify/m044-p01-phase-suite.sh`: invoke every `m044-p01-*.sh` verifier (except itself), tally `PASS`/`FAIL`, emit `BATTERY: pass=N fail=M` + exit non-zero on any fail. (Framework rollup `check-must-haves.sh` is invoked separately by the runner, never from a Truth line.)
4. Run the full suite green; capture evidence into the phase SUMMARY at close.

## Must-Haves

- SC-5 (fail-loud consumer), SC-6 (deterministic + within-budget), SC-10 (0-MEM warning), SC-11 (single doctor), SC-12 (canonical path) all exercised by an on-disk verifier; the phase-suite aggregates them.

## Verification

`bash tools/verify/m044-p01-t02-determinism-budget.sh`
`bash tools/verify/m044-p01-phase-suite.sh`

## Inputs

### From Previous Tasks
- `scripts/dispatch/lib/knowledge-provenance.sh` (T02) — `kp_grep_fallback`, `kp_emit_header`, `kp_index_state`.
- `scripts/diagnostics/check-knowledge-activation.sh` (T04).
- All `tools/verify/m044-p01-*.sh` from T01-T04.

### From Disk (Pre-existing)
- `scripts/dispatch/lib/reference-budget.sh` — budget governor used by the determinism/budget assertion.

## Constraints

- Fixtures are deterministic and self-contained (no network, no wall-clock). The phase-suite must be re-runnable byte-stably. Bash 3.2. Path discipline: all verifiers under `tools/verify/` (project-owned, milestone-prefixed); fixtures under the milestone dir, not `scripts/`.

## Expected Output

`bash tools/verify/m044-p01-phase-suite.sh` ⇒ `BATTERY: pass=8 fail=0`, exit 0.

## Notes

- Expected verifier output: `PASS: ...` per verifier; suite `BATTERY: pass=N fail=0`.
