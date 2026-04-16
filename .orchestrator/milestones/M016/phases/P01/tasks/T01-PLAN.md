---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M016"
name: "Make --completed_at optional with now sentinel in write-summary.sh"
depends_on: []
---

## Prerequisites

No upstream tasks. The script `scripts/knowledge/write-summary.sh` exists and is Bash 3.2 compatible.

## Description

Modify `scripts/knowledge/write-summary.sh` so that the `--completed_at` field is optional for all summary types (task, phase, milestone). When omitted, it defaults to the current UTC timestamp computed internally via `date -u +%Y-%m-%dT%H:%M:%SZ`. When passed as `--completed_at=now`, the same internal computation occurs. When passed with an explicit ISO-8601 value, the value is used as-is (backwards compatible).

This eliminates the #1 source of Claude Code safety prompts during autonomous execution: subagents calling `write-summary.sh` with `--completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)` which triggers the harness's command-substitution detector.

## Steps

### Step 1: Modify the required fields lists to remove completed_at

In `scripts/knowledge/write-summary.sh`, the required fields are defined on lines 109-111. Remove `completed_at` from all three lists:

**Before** (line 109):
```
TASK_FIELDS="id parent milestone provides requires affects key_files key_decisions patterns_established drill_down_paths duration verification_result completed_at body"
```

**After** (line 109):
```
TASK_FIELDS="id parent milestone provides requires affects key_files key_decisions patterns_established drill_down_paths duration verification_result body"
```

Apply the same removal to `PHASE_FIELDS` (line 110) and `MILESTONE_FIELDS` (line 111).

### Step 2: Add completed_at defaulting logic after field validation

After the required-fields validation loop (after line 127), add logic to handle `completed_at`:

```bash
# Handle completed_at: optional, defaults to now
f_completed_raw=$(lookup_field "completed_at") || true
if [ -z "$f_completed_raw" ] || [ "$f_completed_raw" = "now" ]; then
  f_completed=$(date -u +%Y-%m-%dT%H:%M:%SZ)
else
  f_completed="$f_completed_raw"
fi
```

### Step 3: Remove the standalone completed_at extraction

On line 142, remove the existing line:
```
f_completed=$(lookup_field "completed_at") || true
```

This is now handled by the block added in Step 2.

### Step 4: Update the usage header and example

Update the script's header comment (lines 7-8) to document the new behavior:

**Before** (lines 7-8):
```
# Required fields for task: id, parent, milestone, provides, requires, affects,
#   key_files, key_decisions, patterns_established, drill_down_paths,
#   duration, verification_result, completed_at, body
```

**After**:
```
# Required fields for task: id, parent, milestone, provides, requires, affects,
#   key_files, key_decisions, patterns_established, drill_down_paths,
#   duration, verification_result, body
# Optional fields: completed_at (defaults to current UTC; accepts "now" sentinel or ISO-8601)
```

Update the example in the `usage()` function (lines 29-35) to show omitted `--completed_at`:

**Before** (line 34):
```
    --completed_at=2026-03-19T14:30:00Z --body="Summary body text here"
```

**After**:
```
    --body="Summary body text here"
```

And add a note after the example:
```

  --completed_at is optional. Omit it to default to now, or pass --completed_at=now.
  Explicit ISO-8601 values (e.g., --completed_at=2026-03-19T14:30:00Z) are also accepted.
```

### Step 5: Create verify scripts

Create 3 verify scripts under `scripts/verify/`:

**`scripts/verify/m016-p01-completed-at-optional.sh`**:
```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify write-summary.sh works with --completed_at omitted
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRITE_SUMMARY="$PROJECT_ROOT/scripts/knowledge/write-summary.sh"
TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

bash "$WRITE_SUMMARY" task "$TMP_OUT" \
  --id=TTEST --parent=PTEST --milestone=MTEST \
  --provides="test" --requires="test" --affects="test" \
  --key_files="test.sh" --key_decisions="DTEST" \
  --patterns_established="test" --drill_down_paths="test" \
  --duration=1 --verification_result=pass \
  --body="Test summary without completed_at"

if grep -q 'completed_at:' "$TMP_OUT"; then
  ts=$(grep 'completed_at:' "$TMP_OUT" | head -1)
  if echo "$ts" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T'; then
    echo "PASS: completed_at auto-populated with ISO timestamp"
    exit 0
  fi
fi
echo "FAIL: completed_at not auto-populated"
exit 1
```

**`scripts/verify/m016-p01-completed-at-now-sentinel.sh`**:
```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify write-summary.sh accepts --completed_at=now
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRITE_SUMMARY="$PROJECT_ROOT/scripts/knowledge/write-summary.sh"
TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

bash "$WRITE_SUMMARY" task "$TMP_OUT" \
  --id=TTEST --parent=PTEST --milestone=MTEST \
  --provides="test" --requires="test" --affects="test" \
  --key_files="test.sh" --key_decisions="DTEST" \
  --patterns_established="test" --drill_down_paths="test" \
  --duration=1 --verification_result=pass \
  --completed_at=now \
  --body="Test summary with completed_at=now"

if grep -q 'completed_at:' "$TMP_OUT"; then
  ts=$(grep 'completed_at:' "$TMP_OUT" | head -1)
  if echo "$ts" | grep -qE '[0-9]{4}-[0-9]{2}-[0-9]{2}T'; then
    echo "PASS: completed_at=now resolved to ISO timestamp"
    exit 0
  fi
fi
echo "FAIL: completed_at=now not resolved"
exit 1
```

**`scripts/verify/m016-p01-completed-at-explicit.sh`**:
```bash
#!/usr/bin/env bash
set -euo pipefail
# Verify write-summary.sh still accepts explicit ISO timestamps
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WRITE_SUMMARY="$PROJECT_ROOT/scripts/knowledge/write-summary.sh"
TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

bash "$WRITE_SUMMARY" task "$TMP_OUT" \
  --id=TTEST --parent=PTEST --milestone=MTEST \
  --provides="test" --requires="test" --affects="test" \
  --key_files="test.sh" --key_decisions="DTEST" \
  --patterns_established="test" --drill_down_paths="test" \
  --duration=1 --verification_result=pass \
  --completed_at=2026-01-01T00:00:00Z \
  --body="Test summary with explicit timestamp"

if grep -q '2026-01-01T00:00:00Z' "$TMP_OUT"; then
  echo "PASS: explicit completed_at preserved verbatim"
  exit 0
fi
echo "FAIL: explicit completed_at not preserved"
exit 1
```

Note: execute permission is not needed — all invocations use `bash <path>`.

### Step 6: Run verify scripts

Run each verify script individually:
```
bash scripts/verify/m016-p01-completed-at-optional.sh
bash scripts/verify/m016-p01-completed-at-now-sentinel.sh
bash scripts/verify/m016-p01-completed-at-explicit.sh
```

All three must print `PASS:` and exit 0.

## Must-Haves

- `write-summary.sh` accepts a call with no `--completed_at` flag and defaults to the current UTC timestamp
- `write-summary.sh` accepts `--completed_at=now` and resolves it to the current UTC timestamp
- `write-summary.sh` still accepts `--completed_at=2026-01-01T00:00:00Z` (explicit ISO value) unchanged

## Verification

```
bash scripts/verify/m016-p01-completed-at-optional.sh
bash scripts/verify/m016-p01-completed-at-now-sentinel.sh
bash scripts/verify/m016-p01-completed-at-explicit.sh
```

Each must print `PASS:` and exit 0.

## Inputs

### From Disk (Pre-existing)
- `scripts/knowledge/write-summary.sh` — the script being modified. Current API requires `--completed_at` as a mandatory field (line 109). Uses parallel arrays for Bash 3.2 compat (no `declare -A`). `lookup_field()` returns empty string + exit 1 on miss.

## Constraints

- Bash 3.2 compatible. No `declare -A`, `mapfile`, `${var,,}`.
- Backwards compatible: `--completed_at=<ISO>` continues to work when supplied.
- The `date -u +%Y-%m-%dT%H:%M:%SZ` format must match what callers currently pass — no trailing nanoseconds or timezone offset.

## Expected Output

- `scripts/knowledge/write-summary.sh` modified: `--completed_at` removed from required fields, defaulting logic added, usage header updated.
- 3 new verify scripts created and passing.
- No other files modified.
