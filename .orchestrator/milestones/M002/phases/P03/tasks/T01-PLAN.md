---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P03"
milestone: "M002"
name: "Create verification scripts for P03 must-haves"
depends_on: []
---

## Prerequisites

- P01 and P02 are complete. The knowledge storage foundation (detail files, index, CRUD scripts, lifecycle scripts) is fully delivered.
- The scripts under test (`traverse-graph.sh`, `resolve-entries.sh`) do not yet exist. T01 creates verification scripts that will fail until T02 and T03 deliver the implementations.

## Description

Create 8 verification scripts under `scripts/verify/m002-p03-*.sh`. Each script is a self-contained behavioral test that:
1. Creates a temporary directory with test fixture data (detail files with YAML frontmatter, an index file).
2. Sets `PROJECT_ROOT` to the temp directory for isolation.
3. Runs the script under test.
4. Asserts expected output/behavior.
5. Prints `PASS: <description>` on success or `FAIL: <description>` on failure.
6. Cleans up the temp directory.

All scripts must be Bash 3.2 compatible (no associative arrays, no `mapfile`, no `readarray`).

## Steps

### Step 1: Create a shared test-fixture helper

Each verification script needs to create detail files with specific `relates_to` values. Define a reusable pattern (inline in each script, not a shared file) for creating test fixtures:

```bash
# Standard fixture setup pattern used in each script
setup_fixtures() {
  local tmpdir
  tmpdir="$(mktemp -d)"
  export PROJECT_ROOT="$tmpdir"
  mkdir -p "$tmpdir/knowledge/convention"
  mkdir -p "$tmpdir/knowledge/gotcha"
  mkdir -p "$tmpdir/knowledge/archive"
  # Create KNOWLEDGE-INDEX.md header
  cat > "$tmpdir/KNOWLEDGE-INDEX.md" <<'HEADER'
# Knowledge Index
<!-- Generated artifact — rebuild with: bash scripts/knowledge/rebuild-index.sh -->
<!-- Format: id | scope_tags | category | confidence | created_at | verified:date | hits:N | description -->
HEADER
  echo "$tmpdir"
}

# Standard fixture: entry with relates_to
create_entry_file() {
  local dir="$1" id="$2" category="$3" relates_to="$4" description="$5"
  cat > "$dir/knowledge/$category/$id.md" <<EOF
---
id: $id
scope_tags: "[project]"
category: $category
confidence: 0.90
created_at: 2026-04-01
last_verified: 2026-04-01
hit_count: 0
source_unit: "M002/P03"
source_type: execution
supersedes: ""
superseded_by: ""
relates_to: $relates_to
---

# $id: $description

Body text for $id.
EOF
  # Add to index
  echo "$id | [project] | $category | 0.90 | 2026-04-01 | verified:2026-04-01 | hits:0 | $description" >> "$dir/KNOWLEDGE-INDEX.md"
}
```

### Step 2: Create the 8 verification scripts

Create each script at the path shown. Each must be `chmod +x` compatible but invoked via `bash scripts/verify/...`.

**2a. `scripts/verify/m002-p03-traverse-reads-relates.sh`**

Creates entry MEM001 with `relates_to: [MEM002, MEM003]`, creates MEM002 and MEM003 as warm entries. Runs `traverse-graph.sh MEM001` and asserts stdout contains MEM002 and MEM003.

**2b. `scripts/verify/m002-p03-traverse-max-cap.sh`**

Creates entry MEM001 with `relates_to: [MEM002, MEM003, MEM004, MEM005, MEM006, MEM007]` (6 related entries, all warm). Runs `traverse-graph.sh MEM001` and asserts stdout contains at most 5 entry IDs (the default cap).

**2c. `scripts/verify/m002-p03-traverse-cycle-safe.sh`**

Creates MEM001 with `relates_to: [MEM002]` and MEM002 with `relates_to: [MEM001]`. Runs `traverse-graph.sh MEM001` and asserts MEM002 appears exactly once and MEM001 does NOT appear (seed entry excluded from output).

**2d. `scripts/verify/m002-p03-traverse-one-hop.sh`**

Creates MEM001 -> MEM002 -> MEM003 chain (MEM001 relates to MEM002, MEM002 relates to MEM003). Runs `traverse-graph.sh MEM001` and asserts MEM002 is in output but MEM003 is NOT (only 1 hop).

**2e. `scripts/verify/m002-p03-traverse-no-relates.sh`**

Creates MEM001 with `relates_to: []` (empty). Runs `traverse-graph.sh MEM001` and asserts stdout is empty and exit code is 0.

**2f. `scripts/verify/m002-p03-resolve-outputs-content.sh`**

Creates MEM001 and MEM002 with body text. Runs `resolve-entries.sh MEM001 MEM002` and asserts stdout contains the body text of both entries.

**2g. `scripts/verify/m002-p03-resolve-skips-missing.sh`**

Creates MEM001 only. Runs `resolve-entries.sh MEM001 MEM999` and asserts: exit code is 0, stdout contains MEM001 content, stderr contains a warning about MEM999.

**2h. `scripts/verify/m002-p03-resolve-preserves-ids.sh`**

Creates MEM001 and MEM002. Runs `resolve-entries.sh MEM001 MEM002` and asserts each entry's output section contains the entry ID (e.g., `# MEM001:` appears in output).

### Step 3: Verify all scripts are syntactically valid

Run `bash -n scripts/verify/m002-p03-*.sh` to check for syntax errors. All should pass syntax check.

## Must-Haves

This task creates the verification infrastructure. It addresses ALL 8 phase truths by creating their corresponding Check: scripts. The scripts will fail until T02 and T03 deliver implementations.

## Verification

Run each script and confirm it exits (it will FAIL since the implementations don't exist yet, but the script itself must not have syntax errors):

```
bash -n scripts/verify/m002-p03-traverse-reads-relates.sh
bash -n scripts/verify/m002-p03-traverse-max-cap.sh
bash -n scripts/verify/m002-p03-traverse-cycle-safe.sh
bash -n scripts/verify/m002-p03-traverse-one-hop.sh
bash -n scripts/verify/m002-p03-traverse-no-relates.sh
bash -n scripts/verify/m002-p03-resolve-outputs-content.sh
bash -n scripts/verify/m002-p03-resolve-skips-missing.sh
bash -n scripts/verify/m002-p03-resolve-preserves-ids.sh
```

All 8 must pass syntax validation (`bash -n` exits 0).

## Inputs

### From Previous Tasks

None — this is the first task in P03.

### From Disk (Pre-existing)

- `scripts/knowledge/lib/index-utils.sh` — provides `get_project_root()`, `get_index_path()`, `format_index_entry()`. Verification scripts source this to set up fixture index files. Supports `PROJECT_ROOT` env var override for temp-directory isolation.
- `scripts/knowledge/lib/detail-utils.sh` — provides `find_detail_file(entry_id)` which scans `knowledge/*/ID.md` and returns the path; `fm_field(file, field)` which extracts a YAML frontmatter field value. Both depend on index-utils.sh being sourced first.
- `scripts/knowledge/create-entry.sh` — alternative way to create fixtures (accepts `--id`, `--category`, `--confidence`, `--scope-tags`, `--source-unit`, `--source-type`, `--description`, `--body`, `--relates-to`). Prints `CREATED: MEM### at knowledge/cat/MEM###.md`. Respects `PROJECT_ROOT`.

## Constraints

- Bash 3.2 compatible (no associative arrays, no `mapfile`, no `readarray`, no `[[ ]]` where `[ ]` suffices).
- Each verification script must be fully self-contained — no shared test-helper library file (inline the fixture helpers).
- All temp directories must be cleaned up on exit (use `trap` for cleanup).
- Scripts must use `PROJECT_ROOT` env var to isolate from the real project.
- PASS/FAIL output format: `echo "PASS: description"` or `echo "FAIL: description"`.
- Exit 0 on PASS, exit 1 on FAIL.

## Expected Output

8 new files created:
```
scripts/verify/m002-p03-traverse-reads-relates.sh
scripts/verify/m002-p03-traverse-max-cap.sh
scripts/verify/m002-p03-traverse-cycle-safe.sh
scripts/verify/m002-p03-traverse-one-hop.sh
scripts/verify/m002-p03-traverse-no-relates.sh
scripts/verify/m002-p03-resolve-outputs-content.sh
scripts/verify/m002-p03-resolve-skips-missing.sh
scripts/verify/m002-p03-resolve-preserves-ids.sh
```

All pass `bash -n` syntax check. All will FAIL when run (since `traverse-graph.sh` and `resolve-entries.sh` don't exist yet) but will PASS after T02 and T03 complete.
