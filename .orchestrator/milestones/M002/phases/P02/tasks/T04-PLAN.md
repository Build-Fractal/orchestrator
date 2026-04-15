---
schema_version: "1.0"
type: task-plan
task: "T04"
phase: "P02"
milestone: "M002"
name: "End-to-End Lifecycle Verification"
depends_on: ["T01", "T02", "T03"]
---

## Prerequisites

T01 created all 10 verification scripts. T02 validated and hardened the 4 lifecycle scripts against P01 libraries. T03 integrated lifecycle operations into consolidate-artifacts.sh. All 10 verification scripts should pass. This task performs the integration test that proves the full lifecycle works end-to-end.

## Description

Execute a full knowledge entry lifecycle roundtrip in a temporary test environment. Create entries, compute staleness, detect overlaps, increment hits, update confidence, supersede, archive, promote — then verify all operations are idempotent, the index stays consistent, and all 10 must-have verification scripts pass. This is the final validation task for P02.

## Steps

### Step 1: Run all 10 verification scripts

Before testing behavior, confirm that all static/structural checks pass:

```
bash scripts/verify/m002-p02-staleness-sources.sh
bash scripts/verify/m002-p02-staleness-archive-flags.sh
bash scripts/verify/m002-p02-overlap-jaccard.sh
bash scripts/verify/m002-p02-overlap-no-automerge.sh
bash scripts/verify/m002-p02-increment-delegates.sh
bash scripts/verify/m002-p02-confidence-delegates.sh
bash scripts/verify/m002-p02-consolidate-overlap.sh
bash scripts/verify/m002-p02-consolidate-staleness.sh
bash scripts/verify/m002-p02-bash32-compat.sh
bash scripts/verify/m002-p02-idempotent.sh
```

All 10 must print `PASS:`. If any fails, stop and investigate before proceeding to behavioral tests.

### Step 2: Set up a temporary test environment

Create a temporary directory that mimics the project structure:

```bash
tmp_dir=$(mktemp -d)
mkdir -p "$tmp_dir/knowledge/convention"
mkdir -p "$tmp_dir/knowledge/gotcha"
mkdir -p "$tmp_dir/knowledge/archive"
touch "$tmp_dir/extension.yml"  # So get_project_root() finds it
```

Set `PROJECT_ROOT="$tmp_dir"` before sourcing any libraries, so all operations target the temp directory.

### Step 3: Create test entries

Use `create-entry.sh` to create 3 entries in the temp environment:

```bash
export PROJECT_ROOT="$tmp_dir"

# Entry 1: convention, high confidence, recent
bash scripts/knowledge/create-entry.sh \
  --id MEM001 \
  --category convention \
  --scope "[project]" \
  --confidence 0.95 \
  --description "Always use SafeAreaProvider" \
  --body "Use SafeAreaProvider not SafeAreaView for screen wrappers." \
  --source-unit "M001/P01" \
  --source-type "execution"

# Entry 2: convention, high confidence, recent (overlapping content)
bash scripts/knowledge/create-entry.sh \
  --id MEM002 \
  --category convention \
  --scope "[project]" \
  --confidence 0.90 \
  --description "Screen wrappers need SafeAreaProvider" \
  --body "Use SafeAreaProvider not SafeAreaView for screen wrappers." \
  --source-unit "M001/P02" \
  --source-type "execution"

# Entry 3: gotcha, old verification date
bash scripts/knowledge/create-entry.sh \
  --id MEM003 \
  --category gotcha \
  --scope "[milestone:M001]" \
  --confidence 0.85 \
  --description "React Native 0.72 has broken hot reload" \
  --body "Hot reload in RN 0.72 fails on iOS simulator. Workaround: restart metro." \
  --source-unit "M001/P03" \
  --source-type "verification-failure"
```

Verify index has 3 entries.

### Step 4: Test compute-staleness.sh

Run the staleness report:

```bash
export PROJECT_ROOT="$tmp_dir"
bash scripts/knowledge/compute-staleness.sh
```

Expected: a report showing all 3 entries with their raw confidence, effective confidence, days since verified, and hit counts. Since entries were just created, effective confidence should equal raw confidence (0 days since verification).

To test staleness decay, manually modify MEM003's `last_verified` field to a date 90 days in the past, then re-run:

```bash
# Modify last_verified to 90 days ago
old_date=$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d "90 days ago" +%Y-%m-%d)
sed -i '' "s/^last_verified: .*/last_verified: $old_date/" "$tmp_dir/knowledge/gotcha/MEM003.md"
bash scripts/knowledge/compute-staleness.sh
```

Expected: MEM003's effective confidence should be lower than 0.85 (decayed by the staleness formula).

### Step 5: Test detect-overlap.sh

Run overlap detection:

```bash
export PROJECT_ROOT="$tmp_dir"
bash scripts/knowledge/detect-overlap.sh
```

Expected output: `OVERLAP: MEM001 and MEM002 (category: convention, similarity: X.XX) — review suggested` because both entries have nearly identical body content.

### Step 6: Test increment-hits.sh and update-confidence.sh

```bash
export PROJECT_ROOT="$tmp_dir"

# Increment hits on MEM001
bash scripts/knowledge/increment-hits.sh --id MEM001
# Expected: UPDATED: MEM001 (hit_count)

# Increment again (idempotency — should work, incrementing further)
bash scripts/knowledge/increment-hits.sh --id MEM001
# Expected: UPDATED: MEM001 (hit_count)

# Update confidence on MEM002
bash scripts/knowledge/update-confidence.sh --id MEM002 --confidence 0.80
# Expected: UPDATED: MEM002 (confidence)
```

Verify the index reflects updated values by checking MEM001's hit count is 2 and MEM002's confidence is 0.80.

### Step 7: Test supersession

```bash
export PROJECT_ROOT="$tmp_dir"

# Supersede MEM001 with MEM002
bash scripts/knowledge/supersede-entry.sh --old-id MEM001 --new-id MEM002
# Expected: SUPERSEDED: MEM001 by MEM002

# Idempotency check
bash scripts/knowledge/supersede-entry.sh --old-id MEM001 --new-id MEM002
# Expected: ALREADY_SUPERSEDED: MEM001 by MEM002
```

Verify MEM001 is no longer in the index but its detail file still exists.

### Step 8: Test archive and promote

```bash
export PROJECT_ROOT="$tmp_dir"

# Archive MEM003
bash scripts/knowledge/archive-entry.sh --id MEM003
# Expected: ARCHIVED: MEM003 moved to knowledge/archive/MEM003.md

# Idempotency
bash scripts/knowledge/archive-entry.sh --id MEM003
# Expected: ALREADY_ARCHIVED: MEM003 is already in knowledge/archive/

# Promote MEM003 back
bash scripts/knowledge/promote-entry.sh --id MEM003
# Expected: PROMOTED: MEM003 moved to knowledge/gotcha/MEM003.md with confidence 0.80

# Idempotency (already in warm storage)
bash scripts/knowledge/promote-entry.sh --id MEM003
# Expected: NOT_ARCHIVED: MEM003 is not in archive, nothing to promote
```

### Step 9: Verify index consistency

Run `rebuild-index.sh` and compare with the current index to ensure they match:

```bash
export PROJECT_ROOT="$tmp_dir"
bash scripts/knowledge/rebuild-index.sh
```

The index should contain exactly MEM002 and MEM003 (MEM001 was superseded and removed from index, MEM003 was re-promoted).

### Step 10: Clean up

```bash
rm -rf "$tmp_dir"
```

### Step 11: Run all 10 verification scripts one final time

```
bash scripts/verify/m002-p02-staleness-sources.sh
bash scripts/verify/m002-p02-staleness-archive-flags.sh
bash scripts/verify/m002-p02-overlap-jaccard.sh
bash scripts/verify/m002-p02-overlap-no-automerge.sh
bash scripts/verify/m002-p02-increment-delegates.sh
bash scripts/verify/m002-p02-confidence-delegates.sh
bash scripts/verify/m002-p02-consolidate-overlap.sh
bash scripts/verify/m002-p02-consolidate-staleness.sh
bash scripts/verify/m002-p02-bash32-compat.sh
bash scripts/verify/m002-p02-idempotent.sh
```

All 10 must print `PASS:`.

## Must-Haves

This task validates ALL phase must-haves through both structural checks (verification scripts) and behavioral tests (end-to-end lifecycle). Specifically:
- compute-staleness.sh walks entries and shows raw vs effective confidence (Step 4)
- compute-staleness.sh auto-archive flags work (tested structurally in Step 1)
- detect-overlap.sh flags similar entries (Step 5)
- detect-overlap.sh does not auto-merge (Step 5)
- increment-hits.sh delegates correctly (Step 6)
- update-confidence.sh delegates correctly (Step 6)
- consolidate-artifacts.sh integrates lifecycle scripts (Step 1 structural check)
- Bash 3.2 compatibility (Step 1 structural check)
- Idempotency (Steps 6, 7, 8)

## Verification

All 10 verification scripts print `PASS:`:

```
bash scripts/verify/m002-p02-staleness-sources.sh
bash scripts/verify/m002-p02-staleness-archive-flags.sh
bash scripts/verify/m002-p02-overlap-jaccard.sh
bash scripts/verify/m002-p02-overlap-no-automerge.sh
bash scripts/verify/m002-p02-increment-delegates.sh
bash scripts/verify/m002-p02-confidence-delegates.sh
bash scripts/verify/m002-p02-consolidate-overlap.sh
bash scripts/verify/m002-p02-consolidate-staleness.sh
bash scripts/verify/m002-p02-bash32-compat.sh
bash scripts/verify/m002-p02-idempotent.sh
```

Behavioral roundtrip demonstrates:
- Staleness decay reduces effective confidence over time
- Overlap detection finds similar entries
- Hit count incrementing works atomically
- Confidence updates propagate to index
- Supersession removes old entry from index but preserves detail file
- Archive moves to cold storage; promote restores to warm
- All operations are idempotent (second invocation returns ALREADY_* message)
- Index stays consistent through all operations

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p02-*.sh` (from T01) — 10 verification scripts. Each takes no arguments, prints `PASS:`/`FAIL:`, exits 0/1.
- Validated lifecycle scripts (from T02):
  - `scripts/knowledge/compute-staleness.sh` — batch staleness report. Invoke: `bash scripts/knowledge/compute-staleness.sh [--archive-below CONF] [--min-hits N] [--dry-run]`. Reads `KNOWLEDGE-INDEX.md` via `get_index_path()`, computes effective confidence via `compute_effective_confidence(conf, date, [ref])`, outputs formatted table. Auto-archives via `archive-entry.sh` when flags provided.
  - `scripts/knowledge/detect-overlap.sh` — content similarity. Invoke: `bash scripts/knowledge/detect-overlap.sh [--threshold 0.70]`. Scans `knowledge/*/` excluding archive, computes word-level Jaccard similarity per category pair, outputs `OVERLAP:` lines or `NO_OVERLAPS:`.
  - `scripts/knowledge/increment-hits.sh` — thin wrapper. Invoke: `bash scripts/knowledge/increment-hits.sh --id MEM###`. Delegates to `update-entry.sh --increment-hits`.
  - `scripts/knowledge/update-confidence.sh` — thin wrapper. Invoke: `bash scripts/knowledge/update-confidence.sh --id MEM### --confidence 0.XX`. Delegates to `update-entry.sh`.
- Modified `scripts/knowledge/consolidate-artifacts.sh` (from T03) — now invokes `detect-overlap.sh` and `compute-staleness.sh` as advisory checks after file archival, reporting findings to stderr.

### From Disk (Pre-existing)

- `scripts/knowledge/create-entry.sh` — Creates a detail file and updates the index. Invoke: `bash scripts/knowledge/create-entry.sh --id ID --category CAT --scope SCOPE --confidence CONF --description DESC --body BODY --source-unit UNIT --source-type TYPE`.
- `scripts/knowledge/supersede-entry.sh` — Marks old entry superseded, removes from index. Invoke: `bash scripts/knowledge/supersede-entry.sh --old-id ID --new-id ID`. Outputs `SUPERSEDED:` or `ALREADY_SUPERSEDED:`.
- `scripts/knowledge/archive-entry.sh` — Moves to cold storage. Invoke: `bash scripts/knowledge/archive-entry.sh --id ID`. Outputs `ARCHIVED:` or `ALREADY_ARCHIVED:`.
- `scripts/knowledge/promote-entry.sh` — Restores from archive. Invoke: `bash scripts/knowledge/promote-entry.sh --id ID [--confidence CONF] [--category CAT]`. Outputs `PROMOTED:` or `NOT_ARCHIVED:`. Default confidence reset: 0.80.
- `scripts/knowledge/rebuild-index.sh` — Regenerates index from disk. Invoke: `bash scripts/knowledge/rebuild-index.sh`.
- `scripts/knowledge/update-entry.sh` — Modifies entry metadata. Invoke: `bash scripts/knowledge/update-entry.sh --id ID [--confidence CONF] [--last-verified DATE|now] [--hit-count N] [--increment-hits]`. Outputs `UPDATED:`.

## Constraints

- The end-to-end test must run in a temporary directory to avoid polluting the project's actual knowledge base.
- Set `PROJECT_ROOT` environment variable to the temp directory so all library functions target it.
- Clean up the temp directory after testing.
- Do not modify any scripts in this task — this is a validation-only task. If a script fails during testing, the fix belongs in T02 or T03, not T04.

## Expected Output

All 10 verification scripts pass. The behavioral roundtrip completes successfully with correct output at each step. The phase is ready for summary and verification closure.
