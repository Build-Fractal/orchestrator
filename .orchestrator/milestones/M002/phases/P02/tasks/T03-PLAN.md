---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P02"
milestone: "M002"
name: "Integrate Lifecycle into Consolidation Flow"
depends_on: ["T02"]
---

## Prerequisites

T02 has validated that the lifecycle scripts (compute-staleness.sh, detect-overlap.sh, increment-hits.sh, update-confidence.sh) are working correctly against the P01-delivered libraries. The consolidation script `scripts/knowledge/consolidate-artifacts.sh` currently handles only file archival (moving task plans, task summaries, and phase plans to archive/). It needs to also invoke the knowledge lifecycle scripts as part of consolidation.

## Description

Extend `scripts/knowledge/consolidate-artifacts.sh` to invoke `detect-overlap.sh` and `compute-staleness.sh` as advisory lifecycle checks during milestone consolidation. The consolidation flow should:

1. Run the existing file archival logic (unchanged)
2. Run `detect-overlap.sh` to check for content overlaps in the knowledge base
3. Run `compute-staleness.sh` to report stale entries in the knowledge base
4. Report findings to stdout/stderr but NOT auto-archive or auto-merge (advisory only)

This satisfies FR-107 (overlap detection during consolidation) and US-2 AC-4 (consolidation flags overlap for human review).

## Steps

### Step 1: Read the current consolidate-artifacts.sh

Read `scripts/knowledge/consolidate-artifacts.sh` to understand the current structure. The script:
- Takes 2 arguments: `<orchestrator-root>` and `<milestone-id>`
- Validates milestone directory and roadmap exist
- Verifies all phases are complete (have summaries)
- Measures size before/after
- Archives task plans, task summaries, phase plans
- Reports consolidation results

### Step 2: Add knowledge lifecycle integration

Insert a new section after the existing file archival logic (after the "Measure size after consolidation" block, before the final report) that:

1. **Runs overlap detection** by invoking `detect-overlap.sh`. Capture output and report any OVERLAP lines. If `detect-overlap.sh` is not found, skip gracefully with a warning.

2. **Runs staleness computation** by invoking `compute-staleness.sh` (read-only, no --archive-below). Capture output and report the staleness summary. If `compute-staleness.sh` is not found, skip gracefully with a warning.

Both invocations are advisory — they report findings but do not take action. The consolidation script's exit code is determined only by the file archival success, not by overlap/staleness findings.

Add the following code block after the size measurement section (after line ~145, before the final report):

```bash
# --- Knowledge lifecycle checks (advisory) ---
KNOWLEDGE_DIR="$PROJECT_ROOT/scripts/knowledge"

# Overlap detection
if [ -f "$KNOWLEDGE_DIR/detect-overlap.sh" ]; then
  echo "" >&2
  echo "CONSOLIDATE: Running overlap detection..." >&2
  overlap_output=$(bash "$KNOWLEDGE_DIR/detect-overlap.sh" 2>&1) || true
  if echo "$overlap_output" | grep -q "^OVERLAP:"; then
    echo "CONSOLIDATE: Overlapping entries detected:" >&2
    echo "$overlap_output" | grep "^OVERLAP:" >&2
  else
    echo "CONSOLIDATE: No overlapping entries found" >&2
  fi
else
  echo "CONSOLIDATE: detect-overlap.sh not found, skipping overlap check" >&2
fi

# Staleness report
if [ -f "$KNOWLEDGE_DIR/compute-staleness.sh" ]; then
  echo "" >&2
  echo "CONSOLIDATE: Running staleness report..." >&2
  staleness_output=$(bash "$KNOWLEDGE_DIR/compute-staleness.sh" 2>&1) || true
  if [ -n "$staleness_output" ]; then
    echo "$staleness_output" >&2
  fi
else
  echo "CONSOLIDATE: compute-staleness.sh not found, skipping staleness check" >&2
fi
```

### Step 3: Verify the integration

Run the two consolidation verification scripts:

```
bash scripts/verify/m002-p02-consolidate-overlap.sh
bash scripts/verify/m002-p02-consolidate-staleness.sh
```

Both should now print `PASS:`.

### Step 4: Run all 10 verification scripts

Confirm that all 10 verification scripts now pass:

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

This task addresses these phase must-haves:
- consolidate-artifacts.sh invokes detect-overlap.sh during consolidation and reports any flagged overlaps
- consolidate-artifacts.sh invokes compute-staleness.sh during consolidation and reports stale entries

## Verification

```
bash scripts/verify/m002-p02-consolidate-overlap.sh
bash scripts/verify/m002-p02-consolidate-staleness.sh
```

Expected output:
```
PASS: consolidate-artifacts.sh integrates detect-overlap.sh
PASS: consolidate-artifacts.sh integrates compute-staleness.sh
```

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p02-consolidate-overlap.sh` (from T01)
  - Key API: Takes no arguments. Greps `consolidate-artifacts.sh` for the string `detect-overlap`. Prints `PASS:` or `FAIL:` and exits 0/1.
- `scripts/verify/m002-p02-consolidate-staleness.sh` (from T01)
  - Key API: Takes no arguments. Greps `consolidate-artifacts.sh` for the string `compute-staleness`. Prints `PASS:` or `FAIL:` and exits 0/1.
- Validation from T02 confirming `detect-overlap.sh` and `compute-staleness.sh` work correctly with P01 libraries.

### From Disk (Pre-existing)

- `scripts/knowledge/consolidate-artifacts.sh` — 151 lines. Takes `<orchestrator-root> <milestone-id>`. Validates milestone directory, reads phases from roadmap via `scripts/state/read-roadmap.sh`, verifies all phases complete, archives task plans/summaries/phase plans to `$MILESTONE_DIR/archive/$pid/`, reports size reduction. Uses `PROJECT_ROOT` derived from script location. The `KNOWLEDGE_DIR` will be `$PROJECT_ROOT/scripts/knowledge`.
- `scripts/knowledge/detect-overlap.sh` — 157 lines. Takes optional `--threshold 0.70`. Outputs `OVERLAP: ID1 and ID2 (category: CAT, similarity: 0.XX) — review suggested` or `NO_OVERLAPS: all entries have <70% similarity`. Exit 0 in both cases.
- `scripts/knowledge/compute-staleness.sh` — 143 lines. Takes optional `--archive-below CONF --min-hits N --dry-run`. Without flags, outputs a read-only staleness report to stdout. Exit 0.

## Constraints

- The integration is advisory only: findings are reported to stderr, but the consolidation exit code is NOT affected by overlap/staleness results.
- Both lifecycle script invocations must be wrapped in `|| true` to prevent a failure in overlap/staleness from aborting consolidation.
- If the lifecycle scripts are missing (e.g., in a minimal installation), consolidation must continue with a warning, not fail.
- Do not change the existing file archival logic or size measurement — only add new sections after the existing logic.
- Maintain Bash 3.2 compatibility (no associative arrays, no process substitution in the new code).

## Expected Output

Modified `scripts/knowledge/consolidate-artifacts.sh` with approximately 25 new lines added for lifecycle integration. The script's public interface (arguments, stdout output format) is unchanged. New output goes to stderr with `CONSOLIDATE:` prefix.

All 10 verification scripts pass.
