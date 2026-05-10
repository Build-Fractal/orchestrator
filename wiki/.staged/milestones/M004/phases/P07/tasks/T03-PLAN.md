---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P07"
milestone: "M004"
name: "Verification helper scripts and phase verification"
depends_on: [T01, T02]
---

## Prerequisites

Before starting, verify from the repo root:

```bash
# T01 complete: check-recipe.sh exists and passes
bash scripts/diagnostics/check-recipe.sh --root . 2>/dev/null | grep -q 'DOCTOR:RECIPE' && echo "ok: T01 complete"

# T02 complete: run-doctor.sh includes recipe check
grep -q 'check-recipe.sh' scripts/diagnostics/run-doctor.sh && echo "ok: T02 doctor"
grep -q 'check-recipe.sh' extension.yml && echo "ok: T02 extension"

# Pre-existing checks work
bash scripts/diagnostics/check-events.sh --root . 2>/dev/null | grep -q 'DOCTOR:EVENTS' && echo "ok: events check"
bash scripts/diagnostics/check-constitution.sh --root . 2>/dev/null | grep -q 'DOCTOR:CONSTITUTION' && echo "ok: constitution check"
```

All must print `ok:`. If any fail, STOP.

## Description

Create verification helper scripts for all P07 truth checks and run the full phase verification. This is primarily a verification task -- the scripts are thin wrappers that validate the truths declared in P07-PLAN.md. Each helper script is a single-file invocation per AD-19.

The verification helpers confirm:
1. check-recipe.sh exists, is executable, and produces correct output
2. check-recipe.sh validates fields, source types, and priorities
3. run-doctor.sh includes the recipe conformance check
4. extension.yml registers check-recipe.sh
5. Pre-existing check-events.sh and check-constitution.sh satisfy M004 requirements

## Cross-Cutting Constraints (verbatim from P07-PLAN.md)

1. **Bash 3.2** -- no `declare -A`, no `readarray`, no `mapfile`, no `<(...)` as redirect target.
2. **No jq.**
3. **AD-19 shape** -- verification helper scripts must be single-file invocations. No inline compound bash in Check: commands.
4. **Do not modify check-constitution.sh, check-events.sh, or any P02/P05/P06 scripts.**

## Steps

### Step 1: Create verification helper scripts

Create the following scripts under scripts/verify/:

**m004-p07-recipe-exists.sh** -- Verifies check-recipe.sh exists and is executable.

**m004-p07-recipe-fields.sh** -- Runs check-recipe.sh on the default recipe and verifies all 7 sections are validated (sections=7 in output).

**m004-p07-recipe-sources.sh** -- Verifies check-recipe.sh catches invalid source types by creating a temporary invalid recipe and running the check against it.

**m004-p07-recipe-priorities.sh** -- Verifies check-recipe.sh catches invalid priorities by creating a temporary invalid recipe and running the check against it.

**m004-p07-recipe-output.sh** -- Verifies check-recipe.sh emits DOCTOR:RECIPE structured output with status, sections, and invalid fields.

**m004-p07-doctor-recipe.sh** -- Verifies run-doctor.sh contains the check-recipe.sh invocation.

**m004-p07-extension-recipe.sh** -- Verifies extension.yml contains check-recipe.sh.

**m004-p07-events-existing.sh** -- Verifies check-events.sh exists and produces DOCTOR:EVENTS output.

**m004-p07-constitution-existing.sh** -- Verifies check-constitution.sh exists and produces DOCTOR:CONSTITUTION output.

Each script:
- Prints PASS/FAIL lines
- Exits 0 if all checks pass, 1 if any fail
- Uses the standard verification helper pattern from P06

### Step 2: Make all scripts executable

```bash
chmod +x scripts/verify/m004-p07-*.sh
```

### Step 3: Run all verification helpers

Run each verification helper script from the repo root to confirm all P07 truths pass.

### Step 4: Run full doctor suite

Run `bash scripts/diagnostics/run-doctor.sh --root .` and verify the Recipe Conformance check appears in the output and passes.

## Must-Haves

### Truths

- All 9 verification helper scripts exist and are executable
  - Check: `bash scripts/verify/m004-p07-recipe-exists.sh`
- check-recipe.sh validates fields correctly
  - Check: `bash scripts/verify/m004-p07-recipe-fields.sh`
- check-recipe.sh validates source types correctly
  - Check: `bash scripts/verify/m004-p07-recipe-sources.sh`
- check-recipe.sh validates priorities correctly
  - Check: `bash scripts/verify/m004-p07-recipe-priorities.sh`
- check-recipe.sh emits correct structured output
  - Check: `bash scripts/verify/m004-p07-recipe-output.sh`
- run-doctor.sh includes recipe conformance
  - Check: `bash scripts/verify/m004-p07-doctor-recipe.sh`
- extension.yml registers check-recipe.sh
  - Check: `bash scripts/verify/m004-p07-extension-recipe.sh`
- Pre-existing event check works
  - Check: `bash scripts/verify/m004-p07-events-existing.sh`
- Pre-existing constitution check works
  - Check: `bash scripts/verify/m004-p07-constitution-existing.sh`

### Artifacts

- scripts/verify/m004-p07-recipe-exists.sh (min 5 lines)
- scripts/verify/m004-p07-recipe-fields.sh (min 5 lines)
- scripts/verify/m004-p07-recipe-sources.sh (min 10 lines)
- scripts/verify/m004-p07-recipe-priorities.sh (min 10 lines)
- scripts/verify/m004-p07-recipe-output.sh (min 5 lines)
- scripts/verify/m004-p07-doctor-recipe.sh (min 5 lines)
- scripts/verify/m004-p07-extension-recipe.sh (min 5 lines)
- scripts/verify/m004-p07-events-existing.sh (min 5 lines)
- scripts/verify/m004-p07-constitution-existing.sh (min 5 lines)

## Verification

Run from repo root:
1. `bash scripts/verify/m004-p07-recipe-exists.sh` -- PASS
2. `bash scripts/verify/m004-p07-recipe-fields.sh` -- PASS
3. `bash scripts/verify/m004-p07-recipe-sources.sh` -- PASS
4. `bash scripts/verify/m004-p07-recipe-priorities.sh` -- PASS
5. `bash scripts/verify/m004-p07-recipe-output.sh` -- PASS
6. `bash scripts/verify/m004-p07-doctor-recipe.sh` -- PASS
7. `bash scripts/verify/m004-p07-extension-recipe.sh` -- PASS
8. `bash scripts/verify/m004-p07-events-existing.sh` -- PASS
9. `bash scripts/verify/m004-p07-constitution-existing.sh` -- PASS

## Inputs

### From Previous Tasks

- T01: `scripts/diagnostics/check-recipe.sh` must exist and emit `DOCTOR:RECIPE` output.
- T02: `scripts/diagnostics/run-doctor.sh` must include the recipe check. `extension.yml` must register check-recipe.sh.

**API surface from T01:** check-recipe.sh accepts `--root <dir>` and optionally `--recipe <file>`. Emits `DOCTOR:RECIPE status=<ok|warn> sections=N invalid=N`. Exits 0 if ok, 1 if warn.

**API surface from T02:** run-doctor.sh has a `run_check "Recipe Conformance"` line. extension.yml has a `check-recipe.sh` entry.

### From Disk

- scripts/diagnostics/check-recipe.sh -- T01 output. The script to verify.
- scripts/diagnostics/run-doctor.sh -- T02 output. The file to verify contains recipe check.
- extension.yml -- T02 output. The file to verify contains check-recipe.sh.
- scripts/diagnostics/check-events.sh -- Pre-existing. The script to verify works.
- scripts/diagnostics/check-constitution.sh -- Pre-existing. The script to verify works.
- templates/context-recipe.yaml -- The default recipe used for validation tests.

## Constraints

- Verification scripts are read-only -- they validate state but do not modify any files.
- Each script must be self-contained (single-file invocation per AD-19).
- Scripts that test invalid input must use temp files and clean them up.
- All scripts must exit 0 on success and 1 on failure.

## Expected Output

- 9 new verification helper scripts under scripts/verify/m004-p07-*.sh
- All scripts pass when run against the current repo state (after T01 and T02)
