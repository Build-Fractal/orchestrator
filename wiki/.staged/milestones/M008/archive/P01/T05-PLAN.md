---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M008"
name: "Bash 3.2 compatibility check + integration smoke test"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 complete: `scripts/dispatch/detect-capabilities.sh` refactored with new capabilities and `--profile` flag.
- T02 complete: `scripts/engine/intensity-analyze.sh` exists and outputs structured analysis.
- T03 complete: `scripts/engine/intensity-recommend.sh` exists and combines analysis + capabilities.
- T04 complete: `templates/intensity-metadata.md` and `scripts/engine/context-pressure.sh` exist.
- All 9 verification scripts from T01-T04 pass.

## Description

Two deliverables:

1. **Bash 3.2 compatibility verification script** -- scans all new/modified
   scripts from P01 for Bash 3.2 incompatible constructs: `declare -A`
   (associative arrays), `readarray`/`mapfile`, `|&` (pipe stderr), `&>>`
   (append redirect), `${var,,}` or `${var^^}` (case modification), and
   `[[ $var =~ pattern ]]` with variable patterns (literal patterns are OK).
   This is the standard compatibility check used across all milestones.

2. **Integration smoke test** -- runs the full end-to-end intensity engine
   pipeline: detect capabilities -> analyze description -> recommend intensity.
   Verifies:
   - The pipeline produces valid output for three representative descriptions
     (trivial, moderate, large+risky)
   - All scripts exit 0
   - Output fields are present and have valid values
   - The recommendation engine correctly consumes analyzer and capability outputs
   - context-pressure.sh correctly evaluates a simulated payload

This task does NOT create new functionality -- it only verifies that T01-T04
deliverables work together correctly.

## Steps

### Step 1 -- Create `scripts/verify/m008-p01-bash32-compat.sh`

```bash
#!/usr/bin/env bash
# Verifies all P01 scripts are Bash 3.2 compatible.
# Checks for prohibited constructs: declare -A, readarray, mapfile, |&, &>>,
# ${var,,}, ${var^^}, variable regex patterns.
set -eu

fail_count=0
pass_count=0

check_file() {
  local f="$1"
  local bad=false

  # declare -A (associative arrays)
  if grep -nE 'declare\s+-A\b' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses declare -A (associative arrays)"
    bad=true
  fi

  # readarray / mapfile
  if grep -nE '\b(readarray|mapfile)\b' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses readarray/mapfile"
    bad=true
  fi

  # |& (pipe stderr)
  if grep -nE '\|\&' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses |& (pipe stderr)"
    bad=true
  fi

  # &>> (append redirect both)
  if grep -nE '\&>>' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses &>> (append redirect)"
    bad=true
  fi

  # ${var,,} or ${var^^} (case modification)
  if grep -nE '\$\{[a-zA-Z_][a-zA-Z0-9_]*(,,|^^)\}' "$f" >/dev/null 2>&1; then
    echo "FAIL: $f uses case modification syntax"
    bad=true
  fi

  if [[ "$bad" = true ]]; then
    fail_count=$((fail_count + 1))
  else
    pass_count=$((pass_count + 1))
  fi
}

# Check all P01 scripts
check_file "scripts/dispatch/detect-capabilities.sh"
check_file "scripts/engine/intensity-analyze.sh"
check_file "scripts/engine/intensity-recommend.sh"
check_file "scripts/engine/context-pressure.sh"

if [[ "$fail_count" -gt 0 ]]; then
  echo "FAIL: $fail_count file(s) have Bash 3.2 incompatible constructs"
  exit 1
fi

echo "PASS: all $pass_count P01 scripts are Bash 3.2 compatible"
```

### Step 2 -- Run the integration smoke test

This step is the verification for T05. It is performed by running all
verification scripts from T01-T04 plus the bash32 compat check, and then
performing three end-to-end pipeline tests.

The integration tests are embedded in the verification section below and
do not require a separate script file. However, for automated execution
via the orchestrator's verification system, we verify by running the
bash32-compat script which covers the cross-cutting concern.

The three end-to-end pipeline tests to run manually (or in a future
integration test script):

**Test A -- Trivial task:**
```bash
output="$(echo "Fix a typo in the README" | bash scripts/engine/intensity-recommend.sh 2>/dev/null)"
echo "$output" | grep -q "^intensity=Quick" || echo "FAIL: trivial should be Quick"
echo "$output" | grep -q "^confidence=high" || echo "FAIL: trivial should be high confidence"
```

**Test B -- Moderate task:**
```bash
output="$(echo "Add a new API endpoint for user profiles with validation" | bash scripts/engine/intensity-recommend.sh 2>/dev/null)"
echo "$output" | grep -q "^intensity=Standard" || echo "FAIL: moderate should be Standard"
```

**Test C -- Large + risky task:**
```bash
output="$(echo "Rewrite the authentication system with database migration and OAuth2 integration" | bash scripts/engine/intensity-recommend.sh 2>/dev/null)"
echo "$output" | grep -q "^intensity=Full" || echo "FAIL: large+risky should be Full"
echo "$output" | grep -q "^risk_signals=" || echo "FAIL: should have risk signals"
risk_signals="$(echo "$output" | grep "^risk_signals=" | cut -d= -f2-)"
test "$risk_signals" != "none" || echo "FAIL: risk signals should not be none"
```

**Test D -- Context pressure integration:**
```bash
output="$(bash scripts/engine/context-pressure.sh --tokens 5000 --intensity Quick 2>/dev/null)"
echo "$output" | grep -q "^pressure=low" || echo "FAIL: 5k tokens should be low pressure"
echo "$output" | grep -q "^action=proceed" || echo "FAIL: low pressure should proceed"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "All scripts are Bash 3.2 compatible (no associative arrays, no
  readarray, no |&)."
- **Artifacts**: `scripts/verify/m008-p01-bash32-compat.sh`.

## Verification

Run the verification script:

```bash
bash scripts/verify/m008-p01-bash32-compat.sh
```

Should print PASS and exit 0.

Then run ALL phase P01 verification scripts to confirm everything passes:

```bash
bash scripts/verify/m008-p01-capabilities-backward-compat.sh
bash scripts/verify/m008-p01-capabilities-profile.sh
bash scripts/verify/m008-p01-analyze-output-format.sh
bash scripts/verify/m008-p01-analyze-trivial.sh
bash scripts/verify/m008-p01-analyze-moderate.sh
bash scripts/verify/m008-p01-analyze-risk-escalation.sh
bash scripts/verify/m008-p01-recommend-output-format.sh
bash scripts/verify/m008-p01-recommend-capabilities.sh
bash scripts/verify/m008-p01-metadata-template.sh
bash scripts/verify/m008-p01-context-pressure.sh
bash scripts/verify/m008-p01-bash32-compat.sh
```

All 11 should print PASS and exit 0.

### Files Touched By This Task

- `scripts/verify/m008-p01-bash32-compat.sh` (create)

## Inputs

### From Previous Tasks

- **T01**: `scripts/dispatch/detect-capabilities.sh` (modified) --
  `bash scripts/verify/m008-p01-capabilities-backward-compat.sh` and
  `bash scripts/verify/m008-p01-capabilities-profile.sh` must pass.

- **T02**: `scripts/engine/intensity-analyze.sh` (created) --
  `bash scripts/verify/m008-p01-analyze-output-format.sh`,
  `bash scripts/verify/m008-p01-analyze-trivial.sh`,
  `bash scripts/verify/m008-p01-analyze-moderate.sh`, and
  `bash scripts/verify/m008-p01-analyze-risk-escalation.sh` must pass.

- **T03**: `scripts/engine/intensity-recommend.sh` (created) --
  `bash scripts/verify/m008-p01-recommend-output-format.sh` and
  `bash scripts/verify/m008-p01-recommend-capabilities.sh` must pass.

- **T04**: `templates/intensity-metadata.md` and `scripts/engine/context-pressure.sh`
  (created) -- `bash scripts/verify/m008-p01-metadata-template.sh` and
  `bash scripts/verify/m008-p01-context-pressure.sh` must pass.

### From Disk (Pre-existing)

None beyond T01-T04 outputs.

## Constraints

- This task creates only ONE new file (the bash32-compat check script).
- The integration tests are manual verification steps, not additional scripts,
  to avoid speculative complexity (Constitution XIV).
- All 11 verification scripts from the phase must pass for P01 to be considered
  complete.

## Expected Output

After completing this task:

1. `scripts/verify/m008-p01-bash32-compat.sh` exists, ~50+ lines.
2. `bash scripts/verify/m008-p01-bash32-compat.sh` prints PASS -- all 4 P01
   scripts pass the Bash 3.2 compatibility check.
3. All 11 P01 verification scripts pass (PASS output, exit 0).
4. The end-to-end pipeline test confirms:
   - "Fix a typo in the README" -> Quick, high confidence
   - "Add a new API endpoint..." -> Standard
   - "Rewrite the authentication system..." -> Full with risk signals
5. `git status` shows 1 new file.
