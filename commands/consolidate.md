---
description: "Use when compressing knowledge and archiving verbose artifacts after milestone completion."
---

# Consolidate Knowledge

Compress and archive verbose artifacts from a completed milestone, reducing the footprint while preserving essential summaries, decisions, and knowledge. This is a post-completion optimization — the milestone must already be validated before consolidation.

## Prerequisites

Before consolidating, verify the milestone is eligible:

### 1. Derive Current State

```bash
bash scripts/state/derive-phase.sh <milestone-dir>
```

Consolidation is valid when the returned state is one of:
- `completing` — milestone is in its final state transition
- `complete` — milestone has been validated and completed

If state is anything else (`pre-planning`, `discussing`, `planning`, `executing`, `summarizing`, `validating`), report: "Milestone is not ready for consolidation — complete all phases and validate first." and exit.

### 2. Verify All Phases Complete

All phases in the roadmap must have phase summaries. The consolidation script enforces this check internally, but verifying upfront avoids partial archiving:

```bash
bash scripts/state/read-roadmap.sh <milestone-dir>/<milestone-id>-ROADMAP.md phases
```

For each phase listed, confirm `<milestone-dir>/phases/<P##>/<P##>-SUMMARY.md` exists. If any phase lacks a summary, report: "Phase <P##> is incomplete — run `speckit.orchestrator.verify` on remaining phases before consolidating." and exit.

## Core Workflow

### Step 1 — Check Milestone State

Run state derivation to confirm the milestone is in `completing` or `complete` state:

```bash
state=$(bash scripts/state/derive-phase.sh <milestone-dir>)
```

If the state is not `completing` or `complete`, stop and inform the developer.

### Step 2 — Run Consolidation

Execute the consolidation script:

```bash
bash scripts/knowledge/consolidate-artifacts.sh <orchestrator-root> <milestone-id>
```

This script:
- Measures the `phases/` directory size before and after archiving
- Moves task plans (`T##-PLAN.md`), task summaries (`T##-SUMMARY.md`), and phase plans (`P##-PLAN.md`) to `<milestone-dir>/archive/` organized by phase ID
- Preserves phase summaries (`P##-SUMMARY.md`), the roadmap, DECISIONS.md, and KNOWLEDGE.md in their original locations
- Reports bytes before/after and reduction percentage to stderr

### Step 3 — Review Consolidation Report

After the script completes, check the stderr output for the reduction metrics:

```
CONSOLIDATE: <before-bytes> → <after-bytes> (<N>% reduction)
```

Verify:
- The reduction percentage is ≥60% (typical range: 70-90%)
- The stdout confirmation line shows: `CONSOLIDATE: <M###> consolidated, <N> phases archived`

If the reduction is below 60%, this may indicate the milestone had few verbose artifacts to begin with — this is acceptable if all phases are represented in the archive.

### Step 4 — Verify Preserved Artifacts

Confirm that essential artifacts remain accessible after consolidation:

- **Phase summaries**: `<milestone-dir>/phases/<P##>/<P##>-SUMMARY.md` for each phase
- **Roadmap**: `<milestone-dir>/<milestone-id>-ROADMAP.md`
- **DECISIONS.md**: at the orchestrator root (`.specify/orchestrator/DECISIONS.md`)
- **KNOWLEDGE.md**: at the orchestrator root (`.specify/orchestrator/KNOWLEDGE.md`)
- **Milestone summary template**: `templates/milestone-summary.md` (available for final summary generation)

### Step 5 — Confirm Milestone State

After consolidation, the milestone remains in `complete` state. Consolidation is a post-completion optimization — it does not change the state machine. Verify:

```bash
bash scripts/state/derive-phase.sh <milestone-dir>
```

The state should still be `complete` (or `completing` if the milestone summary has not yet been written).

## Output

Report the following to the developer:

1. **Reduction percentage**: e.g., "Consolidated M001: 87% reduction in active artifact footprint"
2. **Archived phases**: e.g., "3 phases archived (P01, P02, P03)"
3. **Preserved files**: List the key files that remain accessible:
   - Phase summaries (one per phase)
   - Roadmap
   - DECISIONS.md
   - KNOWLEDGE.md
4. **Archive location**: e.g., "Archived originals available at `<milestone-dir>/archive/`"

### Step 6 — Merge Worktree (if applicable)

If git worktree isolation was used during execution (FR-075), merge the worktree branch back:

1. Detect worktree: check if `.worktrees/<M###>` exists
2. If present:
   ```bash
   git checkout <feature-branch>
   git merge orchestrator/<M###> --no-ff -m "Merge orchestrator/<M###> into <feature-branch>"
   git worktree remove .worktrees/<M###>
   git branch -d orchestrator/<M###>
   ```
3. If not present, skip this step silently (worktree isolation was not used)

This step is idempotent — if the worktree was already removed, the commands gracefully skip.

## Idempotency

Running consolidate twice is safe:

- **Already-archived phases are skipped**: If a phase's task files have already been moved to `archive/`, the consolidation script does not attempt to move them again.
- **Reduction metrics reflect current state**: On a second run, the before/after measurement will show minimal or zero reduction since the artifacts were already archived.
- **No data loss risk**: The script moves files rather than deleting them — originals are always preserved in the archive directory.

This satisfies R012 (idempotent commands).

## Error Handling

### Incomplete Phases

If any phase lacks a `P##-SUMMARY.md`, the consolidation script exits non-zero with a message naming the incomplete phase. Resolution: complete the phase via `speckit.orchestrator.verify` and write the phase summary before re-attempting consolidation.

### Partial Consolidation Failure

If the script fails partway through (e.g., disk space issue, permission error):
- Already-moved files are in `archive/` — they are safe and intact
- Files not yet moved remain in their original `phases/` locations
- Re-running consolidation will pick up where it left off (idempotent)

### Archive Directory Already Exists

If `<milestone-dir>/archive/` already exists from a prior consolidation or rollback:
- The script creates phase-specific subdirectories under `archive/` (e.g., `archive/P01/`, `archive/P02/`)
- Existing archive contents from other operations (e.g., rollback) are not disturbed
- New archived files are added alongside existing ones

### Missing Milestone Directory

If the milestone directory does not exist, the script exits non-zero: "Milestone directory not found." Resolution: verify the milestone ID and orchestrator root path.

## Referenced Scripts

- `scripts/knowledge/consolidate-artifacts.sh` — performs the archival and reports reduction metrics
- `scripts/state/derive-phase.sh` — derives current milestone state from disk artifacts

## Referenced Templates

- `templates/milestone-summary.md` — template for the final milestone summary (generated separately, preserved by consolidation)
