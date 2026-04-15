---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P07"
milestone: "M002"
name: "Verification Scripts for All P07 Must-Haves"
depends_on: []
---

## Prerequisites

P07 has no task-level upstream dependencies. The following diagnostics scripts already exist on disk from prior milestones:

- `scripts/diagnostics/run-doctor.sh` (~136 lines) -- orchestrates all diagnostic checks, produces scored health report, appends to doctor-history.jsonl
- `scripts/diagnostics/check-orphaned.sh` (~69 lines) -- detects index entries without detail files and detail files without index entries
- `scripts/diagnostics/check-stale.sh` (~75 lines) -- flags entries not verified in 90+ days with low hit counts, computes effective confidence via staleness decay
- `scripts/diagnostics/check-scope.sh` (~40 lines) -- flags entries with no scope tags
- `scripts/diagnostics/check-cost-spikes.sh` (~68 lines) -- flags tasks costing >5x average
- `commands/doctor.md` (~32 lines) -- agent instruction document for the doctor command
- `extension.yml` -- already registers speckit.orchestrator.doctor command and all diagnostics scripts

## Description

Create 9 verification scripts under `scripts/verify/m002-p07-*.sh` that mechanically check all P07 must-haves. Each script is a single-file invocation (per AD-19) that prints `PASS: <message>` on success or `FAIL: <message>` on failure, exiting 0 on pass and 1 on fail.

## Steps

### Step 1: Create `scripts/verify/m002-p07-runner-invokes-checks.sh`

Verifies that `run-doctor.sh` invokes all four core diagnostic check scripts as part of its check suite.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/run-doctor.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'check-orphaned.sh' "$f" || { echo "FAIL: run-doctor.sh does not invoke check-orphaned.sh"; exit 1; }
grep -q 'check-stale.sh' "$f" || { echo "FAIL: run-doctor.sh does not invoke check-stale.sh"; exit 1; }
grep -q 'check-scope.sh' "$f" || { echo "FAIL: run-doctor.sh does not invoke check-scope.sh"; exit 1; }
grep -q 'check-cost-spikes.sh' "$f" || { echo "FAIL: run-doctor.sh does not invoke check-cost-spikes.sh"; exit 1; }
grep -q 'run_check' "$f" || { echo "FAIL: run-doctor.sh missing run_check function"; exit 1; }
echo "PASS: run-doctor.sh invokes all four core diagnostic check scripts"
```

### Step 2: Create `scripts/verify/m002-p07-orphaned-detects-both.sh`

Verifies that `check-orphaned.sh` sources index-utils.sh and scans for both directions of orphan (index without detail, detail without index).

```bash
#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/check-orphaned.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'index-utils.sh' "$f" || { echo "FAIL: does not source index-utils.sh"; exit 1; }
grep -q 'index_has_entry' "$f" || { echo "FAIL: does not check for detail files without index entries"; exit 1; }
grep -q 'knowledge_dir' "$f" || grep -q 'knowledge/' "$f" || { echo "FAIL: does not scan knowledge directory for detail files"; exit 1; }
grep -q 'index_path' "$f" || grep -q 'INDEX' "$f" || { echo "FAIL: does not read index for entry scanning"; exit 1; }
grep -q 'WARNING.*no detail file\|WARNING.*Index entry' "$f" || { echo "FAIL: missing warning for index entries without detail files"; exit 1; }
grep -q 'WARNING.*no index entry\|WARNING.*Detail file' "$f" || { echo "FAIL: missing warning for detail files without index entries"; exit 1; }
echo "PASS: check-orphaned.sh detects both orphan directions"
```

### Step 3: Create `scripts/verify/m002-p07-stale-threshold.sh`

Verifies that `check-stale.sh` sources staleness.sh and flags entries past the 90-day staleness threshold.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/check-stale.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'staleness.sh' "$f" || { echo "FAIL: does not source staleness.sh"; exit 1; }
grep -q 'compute_effective_confidence' "$f" || { echo "FAIL: does not compute effective confidence"; exit 1; }
grep -q 'STALE_DAYS=90\|90' "$f" || { echo "FAIL: missing 90-day staleness threshold"; exit 1; }
grep -q 'days_since' "$f" || { echo "FAIL: does not compute days since last verified"; exit 1; }
grep -q 'hit_count\|hits' "$f" || { echo "FAIL: does not check hit count for keep-alive exemption"; exit 1; }
grep -q 'WARNING.*stale' "$f" || { echo "FAIL: missing stale entry warning message"; exit 1; }
echo "PASS: check-stale.sh flags entries past 90-day threshold with low hits"
```

### Step 4: Create `scripts/verify/m002-p07-scope-flags-unscoped.sh`

Verifies that `check-scope.sh` flags entries with no scope tags.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/check-scope.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'scope_tag' "$f" || { echo "FAIL: does not extract scope tag from index"; exit 1; }
grep -q 'WARNING.*no scope tag\|WARNING.*unscoped\|WARNING.*ALL dispatches' "$f" || { echo "FAIL: missing warning for unscoped entries"; exit 1; }
grep -q 'index-utils.sh' "$f" || { echo "FAIL: does not source index-utils.sh"; exit 1; }
echo "PASS: check-scope.sh flags entries with no scope tags"
```

### Step 5: Create `scripts/verify/m002-p07-cost-spike-threshold.sh`

Verifies that `check-cost-spikes.sh` flags tasks costing >5x the average.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/check-cost-spikes.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'cost_estimated' "$f" || { echo "FAIL: does not parse cost_estimated from execution log"; exit 1; }
grep -q '5\|spike_threshold' "$f" || { echo "FAIL: missing 5x cost spike threshold"; exit 1; }
grep -q 'avg_cost\|average' "$f" || { echo "FAIL: does not compute average cost"; exit 1; }
grep -q 'execution-log.jsonl\|exec_log' "$f" || { echo "FAIL: does not read execution-log.jsonl"; exit 1; }
grep -q 'WARNING.*cost\|WARNING.*spike' "$f" || { echo "FAIL: missing cost spike warning message"; exit 1; }
grep -q 'unit_id\|unitId' "$f" || { echo "FAIL: does not include unit ID in warning"; exit 1; }
echo "PASS: check-cost-spikes.sh flags tasks costing >5x average"
```

### Step 6: Create `scripts/verify/m002-p07-history-append.sh`

Verifies that `run-doctor.sh` appends JSON to doctor-history.jsonl with required fields.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/diagnostics/run-doctor.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'doctor-history.jsonl' "$f" || { echo "FAIL: does not reference doctor-history.jsonl"; exit 1; }
grep -q 'timestamp' "$f" || { echo "FAIL: missing timestamp field in history output"; exit 1; }
grep -q 'checks_passed' "$f" || { echo "FAIL: missing checks_passed field in history output"; exit 1; }
grep -q 'checks_total' "$f" || { echo "FAIL: missing checks_total field in history output"; exit 1; }
grep -q 'status' "$f" || { echo "FAIL: missing status field in history output"; exit 1; }
grep -q '>>' "$f" || { echo "FAIL: does not append (>>) to history file"; exit 1; }
echo "PASS: run-doctor.sh appends JSON with required fields to doctor-history.jsonl"
```

### Step 7: Create `scripts/verify/m002-p07-doctor-md-sections.sh`

Verifies that `commands/doctor.md` describes all four core check categories.

```bash
#!/usr/bin/env bash
set -eu
f="commands/doctor.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qi 'orphan' "$f" || { echo "FAIL: doctor.md does not mention orphaned artifacts"; exit 1; }
grep -qi 'stale' "$f" || { echo "FAIL: doctor.md does not mention stale knowledge"; exit 1; }
grep -qi 'scope' "$f" || { echo "FAIL: doctor.md does not mention scope issues"; exit 1; }
grep -qi 'cost' "$f" || { echo "FAIL: doctor.md does not mention cost spikes"; exit 1; }
grep -q 'speckit.orchestrator.doctor' "$f" || { echo "FAIL: doctor.md missing command name"; exit 1; }
grep -q 'run-doctor.sh' "$f" || { echo "FAIL: doctor.md does not reference run-doctor.sh"; exit 1; }
echo "PASS: doctor.md describes all four core check categories"
```

### Step 8: Create `scripts/verify/m002-p07-extension-registration.sh`

Verifies that `extension.yml` registers the doctor command and all four core diagnostics scripts.

```bash
#!/usr/bin/env bash
set -eu
f="extension.yml"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'speckit.orchestrator.doctor' "$f" || { echo "FAIL: doctor command not registered"; exit 1; }
grep -q 'commands/doctor.md' "$f" || { echo "FAIL: commands/doctor.md not registered"; exit 1; }
grep -q 'scripts/diagnostics/run-doctor.sh' "$f" || { echo "FAIL: run-doctor.sh not registered"; exit 1; }
grep -q 'scripts/diagnostics/check-orphaned.sh' "$f" || { echo "FAIL: check-orphaned.sh not registered"; exit 1; }
grep -q 'scripts/diagnostics/check-stale.sh' "$f" || { echo "FAIL: check-stale.sh not registered"; exit 1; }
grep -q 'scripts/diagnostics/check-scope.sh' "$f" || { echo "FAIL: check-scope.sh not registered in extension.yml"; exit 1; }
grep -q 'scripts/diagnostics/check-cost-spikes.sh' "$f" || { echo "FAIL: check-cost-spikes.sh not registered"; exit 1; }
echo "PASS: extension.yml registers doctor command and all core diagnostics scripts"
```

### Step 9: Create `scripts/verify/m002-p07-bash32-compat.sh`

Verifies that all diagnostics scripts are Bash 3.2 compatible.

```bash
#!/usr/bin/env bash
set -eu
files="scripts/diagnostics/run-doctor.sh scripts/diagnostics/check-orphaned.sh scripts/diagnostics/check-stale.sh scripts/diagnostics/check-scope.sh scripts/diagnostics/check-cost-spikes.sh"
for f in $files; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
grep -rlE 'declare -A|readarray|mapfile' $files && { echo "FAIL: Bash 3.2 incompatible constructs found"; exit 1; }
echo "PASS: all diagnostics scripts are Bash 3.2 compatible"
```

### Step 10: Make all scripts executable

```bash
chmod +x scripts/verify/m002-p07-*.sh
```

## Must-Haves

This task delivers all 9 verification scripts required by the phase plan. Every other task in this phase uses these scripts for mechanical verification.

## Verification

Run each verification script. Since existing scripts already deliver the M002 diagnostics implementation, most checks should pass immediately:

```
bash scripts/verify/m002-p07-runner-invokes-checks.sh
bash scripts/verify/m002-p07-orphaned-detects-both.sh
bash scripts/verify/m002-p07-stale-threshold.sh
bash scripts/verify/m002-p07-scope-flags-unscoped.sh
bash scripts/verify/m002-p07-cost-spike-threshold.sh
bash scripts/verify/m002-p07-history-append.sh
bash scripts/verify/m002-p07-doctor-md-sections.sh
bash scripts/verify/m002-p07-extension-registration.sh
bash scripts/verify/m002-p07-bash32-compat.sh
```

Expected output for each: `PASS: <description>`

## Inputs

### From Previous Tasks

None -- this is the first task in the phase.

### From Disk (Pre-existing)

- `scripts/diagnostics/run-doctor.sh` -- orchestrates diagnostic checks. Defines `run_check()` function that runs each check script, captures output, parses `DOCTOR:` status lines or exit codes, and tallies pass/fail. Appends JSON summary to `doctor-history.jsonl` with `timestamp`, `checks_passed`, `checks_total`, `advisory_warnings`, `status` fields.
- `scripts/diagnostics/check-orphaned.sh` -- orphan detection. Sources `scripts/knowledge/lib/index-utils.sh`. Reads `KNOWLEDGE-INDEX.md` line by line, checks each entry ID against `knowledge/{category}/{id}.md` files. Then scans `knowledge/*/*.md` (excluding archive) and checks each against the index via `index_has_entry()`. Prints `WARNING:` lines for orphans, `PASS:` if clean.
- `scripts/diagnostics/check-stale.sh` -- staleness detection. Sources both `index-utils.sh` and `staleness.sh`. Reads index, parses `verified:YYYY-MM-DD` and `hits:N` fields, calls `days_since()` and `compute_effective_confidence()`. Flags entries with >=90 days since verification AND <=10 hits. Also flags entries with effective confidence <= 0.50. Prints `WARNING:` or `PASS:`.
- `scripts/diagnostics/check-scope.sh` -- scope detection. Sources `index-utils.sh`. Reads index, extracts column 2 (scope tag). Flags empty scope tags with `WARNING:` message. Prints `PASS:` if all entries have scope tags.
- `scripts/diagnostics/check-cost-spikes.sh` -- cost spike detection. Reads `execution-log.jsonl`, extracts `cost_estimated` field via sed, computes average with awk, flags entries >5x average. Includes `unit_id` in warning. Falls back gracefully when no log or insufficient data.
- `commands/doctor.md` -- agent instruction document. Lists 4 check categories (Orphaned Artifacts, Stale Knowledge, Scope Issues, Cost Spikes). References `run-doctor.sh` usage.
- `extension.yml` -- extension manifest. Registers `speckit.orchestrator.doctor` command pointing to `commands/doctor.md`. Registers all diagnostics scripts under `provides.scripts`.

## Constraints

- All verification scripts must use single-script-file invocation shape per AD-19
- No compound bash, no subshells, no pipes inside $(), no inline for/if/while in Check: commands
- Each script must be independently executable: `bash scripts/verify/m002-p07-<name>.sh`
- Scripts must print PASS/FAIL and exit 0/1 respectively

## Expected Output

9 new files under `scripts/verify/`:
- `m002-p07-runner-invokes-checks.sh`
- `m002-p07-orphaned-detects-both.sh`
- `m002-p07-stale-threshold.sh`
- `m002-p07-scope-flags-unscoped.sh`
- `m002-p07-cost-spike-threshold.sh`
- `m002-p07-history-append.sh`
- `m002-p07-doctor-md-sections.sh`
- `m002-p07-extension-registration.sh`
- `m002-p07-bash32-compat.sh`

All scripts are executable and follow the single-script-file shape convention.
