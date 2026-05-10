---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P01"
milestone: "M005"
name: "Add unchanged outcome to record-result.sh"
depends_on: []
---

## Description

Update `scripts/lifecycle/record-result.sh` to accept `unchanged` as a
valid value for the `--outcome=` flag. This is a minimal change: add
`unchanged` to the outcome validation case statement and update the usage
comment.

The `unchanged` outcome is used when a dispatched agent produces output
whose content hash matches the prior dispatch result. The caller (the
orchestrator's dispatch loop) determines whether the outcome is unchanged
by comparing hashes -- `record-result.sh` itself does not compute hashes.
It simply needs to accept the value without rejecting it as invalid.

This task has no dependency on T01 (hash.sh) or any other P01 task. The
hash library is not needed here because the script is a recording tool,
not a computation tool. The caller is responsible for determining the
outcome value before invoking this script.

## Steps

### Step 1 -- Add unchanged to the outcome validation case statement

In `scripts/lifecycle/record-result.sh`, locate the outcome validation
block (currently lines 105-111):

```bash
# --- Validate outcome value ---
case "$OUTCOME" in
  success|failure|retry|blocked|timeout|stuck) ;;
  *)
    echo "record-result.sh: invalid outcome: $OUTCOME (expected: success|failure|retry|blocked|timeout|stuck)" >&2
    exit 1
    ;;
esac
```

Update it to include `unchanged`:

```bash
# --- Validate outcome value ---
case "$OUTCOME" in
  success|failure|retry|blocked|timeout|stuck|unchanged) ;;
  *)
    echo "record-result.sh: invalid outcome: $OUTCOME (expected: success|failure|retry|blocked|timeout|stuck|unchanged)" >&2
    exit 1
    ;;
esac
```

### Step 2 -- Update the usage comment

Update the script header comment (currently lines 8-9) to include
`unchanged` in the outcome list:

Change:
```
# Usage: record-result.sh <execution-log> --milestone=M### --phase=P## --task=T## --outcome=<success|failure|retry> [options]
```

To:
```
# Usage: record-result.sh <execution-log> --milestone=M### --phase=P## --task=T## --outcome=<success|failure|retry|unchanged> [options]
```

Also update the `--outcome=<value>` description (currently line 14):

Change:
```
#   --outcome=<value>            One of: success, failure, retry, blocked, timeout, stuck
```

To:
```
#   --outcome=<value>            One of: success, failure, retry, blocked, timeout, stuck, unchanged
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "record-result.sh accepts unchanged as a valid outcome value."
- **Artifacts**: modified `scripts/lifecycle/record-result.sh`.

## Verification

Run the verification script:

```bash
bash scripts/verify/p01-outcome-unchanged.sh
```

Expected output: `PASS: record-result.sh accepts unchanged outcome`

Additionally, test that the script actually accepts the value at runtime
by invoking it with a temp log file:

```bash
bash scripts/lifecycle/record-result.sh /tmp/p01-test-log.jsonl \
  --milestone=M005 --phase=P01 --task=T05 --outcome=unchanged
```

Expected output: `RECORD:APPENDED /tmp/p01-test-log.jsonl`

Then verify the JSONL entry contains `"outcome":"unchanged"`:

```bash
grep -q '"outcome":"unchanged"' /tmp/p01-test-log.jsonl
echo "Runtime test PASS"
rm -f /tmp/p01-test-log.jsonl
```

### Files Touched By This Task

- `scripts/lifecycle/record-result.sh` (modify -- add unchanged to outcome
  case statement, update usage comments)

## Inputs

### From Previous Tasks

None -- T05 is independent of all other P01 tasks.

### From Disk (Pre-existing)

- `scripts/lifecycle/record-result.sh` -- the file to modify. Current structure:
  - Lines 1-33: header comments and usage documentation
  - Lines 35-43: initial argument parsing (extract execution log path)
  - Lines 44-90: flag parsing (while/case loop for --milestone=, --phase=,
    --task=, --outcome=, and optional flags)
  - Lines 92-101: required field validation
  - Lines 105-111: **outcome validation case statement** (the target of this
    change). Currently accepts: success, failure, retry, blocked, timeout, stuck.
  - Lines 113-115: generate timestamp and unitId
  - Lines 117-173: build JSON entry
  - Lines 175-184: create log directory, append to log, echo RECORD:APPENDED

  The outcome value flows through directly into the JSON entry at line 127:
  `json="${json},\"outcome\":\"${OUTCOME}\""`. No further mapping or
  transformation is applied -- the case statement is the only gate.

## Expected Output

After completing this task:

1. `scripts/lifecycle/record-result.sh` accepts `--outcome=unchanged`
   without error.
2. The JSONL output contains `"outcome":"unchanged"` when invoked with
   that flag.
3. All other outcome values (success, failure, retry, blocked, timeout,
   stuck) continue to work as before.
4. `bash scripts/verify/p01-outcome-unchanged.sh` prints PASS.
5. `git status` shows 1 modified file. Nothing else touched.
