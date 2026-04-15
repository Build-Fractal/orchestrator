---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P06"
milestone: "M004"
name: "Phase Verification"
depends_on: [T02, T03, T04]
---

## Prerequisites

Before starting, verify from the repo root:

```bash
# All prior tasks complete — each target script has emit_result
grep -q 'emit_result' scripts/verify/check-must-haves.sh && echo "ok: T01"
grep -q 'emit_result' scripts/lifecycle/record-result.sh && echo "ok: T02"
grep -q 'emit_result' scripts/telemetry/record-telemetry.sh && echo "ok: T03a"
grep -q 'emit_result' scripts/telemetry/aggregate-metrics.sh && echo "ok: T03b"
grep -q 'emit_result' scripts/dispatch/classify-complexity.sh && echo "ok: T04a"
grep -q 'emit_result' scripts/lifecycle/phase-transition.sh && echo "ok: T04b"

# Verification helpers exist
test -f scripts/verify/m004-p06-sources-errors.sh && echo "ok: verify scripts"
```

All must print `ok:`. If any fail, STOP -- prior tasks are not complete.

## Description

This is a verification-only task. No code changes are made. Run all phase-level verification checks to confirm every P06 truth holds, then run standalone smoke tests on each target script to confirm NFR-204 (standalone compatibility) is preserved.

This task exists to provide a clean verification gate before the phase is marked complete. If any check fails, the failure must be reported with the specific script and check that failed so the appropriate prior task can be re-dispatched.

## Cross-Cutting Constraints

1. **No code changes** -- this task is verification-only. Do not modify any script.
2. **Run all checks from repo root** -- the check-must-haves PROJECT_ROOT detection (fixed in T01) resolves correctly from repo root.

## Steps

### Step 1: Run all phase-level truth checks

Execute every verification helper script from repo root. Each must exit 0 and print PASS.

```bash
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== Phase-level truth checks ==="
bash scripts/verify/m004-p06-sources-errors.sh
bash scripts/verify/m004-p06-sources-events.sh
bash scripts/verify/m004-p06-emit-result.sh
bash scripts/verify/m004-p06-emit-event.sh
bash scripts/verify/m004-p06-standalone-safe.sh
bash scripts/verify/m004-p06-bash32-compat.sh
bash scripts/verify/m004-p06-check-must-haves-root.sh
bash scripts/verify/m004-p06-record-result-runid.sh
bash scripts/verify/m004-p06-record-result-errorkind.sh
bash scripts/verify/m004-p06-aggregate-errorkind.sh
echo "=== All phase-level truth checks passed ==="
```

If any check fails, record which check failed and STOP.

### Step 2: Run standalone smoke tests

For each target script, run it WITHOUT ORCH_RUN_ID set and verify:
- It produces the expected stdout output.
- It does NOT produce any EVENT: or RESULT: lines on stderr.
- It exits with the expected exit code.

```bash
unset ORCH_RUN_ID
unset ORCH_STARTED_AT

echo "=== Standalone smoke tests ==="

# 1. classify-complexity.sh
result=$(bash scripts/dispatch/classify-complexity.sh tests/fixtures/auto-loop/milestones/M001/phases/P02/tasks/T01-PAYLOAD.md 2>/tmp/t05-stderr.txt)
test -n "$result" && echo "PASS: classify-complexity produces output: $result"
! grep -qE 'EVENT:|RESULT:' /tmp/t05-stderr.txt && echo "PASS: classify-complexity no engine output in standalone"

# 2. record-result.sh
tmp=$(mktemp)
bash scripts/lifecycle/record-result.sh "$tmp" --milestone=M001 --phase=P01 --task=T01 --outcome=success 2>/tmp/t05-stderr.txt
grep -q '"outcome":"success"' "$tmp" && echo "PASS: record-result writes JSONL"
! grep -q '"run_id"' "$tmp" && echo "PASS: record-result no run_id in standalone"
! grep -qE 'EVENT:|RESULT:' /tmp/t05-stderr.txt && echo "PASS: record-result no engine output in standalone"
rm -f "$tmp"

# 3. record-telemetry.sh
tmp=$(mktemp)
bash scripts/telemetry/record-telemetry.sh "$tmp" --unit-id=M001/P01/T01 --model=test 2>/tmp/t05-stderr.txt
grep -q '"type":"telemetry"' "$tmp" && echo "PASS: record-telemetry writes JSONL"
! grep -q '"run_id"' "$tmp" && echo "PASS: record-telemetry no run_id in standalone"
! grep -qE 'EVENT:|RESULT:' /tmp/t05-stderr.txt && echo "PASS: record-telemetry no engine output in standalone"
rm -f "$tmp"

# 4. aggregate-metrics.sh (needs a log file with data)
tmp=$(mktemp)
echo '{"timestamp":"2026-04-13T00:00:00Z","unitId":"M001/P01/T01","milestone":"M001","outcome":"success","attempt":1}' > "$tmp"
bash scripts/telemetry/aggregate-metrics.sh "$tmp" --format=text 2>/tmp/t05-stderr.txt | head -3
! grep -qE 'EVENT:|RESULT:' /tmp/t05-stderr.txt && echo "PASS: aggregate-metrics no engine output in standalone"
rm -f "$tmp"

# 5. check-must-haves.sh (needs a phase with a plan)
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M004/phases/P05 2>/tmp/t05-stderr.txt | head -3
! grep -qE 'EVENT:|RESULT:' /tmp/t05-stderr.txt && echo "PASS: check-must-haves no engine output in standalone"

# 6. phase-transition.sh (needs a milestone dir with completed phase)
bash scripts/lifecycle/phase-transition.sh .specify/orchestrator/milestones/M004 P05 2>/tmp/t05-stderr.txt | head -3
! grep -qE 'EVENT:|RESULT:' /tmp/t05-stderr.txt && echo "PASS: phase-transition no engine output in standalone"

echo "=== All standalone smoke tests passed ==="
```

### Step 3: Run engine-mode smoke tests

Set ORCH_RUN_ID and verify each script emits at least one EVENT: and one RESULT: line on stderr.

```bash
export ORCH_RUN_ID="p06-verify-run"
export ORCH_STARTED_AT="2026-04-13T00:00:00Z"

echo "=== Engine-mode smoke tests ==="

# 1. classify-complexity.sh
bash scripts/dispatch/classify-complexity.sh tests/fixtures/auto-loop/milestones/M001/phases/P02/tasks/T01-PAYLOAD.md 2>/tmp/t05-engine.txt >/dev/null
grep -q 'EVENT:' /tmp/t05-engine.txt && echo "PASS: classify-complexity emits EVENT"
grep -q 'RESULT:' /tmp/t05-engine.txt && echo "PASS: classify-complexity emits RESULT"

# 2. record-result.sh
tmp=$(mktemp)
bash scripts/lifecycle/record-result.sh "$tmp" --milestone=M001 --phase=P01 --task=T01 --outcome=success 2>/tmp/t05-engine.txt
grep -q 'EVENT:' /tmp/t05-engine.txt && echo "PASS: record-result emits EVENT"
grep -q 'RESULT:' /tmp/t05-engine.txt && echo "PASS: record-result emits RESULT"
grep -q '"run_id":"p06-verify-run"' "$tmp" && echo "PASS: record-result includes run_id"
rm -f "$tmp"

# 3. record-telemetry.sh
tmp=$(mktemp)
bash scripts/telemetry/record-telemetry.sh "$tmp" --unit-id=M001/P01/T01 --model=test 2>/tmp/t05-engine.txt
grep -q 'EVENT:' /tmp/t05-engine.txt && echo "PASS: record-telemetry emits EVENT"
grep -q 'RESULT:' /tmp/t05-engine.txt && echo "PASS: record-telemetry emits RESULT"
rm -f "$tmp"

# 4. aggregate-metrics.sh
tmp=$(mktemp)
echo '{"timestamp":"2026-04-13T00:00:00Z","unitId":"M001/P01/T01","milestone":"M001","outcome":"success","attempt":1}' > "$tmp"
bash scripts/telemetry/aggregate-metrics.sh "$tmp" --format=text 2>/tmp/t05-engine.txt >/dev/null
grep -q 'EVENT:' /tmp/t05-engine.txt && echo "PASS: aggregate-metrics emits EVENT"
grep -q 'RESULT:' /tmp/t05-engine.txt && echo "PASS: aggregate-metrics emits RESULT"
rm -f "$tmp"

# 5. check-must-haves.sh
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M004/phases/P05 2>/tmp/t05-engine.txt >/dev/null || true
grep -q 'EVENT:' /tmp/t05-engine.txt && echo "PASS: check-must-haves emits EVENT"
grep -q 'RESULT:' /tmp/t05-engine.txt && echo "PASS: check-must-haves emits RESULT"

# 6. phase-transition.sh
bash scripts/lifecycle/phase-transition.sh .specify/orchestrator/milestones/M004 P05 2>/tmp/t05-engine.txt >/dev/null
grep -q 'EVENT:' /tmp/t05-engine.txt && echo "PASS: phase-transition emits EVENT"
grep -q 'RESULT:' /tmp/t05-engine.txt && echo "PASS: phase-transition emits RESULT"

echo "=== All engine-mode smoke tests passed ==="
```

### Step 4: Run check-must-haves on P06 itself

Verify that check-must-haves.sh can process the P06 phase plan:

```bash
bash scripts/verify/check-must-haves.sh .specify/orchestrator/milestones/M004/phases/P06
```

This is the ultimate integration test: check-must-haves.sh (fixed in T01) resolves PROJECT_ROOT correctly for `.specify/orchestrator/milestones/M004/phases/P06/` and evaluates all truth checks, which invoke the verification helper scripts created for P06.

### Step 5: Report results

Summarize all check results. If all pass, the phase is ready for completion. If any fail, list the specific failures with the task that should be re-dispatched to fix them.

## Must-Haves

### Truths

- All 10 phase-level truth verification helpers pass
  - Check: `bash scripts/verify/m004-p06-sources-errors.sh`
- All target scripts work in standalone mode (no EVENT/RESULT when ORCH_RUN_ID unset)
  - Check: `bash scripts/verify/m004-p06-standalone-safe.sh`
- All target scripts are Bash 3.2 compatible
  - Check: `bash scripts/verify/m004-p06-bash32-compat.sh`

### Artifacts

No new artifacts. This task is verification-only.

## Verification

All verification is in the Steps above. Success criteria: every check in Steps 1-4 passes.

## Inputs

### From Previous Tasks

- T01: `scripts/verify/check-must-haves.sh` -- fixed PROJECT_ROOT bug, integrated with libs.
- T02: `scripts/lifecycle/record-result.sh` -- integrated with libs, added run_id + error_kind.
- T03: `scripts/telemetry/record-telemetry.sh` -- integrated with libs, added run_id. `scripts/telemetry/aggregate-metrics.sh` -- integrated with libs, added error_kind grouping.
- T04: `scripts/dispatch/classify-complexity.sh` and `scripts/lifecycle/phase-transition.sh` -- integrated with libs.

**API surface:** All 6 scripts must source lib/errors.sh + lib/events.sh, call emit_event and emit_result when ORCH_RUN_ID is set, and behave identically when ORCH_RUN_ID is unset.

### From Disk

- All 6 target scripts (modified by T01-T04).
- All `scripts/verify/m004-p06-*.sh` verification helper scripts.
- P06-PLAN.md (for check-must-haves.sh to parse truths).
- Test fixtures for smoke tests.

## Constraints

- NO code changes. Verification only.
- If any check fails, report the failure clearly with the script name and the failing check command.

## Expected Output

- A verification report confirming all P06 truths hold.
- Confirmation that all 6 target scripts work correctly in both standalone and engine modes.
- If failures exist: a list of specific failures and which prior task (T01-T04) should be re-dispatched.
