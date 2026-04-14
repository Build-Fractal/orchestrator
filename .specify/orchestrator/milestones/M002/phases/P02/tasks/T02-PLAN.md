---
schema_version: "1.0"
type: task-plan
task: "T02"
phase: "P02"
milestone: "M002"
name: "Validate and Harden Lifecycle Scripts"
depends_on: ["T01"]
---

## Prerequisites

T01 has created all 10 verification scripts under `scripts/verify/m002-p02-*.sh`. The following lifecycle scripts exist on disk from the initial M002 commit and need validation against the P01-delivered library interfaces:
- `scripts/knowledge/compute-staleness.sh`
- `scripts/knowledge/detect-overlap.sh`
- `scripts/knowledge/increment-hits.sh`
- `scripts/knowledge/update-confidence.sh`

## Description

Review and harden the four pre-existing lifecycle scripts to ensure they properly integrate with the P01-delivered shared libraries (index-utils.sh, detail-utils.sh, staleness.sh). The scripts were created before P01 delivered the canonical library implementations, so they may have stale assumptions, missing source statements, or interface mismatches. Fix any issues found.

## Steps

### Step 1: Validate compute-staleness.sh

Read `scripts/knowledge/compute-staleness.sh` and verify it:

1. **Sources the correct libraries**: Must source `lib/index-utils.sh` and `lib/staleness.sh` using the `SCRIPT_DIR` pattern established in P01.
2. **Uses `get_index_path()`** from index-utils.sh to locate the index (not a hardcoded path).
3. **Calls `compute_effective_confidence()`** from staleness.sh with the correct 3-argument signature: `compute_effective_confidence <confidence> <last_verified_date> [<reference_date>]`.
4. **Calls `days_since()`** from staleness.sh for the days column.
5. **Parses pipe-delimited index lines** using the same field ordering as `format_index_entry()` from index-utils.sh: `id | scope_tags | category | confidence | created_at | verified:date | hits:N | description`.
6. **Strips `verified:` and `hits:` prefixes** when extracting fields from index lines.
7. **Uses archive-entry.sh** for the `--archive-below` auto-archive path (not raw file moves).

The existing script (143 lines) already does all of the above correctly. If no issues are found, document that in the verification output.

If any issue is found, fix it. Common issues to watch for:
- Sourcing `staleness.sh` without first sourcing `index-utils.sh` (index-utils.sh provides `get_project_root()` needed by staleness.sh's caller)
- Field position mismatch in awk (e.g., confidence at $4 in the pipe-delimited format)
- Missing `verified:` or `hits:` prefix stripping

### Step 2: Validate detect-overlap.sh

Read `scripts/knowledge/detect-overlap.sh` and verify it:

1. **Sources index-utils.sh** for `get_project_root()`.
2. **Scans `knowledge/*/` directories** and skips `knowledge/archive/`.
3. **Computes Jaccard similarity** using sorted unique word files and `comm -12` for intersection.
4. **Uses awk for floating-point comparison** (not bc, for Bash 3.2 compatibility).
5. **Outputs `OVERLAP:` lines** with entry IDs, category, similarity score, and review recommendation.
6. **Does NOT auto-merge** entries.

The existing script (157 lines) already implements all of the above. Verify and document.

### Step 3: Validate increment-hits.sh

Read `scripts/knowledge/increment-hits.sh` and verify:

1. It delegates to `update-entry.sh` via `exec "$SCRIPT_DIR/update-entry.sh" "$@" --increment-hits`.
2. The `--id` argument is passed through correctly (the `$@` expansion before `--increment-hits` ensures this).
3. The exec pattern means the wrapper does not trap errors separately — update-entry.sh's exit code propagates directly.

Current implementation (7 lines) is correct. Verify and document.

### Step 4: Validate update-confidence.sh

Read `scripts/knowledge/update-confidence.sh` and verify:

1. It delegates to `update-entry.sh` via `exec "$SCRIPT_DIR/update-entry.sh" "$@"`.
2. The caller passes `--id MEM### --confidence 0.85` which update-entry.sh accepts directly.

Current implementation (7 lines) is correct. Verify and document.

### Step 5: Run verification scripts

Run all 8 verification scripts that should pass at this point:

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

All 8 must print `PASS:`.

## Must-Haves

This task addresses these phase must-haves:
- compute-staleness.sh sources lib/staleness.sh and lib/index-utils.sh, walks all index entries, and outputs a formatted report
- compute-staleness.sh supports --archive-below and --min-hits flags with --dry-run
- detect-overlap.sh compares entries using word-level Jaccard similarity and flags pairs exceeding 70% threshold
- detect-overlap.sh outputs OVERLAP lines without auto-merging
- increment-hits.sh delegates to update-entry.sh --increment-hits
- update-confidence.sh delegates to update-entry.sh
- All lifecycle scripts are Bash 3.2 compatible
- All lifecycle scripts are idempotent

## Verification

Run all 8 applicable verification scripts. Expected output:

```
PASS: compute-staleness.sh sources lib/staleness.sh and lib/index-utils.sh and calls compute_effective_confidence
PASS: compute-staleness.sh supports --archive-below, --min-hits, and --dry-run flags
PASS: detect-overlap.sh uses Jaccard similarity with threshold
PASS: detect-overlap.sh flags overlaps for review without auto-merging
PASS: increment-hits.sh delegates to update-entry.sh --increment-hits
PASS: update-confidence.sh delegates to update-entry.sh
PASS: all lifecycle scripts are Bash 3.2 compatible
PASS: lifecycle scripts support idempotent operation
```

## Inputs

### From Previous Tasks

- `scripts/verify/m002-p02-*.sh` (from T01) — 10 verification scripts. Each takes no arguments and outputs `PASS:`/`FAIL:` lines with exit 0/1. Invoke as `bash scripts/verify/m002-p02-<name>.sh`.

### From Disk (Pre-existing)

- `scripts/knowledge/compute-staleness.sh` — 143 lines. Sources `lib/staleness.sh` (provides `compute_effective_confidence(confidence, last_verified, [ref_date])` and `days_since(past_date, [ref_date])`) and `lib/index-utils.sh` (provides `get_index_path()`). Walks index lines, parses pipe-delimited fields with awk, outputs a formatted table. Supports `--archive-below CONF --min-hits N --dry-run` for conditional archival via `archive-entry.sh`.
- `scripts/knowledge/detect-overlap.sh` — 157 lines. Sources `lib/index-utils.sh` (for `get_project_root()`). Scans `knowledge/*/` excluding `archive/`, extracts word lists from markdown body, computes Jaccard similarity via `comm -12` and awk, outputs `OVERLAP: ID1 and ID2 (category: CAT, similarity: 0.XX) — review suggested`. Default threshold 0.70, configurable via `--threshold`.
- `scripts/knowledge/increment-hits.sh` — 7 lines. `exec "$SCRIPT_DIR/update-entry.sh" "$@" --increment-hits`.
- `scripts/knowledge/update-confidence.sh` — 7 lines. `exec "$SCRIPT_DIR/update-entry.sh" "$@"`.
- `scripts/knowledge/update-entry.sh` — 123 lines. Accepts `--id ID [--confidence CONF] [--last-verified DATE|now] [--hit-count N] [--increment-hits]`. Sources `lib/index-utils.sh` and `lib/detail-utils.sh`. Uses `find_detail_file()`, `fm_field()`, `sed_i()` for frontmatter modification, `format_index_entry()` and `index_update_entry()` for atomic index sync.
- `scripts/knowledge/lib/staleness.sh` — 84 lines. Provides `days_since(past_date, [ref_date])` and `compute_effective_confidence(confidence, last_verified, [ref_date])`. Formula: `effective = confidence * max(0.5, 1.0 - (days / 180))`. Uses awk for floating-point math.
- `scripts/knowledge/lib/index-utils.sh` — 228 lines. Provides `get_project_root()`, `get_index_path()`, `init_index()`, `index_add_entry(line)`, `index_remove_entry(id)`, `index_update_entry(id, line)`, `index_has_entry(id)`, `index_get_entry(id)`, `format_index_entry(id, scope, cat, conf, created, verified, hits, desc)`, `next_entry_id()`, `write_full_index(entries)`.
- `scripts/knowledge/lib/detail-utils.sh` — 46 lines. Provides `sed_i(args...)`, `find_detail_file(entry_id)`, `fm_field(file, field_name)`.

## Constraints

- Do NOT modify scripts unless an actual integration issue is found. If the scripts already work correctly with P01 libraries, leave them unchanged and document the validation.
- All modifications must maintain Bash 3.2 compatibility.
- All modifications must preserve idempotency.
- Do not change public interfaces (argument names, output formats) — downstream scripts and tests depend on them.

## Expected Output

8 of 10 verification scripts pass. The 2 consolidation integration checks (`m002-p02-consolidate-overlap.sh` and `m002-p02-consolidate-staleness.sh`) are expected to fail until T03 completes.

If any of the 4 lifecycle scripts needed modifications, document what changed and why. If no modifications were needed, state that the scripts passed validation unchanged.
