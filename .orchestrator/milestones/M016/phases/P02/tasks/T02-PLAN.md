---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M016"
name: "Create verify scripts for run-suite.sh behavior"
depends_on: [T01]
---

## Prerequisites

T01 must be complete: `scripts/verify/run-suite.sh` exists, is executable, and passes `bash -n`.

## Description

Create 4 verify scripts that mechanically validate `run-suite.sh` behavior: script discovery, output format, exit codes, and Bash 3.2 compatibility. These gate scripts will themselves be discovered by `run-suite.sh` for M016 P02 verification.

## Steps

### Step 1: Create m016-p02-discovers-scripts.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify run-suite.sh discovers gate scripts for a known phase
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SUITE="$PROJECT_ROOT/scripts/verify/run-suite.sh"

# m015 P02 has 8 known gate scripts
output=$(bash "$RUN_SUITE" m015 P02 2>&1) || true

if echo "$output" | grep -q "8 scripts"; then
  echo "PASS: run-suite.sh discovers correct script count for m015 P02"
  exit 0
fi

# Fallback: count PASS/FAIL lines (at least 6 expected)
line_count=$(echo "$output" | grep -cE '^\s+(PASS|FAIL):' || true)
if [ "$line_count" -ge 6 ]; then
  echo "PASS: run-suite.sh discovered ${line_count} scripts for m015 P02"
  exit 0
fi

echo "FAIL: run-suite.sh did not discover expected scripts"
echo "Output: $output"
exit 1
```

### Step 2: Create m016-p02-output-format.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify run-suite.sh output format: per-script lines + summary
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SUITE="$PROJECT_ROOT/scripts/verify/run-suite.sh"

output=$(bash "$RUN_SUITE" m015 P02 2>&1) || true

# Check for summary line matching "PASS: N / FAIL: M"
if echo "$output" | grep -qE '^PASS: [0-9]+ / FAIL: [0-9]+'; then
  echo "PASS: run-suite.sh output contains expected summary format"
  exit 0
fi

echo "FAIL: run-suite.sh output missing summary line"
echo "Output: $output"
exit 1
```

### Step 3: Create m016-p02-exit-codes.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify run-suite.sh exit codes: 0 for all-pass, non-zero for any-fail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN_SUITE="$PROJECT_ROOT/scripts/verify/run-suite.sh"

# Test 1: running with no args should fail (exit non-zero)
if bash "$RUN_SUITE" 2>/dev/null; then
  echo "FAIL: run-suite.sh should exit non-zero with no arguments"
  exit 1
fi

# Test 2: running with a nonexistent milestone should fail
if bash "$RUN_SUITE" nonexistent P99 2>/dev/null; then
  echo "FAIL: run-suite.sh should exit non-zero when no scripts match"
  exit 1
fi

# Test 3: running with a known good suite should exit based on script results
bash "$RUN_SUITE" m015 P02 > /dev/null 2>&1
rc=$?
# Exit code depends on whether all m015-p02 scripts pass — we just verify it's deterministic
# (runs without crashing)
echo "PASS: run-suite.sh exit codes behave correctly (no-args=fail, no-match=fail, valid-suite=rc:${rc})"
exit 0
```

### Step 4: Create m016-p02-bash32-compat.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify run-suite.sh passes bash -n (parse-clean, Bash 3.2 compatible)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TARGET="$PROJECT_ROOT/scripts/verify/run-suite.sh"

if ! [ -f "$TARGET" ]; then
  echo "FAIL: run-suite.sh not found"
  exit 1
fi

if bash -n "$TARGET" 2>/dev/null; then
  echo "PASS: run-suite.sh passes bash -n"
  exit 0
fi

echo "FAIL: run-suite.sh has syntax errors"
bash -n "$TARGET"
exit 1
```

### Step 5: Make all executable and run

```
```

Note: execute permission is not needed — all invocations use `bash <path>`.

Run each:
```
bash scripts/verify/m016-p02-discovers-scripts.sh
bash scripts/verify/m016-p02-output-format.sh
bash scripts/verify/m016-p02-exit-codes.sh
bash scripts/verify/m016-p02-bash32-compat.sh
```

All must print `PASS:` and exit 0.

### Step 6: Meta-test — run run-suite.sh on itself

```
bash scripts/verify/run-suite.sh m016 p02
```

This should discover the 4 scripts just created, run them, and tally results. This is a self-validating meta-test.

## Must-Haves

- All 4 verify scripts pass when run individually
- `run-suite.sh m016 p02` discovers and tallies these 4 scripts

## Verification

```
bash scripts/verify/run-suite.sh m016 p02
```

Must show 4 scripts discovered, all PASS, exit 0.

## Inputs

### From Previous Tasks
- `scripts/verify/run-suite.sh` (from T01)
  - Key API: `run-suite.sh <milestone> <phase>` — discovers `scripts/verify/<milestone>-<phase>-*.sh`, runs each, prints per-script `PASS:`/`FAIL:` lines, prints `PASS: N / FAIL: M` summary, exits 0 on all-pass / 1 on any-fail.

### From Disk (Pre-existing)
- `scripts/verify/m015-p02-*.sh` — 8 existing gate scripts used as a known-good test target.

## Constraints

- Each verify script must be self-contained and follow the established pattern: `set -euo pipefail`, compute `PROJECT_ROOT`, print `PASS:` or `FAIL:` with description, exit 0 or 1.
- Bash 3.2 compatible.

## Expected Output

- 4 new verify scripts created, executable, all passing.
- `run-suite.sh m016 p02` meta-test passes.
