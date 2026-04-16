---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M016"
goal: "Create a verify-suite wrapper script that auto-discovers, executes, and tallies gate scripts for a phase, replacing chained && pipelines and inline awk"
demo_sentence: "A developer runs bash scripts/verify/run-suite.sh m016 P01 and sees per-script PASS/FAIL status plus aggregate counts — no chained && or inline awk needed."
risk: "medium"
depends_on: []
---

## Must-Haves

### Truths

- `run-suite.sh` discovers and runs all `scripts/verify/m015-p02-*.sh` gate scripts when invoked with `m015 P02`
  - Check: `bash scripts/verify/m016-p02-discovers-scripts.sh`
- `run-suite.sh` prints per-script PASS/FAIL status lines and a summary line matching `PASS: N / FAIL: M`
  - Check: `bash scripts/verify/m016-p02-output-format.sh`
- `run-suite.sh` exits 0 when all scripts pass and non-zero when any script fails
  - Check: `bash scripts/verify/m016-p02-exit-codes.sh`
- `run-suite.sh` is Bash 3.2 compatible (passes `bash -n`)
  - Check: `bash scripts/verify/m016-p02-bash32-compat.sh`

### Artifacts

- `scripts/verify/run-suite.sh` (min 40 lines, contains "PASS:")
- `scripts/verify/m016-p02-discovers-scripts.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m016-p02-output-format.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m016-p02-exit-codes.sh` (min 10 lines, contains "PASS")
- `scripts/verify/m016-p02-bash32-compat.sh` (min 5 lines, contains "PASS")

### Key Links

- `scripts/verify/run-suite.sh` → `scripts/verify/` (discovers gate scripts by naming convention)

## Tasks

### T01: Create run-suite.sh wrapper script

See `tasks/T01-PLAN.md`.

### T02: Create verify scripts for run-suite.sh behavior

See `tasks/T02-PLAN.md`.

## Task Dependencies

```
T01 → T02
```

T02 tests the script from T01.

## Files Likely Touched

- `scripts/verify/run-suite.sh` (create)
- `scripts/verify/m016-p02-discovers-scripts.sh` (create)
- `scripts/verify/m016-p02-output-format.sh` (create)
- `scripts/verify/m016-p02-exit-codes.sh` (create)
- `scripts/verify/m016-p02-bash32-compat.sh` (create)
