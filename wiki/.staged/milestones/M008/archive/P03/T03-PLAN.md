---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M008"
name: "Create scripts/knowledge/intensity-knowledge.sh -- intensity-aware knowledge gate"
depends_on: []
---

## Prerequisites

- `scripts/knowledge/write-summary.sh` (existing) — writes task/phase summary. Always runs at every intensity.
- `scripts/knowledge/append-decision.sh` (existing) — appends a decision register entry. Runs at Standard and Full.
- `scripts/knowledge/append-knowledge.sh` (existing) — appends a knowledge entry. Runs at Full only.
- `scripts/knowledge/rebuild-index.sh` (existing) — rebuilds the knowledge SQL index. Runs at Full only.
- `templates/intensity-metadata.md` (from P01) — intensity source.
- Bash 3.2+.

## Description

Create `scripts/knowledge/intensity-knowledge.sh` — a thin wrapper over the existing knowledge pipeline that dispatches the appropriate subset of knowledge scripts based on the active intensity:

| Intensity | Scripts invoked (in order) |
|-----------|----------------------------|
| Quick     | write-summary.sh |
| Standard  | write-summary.sh, append-decision.sh |
| Full      | write-summary.sh, append-decision.sh, append-knowledge.sh, rebuild-index.sh |

The wrapper forwards arguments through transparently — whatever the caller passes after `--` flows to each invoked script unchanged. Individual knowledge scripts remain the source of truth for their own behavior ([M007](../../../../milestones/M007/index.md) pipeline is untouched).

Supports `--dry-run` mode that prints which scripts WOULD run without executing them. This is what the integration test uses (T05) to avoid needing real summary/decision inputs.

## Steps

### Step 1 — Create scripts/knowledge/intensity-knowledge.sh

Write verbatim to `scripts/knowledge/intensity-knowledge.sh`:

```bash
#!/usr/bin/env bash
# scripts/knowledge/intensity-knowledge.sh -- Intensity-aware knowledge
# generation gate.
#
# Reads intensity from a metadata file and invokes the matching subset
# of the knowledge pipeline:
#
#   Quick    -> write-summary.sh
#   Standard -> write-summary.sh, append-decision.sh
#   Full     -> write-summary.sh, append-decision.sh,
#               append-knowledge.sh, rebuild-index.sh
#
# The underlying M007 knowledge scripts are NOT modified. This wrapper
# is the pipeline gate; they remain the source of truth for their own
# behavior.
#
# Usage:
#   intensity-knowledge.sh --intensity-metadata <path> [--dry-run]
#                          [-- <args forwarded to each sub-script>]
#
#   intensity-knowledge.sh --intensity <Quick|Standard|Full> [--dry-run]
#                          [-- <forwarded args>]
#
# In --dry-run mode, the script prints `WOULD_RUN: <script-path> <args>`
# lines for each step that would execute, then exits 0. No sub-scripts
# are invoked.
#
# Output (normal mode): the interleaved stdout of each sub-script.
# Errors from any sub-script cause this wrapper to stop and exit with
# the sub-script's exit code.
#
# Bash 3.2 compatible.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METADATA_FILE=""
INTENSITY=""
DRY_RUN=0
FORWARD_ARGS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --intensity-metadata)
      METADATA_FILE="${2:-}"; shift 2 ;;
    --intensity)
      INTENSITY="${2:-}"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    --)
      shift
      # Remaining args are forwarded verbatim.
      FORWARD_ARGS="$*"
      break
      ;;
    *)
      shift ;;
  esac
done

# Resolve intensity
if [[ -z "$INTENSITY" ]] && [[ -n "$METADATA_FILE" ]]; then
  if [[ ! -f "$METADATA_FILE" ]]; then
    echo "ERROR: metadata file not found: $METADATA_FILE" >&2
    exit 1
  fi
  INTENSITY="$(grep -E '^intensity:' "$METADATA_FILE" | head -n 1 | sed -E 's/^intensity:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')"
fi

if [[ -z "$INTENSITY" ]]; then
  echo "ERROR: --intensity or --intensity-metadata required" >&2
  exit 1
fi

case "$INTENSITY" in
  Quick|Standard|Full) ;;
  *)
    echo "ERROR: invalid intensity '$INTENSITY' (expected Quick|Standard|Full)" >&2
    exit 2 ;;
esac

# Define the pipeline steps per intensity. Parallel indexed arrays per
# MEM001 (no associative arrays in bash 3.2).

step_count=0
step_0=""
step_1=""
step_2=""
step_3=""

case "$INTENSITY" in
  Quick)
    step_0="$SCRIPT_DIR/write-summary.sh"
    step_count=1
    ;;
  Standard)
    step_0="$SCRIPT_DIR/write-summary.sh"
    step_1="$SCRIPT_DIR/append-decision.sh"
    step_count=2
    ;;
  Full)
    step_0="$SCRIPT_DIR/write-summary.sh"
    step_1="$SCRIPT_DIR/append-decision.sh"
    step_2="$SCRIPT_DIR/append-knowledge.sh"
    step_3="$SCRIPT_DIR/rebuild-index.sh"
    step_count=4
    ;;
esac

run_step() {
  local script="$1"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "WOULD_RUN: $script $FORWARD_ARGS"
    return 0
  fi
  if [[ ! -f "$script" ]]; then
    echo "ERROR: knowledge script missing: $script" >&2
    return 1
  fi
  # Forward args. Using $FORWARD_ARGS unquoted is intentional — the
  # caller's args re-split on whitespace. Callers that need to pass
  # arguments containing spaces should invoke the sub-scripts directly.
  # shellcheck disable=SC2086
  bash "$script" $FORWARD_ARGS
}

i=0
while [[ $i -lt $step_count ]]; do
  case "$i" in
    0) step="$step_0" ;;
    1) step="$step_1" ;;
    2) step="$step_2" ;;
    3) step="$step_3" ;;
  esac
  run_step "$step" || {
    rc=$?
    echo "ERROR: step '$step' exited $rc" >&2
    exit "$rc"
  }
  i=$((i + 1))
done

echo "INTENSITY_KNOWLEDGE: completed intensity=$INTENSITY steps=$step_count"
exit 0
```

### Step 2 — Make executable

```bash
chmod +x scripts/knowledge/intensity-knowledge.sh
```

### Step 3 — Create scripts/verify/m008-p03-knowledge-pipeline.sh

Write verbatim:

```bash
#!/usr/bin/env bash
# Verifies intensity-knowledge.sh dispatches the expected subset of
# knowledge scripts at each intensity level, using --dry-run mode so
# we do not need real summary/decision inputs.
set -u

f="scripts/knowledge/intensity-knowledge.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
test -x "$f" || { echo "FAIL: $f not executable"; exit 1; }

# Quick -> write-summary.sh only
out="$(bash "$f" --intensity Quick --dry-run 2>/dev/null)"
echo "$out" | grep -q 'WOULD_RUN:.*write-summary.sh' || { echo "FAIL: Quick did not plan write-summary.sh"; exit 1; }
if echo "$out" | grep -q 'WOULD_RUN:.*append-decision.sh'; then
  echo "FAIL: Quick should NOT plan append-decision.sh"; exit 1
fi
if echo "$out" | grep -q 'WOULD_RUN:.*append-knowledge.sh'; then
  echo "FAIL: Quick should NOT plan append-knowledge.sh"; exit 1
fi
if echo "$out" | grep -q 'WOULD_RUN:.*rebuild-index.sh'; then
  echo "FAIL: Quick should NOT plan rebuild-index.sh"; exit 1
fi

# Standard -> write-summary.sh + append-decision.sh
out="$(bash "$f" --intensity Standard --dry-run 2>/dev/null)"
echo "$out" | grep -q 'WOULD_RUN:.*write-summary.sh' || { echo "FAIL: Standard missing write-summary.sh"; exit 1; }
echo "$out" | grep -q 'WOULD_RUN:.*append-decision.sh' || { echo "FAIL: Standard missing append-decision.sh"; exit 1; }
if echo "$out" | grep -q 'WOULD_RUN:.*append-knowledge.sh'; then
  echo "FAIL: Standard should NOT plan append-knowledge.sh"; exit 1
fi
if echo "$out" | grep -q 'WOULD_RUN:.*rebuild-index.sh'; then
  echo "FAIL: Standard should NOT plan rebuild-index.sh"; exit 1
fi

# Full -> all four
out="$(bash "$f" --intensity Full --dry-run 2>/dev/null)"
echo "$out" | grep -q 'WOULD_RUN:.*write-summary.sh' || { echo "FAIL: Full missing write-summary.sh"; exit 1; }
echo "$out" | grep -q 'WOULD_RUN:.*append-decision.sh' || { echo "FAIL: Full missing append-decision.sh"; exit 1; }
echo "$out" | grep -q 'WOULD_RUN:.*append-knowledge.sh' || { echo "FAIL: Full missing append-knowledge.sh"; exit 1; }
echo "$out" | grep -q 'WOULD_RUN:.*rebuild-index.sh' || { echo "FAIL: Full missing rebuild-index.sh"; exit 1; }

# --intensity-metadata resolves to same plan
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
printf '%s\n' '---' 'intensity: "Full"' '---' > "$tmp/meta.md"
out="$(bash "$f" --intensity-metadata "$tmp/meta.md" --dry-run 2>/dev/null)"
echo "$out" | grep -q 'WOULD_RUN:.*rebuild-index.sh' || { echo "FAIL: metadata-file Full should include rebuild-index.sh"; exit 1; }

# Invalid intensity rejected
err="$(bash "$f" --intensity Medium --dry-run 2>&1 >/dev/null)"
rc=$?
if [[ $rc -eq 0 ]]; then echo "FAIL: invalid intensity did not exit non-zero"; exit 1; fi

echo "PASS: intensity-knowledge.sh dispatches expected subset per level"
```

### Step 4 — Make verify script executable

```bash
chmod +x scripts/verify/m008-p03-knowledge-pipeline.sh
```

## Must-Haves

From the phase plan, this task addresses:

- **Truths**: knowledge pipeline truth ("runs write-summary at Quick; adds append-decision at Standard; full pipeline at Full").
- **Artifacts**: `scripts/knowledge/intensity-knowledge.sh`, `scripts/verify/m008-p03-knowledge-pipeline.sh`.

## Verification

```bash
bash scripts/verify/m008-p03-knowledge-pipeline.sh
```

Prints `PASS:` and exits 0.

### Files Touched By This Task

- `scripts/knowledge/intensity-knowledge.sh` (create)
- `scripts/verify/m008-p03-knowledge-pipeline.sh` (create)

## Inputs

### From Previous Tasks

- None. T03 is independent within P03.

### From Disk (Pre-existing)

- `scripts/knowledge/write-summary.sh` — existing; invoked at all intensities. Behavioral contract: consumes a task/phase completion context, writes summary file. Wrapper forwards `$FORWARD_ARGS` unchanged.
- `scripts/knowledge/append-decision.sh` — existing; invoked at Standard and Full. Appends decision register entry.
- `scripts/knowledge/append-knowledge.sh` — existing; invoked at Full. Appends knowledge entry.
- `scripts/knowledge/rebuild-index.sh` — existing; invoked at Full. Rebuilds knowledge index.
- `templates/intensity-metadata.md` — schema source; only the `intensity:` field is read.

## Constraints

- Bash 3.2 compatible — no associative arrays, no `readarray`, no `|&`, no process substitution. Parallel indexed arrays (`step_0`, `step_1`, `step_2`, `step_3`) per MEM001.
- MUST NOT modify or re-implement any of the underlying knowledge scripts (M007 pipeline is the source of truth).
- MUST preserve invocation order: summary first (Quick/Standard/Full), then decision (Standard/Full), then knowledge entry (Full), then rebuild-index (Full). This order is load-bearing: rebuild-index consumes the files written by the earlier steps.
- Failure short-circuits: if any step exits non-zero, the wrapper exits with the same code and does NOT invoke subsequent steps.
- `--dry-run` prints `WOULD_RUN: <script> <args>` lines on stdout, one per step, and exits 0 without invoking anything. Used by the T05 integration test to avoid needing real inputs.

## Expected Output

After completing this task:

1. `scripts/knowledge/intensity-knowledge.sh` exists (~120 lines), executable.
2. `bash scripts/knowledge/intensity-knowledge.sh --intensity Quick --dry-run` prints a single line starting `WOULD_RUN:` and referencing `write-summary.sh`.
3. `bash scripts/knowledge/intensity-knowledge.sh --intensity Full --dry-run` prints four `WOULD_RUN:` lines referencing `write-summary.sh`, `append-decision.sh`, `append-knowledge.sh`, `rebuild-index.sh` in that order.
4. Invalid intensity exits non-zero with a stderr diagnostic.
5. The verify script prints `PASS:` and exits 0.
6. `git status` shows 2 new files.
