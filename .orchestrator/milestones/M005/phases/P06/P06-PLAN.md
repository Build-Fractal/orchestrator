---
schema_version: "1.0"
type: phase-plan
phase: "P06"
milestone: "M005"
goal: "Expand run-doctor.sh into a scored health report covering constitution v2.0 compliance, event emission, content hashes, run IDs, and task plan shape lint"
demo_sentence: "A developer runs `bash scripts/diagnostics/run-doctor.sh --root .` and sees a scored health report (N/M checks passed) that includes constitution principle coverage, event emission, knowledge hash validation, JSONL run_id presence, task plan shape lint, and permission drift — each emitting DOCTOR:* structured output."
risk: "low"
depends_on: ["P01", "P02", "P03", "P04", "P05", "P07"]
---

## Must-Haves

### Truths

- check-constitution.sh scans phase plan files for principle references and emits `DOCTOR:CONSTITUTION status=<ok|warn> principles_found=N principles_total=13`
  - Check: `bash scripts/verify/p06-check-constitution.sh`
- check-events.sh scans engine-path scripts for `emit_event` presence and emits `DOCTOR:EVENTS status=<ok|warn> compliant=N total=N`
  - Check: `bash scripts/verify/p06-check-events.sh`
- check-hashes.sh scans knowledge entries for valid `content_hash` fields and emits `DOCTOR:HASHES status=<ok|warn> valid=N missing=N`
  - Check: `bash scripts/verify/p06-check-hashes.sh`
- check-run-ids.sh scans recent JSONL entries for `run_id` field presence and emits `DOCTOR:RUNIDS status=<ok|warn> with_id=N without_id=N`
  - Check: `bash scripts/verify/p06-check-run-ids.sh`
- check-plans.sh scans task plan Check: commands and inline bash blocks for AD-19 trigger patterns and emits `DOCTOR:PLANS status=<ok|warn> heuristic_risk=N trigger=<class>`
  - Check: `bash scripts/verify/p06-check-plans.sh`
- run-doctor.sh produces a scored health report with `Checks passed: N / M` in the summary
  - Check: `bash scripts/verify/p06-scored-doctor.sh`
- extension.yml registers all new diagnostic scripts under provides.scripts
  - Check: `bash scripts/verify/p06-extension-registration.sh`

### Artifacts

- scripts/diagnostics/check-constitution.sh (min 40 lines, contains "DOCTOR:CONSTITUTION")
- scripts/diagnostics/check-events.sh (min 40 lines, contains "DOCTOR:EVENTS")
- scripts/diagnostics/check-hashes.sh (min 30 lines, contains "DOCTOR:HASHES")
- scripts/diagnostics/check-run-ids.sh (min 30 lines, contains "DOCTOR:RUNIDS")
- scripts/diagnostics/check-plans.sh (min 60 lines, contains "DOCTOR:PLANS")
- scripts/diagnostics/run-doctor.sh (min 60 lines, contains "Checks passed")

### Key Links

- scripts/diagnostics/run-doctor.sh → scripts/diagnostics/check-constitution.sh (aggregation)
- scripts/diagnostics/run-doctor.sh → scripts/diagnostics/check-events.sh (aggregation)
- scripts/diagnostics/run-doctor.sh → scripts/diagnostics/check-hashes.sh (aggregation)
- scripts/diagnostics/run-doctor.sh → scripts/diagnostics/check-run-ids.sh (aggregation)
- scripts/diagnostics/run-doctor.sh → scripts/diagnostics/check-plans.sh (aggregation)
- scripts/diagnostics/run-doctor.sh → scripts/diagnostics/check-permissions.sh (aggregation)
- extension.yml → scripts/diagnostics/check-constitution.sh (registration)
- extension.yml → scripts/diagnostics/check-events.sh (registration)
- extension.yml → scripts/diagnostics/check-hashes.sh (registration)
- extension.yml → scripts/diagnostics/check-run-ids.sh (registration)
- extension.yml → scripts/diagnostics/check-plans.sh (registration)

## Tasks

### T01: check-constitution.sh + check-events.sh

Create two diagnostic scripts: constitution v2.0 principle coverage checker and engine-path event emission checker.

### T02: check-hashes.sh + check-run-ids.sh

Create two diagnostic scripts: knowledge entry content_hash validator and JSONL run_id presence checker.

### T03: check-plans.sh

Create the AD-19 task plan shape lint — the most complex individual check, scanning for the full forbidden trigger set.

### T04: Scored run-doctor.sh + extension.yml registration

Rewrite run-doctor.sh to aggregate all checks (existing + new + P07 check-permissions.sh) into a scored health report with pass/total counts. Register all new diagnostic scripts in extension.yml.

## Task Dependencies

T01 → T04
T02 → T04
T03 → T04

T01, T02, T03 are independent — can execute in any order or concurrently.
T04 depends on all three (wires their output into the aggregated doctor).

## Files Likely Touched

- scripts/diagnostics/check-constitution.sh (create)
- scripts/diagnostics/check-events.sh (create)
- scripts/diagnostics/check-hashes.sh (create)
- scripts/diagnostics/check-run-ids.sh (create)
- scripts/diagnostics/check-plans.sh (create)
- scripts/diagnostics/run-doctor.sh (modify)
- extension.yml (modify)
- scripts/verify/p06-check-constitution.sh (create)
- scripts/verify/p06-check-events.sh (create)
- scripts/verify/p06-check-hashes.sh (create)
- scripts/verify/p06-check-run-ids.sh (create)
- scripts/verify/p06-check-plans.sh (create)
- scripts/verify/p06-scored-doctor.sh (create)
- scripts/verify/p06-extension-registration.sh (create)
