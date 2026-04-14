---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P02"
milestone: "M002"
name: "Verification Scripts for All Must-Haves"
depends_on: []
---

## Prerequisites

P01 is complete. The following scripts exist on disk and were delivered by P01 or by the initial M002 commit:
- `scripts/knowledge/compute-staleness.sh` (batch staleness report)
- `scripts/knowledge/detect-overlap.sh` (content similarity detection)
- `scripts/knowledge/increment-hits.sh` (thin wrapper)
- `scripts/knowledge/update-confidence.sh` (thin wrapper)
- `scripts/knowledge/consolidate-artifacts.sh` (milestone consolidation)
- `scripts/knowledge/lib/staleness.sh` (staleness decay library)
- `scripts/knowledge/lib/index-utils.sh` (index read/write utilities)
- `scripts/knowledge/lib/detail-utils.sh` (shared detail file helpers)
- `scripts/knowledge/archive-entry.sh` (warm-to-cold storage)
- `scripts/knowledge/update-entry.sh` (metadata modification)

## Description

Create 10 verification scripts under `scripts/verify/m002-p02-*.sh` that mechanically check all P02 must-haves. Each script is a single-file invocation (per AD-19) that prints `PASS: <message>` on success or `FAIL: <message>` on failure, exiting 0 on pass and 1 on fail.

## Steps

### Step 1: Create `scripts/verify/m002-p02-staleness-sources.sh`

Verifies that `compute-staleness.sh` sources both `lib/staleness.sh` and `lib/index-utils.sh`, and calls `compute_effective_confidence`.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/knowledge/compute-staleness.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'staleness\.sh' "$f" || { echo "FAIL: does not source staleness.sh"; exit 1; }
grep -q 'index-utils\.sh' "$f" || { echo "FAIL: does not source index-utils.sh"; exit 1; }
grep -q 'compute_effective_confidence' "$f" || { echo "FAIL: does not call compute_effective_confidence"; exit 1; }
echo "PASS: compute-staleness.sh sources lib/staleness.sh and lib/index-utils.sh and calls compute_effective_confidence"
```

### Step 2: Create `scripts/verify/m002-p02-staleness-archive-flags.sh`

Verifies that `compute-staleness.sh` supports `--archive-below`, `--min-hits`, and `--dry-run` flags.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/knowledge/compute-staleness.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '\-\-archive-below' "$f" || { echo "FAIL: missing --archive-below flag"; exit 1; }
grep -q '\-\-min-hits' "$f" || { echo "FAIL: missing --min-hits flag"; exit 1; }
grep -q '\-\-dry-run' "$f" || { echo "FAIL: missing --dry-run flag"; exit 1; }
echo "PASS: compute-staleness.sh supports --archive-below, --min-hits, and --dry-run flags"
```

### Step 3: Create `scripts/verify/m002-p02-overlap-jaccard.sh`

Verifies that `detect-overlap.sh` implements Jaccard similarity and references the 70% threshold.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/knowledge/detect-overlap.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qiE 'jaccard|similarity' "$f" || { echo "FAIL: no Jaccard/similarity logic"; exit 1; }
grep -q '0\.70\|70%\|threshold' "$f" || { echo "FAIL: no 70% threshold reference"; exit 1; }
echo "PASS: detect-overlap.sh uses Jaccard similarity with threshold"
```

### Step 4: Create `scripts/verify/m002-p02-overlap-no-automerge.sh`

Verifies that `detect-overlap.sh` outputs OVERLAP lines with review recommendation but does NOT contain auto-merge logic.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/knowledge/detect-overlap.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'OVERLAP' "$f" || { echo "FAIL: no OVERLAP output format"; exit 1; }
grep -q 'review' "$f" || { echo "FAIL: no review recommendation in output"; exit 1; }
grep -qiE 'auto.merge|auto_merge|performing merge' "$f" && { echo "FAIL: contains auto-merge logic"; exit 1; }
echo "PASS: detect-overlap.sh flags overlaps for review without auto-merging"
```

### Step 5: Create `scripts/verify/m002-p02-increment-delegates.sh`

Verifies that `increment-hits.sh` delegates to `update-entry.sh` with `--increment-hits`.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/knowledge/increment-hits.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'update-entry\.sh' "$f" || { echo "FAIL: does not delegate to update-entry.sh"; exit 1; }
grep -q '\-\-increment-hits' "$f" || { echo "FAIL: does not pass --increment-hits flag"; exit 1; }
echo "PASS: increment-hits.sh delegates to update-entry.sh --increment-hits"
```

### Step 6: Create `scripts/verify/m002-p02-confidence-delegates.sh`

Verifies that `update-confidence.sh` delegates to `update-entry.sh`.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/knowledge/update-confidence.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'update-entry\.sh' "$f" || { echo "FAIL: does not delegate to update-entry.sh"; exit 1; }
echo "PASS: update-confidence.sh delegates to update-entry.sh"
```

### Step 7: Create `scripts/verify/m002-p02-consolidate-overlap.sh`

Verifies that `consolidate-artifacts.sh` references `detect-overlap.sh` for overlap checking during consolidation.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/knowledge/consolidate-artifacts.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'detect-overlap' "$f" || { echo "FAIL: consolidate-artifacts.sh does not invoke detect-overlap.sh"; exit 1; }
echo "PASS: consolidate-artifacts.sh integrates detect-overlap.sh"
```

### Step 8: Create `scripts/verify/m002-p02-consolidate-staleness.sh`

Verifies that `consolidate-artifacts.sh` references `compute-staleness.sh` for staleness reporting during consolidation.

```bash
#!/usr/bin/env bash
set -eu
f="scripts/knowledge/consolidate-artifacts.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q 'compute-staleness' "$f" || { echo "FAIL: consolidate-artifacts.sh does not invoke compute-staleness.sh"; exit 1; }
echo "PASS: consolidate-artifacts.sh integrates compute-staleness.sh"
```

### Step 9: Create `scripts/verify/m002-p02-bash32-compat.sh`

Verifies that none of the lifecycle scripts use Bash 3.2-incompatible features.

```bash
#!/usr/bin/env bash
set -eu
files="scripts/knowledge/compute-staleness.sh scripts/knowledge/detect-overlap.sh scripts/knowledge/increment-hits.sh scripts/knowledge/update-confidence.sh"
for f in $files; do
  test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
done
grep -rlE 'declare -A|readarray|mapfile' $files && { echo "FAIL: Bash 3.2 incompatible constructs found"; exit 1; }
echo "PASS: all lifecycle scripts are Bash 3.2 compatible"
```

### Step 10: Create `scripts/verify/m002-p02-idempotent.sh`

Verifies that compute-staleness.sh has idempotency markers (dry-run support or no-side-effect default mode).

```bash
#!/usr/bin/env bash
set -eu
f="scripts/knowledge/compute-staleness.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -qE 'dry.run|idempotent|DRY.RUN|no side' "$f" || { echo "FAIL: no idempotency marker found"; exit 1; }
f2="scripts/knowledge/detect-overlap.sh"
test -f "$f2" || { echo "FAIL: $f2 missing"; exit 1; }
grep -qE 'NO_OVERLAPS|found_overlap' "$f2" || { echo "FAIL: detect-overlap.sh missing read-only marker"; exit 1; }
echo "PASS: lifecycle scripts support idempotent operation"
```

### Step 11: Make all scripts executable

```bash
chmod +x scripts/verify/m002-p02-*.sh
```

## Must-Haves

This task delivers all 10 verification scripts required by the phase plan. Every other task in this phase uses these scripts for mechanical verification.

## Verification

Run each verification script. Since T02 and T03 have not yet executed, some checks will fail (specifically the consolidation integration checks). The following should pass immediately because the scripts already exist from prior work:

```
bash scripts/verify/m002-p02-staleness-sources.sh
bash scripts/verify/m002-p02-staleness-archive-flags.sh
bash scripts/verify/m002-p02-overlap-jaccard.sh
bash scripts/verify/m002-p02-overlap-no-automerge.sh
bash scripts/verify/m002-p02-increment-delegates.sh
bash scripts/verify/m002-p02-confidence-delegates.sh
bash scripts/verify/m002-p02-bash32-compat.sh
bash scripts/verify/m002-p02-idempotent.sh
```

Expected output for each: `PASS: <description>`

The following will fail until T03 completes:
```
bash scripts/verify/m002-p02-consolidate-overlap.sh
bash scripts/verify/m002-p02-consolidate-staleness.sh
```

## Inputs

### From Previous Tasks

None — this is the first task in the phase.

### From Disk (Pre-existing)

- `scripts/knowledge/compute-staleness.sh` — batch staleness report script (143 lines), sources lib/staleness.sh and lib/index-utils.sh, calls compute_effective_confidence, supports --archive-below/--min-hits/--dry-run
- `scripts/knowledge/detect-overlap.sh` — content similarity script (157 lines), uses word-level Jaccard similarity, outputs OVERLAP lines, 70% default threshold
- `scripts/knowledge/increment-hits.sh` — thin wrapper (7 lines), delegates to update-entry.sh with --increment-hits
- `scripts/knowledge/update-confidence.sh` — thin wrapper (7 lines), delegates to update-entry.sh
- `scripts/knowledge/consolidate-artifacts.sh` — milestone consolidation script (151 lines), currently does NOT invoke lifecycle scripts

## Constraints

- All verification scripts must use single-script-file invocation shape per AD-19
- No compound bash, no subshells, no pipes inside $(), no inline for/if/while in Check: commands
- Each script must be independently executable: `bash scripts/verify/m002-p02-<name>.sh`
- Scripts must print PASS/FAIL and exit 0/1 respectively

## Expected Output

10 new files under `scripts/verify/`:
- `m002-p02-staleness-sources.sh`
- `m002-p02-staleness-archive-flags.sh`
- `m002-p02-overlap-jaccard.sh`
- `m002-p02-overlap-no-automerge.sh`
- `m002-p02-increment-delegates.sh`
- `m002-p02-confidence-delegates.sh`
- `m002-p02-consolidate-overlap.sh`
- `m002-p02-consolidate-staleness.sh`
- `m002-p02-bash32-compat.sh`
- `m002-p02-idempotent.sh`

All scripts are executable and follow the single-script-file shape convention.
