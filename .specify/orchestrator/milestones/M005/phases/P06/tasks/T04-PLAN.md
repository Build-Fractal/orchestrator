---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P06"
milestone: "M005"
name: "Scored run-doctor.sh + extension.yml registration"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

T01 delivered `check-constitution.sh` and `check-events.sh`. T02 delivered `check-hashes.sh` and `check-run-ids.sh`. T03 delivered `check-plans.sh`. P07 delivered `check-permissions.sh`. P04 delivered `check-instructions.sh`. P05 delivered `check-providers.sh`. All emit `DOCTOR:*` structured output with `status=ok` or `status=warn`.

## Description

Rewrite `scripts/diagnostics/run-doctor.sh` to:
1. Run all diagnostic checks (existing + new) in sequence
2. Parse each check's `DOCTOR:*` structured output to extract pass/fail status
3. Produce a **scored health report** with `Checks passed: N / M` in the summary
4. Treat `check-plans.sh` as advisory (its warnings don't count toward failures)
5. Append the scored result to `doctor-history.jsonl`

Also update `extension.yml` to register all 5 new diagnostic scripts.

## Steps

### Step 1: Rewrite `scripts/diagnostics/run-doctor.sh`

Replace the current run-doctor.sh with a new version that:

**Header:**
```bash
#!/usr/bin/env bash
# scripts/diagnostics/run-doctor.sh — Aggregated health report.
#
# Runs all diagnostic checks and produces a scored health report.
# Each check emits DOCTOR:* structured output. This script aggregates
# the results into: Checks passed: N / M.
#
# Usage: run-doctor.sh [--root <project-root>] [--format text|json]
#
# Bash 3.2 compatible.
set -euo pipefail
```

**Check registry**: Define the checks to run as a list. Each check has:
- A display name
- The script path
- Any extra arguments
- Whether it is advisory (warnings don't count as failures)

The check list (in order):
1. "Orphaned Artifacts" — `check-orphaned.sh` (existing, not advisory)
2. "Stale Knowledge" — `check-stale.sh` (existing, not advisory)
3. "Scope Issues" — `check-scope.sh` (existing, not advisory)
4. "Cost Spikes" — `check-cost-spikes.sh` (existing, not advisory)
5. "Instruction Conformance" — `check-instructions.sh --root "$PROJECT_ROOT"` (P04, not advisory)
6. "Provider Conformance" — `check-providers.sh --root "$PROJECT_ROOT"` (P05, not advisory)
7. "Permission Drift" — `check-permissions.sh --project-root "$PROJECT_ROOT" --quiet` (P07, not advisory)
8. "Constitution Coverage" — `check-constitution.sh --root "$PROJECT_ROOT"` (P06 T01, not advisory)
9. "Event Emission" — `check-events.sh --root "$PROJECT_ROOT"` (P06 T01, not advisory)
10. "Content Hashes" — `check-hashes.sh --root "$PROJECT_ROOT"` (P06 T02, not advisory)
11. "Run ID Coverage" — `check-run-ids.sh --root "$PROJECT_ROOT"` (P06 T02, not advisory)
12. "Task Plan Shape" — `check-plans.sh --root "$PROJECT_ROOT"` (P06 T03, **advisory**)

**Runner function**: Rewrite `run_check` to:
1. Run the check script, capture stdout and exit code
2. Parse the first `DOCTOR:` line from output to extract `status=`
3. If `status=ok` or `status=skip`, count as passed
4. If `status=warn` or `status=drift` or `status=missing`, count as failed (unless advisory)
5. Display the check output
6. Return the structured result for aggregation

**Summary section**: After all checks:
```
=== Health Report ===
Checks passed: N / M
Advisory warnings: K
Status: HEALTHY | NEEDS_ATTENTION
```

Where:
- `N` = checks that passed (status=ok or status=skip)
- `M` = total non-advisory checks
- `K` = advisory checks that reported warnings
- Status = HEALTHY if N == M, NEEDS_ATTENTION otherwise

**History append**: Write a JSONL entry with:
```json
{"timestamp":"...","checks_passed":N,"checks_total":M,"advisory_warnings":K,"status":"healthy|needs_attention"}
```

**check-permissions.sh special handling**: This script may exit 2 if the target file doesn't exist (status=missing). Treat exit 2 as a valid non-crash exit. The `DOCTOR:PERMISSIONS status=missing` line should be parsed as a failure (permissions file is missing), not a crash.

### Step 2: Update `extension.yml`

Add the 5 new diagnostic scripts to the `provides.scripts` section. Add them after the existing `check-permissions.sh` entry:

```yaml
    - file: scripts/diagnostics/check-instructions.sh
      executable: true
    - file: scripts/diagnostics/check-constitution.sh
      executable: true
    - file: scripts/diagnostics/check-events.sh
      executable: true
    - file: scripts/diagnostics/check-hashes.sh
      executable: true
    - file: scripts/diagnostics/check-run-ids.sh
      executable: true
    - file: scripts/diagnostics/check-plans.sh
      executable: true
```

Note: `check-instructions.sh` was delivered in P04 but may not yet be registered in extension.yml — verify and add if missing.

### Step 3: Create verification scripts

Create `scripts/verify/p06-scored-doctor.sh`:

```bash
#!/usr/bin/env bash
# Verify run-doctor.sh produces a scored health report.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

script="$PROJECT_ROOT/scripts/diagnostics/run-doctor.sh"

# File exists
[ -f "$script" ] || { echo "FAIL: run-doctor.sh not found"; exit 1; }

# Contains scored output marker
grep -q 'Checks passed' "$script" || { echo "FAIL: run-doctor.sh missing 'Checks passed' output"; exit 1; }

# Runs and produces scored output
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
echo "$output" | grep -q 'Checks passed' || { echo "FAIL: no 'Checks passed' in doctor output"; exit 1; }

# Verify the summary contains N / M format
echo "$output" | grep -qE 'Checks passed: [0-9]+ / [0-9]+' || { echo "FAIL: scored output not in N / M format"; exit 1; }

echo "PASS: run-doctor.sh produces scored health report"
```

Create `scripts/verify/p06-extension-registration.sh`:

```bash
#!/usr/bin/env bash
# Verify all P06 diagnostic scripts are registered in extension.yml.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ext="$PROJECT_ROOT/extension.yml"
missing=0

for script in check-constitution.sh check-events.sh check-hashes.sh check-run-ids.sh check-plans.sh; do
  if ! grep -q "$script" "$ext"; then
    echo "FAIL: $script not registered in extension.yml"
    missing=$((missing + 1))
  fi
done

if [ "$missing" -gt 0 ]; then
  exit 1
fi

echo "PASS: all P06 diagnostic scripts registered in extension.yml"
```

Make both verification scripts executable.

## Must-Haves

- run-doctor.sh produces a scored health report with `Checks passed: N / M` in the summary
- extension.yml registers all new diagnostic scripts under provides.scripts
- run-doctor.sh wires check-permissions.sh (P07) into the aggregated report
- run-doctor.sh treats check-plans.sh as advisory (does not count toward failures)

### Artifacts

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

## Verification

```
bash scripts/verify/p06-scored-doctor.sh
bash scripts/verify/p06-extension-registration.sh
```

Expected: both output `PASS: ...`

## Inputs

### From Previous Tasks
- `scripts/diagnostics/check-constitution.sh` (from T01)
  - Key API: standalone script, takes `--root <path>`, emits `DOCTOR:CONSTITUTION status=<ok|warn> principles_found=N principles_total=13`, exits 0 on ok / 1 on warn
- `scripts/diagnostics/check-events.sh` (from T01)
  - Key API: standalone script, takes `--root <path>`, emits `DOCTOR:EVENTS status=<ok|warn> compliant=N total=N`, exits 0 on ok / 1 on warn
- `scripts/diagnostics/check-hashes.sh` (from T02)
  - Key API: standalone script, takes `--root <path>`, emits `DOCTOR:HASHES status=<ok|warn> valid=N missing=N`, exits 0 on ok / 1 on warn
- `scripts/diagnostics/check-run-ids.sh` (from T02)
  - Key API: standalone script, takes `--root <path>`, emits `DOCTOR:RUNIDS status=<ok|warn> with_id=N without_id=N`, exits 0 on ok / 1 on warn
- `scripts/diagnostics/check-plans.sh` (from T03)
  - Key API: standalone script, takes `--root <path>`, emits `DOCTOR:PLANS status=<ok|warn> heuristic_risk=N trigger=<class>`, **always exits 0** (advisory)

### From Disk (Pre-existing)
- `scripts/diagnostics/run-doctor.sh` — current version to rewrite (runs 6 checks, produces warnings/errors summary without scoring)
- `scripts/diagnostics/check-orphaned.sh` — existing check (no DOCTOR: output, uses WARNING:/ERROR: lines)
- `scripts/diagnostics/check-stale.sh` — existing check (no DOCTOR: output, uses WARNING:/ERROR: lines)
- `scripts/diagnostics/check-scope.sh` — existing check (no DOCTOR: output, uses WARNING:/ERROR: lines)
- `scripts/diagnostics/check-cost-spikes.sh` — existing check (no DOCTOR: output, uses WARNING:/ERROR: lines)
- `scripts/diagnostics/check-instructions.sh` (from P04) — emits `DOCTOR:INSTRUCTIONS status=<ok|warn> files=N missing=N`, exits 0/1
- `scripts/diagnostics/check-providers.sh` (from P05) — emits `DOCTOR:PROVIDERS status=<ok|warn|skip> files=N issues=N`, exits 0/1
- `scripts/diagnostics/check-permissions.sh` (from P07) — emits `DOCTOR:PERMISSIONS status=<ok|drift|missing> gaps=N stale=N`, exits 0/1/2
- `extension.yml` — current registration list to update

## Constraints

- Bash 3.2 compatible
- Must handle mixed output formats: legacy checks (WARNING:/ERROR: lines) and new checks (DOCTOR:* structured lines). For legacy checks without DOCTOR: lines, count as passed if exit code is 0, failed if non-zero.
- check-permissions.sh exits 2 when target is missing — treat as valid non-crash exit
- check-plans.sh is advisory — its warnings contribute to the advisory count but not the pass/fail score
- The `doctor-history.jsonl` entry must include the new `checks_passed` and `checks_total` fields
- extension.yml modifications are additive — do not remove or reorder existing entries

## Expected Output

Modified files:
- `scripts/diagnostics/run-doctor.sh` — ~100-130 lines, scored health report
- `extension.yml` — 5 new script entries added to provides.scripts

New files:
- `scripts/verify/p06-scored-doctor.sh` — ~25 lines
- `scripts/verify/p06-extension-registration.sh` — ~20 lines
