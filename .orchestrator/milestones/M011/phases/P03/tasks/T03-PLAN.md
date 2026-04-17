---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P03"
milestone: "M011"
name: "End-to-end demo scenario + provenance + idempotent re-ingest verification"
depends_on: [T02]
---

## Prerequisites

T02 is complete. `scripts/knowledge/ingest-spec.sh` now:

- Classifies every chunk as `NEW` / `UNCHANGED` / `CHANGED` by comparing content hashes
- Emits `CREATED: <id>`, `SKIPPED: <id>`, `SUPERSEDED: <old> -> <new>`, `REMOVED: <id>`, `REVIEW: P## affected by <id> supersession` as appropriate
- Writes `superseded_by` / `supersedes` / `superseded_by: "REMOVED"` fields on disk
- Emits an `INGEST: <slug> complete. created=N skipped=N superseded=N removed=N review=N` summary line

On disk:

- `scripts/knowledge/traverse-graph.sh --provenance --id <id>` follows `supersedes` / `superseded_by` chains and prints `PROVENANCE: <id> (chain length: N)` followed by one line per chain member with origin / superseded / current labels. Relies on `knowledge.db`, which is rebuilt by `rebuild-index.sh` (called at the end of `ingest-spec.sh`).
- Verify scripts from T01 and T02 all pass.

## Description

Add the end-to-end demo scenario check that matches the phase roadmap demo sentence, plus provenance traversal and re-ingest-idempotency checks. These are the three remaining must-haves on the phase plan.

This task creates three verify scripts and does not modify `ingest-spec.sh`. If during scripting any of the three checks fails due to a gap in T01/T02 behavior, fix the gap in `ingest-spec.sh` (the task allows scope-reopening for the specific failure, but keep changes minimal — prefer fixing the verify script if the issue is test-logic rather than script-behavior).

## Steps

### Step 1: Create `scripts/verify/m011-p03-demo-scenario.sh`

This script reproduces the phase's demo sentence exactly. Outline:

1. Create a sandbox `TMP_ROOT="$(mktemp -d)"` with `trap 'rm -rf "$TMP_ROOT"' EXIT`.
2. Pre-create `$TMP_ROOT/knowledge/spec/{story,requirement,constraint,nfr,acceptance,non-goal}` and `$TMP_ROOT/.orchestrator`.
3. Write an initial spec at `$TMP_ROOT/test-spec.md` containing at least three requirements:

```
# Demo Spec

## Functional Requirements

- **FR-001**: First requirement (unchanged baseline).
- **FR-003**: Original text of the third requirement.
- **FR-005**: Fifth requirement that will be deleted.
```

4. First ingest: `PROJECT_ROOT="$TMP_ROOT" bash scripts/knowledge/ingest-spec.sh --spec-path "$TMP_ROOT/test-spec.md" --slug demo`. Assert exactly `CREATED: SPEC-FR-001`, `CREATED: SPEC-FR-003`, `CREATED: SPEC-FR-005` all appear and no `SUPERSEDED:` / `REMOVED:` lines are present.
5. Rewrite the spec with FR-003's text changed and FR-005 deleted:

```
# Demo Spec

## Functional Requirements

- **FR-001**: First requirement (unchanged baseline).
- **FR-003**: Revised text of the third requirement.
```

6. Second ingest (same command).
7. Assert the second run's stdout:
   - Contains `SUPERSEDED: SPEC-FR-003 -> SPEC-FR-003-v2`
   - Contains `SKIPPED: SPEC-FR-001`
   - Contains `REMOVED: SPEC-FR-005`
   - Does NOT contain `SUPERSEDED: SPEC-FR-001` or `REMOVED: SPEC-FR-001` or `REMOVED: SPEC-FR-003`
8. If all four assertions pass, print `PASS: demo scenario produced SUPERSEDED/SKIPPED/REMOVED mix for FR-003/FR-001/FR-005`. Otherwise print `FAIL:` with the offending output and exit 1.

Implementation hint — use `grep -q '^SUPERSEDED: SPEC-FR-003 -> SPEC-FR-003-v2$' <<EOF ... EOF` (heredoc fed into grep) or write the second-run output to a temp file and grep the file. Either is fine inside the verify script since AD-19 only applies to the `Check:` command lines in plan files, not to the body of verify scripts.

### Step 2: Create `scripts/verify/m011-p03-provenance-traversable.sh`

1. Reuse the same sandbox pattern as Step 1 (or factor into a small inline setup block).
2. Seed a spec with FR-003 present.
3. First ingest.
4. Modify FR-003's text; re-ingest. This must produce `SUPERSEDED: SPEC-FR-003 -> SPEC-FR-003-v2`.
5. Run `PROJECT_ROOT="$TMP_ROOT" bash scripts/knowledge/traverse-graph.sh --provenance --id SPEC-FR-003` and capture stdout.
6. Assert the output:
   - First line matches `^PROVENANCE: SPEC-FR-003 (chain length: 2)$`
   - Contains a line matching `SPEC-FR-003 .* (origin)` or `SPEC-FR-003 .* (superseded)`
   - Contains a line matching `SPEC-FR-003-v2 .* (current)`
7. Print `PASS:` / `FAIL:` accordingly.

Note: `traverse-graph.sh --provenance` depends on `knowledge.db` being current. `ingest-spec.sh` calls `rebuild-index.sh` at the end, which rebuilds the DB. No extra step is needed — but if `rebuild-index.sh` does not itself populate `knowledge.db` in a sandbox `PROJECT_ROOT`, the test should explicitly run `PROJECT_ROOT="$TMP_ROOT" bash scripts/knowledge/rebuild-index.sh` between the re-ingest and the traverse call. Check the current `rebuild-index.sh` behavior first; add the explicit rebuild only if necessary.

### Step 3: Create `scripts/verify/m011-p03-reingest-idempotent.sh`

Verify that re-ingesting an already-modified spec is itself idempotent (the supersession has already happened once; the second re-ingest must be a no-op):

1. Sandbox setup (same pattern).
2. Seed an initial spec with FR-001 + FR-003 + FR-005.
3. First ingest.
4. Modify FR-003, delete FR-005; re-ingest (this produces the SUPERSEDED / REMOVED lines).
5. **Third ingest** on the already-modified spec. Assert the third run's stdout contains:
   - Zero `CREATED:` lines
   - Zero `SUPERSEDED:` lines
   - Zero `REMOVED:` lines
   - Two `SKIPPED:` lines (one for FR-001, one for FR-003 — note: FR-003 now lives as `SPEC-FR-003-v2`, but the classifier emits the base ID `SPEC-FR-003`; the re-ingest classification must recognize the chain and treat the matching body hash as UNCHANGED)
6. Print `PASS:` / `FAIL:`.

**Edge case the verify script must surface**: after a prior supersession, the classifier emits `SPEC-FR-003` again on the next run. `classify_chunk_decision` calls `find_detail_file "SPEC-FR-003"` — which still resolves to the old (now-superseded) file. If `find_detail_file` returns the superseded file, the comparison is against the old body's hash, which will still differ from the new body → the classifier would loop and create `SPEC-FR-003-v3` on every run.

If this test fails due to that behavior, the fix (reopen scope narrowly into T01's `classify_chunk_decision`): when the existing entry has a non-empty `superseded_by` field that is not `REMOVED`, walk the chain forward to the tip and compare the new hash against the tip's `content_hash` instead. If the tip hash matches, emit `SKIPPED: <base-id>` (UNCHANGED); if it differs, emit `SUPERSEDED: <tip-id> -> <new-version>` (CHANGED). Document the chain-walk adjustment inline and re-run the full P03 verify suite.

### Step 4: Wire the three new scripts into the phase verify set

No changes needed — phase-plan `Check:` entries already reference these three paths. Just confirm each verify script is marked executable (`chmod +x`) when created.

### Step 5: Run the full P03 verify suite

After writing all three scripts, run every P03 verify script in sequence to confirm the phase's must-haves are satisfied:

```
bash scripts/verify/m011-p03-supersede-on-change.sh
bash scripts/verify/m011-p03-skip-unchanged.sh
bash scripts/verify/m011-p03-removed-on-deletion.sh
bash scripts/verify/m011-p03-supersede-frontmatter.sh
bash scripts/verify/m011-p03-removed-frontmatter.sh
bash scripts/verify/m011-p03-provenance-traversable.sh
bash scripts/verify/m011-p03-phase-impact-review.sh
bash scripts/verify/m011-p03-reingest-idempotent.sh
bash scripts/verify/m011-p03-demo-scenario.sh
bash scripts/verify/m011-p03-bash32-compat.sh
```

All ten must print `PASS:` and exit 0.

## Must-Haves

- `scripts/verify/m011-p03-demo-scenario.sh` exists, reproduces the exact roadmap demo sentence scenario (modify FR-003, delete FR-005, leave FR-001 unchanged), and asserts the full SUPERSEDED / SKIPPED / REMOVED line mix
- `scripts/verify/m011-p03-provenance-traversable.sh` exists and confirms `traverse-graph.sh --provenance --id SPEC-FR-003` returns a chain-length-2 provenance output after one supersession
- `scripts/verify/m011-p03-reingest-idempotent.sh` exists and confirms a third ingest on a twice-ingested spec produces zero CREATED / SUPERSEDED / REMOVED lines (chain-tip hash comparison works correctly)
- All ten P03 verify scripts pass

## Verification

```
bash scripts/verify/m011-p03-demo-scenario.sh
bash scripts/verify/m011-p03-provenance-traversable.sh
bash scripts/verify/m011-p03-reingest-idempotent.sh
```

All must print `PASS:` and exit 0.

## Inputs

### From Previous Tasks

- `scripts/knowledge/ingest-spec.sh` (from T01 + T02)
  - API: `ingest-spec.sh --spec-path <path> --slug <slug> [--scope-tags <tags>]`
  - Output on re-ingest: mix of `CREATED:` / `SKIPPED:` / `SUPERSEDED: <old> -> <new>` / `REMOVED: <id>` / `REVIEW: P## affected by <id> supersession` lines, terminated by `INGEST: <slug> complete. created=N skipped=N superseded=N removed=N review=N`
  - Frontmatter side-effects: `superseded_by` populated on changed/removed entries, `supersedes` populated on new versioned entries
  - Calls `rebuild-index.sh` at the end, which regenerates `knowledge.db`
- All verify scripts from T01 and T02 — already pass before T03 starts

### From Disk (Pre-existing)

- `scripts/knowledge/traverse-graph.sh`
  - API: `traverse-graph.sh --provenance --id <entry-id>`
  - Output: `PROVENANCE: <id> (chain length: N)` header followed by lines of shape `  [idx] <id> | <confidence> | <date> | <description> (<label>)` where label is one of `origin` / `superseded` / `current` / `sole entry`
  - Requires `knowledge.db` to exist. Reads it via `get_db_path` from `lib/graph-db.sh`. On missing DB, prints `WARNING: knowledge.db not found ...` and exits 0 — so the test must run `rebuild-index.sh` first (usually already done by `ingest-spec.sh`).
- `scripts/knowledge/rebuild-index.sh` — regenerates `KNOWLEDGE-INDEX.md` and `knowledge.db` by scanning `knowledge/**/*.md`. Respects `PROJECT_ROOT`.
- `scripts/knowledge/lib/detail-utils.sh` — `fm_field` for reading frontmatter in assertion blocks.

## Constraints

- Bash 3.2 compatible for the verify scripts themselves (macOS default). No `declare -A`, no `mapfile`.
- Verify scripts must use sandbox `PROJECT_ROOT=$(mktemp -d)` with an EXIT trap cleanup. Never touch the real project's `knowledge/` tree.
- AD-19: the phase plan's `Check:` command for each verify script is `bash scripts/verify/m011-p03-<name>.sh` — a single-script-file invocation. The verify scripts themselves may use pipes, `$()`, subshells, heredocs, etc. internally.
- Do not modify `traverse-graph.sh`, `rebuild-index.sh`, `supersede-entry.sh`, or `create-entry.sh`.
- `ingest-spec.sh` modifications are allowed only if a verify script surfaces a behavioral gap (specifically: the chain-tip hash comparison edge case in Step 3). Keep any such modification narrowly scoped and re-run all P03 verify scripts after the change.
- Scope: no dispatch integration (that is P04). No CLI wrapper or `orchestrator:ingest` command (that is P05 if scheduled — not in P03's boundary map).

## Expected Output

- 3 new verify scripts: `m011-p03-demo-scenario.sh`, `m011-p03-provenance-traversable.sh`, `m011-p03-reingest-idempotent.sh`
- (Conditional) `scripts/knowledge/ingest-spec.sh` chain-tip hash comparison fix in `classify_chunk_decision`, if the idempotent-re-ingest test surfaces the edge case
- All 10 P03 verify scripts print `PASS:` and exit 0
- The phase demo sentence is now literally reproducible: run the demo scenario script and read the output lines against the roadmap text
