---
schema_version: "1.0"
type: task-summary
id: "T03"
parent: "P03"
milestone: "M027"
provides:
  - "scripts/diagnostics/run-doctor.sh wired with --config-check + --no-anomaly arg-parse cases and two advisory run_check invocations (Anomaly Detection unconditional, Config Drift opt-in via --config-check); scripts/verify/m027-p03-t03-shape-precheck.sh T03-scoped precheck verifier"
requires:
  - "from:M027/P03/T01 what:scripts/diagnostics/check-anomalies.sh; from:M027/P03/T02 what:scripts/diagnostics/check-config-drift.sh + commands/doctor.md anomaly+config-drift sections"
affects:
  - "M027/P03/T04"
key_files:
  - "scripts/diagnostics/run-doctor.sh,scripts/verify/m027-p03-t03-shape-precheck.sh"
key_decisions:
  - "AD-19,CON-1,CON-7,FR-8,FR-12,FR-16,FR-21,MEM012,SC-16"
patterns_established:
  - "Helper-integration via two new advisory run_check invocations at a stable attach point (between Runtime Instruction Drift and Graph Health) with no re-shape of pre-existing canonical run_check sequence (MEM012); arg-parse extension by appending two cases to the existing while/case loop with separate CONFIG_CHECK / NO_ANOMALY init scalars before the loop (bash 3.2 parallel-scalar pattern); flag-passthrough pattern: --no-anomaly on run-doctor.sh propagates to the inner check-anomalies.sh helper invocation via a conditional run_check args string, preserving 5-condition suppression matrix at the helper boundary; T03-scoped precheck verifier shape carry-forward from M027/P01/T03 + P02/T01-T03 (single-script-file Check per AD-19, T04 subsumes via canonical phase-level verifier); Config Drift opt-in pattern via boolean CONFIG_CHECK guard (FR-16) so default run-doctor.sh output is unchanged modulo the always-on advisory Anomaly Detection block"
drill_down_paths:
  - ".orchestrator/milestones/M027/phases/P03/tasks/T03-run-doctor-integration-PLAN.md"
duration: "15m"
verification_result: "pass"
completed_at: "2026-04-27T16:18:14Z"
---

T03 wires the M027/P03 anomaly + config-drift helpers into `scripts/diagnostics/run-doctor.sh`. Two arg-parse cases (`--config-check`, `--no-anomaly`) and two new advisory `run_check` invocations (`Anomaly Detection`, conditional `Config Drift`) inserted between the pre-existing `Runtime Instruction Drift` invocation and the conditional `Graph Health` block. No re-shape of pre-existing canonical structure (MEM012); both new check-rows follow the existing `run_check` calling convention verbatim, advisory marker `"1"`, so neither contributes to `checks_total / checks_passed` nor affects HEALTHY / NEEDS_ATTENTION (FR-8).

## What changed

- `scripts/diagnostics/run-doctor.sh` — 145 -> 160 lines. Added `CONFIG_CHECK=0` + `NO_ANOMALY=0` initializations before the `while` arg-parse loop; appended two cases to the existing `case "$1" in` block for `--config-check` and `--no-anomaly`. Inserted two `run_check` invocations: unconditional `Anomaly Detection` (passes `--no-anomaly` through to the helper when the flag is set on `run-doctor.sh`), and conditional `Config Drift` only when `--config-check` is set. Each marked advisory (`"1"` final arg).
- `scripts/verify/m027-p03-t03-shape-precheck.sh` — new T03-scoped precheck verifier (~52 lines, executable, bash 3.2 clean). Asserts: file exists, line-count >= 140, contains `--config-check` + `--no-anomaly` arg-parse case literals, `CONFIG_CHECK=` + `NO_ANOMALY=` initialization literals, `run_check "Anomaly Detection"` + `run_check "Config Drift"` invocation literals, both new run_check rows carry the trailing `"1"` advisory marker, and a behavioral smoke-test (`bash run-doctor.sh --no-anomaly` emits `Orchestrator Diagnostics`). T04 ships canonical `m027-p03-run-doctor-integration.sh` that subsumes this precheck.

## Suppression matrix honored

T03 is the integration boundary, not the surface itself, so the 5-condition suppression matrix is enforced indirectly: when `run-doctor.sh --no-anomaly` is set, the script invokes `check-anomalies.sh --no-anomaly`, which short-circuits to zero stdout per T01's contract. The other four conditions (`ORCHESTRATOR_AUTO`, `anomaly_check_enabled: false`, `--yes`, sample-size-floor structural carve-out) are enforced inside `check-anomalies.sh` itself and pass through invisibly via the helper's own arg-parse + env probes. The `--- Anomaly Detection ---` section header from `run_check` still appears (run_check always emits the header before script invocation), but the body is empty under suppression — documented behavior per `commands/doctor.md` (T02).

## Constraints satisfied

- **CON-7 (bash 3.2)**: no `declare -A`, no `<<<`, no `mapfile`, no `${var^^}`, no process substitution `<(...)`, no `&>`. Existing run-doctor.sh structure preserved.
- **FR-8 (advisory; never blocks)**: both new run_check rows marked advisory; never contribute to `checks_total / checks_passed` ratio; never block autonomous mode.
- **FR-12 / CON-1 (read-only)**: no new writes by run-doctor.sh itself; both new helpers are read-only per their own contracts.
- **FR-21 / CON-6 / SC-16 (zero-LLM-token)**: bash + invocation of T01/T02 helpers only. No `claude_chat`, no `dispatch-interface.sh`, no LLM call surfaces introduced.
- **FR-16 (config-check opt-in)**: `Config Drift` row only appears when `--config-check` is explicitly set. Without the flag, the only structural change to existing output is the advisory `Anomaly Detection` block (which is itself suppressible via `--no-anomaly`).
- **MEM012 (no re-shape of existing canonical structure)**: pre-existing `run_check` sequence preserved verbatim in pre-edit order; two new rows inserted at a stable attach point (between Runtime Instruction Drift and Graph Health); no pre-existing line re-ordered or re-worded.
- **AD-19 (single-script-file Check shape)**: T03's Verification block invokes a single helper (`m027-p03-t03-shape-precheck.sh`).

## Verification

- `bash scripts/verify/m027-p03-t03-shape-precheck.sh` -> exit 0, `PASS: m027-p03-t03-shape-precheck`.
- Behavioral smoke: `bash scripts/diagnostics/run-doctor.sh --no-anomaly` produces `=== Orchestrator Diagnostics ===` header and `--- Anomaly Detection ---` section (body empty under suppression), no crash, all 17 section headers present including new Anomaly Detection slot before Graph Health.
- `bash scripts/diagnostics/run-doctor.sh --config-check --no-anomaly` produces 18 section headers including both `--- Anomaly Detection ---` and `--- Config Drift ---` immediately before Graph Health.
- `bash scripts/diagnostics/run-doctor.sh --no-anomaly` produces zero `Config Drift` occurrences (FR-16 opt-in invariant verified).

## Cross-task / cross-phase handoff

T04 will ship the canonical phase-level `scripts/verify/m027-p03-run-doctor-integration.sh` verifier that subsumes this precheck (mirrors the M027/P00+P01+P02 T04-subsumes-prechecks pattern). T04's `m027-p03-doctor-byte-identity.sh` will gate the suppressed-mode tail of run-doctor output (analogous to P02's status.md byte-identity contract). T04's `m027-p03-suppression-matrix.sh` will exercise all 5 suppression paths end-to-end through the integration surface — the integration here is what enables that verifier to assert mechanically rather than only via helper-internal contracts.
