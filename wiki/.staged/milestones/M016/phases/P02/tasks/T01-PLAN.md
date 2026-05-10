---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M016"
name: "Create run-suite.sh wrapper script"
depends_on: []
---

## Prerequisites

No upstream tasks. The verify-script naming convention `scripts/verify/<milestone>-<phase>-*.sh` is established (e.g., `m015-p02-*.sh`).

## Description

Create `scripts/verify/run-suite.sh` — a wrapper that auto-discovers all gate scripts for a given milestone+phase, executes each one, prints per-script PASS/FAIL status, and prints an aggregate summary. This replaces the chained `bash a.sh && bash b.sh && ... | awk '{print $1}' | sort | uniq -c` pattern that triggers Claude Code compound-bash and brace-expansion safety prompts.

## Steps

### Step 1: Create scripts/verify/run-suite.sh

Write the following script at `scripts/verify/run-suite.sh`:

```bash
#!/usr/bin/env bash
# scripts/verify/run-suite.sh — Run all gate scripts for a milestone+phase
# Usage: run-suite.sh <milestone> <phase>
#   e.g.: run-suite.sh m016 P01
#
# Discovers scripts/verify/<milestone>-<phase>-*.sh (case-insensitive milestone),
# executes each, prints per-script PASS/FAIL, and a summary line.
# Exit: 0 if all pass, 1 if any fail.
#
# Bash 3.2 compatible.

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: run-suite.sh <milestone> <phase>" >&2
  echo "  e.g.: run-suite.sh m016 P01" >&2
  exit 1
fi

MILESTONE="$1"
PHASE="$2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Normalize: milestone lowercase, phase lowercase for glob
milestone_lower=$(echo "$MILESTONE" | tr '[:upper:]' '[:lower:]')
phase_lower=$(echo "$PHASE" | tr '[:upper:]' '[:lower:]')

# Discover gate scripts
pattern="${SCRIPT_DIR}/${milestone_lower}-${phase_lower}-*.sh"
scripts=""
script_count=0

for f in $pattern; do
  if [ -f "$f" ]; then
    scripts="${scripts} ${f}"
    script_count=$((script_count + 1))
  fi
done

if [ "$script_count" -eq 0 ]; then
  echo "NO SCRIPTS: no gate scripts found matching ${milestone_lower}-${phase_lower}-*.sh"
  exit 1
fi

echo "=== Verify Suite: ${MILESTONE} ${PHASE} (${script_count} scripts) ==="
echo ""

pass_count=0
fail_count=0
fail_names=""

for f in $scripts; do
  name=$(basename "$f")
  if bash "$f" > /dev/null 2>&1; then
    echo "  PASS: $name"
    pass_count=$((pass_count + 1))
  else
    echo "  FAIL: $name"
    fail_count=$((fail_count + 1))
    fail_names="${fail_names} ${name}"
  fi
done

echo ""
echo "PASS: ${pass_count} / FAIL: ${fail_count}"

if [ "$fail_count" -gt 0 ]; then
  echo "Failed:${fail_names}"
  exit 1
fi

exit 0
```

Note: execute permission is not needed — all invocations use `bash <path>`.

### Step 2: Smoke test against [M015](../../../../../milestones/M015/index.md) P02

Run `bash scripts/verify/run-suite.sh m015 P02` to confirm it discovers and executes the 8 existing `m015-p02-*.sh` scripts. Expected output: a header line, 8 per-script status lines, and a summary line.

## Must-Haves

- `run-suite.sh` discovers and runs gate scripts matching the `<milestone>-<phase>-*.sh` naming convention
- `run-suite.sh` prints per-script PASS/FAIL and a summary line
- `run-suite.sh` exits 0 on all-pass, non-zero on any-fail
- Bash 3.2 compatible

## Verification

```
bash scripts/verify/run-suite.sh m015 P02
```

Must show 8 scripts discovered and tally results. Bash 3.2 compatibility is verified by the T02 verify script (`m016-p02-bash32-compat.sh`), not inline `bash -n`.

## Inputs

### From Disk (Pre-existing)
- `scripts/verify/m015-p02-*.sh` — 8 existing gate scripts used as a smoke-test target. Each prints PASS/FAIL and exits 0/1 accordingly.

## Constraints

- Bash 3.2 compatible. No `declare -A`, `mapfile`, `${var,,}`.
- No `awk`, `sort`, `uniq`, or pipe chains in the script's output path — the whole point is to encapsulate these.
- The glob pattern uses lowercase milestone+phase to match the established convention (`m015-p02-*.sh`, not `M015-P02-*.sh`).
- Must handle the case where no scripts match the pattern (exit non-zero with a clear message).

## Expected Output

- `scripts/verify/run-suite.sh` created, executable, parse-clean under Bash 3.2.
- Smoke test against M015 P02 shows 8 discovered scripts with PASS/FAIL tally.
