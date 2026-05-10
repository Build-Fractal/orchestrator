---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P06"
milestone: "M005"
name: "check-constitution.sh + check-events.sh"
depends_on: []
---

## Prerequisites

All upstream phases (P01–P05, P07) are complete. The constitution at `.specify/memory/constitution.md` defines 13 principles (I–XIII). Engine-path scripts in `scripts/state/`, `scripts/dispatch/`, `scripts/lifecycle/`, `scripts/knowledge/`, and `scripts/telemetry/` should emit events per Principle II.

## Description

Create two new diagnostic scripts:

1. **`scripts/diagnostics/check-constitution.sh`** — Scans active phase plan files for references to constitution principles. The v2.0 constitution has 13 principles (I through XIII). The script checks that active phase plans collectively reference all 13. Emits `DOCTOR:CONSTITUTION status=<ok|warn> principles_found=N principles_total=13`.

2. **`scripts/diagnostics/check-events.sh`** — Scans engine-path scripts (under `scripts/state/`, `scripts/dispatch/`, `scripts/lifecycle/`, `scripts/knowledge/`, `scripts/telemetry/`) for `emit_event` calls. Per Principle II amended in v2.0, engine-managed scripts must emit structured events. Reports which scripts lack `emit_event`. Emits `DOCTOR:EVENTS status=<ok|warn> compliant=N total=N`.

## Steps

### Step 1: Create `scripts/diagnostics/check-constitution.sh`

Create the file at `scripts/diagnostics/check-constitution.sh` with these characteristics:

```bash
#!/usr/bin/env bash
# scripts/diagnostics/check-constitution.sh — Constitution v2.0 principle coverage check.
#
# Scans active phase plan files for references to constitution principles I-XIII.
# Active plans = plans under the current milestone's phases/ directories.
#
# Usage: check-constitution.sh [--root <project-root>] [--milestone-dir <dir>]
#
# Output: DOCTOR:CONSTITUTION status=<ok|warn> principles_found=N principles_total=13
#
# Bash 3.2 compatible.
set -eu
```

**Arguments:**
- `--root <project-root>` — defaults to `PROJECT_ROOT` env var or two levels up from script
- `--milestone-dir <dir>` — directory to scan for phase plans. If not provided, scan all milestone dirs under `<root>/.specify/orchestrator/milestones/`

**Logic:**
1. Define the 13 principle identifiers. Use both Roman numeral forms and keyword forms for matching:
   - Principle I / "Context Minimization"
   - Principle II / "Evidence Before Claims"
   - Principle III / "Design Before Code"
   - Principle IV / "Plans Assume Zero Context" / "Zero Context"
   - Principle V / "Fresh Context Per Unit" / "Fresh Context"
   - Principle VI / "State On Disk" / "Disk Is Truth"
   - Principle VII / "Knowledge Compounds"
   - Principle VIII / "No Dead Infrastructure" / "Dead Infrastructure"
   - Principle IX / "Reproducibility Over Convenience" / "Reproducibility"
   - Principle X / "Templating Over Inference"
   - Principle XI / "Single Source of Truth"
   - Principle XII / "Hook Isolation"
   - Principle XIII / "Agent Instruction Schema" / "Instruction Schema"

2. Find all `*-PLAN.md` files under the target milestone directory's `phases/` subdirectories.

3. For each principle, check whether any plan file references it (by Roman numeral pattern like `Principle IV` or `Principle 4` or by keyword). A principle is "found" if at least one plan references it.

4. Count found vs total (13). If all 13 are found, `status=ok`. Otherwise `status=warn` and list which principles are missing.

5. Output the structured line: `DOCTOR:CONSTITUTION status=<ok|warn> principles_found=N principles_total=13`

6. If `status=warn`, list each missing principle on a separate line prefixed with `  MISSING: `.

7. Exit 0 on ok, exit 1 on warn (consistent with other doctor checks).

Make the file executable: `chmod +x scripts/diagnostics/check-constitution.sh`

### Step 2: Create `scripts/diagnostics/check-events.sh`

Create the file at `scripts/diagnostics/check-events.sh` with these characteristics:

```bash
#!/usr/bin/env bash
# scripts/diagnostics/check-events.sh — Engine-path event emission check.
#
# Scans engine-path scripts for emit_event calls per Constitution Principle II
# (v2.0 amendment: engine-managed scripts MUST emit structured events).
#
# Usage: check-events.sh [--root <project-root>]
#
# Output: DOCTOR:EVENTS status=<ok|warn> compliant=N total=N
#
# Bash 3.2 compatible.
set -eu
```

**Arguments:**
- `--root <project-root>` — defaults to `PROJECT_ROOT` env var or two levels up from script

**Logic:**
1. Define the engine-path directories: `scripts/state`, `scripts/dispatch`, `scripts/lifecycle`, `scripts/knowledge`, `scripts/telemetry`.

2. Collect all `.sh` files from these directories. Exclude lib scripts (`scripts/lib/`) since they are sourced, not executed as entry points.

3. For each script, check if it contains the string `emit_event` (via `grep -q 'emit_event'`).

4. Count compliant (has emit_event) vs total. If all are compliant, `status=ok`. Otherwise `status=warn` and list non-compliant scripts.

5. Output the structured line: `DOCTOR:EVENTS status=<ok|warn> compliant=N total=N`

6. If `status=warn`, list each non-compliant script on a separate line prefixed with `  MISSING: `.

7. Exit 0 on ok, exit 1 on warn.

Make the file executable: `chmod +x scripts/diagnostics/check-events.sh`

### Step 3: Create verification scripts

Create `scripts/verify/p06-check-constitution.sh`:

```bash
#!/usr/bin/env bash
# Verify check-constitution.sh exists, is executable, contains DOCTOR:CONSTITUTION,
# and runs without error.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

script="$PROJECT_ROOT/scripts/diagnostics/check-constitution.sh"

# File exists
[ -f "$script" ] || { echo "FAIL: check-constitution.sh not found"; exit 1; }

# Is executable
[ -x "$script" ] || { echo "FAIL: check-constitution.sh not executable"; exit 1; }

# Contains structured output marker
grep -q 'DOCTOR:CONSTITUTION' "$script" || { echo "FAIL: missing DOCTOR:CONSTITUTION output"; exit 1; }

# Runs without crash (exit 0 or 1 are both valid)
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
echo "$output" | grep -q 'DOCTOR:CONSTITUTION' || { echo "FAIL: no DOCTOR:CONSTITUTION in output"; exit 1; }

echo "PASS: check-constitution.sh verified"
```

Create `scripts/verify/p06-check-events.sh`:

```bash
#!/usr/bin/env bash
# Verify check-events.sh exists, is executable, contains DOCTOR:EVENTS,
# and runs without error.
set -eu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

script="$PROJECT_ROOT/scripts/diagnostics/check-events.sh"

# File exists
[ -f "$script" ] || { echo "FAIL: check-events.sh not found"; exit 1; }

# Is executable
[ -x "$script" ] || { echo "FAIL: check-events.sh not executable"; exit 1; }

# Contains structured output marker
grep -q 'DOCTOR:EVENTS' "$script" || { echo "FAIL: missing DOCTOR:EVENTS output"; exit 1; }

# Runs without crash
output="$(bash "$script" --root "$PROJECT_ROOT" 2>&1)" || true
echo "$output" | grep -q 'DOCTOR:EVENTS' || { echo "FAIL: no DOCTOR:EVENTS in output"; exit 1; }

echo "PASS: check-events.sh verified"
```

Make both verification scripts executable.

## Must-Haves

- check-constitution.sh scans phase plan files for principle references and emits `DOCTOR:CONSTITUTION status=<ok|warn> principles_found=N principles_total=13`
- check-events.sh scans engine-path scripts for `emit_event` presence and emits `DOCTOR:EVENTS status=<ok|warn> compliant=N total=N`

### Artifacts

- scripts/diagnostics/check-constitution.sh (min 40 lines, contains "DOCTOR:CONSTITUTION")
- scripts/diagnostics/check-events.sh (min 40 lines, contains "DOCTOR:EVENTS")

## Verification

```
bash scripts/verify/p06-check-constitution.sh
bash scripts/verify/p06-check-events.sh
```

Expected: both output `PASS: ...`

## Inputs

### From Previous Tasks
None — this is the first task in P06.

### From Disk (Pre-existing)
- `.specify/memory/constitution.md` — defines the 13 principles (I–XIII) that check-constitution.sh validates against
- `scripts/state/*.sh`, `scripts/dispatch/*.sh`, `scripts/lifecycle/*.sh`, `scripts/knowledge/*.sh`, `scripts/telemetry/*.sh` — engine-path scripts that check-events.sh validates for emit_event presence
- `scripts/lib/events.sh` — provides `emit_event` function (defines what check-events.sh looks for)
- `.specify/orchestrator/milestones/M005/phases/P*/P*-PLAN.md` — active phase plans that check-constitution.sh scans for principle references
- Existing doctor checks (`check-instructions.sh`, `check-providers.sh`, `check-permissions.sh`) — follow the `DOCTOR:*` structured output pattern that these new scripts must match

## Constraints

- Bash 3.2 compatible (no associative arrays, no `mapfile`, no `declare -A`)
- Follow the `DOCTOR:*` structured output protocol established by P04/P05
- Exit 0 on ok, exit 1 on warn — consistent with other diagnostic scripts
- These are advisory checks — they report state, they do not fix it
- Do not source `errors.sh` or `events.sh` — diagnostic scripts are read-only observers, not engine-path scripts

## Expected Output

Two new files:
- `scripts/diagnostics/check-constitution.sh` — ~60-80 lines
- `scripts/diagnostics/check-events.sh` — ~50-70 lines
- `scripts/verify/p06-check-constitution.sh` — ~25 lines
- `scripts/verify/p06-check-events.sh` — ~25 lines

All executable. Both diagnostic scripts emit `DOCTOR:*` structured output.
