---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M002"
goal: "Validate and harden pre-existing lifecycle scripts (compute-staleness, detect-overlap, increment-hits, update-confidence) against P01-delivered libraries, integrate lifecycle operations into the consolidation flow, and prove the full knowledge entry lifecycle end-to-end"
demo_sentence: "A developer can run compute-staleness.sh to see a batch staleness report with effective confidence decay, run detect-overlap.sh to see flagged similar entries, use increment-hits.sh and update-confidence.sh as thin CLI wrappers, and run consolidate-artifacts.sh to trigger staleness and overlap checks as part of milestone consolidation — all operations idempotent."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

### Truths

- compute-staleness.sh sources lib/staleness.sh and lib/index-utils.sh, walks all index entries, and outputs a formatted report showing raw vs effective confidence
  - Check: `bash scripts/verify/m002-p02-staleness-sources.sh`
- compute-staleness.sh supports --archive-below and --min-hits flags for conditional auto-archival of stale low-hit entries, with --dry-run for preview
  - Check: `bash scripts/verify/m002-p02-staleness-archive-flags.sh`
- detect-overlap.sh compares entries within the same category using word-level Jaccard similarity and flags pairs exceeding 70% threshold
  - Check: `bash scripts/verify/m002-p02-overlap-jaccard.sh`
- detect-overlap.sh outputs OVERLAP lines with entry IDs and similarity score but does NOT auto-merge (review only)
  - Check: `bash scripts/verify/m002-p02-overlap-no-automerge.sh`
- increment-hits.sh delegates to update-entry.sh --increment-hits and passes through --id
  - Check: `bash scripts/verify/m002-p02-increment-delegates.sh`
- update-confidence.sh delegates to update-entry.sh and passes through --id and --confidence
  - Check: `bash scripts/verify/m002-p02-confidence-delegates.sh`
- consolidate-artifacts.sh invokes detect-overlap.sh during consolidation and reports any flagged overlaps
  - Check: `bash scripts/verify/m002-p02-consolidate-overlap.sh`
- consolidate-artifacts.sh invokes compute-staleness.sh during consolidation and reports stale entries
  - Check: `bash scripts/verify/m002-p02-consolidate-staleness.sh`
- All lifecycle scripts are Bash 3.2 compatible (no associative arrays, no readarray, no mapfile)
  - Check: `bash scripts/verify/m002-p02-bash32-compat.sh`
- All lifecycle scripts are idempotent (running twice produces equivalent results)
  - Check: `bash scripts/verify/m002-p02-idempotent.sh`

### Artifacts

- scripts/knowledge/compute-staleness.sh (min 60 lines, contains "compute_effective_confidence")
- scripts/knowledge/detect-overlap.sh (min 80 lines, contains "jaccard")
- scripts/knowledge/increment-hits.sh (min 5 lines, contains "increment-hits")
- scripts/knowledge/update-confidence.sh (min 5 lines, contains "update-entry")
- scripts/knowledge/consolidate-artifacts.sh (min 100 lines, contains "detect-overlap")
- scripts/verify/m002-p02-staleness-sources.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p02-staleness-archive-flags.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p02-overlap-jaccard.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p02-overlap-no-automerge.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p02-increment-delegates.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p02-confidence-delegates.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p02-consolidate-overlap.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p02-consolidate-staleness.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p02-bash32-compat.sh (min 3 lines, contains "PASS")
- scripts/verify/m002-p02-idempotent.sh (min 3 lines, contains "PASS")

### Key Links

- scripts/knowledge/compute-staleness.sh -> scripts/knowledge/lib/staleness.sh (sources decay function)
- scripts/knowledge/compute-staleness.sh -> scripts/knowledge/lib/index-utils.sh (reads index)
- scripts/knowledge/compute-staleness.sh -> scripts/knowledge/archive-entry.sh (optional auto-archive)
- scripts/knowledge/detect-overlap.sh -> scripts/knowledge/lib/index-utils.sh (reads project root)
- scripts/knowledge/increment-hits.sh -> scripts/knowledge/update-entry.sh (delegates to --increment-hits)
- scripts/knowledge/update-confidence.sh -> scripts/knowledge/update-entry.sh (delegates to --confidence)
- scripts/knowledge/consolidate-artifacts.sh -> scripts/knowledge/detect-overlap.sh (overlap check during consolidation)
- scripts/knowledge/consolidate-artifacts.sh -> scripts/knowledge/compute-staleness.sh (staleness check during consolidation)

## Tasks

### T01: Verification Scripts for All Must-Haves

Create all 10 verification scripts under `scripts/verify/m002-p02-*.sh`. Each script performs a focused static or structural check and prints PASS/FAIL. This task must complete first so that all subsequent tasks can be mechanically verified.

### T02: Validate and Harden Lifecycle Scripts

Review compute-staleness.sh, detect-overlap.sh, increment-hits.sh, and update-confidence.sh against the P01-delivered library interfaces. Fix any integration issues (wrong function calls, missing source statements, incompatible assumptions). Ensure all scripts properly source the P01 libraries and follow established patterns.

### T03: Integrate Lifecycle into Consolidation Flow

Extend consolidate-artifacts.sh to invoke detect-overlap.sh and compute-staleness.sh as part of milestone consolidation. The consolidation script should run overlap detection and report findings, run staleness computation and report stale entries, but NOT auto-archive or auto-merge (consolidation is advisory).

### T04: End-to-End Lifecycle Verification

Execute a full lifecycle roundtrip: create entries, compute staleness, detect overlaps, increment hits, update confidence, supersede, archive, promote. Verify all operations are idempotent and the index stays consistent throughout. Run all verification scripts to confirm all must-haves pass.

## Task Dependencies

T01 -> T02 -> T03 -> T04

T01 must come first (verification scripts needed by all subsequent tasks). T02 validates the individual scripts. T03 extends consolidation using the validated scripts. T04 is the integration test that proves everything works together.

## Files Likely Touched

- scripts/verify/m002-p02-staleness-sources.sh (create)
- scripts/verify/m002-p02-staleness-archive-flags.sh (create)
- scripts/verify/m002-p02-overlap-jaccard.sh (create)
- scripts/verify/m002-p02-overlap-no-automerge.sh (create)
- scripts/verify/m002-p02-increment-delegates.sh (create)
- scripts/verify/m002-p02-confidence-delegates.sh (create)
- scripts/verify/m002-p02-consolidate-overlap.sh (create)
- scripts/verify/m002-p02-consolidate-staleness.sh (create)
- scripts/verify/m002-p02-bash32-compat.sh (create)
- scripts/verify/m002-p02-idempotent.sh (create)
- scripts/knowledge/compute-staleness.sh (modify — harden against P01 interfaces)
- scripts/knowledge/detect-overlap.sh (modify — harden against P01 interfaces)
- scripts/knowledge/increment-hits.sh (modify — if needed)
- scripts/knowledge/update-confidence.sh (modify — if needed)
- scripts/knowledge/consolidate-artifacts.sh (modify — add lifecycle integration)
