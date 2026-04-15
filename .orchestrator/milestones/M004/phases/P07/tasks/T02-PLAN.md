---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P07"
milestone: "M004"
name: "Register check-recipe.sh in run-doctor.sh and extension.yml"
depends_on: [T01]
---

## Prerequisites

Before starting, verify from the repo root:

```bash
# T01 complete: check-recipe.sh exists
test -f scripts/diagnostics/check-recipe.sh && echo "ok: check-recipe.sh exists"

# check-recipe.sh emits DOCTOR:RECIPE output
bash scripts/diagnostics/check-recipe.sh --root . 2>/dev/null | grep -q 'DOCTOR:RECIPE' && echo "ok: DOCTOR:RECIPE output"

# run-doctor.sh exists
test -f scripts/diagnostics/run-doctor.sh && echo "ok: run-doctor.sh"

# extension.yml exists
test -f extension.yml && echo "ok: extension.yml"
```

All must print `ok:`. If any fail, STOP.

## Description

Register the new `check-recipe.sh` diagnostic in two places:

1. **run-doctor.sh** -- Add a `run_check "Recipe Conformance"` call that invokes `check-recipe.sh` with the `--root $PROJECT_ROOT` argument pattern. Place it after the existing check calls (after "Run ID Coverage" and before "Task Plan Shape" since recipe conformance is a non-advisory structural check, while "Task Plan Shape" is advisory).

2. **extension.yml** -- Add a script entry for `scripts/diagnostics/check-recipe.sh` in the `provides.scripts` section, following the existing pattern for diagnostic scripts.

This task implements the M004 roadmap requirement that `run-doctor.sh` runs the recipe conformance check alongside existing checks, with results appended to `doctor-history.jsonl`.

## Cross-Cutting Constraints (verbatim from P07-PLAN.md)

1. **Bash 3.2** -- no `declare -A`, no `readarray`, no `mapfile`, no `<(...)` as redirect target.
2. **DOCTOR: output convention** -- check-recipe.sh already emits DOCTOR:RECIPE; run-doctor.sh must parse it.
3. **Do not modify check-constitution.sh, check-events.sh, or any P02/P05/P06 scripts.**
4. **Preserve existing run-doctor.sh structure** -- only add the new check call; do not change existing checks.

## Steps

### Step 1: Read the current run-doctor.sh

Read `scripts/diagnostics/run-doctor.sh` in full. Understand the `run_check` pattern and the ordering of existing checks.

### Step 2: Add recipe conformance check to run-doctor.sh

Add the following line after the "Run ID Coverage" check (line 111) and before the "Task Plan Shape" check (line 112):

```
run_check "Recipe Conformance" "$SCRIPT_DIR/check-recipe.sh" "--root $PROJECT_ROOT" "0"
```

The check is non-advisory (`"0"` as the 4th argument), meaning it counts toward the pass/fail score. Recipe conformance is a structural requirement, not an advisory lint.

### Step 3: Register check-recipe.sh in extension.yml

In the `provides.scripts` section of `extension.yml`, add:

```yaml
    - file: scripts/diagnostics/check-recipe.sh
      executable: true
```

Place it after the existing `check-plans.sh` entry (the last diagnostics script currently registered).

### Step 4: Verify the changes

Run from repo root:

```bash
# Verify run-doctor.sh includes the recipe check
bash scripts/diagnostics/run-doctor.sh --root . 2>&1 | grep -q 'Recipe Conformance'

# Verify extension.yml includes check-recipe.sh
grep -q 'check-recipe.sh' extension.yml
```

## Must-Haves

### Truths

- run-doctor.sh includes the recipe conformance check
  - Check: `bash scripts/verify/m004-p07-doctor-recipe.sh`
- extension.yml registers check-recipe.sh
  - Check: `bash scripts/verify/m004-p07-extension-recipe.sh`

### Artifacts

- scripts/diagnostics/run-doctor.sh (contains "check-recipe.sh")
- extension.yml (contains "check-recipe.sh")

## Verification

Run from repo root:
1. `bash scripts/verify/m004-p07-doctor-recipe.sh` -- PASS
2. `bash scripts/verify/m004-p07-extension-recipe.sh` -- PASS
3. `grep -q 'Recipe Conformance' scripts/diagnostics/run-doctor.sh` -- exits 0
4. `grep -q 'check-recipe.sh' extension.yml` -- exits 0

## Inputs

### From Previous Tasks

- T01: `scripts/diagnostics/check-recipe.sh` must exist and emit `DOCTOR:RECIPE` output.

**API surface from T01:** The script accepts `--root <project-root>` as an argument and emits a single `DOCTOR:RECIPE status=<ok|warn> sections=N invalid=N` line to stdout.

### From Disk

- scripts/diagnostics/run-doctor.sh -- the file to modify. Contains `run_check` calls for each diagnostic. Currently has 12 check calls (lines 101-112).
- extension.yml -- the file to modify. Contains script registrations under `provides.scripts`.

## Constraints

- Do not reorder or modify existing `run_check` calls in run-doctor.sh.
- The new check must be non-advisory (counts toward pass/fail total).
- The extension.yml entry must match the existing format exactly.
- Do not change the scoring or history-append logic in run-doctor.sh.

## Expected Output

- Modified scripts/diagnostics/run-doctor.sh with one new `run_check` call for "Recipe Conformance"
- Modified extension.yml with one new script entry for scripts/diagnostics/check-recipe.sh
