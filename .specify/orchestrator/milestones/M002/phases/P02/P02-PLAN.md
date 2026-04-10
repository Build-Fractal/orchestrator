---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M002"
goal: "Complete the knowledge entry lifecycle with batch staleness computation, content overlap detection, hit count tracking wrappers, and integration into the consolidation workflow"
demo_sentence: "A developer can supersede an entry with a replacement, observe staleness decay reduce effective confidence over time, promote a cold entry back to warm, and see overlap flagged during consolidation — all operations idempotent."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

### Truths

- compute-staleness.sh walks all entries in the index, computes effective_confidence using the decay formula, and outputs a report showing each entry's raw vs effective confidence
  - Check: `grep -qE 'compute_effective_confidence|staleness' scripts/knowledge/compute-staleness.sh`
- compute-staleness.sh can optionally archive entries whose effective confidence drops below a threshold and whose hit_count is below a keep-alive threshold (default: 10)
  - Check: `grep -qE '\-\-archive-below|\-\-min-hits|threshold' scripts/knowledge/compute-staleness.sh`
- detect-overlap.sh compares content of entries in the same category and flags pairs with >70% word-level similarity
  - Check: `grep -qE '70\|overlap\|similar' scripts/knowledge/detect-overlap.sh`
- detect-overlap.sh outputs flagged pairs with entry IDs, similarity score, and suggested action (merge/review) — it does NOT auto-merge
  - Check: `grep -qE 'OVERLAP.*review\|merge.*review\|suggest' scripts/knowledge/detect-overlap.sh`
- increment-hits.sh is a thin wrapper that increments an entry's hit_count and updates the index atomically
  - Check: `grep -qE 'increment.*hits\|update-entry' scripts/knowledge/increment-hits.sh`
- update-confidence.sh adjusts confidence on an entry and updates the index atomically
  - Check: `grep -qE 'confidence\|update-entry' scripts/knowledge/update-confidence.sh`
- All new scripts are Bash 3.2 compatible (no associative arrays, no readarray, no mapfile)
  - Check: `! grep -rE 'declare -A|readarray|mapfile' scripts/knowledge/compute-staleness.sh scripts/knowledge/detect-overlap.sh scripts/knowledge/increment-hits.sh scripts/knowledge/update-confidence.sh`
- All new scripts are idempotent (running twice produces the same result)
  - Check: `grep -qE 'idempotent\|already\|no-op\|skip' scripts/knowledge/compute-staleness.sh`

### Artifacts

- scripts/knowledge/compute-staleness.sh (min 60 lines, contains "effective_confidence")
- scripts/knowledge/detect-overlap.sh (min 80 lines, contains "overlap")
- scripts/knowledge/increment-hits.sh (min 20 lines, contains "increment")
- scripts/knowledge/update-confidence.sh (min 20 lines, contains "confidence")

### Key Links

- scripts/knowledge/compute-staleness.sh -> scripts/knowledge/lib/staleness.sh (sources decay function)
- scripts/knowledge/compute-staleness.sh -> scripts/knowledge/lib/index-utils.sh (reads index)
- scripts/knowledge/compute-staleness.sh -> scripts/knowledge/archive-entry.sh (optional auto-archive)
- scripts/knowledge/detect-overlap.sh -> scripts/knowledge/lib/index-utils.sh (reads index)
- scripts/knowledge/increment-hits.sh -> scripts/knowledge/update-entry.sh (delegates to --increment-hits)
- scripts/knowledge/update-confidence.sh -> scripts/knowledge/update-entry.sh (delegates to --confidence)

## Tasks

### T01: compute-staleness.sh — Batch Staleness Computation

Build a CLI tool that walks all entries in KNOWLEDGE-INDEX.md, computes each entry's effective confidence using the staleness decay formula from lib/staleness.sh, and outputs a report. Supports `--archive-below CONF --min-hits N` flags to auto-archive stale entries with low hit counts.

### T02: detect-overlap.sh — Content Similarity Detection

Build a CLI tool that compares knowledge entries within the same category using word-level Jaccard similarity (computed via awk). Flags pairs exceeding 70% similarity for human review. Output format: `OVERLAP: MEM### and MEM### (similarity: 0.XX) — review suggested`.

### T03: increment-hits.sh and update-confidence.sh — Thin Wrappers

Create two thin wrapper scripts for API consistency with the roadmap boundary map. increment-hits.sh delegates to `update-entry.sh --id ID --increment-hits`. update-confidence.sh delegates to `update-entry.sh --id ID --confidence CONF`.

### T04: End-to-End Lifecycle Verification

Test the full lifecycle roundtrip: create entries, compute staleness, detect overlaps, increment hits, update confidence, supersede, archive, promote. Verify all operations are idempotent and the index stays consistent.

## Task Dependencies

T01 and T02 are independent (can run in parallel).
T03 depends on nothing (thin wrappers).
T04 depends on T01, T02, T03 (integration test).

Parallel opportunity: T01, T02, T03 can all run in parallel. T04 runs last.

## Files Likely Touched

- scripts/knowledge/compute-staleness.sh (create)
- scripts/knowledge/detect-overlap.sh (create)
- scripts/knowledge/increment-hits.sh (create)
- scripts/knowledge/update-confidence.sh (create)
