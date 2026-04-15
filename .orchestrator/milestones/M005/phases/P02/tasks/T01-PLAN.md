---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M005"
name: "Add --cost-source flag to record-telemetry.sh + verification scripts"
depends_on: []
---

## Description

Update `scripts/telemetry/record-telemetry.sh` to accept a `--cost-source`
flag with closed-enum validation and write it to the JSONL entry. Also
create all six verification scripts for phase P02.

The existing script accepts `--cost=<amount>` and writes it as
`cost_estimated`. This task adds a companion `--cost-source=<value>` flag
that records the provenance of the cost value. Per AD-2, the cost_source
enum is closed with three values:

- `estimated` -- cost computed from chars/4 heuristic
- `reported` -- cost returned by the provider API response
- `unknown` -- no cost data available

When `--cost-source` is provided, the script writes
`"cost_source":"<value>"` as a string field in the JSON entry. When
`--cost-source` is not provided, no `cost_source` field is written
(backward compatible).

Invalid cost_source values (anything not in the enum) cause the script
to print an error to stderr and exit 1, matching the existing pattern
for `--unit-id` validation.

## Steps

### Step 1 -- Add --cost-source flag parsing to record-telemetry.sh

In `scripts/telemetry/record-telemetry.sh`, add:

1. A new variable `COST_SOURCE=""` alongside the other option variables
   (after line 43, near `COST_ESTIMATED=""`).

2. A new case in the argument parsing while loop:
   ```
   --cost-source=*) COST_SOURCE="${1#--cost-source=}" ;;
   ```

3. After the required field validation block (after the `UNIT_ID` check
   around line 63), add enum validation:
   ```bash
   # Validate cost_source enum (AD-2: closed set)
   if [ -n "$COST_SOURCE" ]; then
     case "$COST_SOURCE" in
       estimated|reported|unknown) ;;
       *) echo "record-telemetry.sh: invalid --cost-source value: $COST_SOURCE (must be estimated|reported|unknown)" >&2; exit 1 ;;
     esac
   fi
   ```

4. In the JSON construction block (after line 76, near the other optional
   field conditionals), add:
   ```bash
   [ -n "$COST_SOURCE" ] && json="${json},\"cost_source\":\"${COST_SOURCE}\""
   ```
   Note: `cost_source` is a string field (quoted), unlike `cost_estimated`
   which is numeric (unquoted).

5. Update the usage comment at the top of the file to include the new flag:
   ```
   #   --cost-source=<src>          Cost provenance (estimated|reported|unknown)
   ```

### Step 2 -- Create verification scripts

Create six verification scripts under `scripts/verify/`. Each is a
standalone single-script-file check (AD-19 compliant).

**`scripts/verify/p02-cost-source-flag.sh`**

```bash
#!/usr/bin/env bash
# Verifies record-telemetry.sh accepts --cost-source flag in its argument parser.
set -eu
f="scripts/telemetry/record-telemetry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-cost-source' "$f" || { echo "FAIL: $f missing --cost-source flag"; exit 1; }
grep -q 'COST_SOURCE' "$f" || { echo "FAIL: $f missing COST_SOURCE variable"; exit 1; }
echo "PASS: record-telemetry.sh accepts --cost-source flag"
```

**`scripts/verify/p02-cost-source-written.sh`**

```bash
#!/usr/bin/env bash
# Verifies record-telemetry.sh writes cost_source field into JSONL entry.
set -eu
f="scripts/telemetry/record-telemetry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'cost_source' "$f" || { echo "FAIL: $f missing cost_source in JSON output"; exit 1; }
grep -q '"cost_source"' "$f" || { echo "FAIL: $f does not write cost_source as JSON field"; exit 1; }
echo "PASS: record-telemetry.sh writes cost_source field"
```

**`scripts/verify/p02-cost-source-validation.sh`**

```bash
#!/usr/bin/env bash
# Verifies record-telemetry.sh validates cost_source against closed enum.
set -eu
f="scripts/telemetry/record-telemetry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'estimated|reported|unknown' "$f" || { echo "FAIL: $f missing cost_source enum validation"; exit 1; }
echo "PASS: record-telemetry.sh validates cost_source enum"
```

**`scripts/verify/p02-aggregate-groups.sh`**

```bash
#!/usr/bin/env bash
# Verifies aggregate-metrics.sh groups entries by cost_source.
set -eu
f="scripts/telemetry/aggregate-metrics.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'cost_source' "$f" || { echo "FAIL: $f missing cost_source grouping"; exit 1; }
grep -q 'by_cost_source\|By Cost Source\|cost_source' "$f" || { echo "FAIL: $f missing cost_source output section"; exit 1; }
echo "PASS: aggregate-metrics.sh groups by cost_source"
```

**`scripts/verify/p02-null-vs-zero.sh`**

```bash
#!/usr/bin/env bash
# Verifies aggregate-metrics.sh distinguishes null cost from zero cost.
set -eu
f="scripts/telemetry/aggregate-metrics.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'unknown' "$f" || { echo "FAIL: $f does not handle unknown cost source"; exit 1; }
grep -q 'cost_source' "$f" || { echo "FAIL: $f missing cost_source handling"; exit 1; }
echo "PASS: aggregate-metrics.sh distinguishes null vs zero cost"
```

**`scripts/verify/p02-schema-docs.sh`**

```bash
#!/usr/bin/env bash
# Verifies references/file-formats.md documents cost_source enum.
set -eu
f="references/file-formats.md"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'cost_source' "$f" || { echo "FAIL: $f missing cost_source documentation"; exit 1; }
grep -q 'estimated' "$f" || { echo "FAIL: $f missing estimated enum value"; exit 1; }
grep -q 'reported' "$f" || { echo "FAIL: $f missing reported enum value"; exit 1; }
grep -q 'unknown' "$f" || { echo "FAIL: $f missing unknown enum value"; exit 1; }
echo "PASS: file-formats.md documents cost_source enum"
```

Make all executable:

```bash
chmod +x scripts/verify/p02-*.sh
```

### Step 3 -- Smoke test the new flag

Test valid values:

```bash
tmplog="$(mktemp)"
bash scripts/telemetry/record-telemetry.sh "$tmplog" --unit-id=M005/P02/T01 --cost=0.12 --cost-source=estimated
cat "$tmplog"
# Expected: JSONL line containing "cost_source":"estimated"
rm -f "$tmplog"
```

Test invalid value:

```bash
tmplog="$(mktemp)"
bash scripts/telemetry/record-telemetry.sh "$tmplog" --unit-id=M005/P02/T01 --cost-source=bogus 2>/dev/null && echo "FAIL: should have rejected" || echo "OK: rejected invalid value"
rm -f "$tmplog"
```

Test backward compatibility (no --cost-source):

```bash
tmplog="$(mktemp)"
bash scripts/telemetry/record-telemetry.sh "$tmplog" --unit-id=M005/P02/T01 --cost=0.50
cat "$tmplog"
# Expected: JSONL line without cost_source field (backward compatible)
rm -f "$tmplog"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "record-telemetry.sh accepts a --cost-source flag",
  "record-telemetry.sh writes cost_source field into the JSONL entry",
  "record-telemetry.sh rejects invalid --cost-source values".
- **Artifacts**: `scripts/telemetry/record-telemetry.sh` (modify),
  all six `scripts/verify/p02-*.sh` scripts.

## Verification

Run each verification script for the truths addressed by this task:

```bash
bash scripts/verify/p02-cost-source-flag.sh
bash scripts/verify/p02-cost-source-written.sh
bash scripts/verify/p02-cost-source-validation.sh
```

All three should print PASS. The remaining three verification scripts
(p02-aggregate-groups.sh, p02-null-vs-zero.sh, p02-schema-docs.sh) will
FAIL at this point because T02 and T03 have not yet modified their target
files. This is expected.

### Files Touched By This Task

- `scripts/telemetry/record-telemetry.sh` (modify)
- `scripts/verify/p02-cost-source-flag.sh` (create)
- `scripts/verify/p02-cost-source-written.sh` (create)
- `scripts/verify/p02-cost-source-validation.sh` (create)
- `scripts/verify/p02-aggregate-groups.sh` (create)
- `scripts/verify/p02-null-vs-zero.sh` (create)
- `scripts/verify/p02-schema-docs.sh` (create)

## Inputs

### From Previous Tasks

None -- T01 is the phase entry point.

### From Disk (Pre-existing)

- `scripts/telemetry/record-telemetry.sh` -- the existing telemetry
  recording script. Current structure (82 lines):
  - Lines 1-25: header comment with usage documentation
  - Lines 26-31: argument count check and first positional arg (log file)
  - Lines 36-43: variable declarations for optional fields
  - Lines 45-58: while loop parsing `--key=value` flags
  - Lines 60-64: required field validation (unit-id)
  - Lines 66-77: JSON construction with conditional field inclusion
  - Lines 79-81: mkdir, append to log, print structured output

  Key pattern for adding a new field:
  1. Add variable declaration: `COST_SOURCE=""`
  2. Add case branch: `--cost-source=*) COST_SOURCE="${1#--cost-source=}" ;;`
  3. Add JSON field: `[ -n "$COST_SOURCE" ] && json="${json},\"cost_source\":\"${COST_SOURCE}\""`
  (Note: string fields are quoted in JSON, numeric fields are not.)

- `scripts/lib/errors.sh` -- reference for the double-sourcing guard
  pattern and enum validation style. The `orch_is_error_kind` function
  validates against a closed set by iterating a newline-separated string.
  For cost_source, a simpler case-statement validation suffices since there
  are only 3 values.

## Expected Output

After completing this task:

1. `scripts/telemetry/record-telemetry.sh` accepts `--cost-source=estimated`,
   `--cost-source=reported`, and `--cost-source=unknown` without error.
2. A JSONL entry written with `--cost-source=estimated` contains
   `"cost_source":"estimated"`.
3. Calling with `--cost-source=bogus` exits 1 with an error message.
4. Calling without `--cost-source` produces a JSONL entry with no
   `cost_source` field (backward compatible).
5. Six `scripts/verify/p02-*.sh` files exist and are chmod +x.
6. `bash scripts/verify/p02-cost-source-flag.sh` prints PASS.
7. `bash scripts/verify/p02-cost-source-written.sh` prints PASS.
8. `bash scripts/verify/p02-cost-source-validation.sh` prints PASS.
9. `git status` shows 1 modified file + 6 new files. Nothing else touched.
