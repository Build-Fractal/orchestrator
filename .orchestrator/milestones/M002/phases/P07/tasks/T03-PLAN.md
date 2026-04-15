---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P07"
milestone: "M002"
name: "Validate run-doctor.sh Orchestration, doctor-history.jsonl, and Registrations"
depends_on: [T02]
---

## Prerequisites

T02 must be complete -- all 9 verification scripts pass against the existing diagnostics implementation.

## Description

Verify that `run-doctor.sh` correctly orchestrates all check scripts, produces a scored health report, and appends results to `doctor-history.jsonl` with the required JSON schema. Verify `commands/doctor.md` describes all check categories and `extension.yml` registrations are complete. Document the `doctor-history.jsonl` format in `references/file-formats.md`.

## Steps

### Step 1: Verify run-doctor.sh orchestration behavior

Read `scripts/diagnostics/run-doctor.sh` and confirm:

1. It defines a `run_check()` function that accepts check name, script path, args, and advisory flag.
2. It invokes `run_check` for at least these four core checks: check-orphaned.sh, check-stale.sh, check-scope.sh, check-cost-spikes.sh.
3. It tallies `checks_passed` and `checks_total` (non-advisory checks count toward pass/fail).
4. It produces a health report with `HEALTHY` or `NEEDS_ATTENTION` status.
5. It appends a JSON line to `doctor-history.jsonl`.

### Step 2: Verify doctor-history.jsonl JSON schema

Confirm that the JSON line appended by `run-doctor.sh` contains these required fields:
- `timestamp` -- ISO 8601 UTC format (YYYY-MM-DDTHH:MM:SSZ)
- `checks_passed` -- integer
- `checks_total` -- integer
- `advisory_warnings` -- integer
- `status` -- string: "healthy" or "needs_attention"

The current implementation (line ~132 of run-doctor.sh) writes:
```json
{"timestamp":"...","checks_passed":N,"checks_total":N,"advisory_warnings":N,"status":"..."}
```

This matches the requirement. No changes expected.

### Step 3: Verify doctor.md completeness

Read `commands/doctor.md` and confirm it describes:
1. All four core check categories (orphaned artifacts, stale knowledge, scope issues, cost spikes)
2. Usage syntax referencing `run-doctor.sh`
3. Output destination (screen + doctor-history.jsonl)
4. When to run guidance

If any section is missing or incomplete, expand the file.

### Step 4: Verify extension.yml registrations

Confirm `extension.yml` registers:
1. `speckit.orchestrator.doctor` command pointing to `commands/doctor.md`
2. All diagnostics scripts under `provides.scripts`:
   - `scripts/diagnostics/run-doctor.sh`
   - `scripts/diagnostics/check-orphaned.sh`
   - `scripts/diagnostics/check-stale.sh`
   - `scripts/diagnostics/check-scope.sh`
   - `scripts/diagnostics/check-cost-spikes.sh`

### Step 5: Document doctor-history.jsonl in references/file-formats.md

Add a section to `references/file-formats.md` documenting the `doctor-history.jsonl` format:

```markdown
### doctor-history.jsonl

Append-only log of diagnostic results for trend tracking. Written by `scripts/diagnostics/run-doctor.sh` after each doctor run.

**Location**: `.specify/orchestrator/doctor-history.jsonl`

**Format**: One JSON object per line (JSONL).

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | string | ISO 8601 UTC timestamp of the run (e.g., `2026-04-13T16:00:00Z`) |
| `checks_passed` | integer | Number of non-advisory checks that passed |
| `checks_total` | integer | Total number of non-advisory checks run |
| `advisory_warnings` | integer | Number of advisory-only checks that warned |
| `status` | string | `healthy` (all passed) or `needs_attention` (any failed) |

**Example**:

```json
{"timestamp":"2026-04-13T16:00:00Z","checks_passed":12,"checks_total":12,"advisory_warnings":0,"status":"healthy"}
{"timestamp":"2026-04-14T10:30:00Z","checks_passed":10,"checks_total":12,"advisory_warnings":1,"status":"needs_attention"}
```
```

### Step 6: Re-run registration and doctor-md verification scripts

```
bash scripts/verify/m002-p07-doctor-md-sections.sh
bash scripts/verify/m002-p07-extension-registration.sh
bash scripts/verify/m002-p07-history-append.sh
```

All three must print `PASS:` and exit 0.

## Must-Haves

This task validates these phase must-haves:
- run-doctor.sh appends a JSON line to doctor-history.jsonl with required fields
- doctor.md describes all four core check categories
- extension.yml registers doctor command and all diagnostics scripts

## Verification

```
bash scripts/verify/m002-p07-history-append.sh
bash scripts/verify/m002-p07-doctor-md-sections.sh
bash scripts/verify/m002-p07-extension-registration.sh
```

Expected output for each: `PASS: <description>`

## Inputs

### From Previous Tasks
- `scripts/verify/m002-p07-history-append.sh` (from T01)
  - Key API: Standalone bash executable. Checks that `run-doctor.sh` references `doctor-history.jsonl`, includes `timestamp`/`checks_passed`/`checks_total`/`status` fields, and uses `>>` append. Prints `PASS:`/`FAIL:`, exits 0/1.
- `scripts/verify/m002-p07-doctor-md-sections.sh` (from T01)
  - Key API: Standalone bash executable. Checks that `commands/doctor.md` mentions orphan, stale, scope, cost, and references `run-doctor.sh`. Prints `PASS:`/`FAIL:`, exits 0/1.
- `scripts/verify/m002-p07-extension-registration.sh` (from T01)
  - Key API: Standalone bash executable. Checks that `extension.yml` registers doctor command and all core diagnostics scripts. Prints `PASS:`/`FAIL:`, exits 0/1.
- All T02 validation results (9/9 passing) confirm diagnostics scripts are correct.

### From Disk (Pre-existing)
- `scripts/diagnostics/run-doctor.sh` -- runner script. Defines `run_check()` with 4 parameters (name, script, args, advisory). Runs 12 checks. Tallies `checks_passed`/`checks_total`/`advisory_warnings`. Appends JSON to `$PROJECT_ROOT/.specify/orchestrator/doctor-history.jsonl`.
- `commands/doctor.md` -- agent instruction document. Currently 32 lines. Lists 4 check categories, usage syntax, output, when-to-run guidance.
- `extension.yml` -- extension manifest. Currently registers `speckit.orchestrator.doctor` command and all diagnostics scripts.
- `references/file-formats.md` -- format reference document. Currently does NOT document `doctor-history.jsonl`.

## Constraints

- Do not modify run-doctor.sh unless a verification check fails
- The doctor-history.jsonl documentation must use the same table format as other sections in file-formats.md
- Additions to file-formats.md must not break existing content
- All changes maintain Bash 3.2 compatibility

## Expected Output

- `references/file-formats.md` updated with `doctor-history.jsonl` section
- All 3 verification scripts pass
- No changes to `run-doctor.sh`, `commands/doctor.md`, or `extension.yml` unless a verification check fails
