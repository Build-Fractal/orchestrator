---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P04"
milestone: "M005"
name: "Wire check-instructions.sh into run-doctor.sh"
depends_on: ["T01"]
---

## Description

Update `scripts/diagnostics/run-doctor.sh` to include the instruction
conformance check in its diagnostic sequence. This follows the existing
`run_check` pattern already used for orphaned artifacts, stale knowledge,
scope issues, and cost spikes.

The change is a single `run_check` call inserted after the existing checks
and before the Summary section. The check name is "Instruction Conformance"
and it invokes `check-instructions.sh` from the same `$SCRIPT_DIR` directory.

## Steps

### Step 1 — Add the run_check call to run-doctor.sh

Open `scripts/diagnostics/run-doctor.sh` and add the following line after
the existing `run_check` calls (after the `run_check "Cost Spikes"` line
and before the `# Summary` comment):

```bash
run_check "Instruction Conformance" "$SCRIPT_DIR/check-instructions.sh" --root "$PROJECT_ROOT"
```

This follows the same pattern as the other four checks:
- `run_check "Orphaned Artifacts" "$SCRIPT_DIR/check-orphaned.sh"`
- `run_check "Stale Knowledge" "$SCRIPT_DIR/check-stale.sh"`
- `run_check "Scope Issues" "$SCRIPT_DIR/check-scope.sh"`
- `run_check "Cost Spikes" "$SCRIPT_DIR/check-cost-spikes.sh"`

The `--root "$PROJECT_ROOT"` argument tells `check-instructions.sh` where
to find the `commands/` directory. This is already available as
`$PROJECT_ROOT` which is exported by `run-doctor.sh` at the top of the
script.

### Step 2 — Verify the integration

Run run-doctor.sh and confirm the new check appears in the output:

```bash
bash scripts/diagnostics/run-doctor.sh --root .
```

Expected output should include a section:

```
--- Instruction Conformance ---
DOCTOR:INSTRUCTIONS status=<ok|warn> files=N missing=N
```

The check should appear between "Cost Spikes" and "=== Summary ===".

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "`scripts/diagnostics/run-doctor.sh` includes a call to
  `check-instructions.sh` in its diagnostic sequence."
- **Artifacts**: `scripts/diagnostics/run-doctor.sh` (modify, contains
  "check-instructions.sh").

## Verification

Run the verification script:

```bash
bash scripts/verify/p04-doctor-integration.sh
```

Should print PASS. This script checks that `run-doctor.sh` contains a
reference to `check-instructions.sh`.

### Files Touched By This Task

- `scripts/diagnostics/run-doctor.sh` (modify)

## Inputs

### From Previous Tasks

- T01: `scripts/diagnostics/check-instructions.sh` must exist and be
  executable. This is the script that `run-doctor.sh` will invoke via
  `run_check`.

### From Disk (Pre-existing)

- `scripts/diagnostics/run-doctor.sh` — the existing doctor script that
  aggregates all diagnostic checks. Current structure:
  - Lines 1-9: shebang, header, set options
  - Lines 10-20: argument parsing (--root, --format)
  - Lines 22-26: header output
  - Lines 28-56: `run_check()` function definition
  - Lines 58-61: four `run_check` calls (orphaned, stale, scope, cost)
  - Lines 63-78: Summary section + doctor-history.jsonl append

  The new `run_check` call goes at line 62 (after the four existing calls,
  before the Summary comment).

## Expected Output

After completing this task:

1. `scripts/diagnostics/run-doctor.sh` contains a `run_check` call for
   "Instruction Conformance" that invokes `check-instructions.sh`.
2. `bash scripts/verify/p04-doctor-integration.sh` prints PASS.
3. Running `bash scripts/diagnostics/run-doctor.sh --root .` includes
   "Instruction Conformance" in its output between the existing checks
   and the Summary.
4. `git status` shows 1 modified file (`run-doctor.sh`). Nothing else
   touched.
