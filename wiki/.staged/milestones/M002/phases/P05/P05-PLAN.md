---
schema_version: "1.0"
type: phase-plan
phase: "P05"
milestone: "M002"
goal: "Validate, register, and integrate pre-existing telemetry scripts (record-telemetry.sh, aggregate-metrics.sh) into the orchestrator lifecycle — registering them in extension.yml, wiring aggregate metrics into the /status command, ensuring auto-loop.sh passes telemetry fields through to record-result.sh, and proving end-to-end telemetry from dispatch to status display"
demo_sentence: "After dispatching 10 tasks, the execution log contains one entry per task with model, tokens, cost, cache hit rate, duration, and verification result; the /status command surfaces aggregate metrics including cross-milestone comparison."
risk: "medium"
depends_on: []
---

## Must-Haves

### Truths

- record-telemetry.sh appends a JSON line with `"type":"telemetry"` containing unitId, and optional fields model_used, tokens_input, tokens_output, tokens_cache_read, cost_estimated, cost_source, cache_hit_rate, payload_bytes
  - Check: `bash scripts/verify/m002-p05-record-telemetry-fields.sh`
- record-telemetry.sh validates cost_source enum (estimated|reported|unknown) and rejects invalid values
  - Check: `bash scripts/verify/m002-p05-cost-source-enum.sh`
- aggregate-metrics.sh reads both dispatch entries and telemetry entries from execution-log.jsonl, computing total cost, avg cost/task, avg duration, cache hit rate, success rate, and per-milestone comparison
  - Check: `bash scripts/verify/m002-p05-aggregate-metrics-fields.sh`
- aggregate-metrics.sh supports --format=json producing machine-readable output with by_model, by_milestone, and by_cost_source breakdowns
  - Check: `bash scripts/verify/m002-p05-aggregate-json-format.sh`
- auto-loop.sh Step G passes telemetry-related flags (--model, --tokens-input, --tokens-output, --tokens-cache-read, --cost, --cache-hit-rate) through to record-result.sh when values are available
  - Check: `bash scripts/verify/m002-p05-autoloop-telemetry-passthrough.sh`
- commands/status.md references aggregate-metrics.sh for surfacing telemetry in the /status command output
  - Check: `bash scripts/verify/m002-p05-status-references-aggregate.sh`
- extension.yml registers both scripts/telemetry/record-telemetry.sh and scripts/telemetry/aggregate-metrics.sh as executable scripts
  - Check: `bash scripts/verify/m002-p05-extension-registration.sh`
- All telemetry scripts are Bash 3.2 compatible (no associative arrays, no readarray, no mapfile)
  - Check: `bash scripts/verify/m002-p05-bash32-compat.sh`
- All telemetry operations are idempotent (running record-telemetry.sh twice with the same data appends two entries; aggregate-metrics.sh is read-only)
  - Check: `bash scripts/verify/m002-p05-idempotent.sh`

### Artifacts

- scripts/telemetry/record-telemetry.sh (min 30 lines, contains "telemetry")
- scripts/telemetry/aggregate-metrics.sh (min 100 lines, contains "aggregate")
- scripts/verify/m002-p05-record-telemetry-fields.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p05-cost-source-enum.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p05-aggregate-metrics-fields.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p05-aggregate-json-format.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p05-autoloop-telemetry-passthrough.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p05-status-references-aggregate.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p05-extension-registration.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p05-bash32-compat.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p05-idempotent.sh (min 3 lines, contains "PASS")

### Key Links

- scripts/telemetry/record-telemetry.sh -> references/file-formats.md (telemetry entry format documented)
- scripts/telemetry/aggregate-metrics.sh -> scripts/telemetry/record-telemetry.sh (reads entries produced by record-telemetry)
- commands/status.md -> scripts/telemetry/aggregate-metrics.sh (status command surfaces aggregate metrics)
- scripts/lifecycle/auto-loop.sh -> scripts/lifecycle/record-result.sh (passes telemetry fields)
- extension.yml -> scripts/telemetry/record-telemetry.sh (registered as executable script)
- extension.yml -> scripts/telemetry/aggregate-metrics.sh (registered as executable script)

## Tasks

### T01: Verification Scripts for All Must-Haves

Create all 9 verification scripts that mechanically check the P05 must-haves. These scripts must pass after T02-T04 complete, providing the gating checks for phase verification.

### T02: Validate and Harden Telemetry Scripts

Review record-telemetry.sh and aggregate-metrics.sh against the documented JSONL schema in references/file-formats.md. Fix any gaps in field handling, error messaging, or Bash 3.2 compatibility. Register both scripts in extension.yml.

### T03: Integrate Telemetry into Auto-Loop and Status

Wire auto-loop.sh Step G to pass telemetry fields through to record-result.sh. Update commands/status.md to reference aggregate-metrics.sh and describe how telemetry is surfaced in the /status command output.

### T04: End-to-End Telemetry Verification

Create a synthetic execution log with dispatch and telemetry entries spanning two milestones. Run aggregate-metrics.sh in both text and JSON modes to verify all metrics compute correctly. Run all verification scripts to confirm all must-haves pass.

## Task Dependencies

T01 -> T02 -> T03 -> T04

T01 must come first (verification scripts needed by all subsequent tasks). T02 validates the individual scripts and registers them. T03 integrates into auto-loop and status. T04 is the integration test that proves everything works together.

## Files Likely Touched

- scripts/verify/m002-p05-record-telemetry-fields.sh (create)
- scripts/verify/m002-p05-cost-source-enum.sh (create)
- scripts/verify/m002-p05-aggregate-metrics-fields.sh (create)
- scripts/verify/m002-p05-aggregate-json-format.sh (create)
- scripts/verify/m002-p05-autoloop-telemetry-passthrough.sh (create)
- scripts/verify/m002-p05-status-references-aggregate.sh (create)
- scripts/verify/m002-p05-extension-registration.sh (create)
- scripts/verify/m002-p05-bash32-compat.sh (create)
- scripts/verify/m002-p05-idempotent.sh (create)
- scripts/telemetry/record-telemetry.sh (modify)
- scripts/telemetry/aggregate-metrics.sh (modify)
- scripts/lifecycle/auto-loop.sh (modify)
- commands/status.md (modify)
- extension.yml (modify)
- references/file-formats.md (modify)
