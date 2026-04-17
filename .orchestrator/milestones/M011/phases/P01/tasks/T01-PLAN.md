---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M011"
name: "Scaffold spec directory tree and extend create-entry.sh for SPEC- ID support"
depends_on: []
---

## Prerequisites

No upstream tasks. The following files exist and are Bash 3.2 compatible:
- `scripts/knowledge/create-entry.sh` — creates knowledge entries with MEM### IDs under flat category dirs
- `scripts/knowledge/lib/index-utils.sh` — sourced by create-entry.sh for `next_entry_id()` and `format_index_entry()`

## Description

Create the `knowledge/spec/` directory tree with 6 subdirectories (one per spec chunk type) and `.gitkeep` files for each. Then modify `create-entry.sh` to:

1. Accept `--id` values with the `SPEC-` prefix (e.g., `SPEC-FR-001`, `SPEC-US-002`)
2. Validate that SPEC-prefixed IDs are only used with `spec/`-prefixed categories
3. Handle nested category paths via the existing `mkdir -p` (already present but untested for nested paths like `spec/requirement`)

The existing behavior for MEM### auto-generated IDs must remain unchanged.

## Steps

### Step 1: Create the spec directory tree

Create the 6 spec subdirectories under `knowledge/spec/` with `.gitkeep` files:

```
knowledge/spec/story/.gitkeep
knowledge/spec/requirement/.gitkeep
knowledge/spec/constraint/.gitkeep
knowledge/spec/nfr/.gitkeep
knowledge/spec/acceptance/.gitkeep
knowledge/spec/non-goal/.gitkeep
```

Each `.gitkeep` file is empty (0 bytes). The parent `knowledge/spec/` directory is created implicitly by `mkdir -p`.

### Step 2: Add SPEC- namespace validation to create-entry.sh

In `scripts/knowledge/create-entry.sh`, after the required-fields validation block (after line 58, before the auto-generate ID section), add SPEC- namespace validation:

**Insert after line 58** (after the `if [ -n "$missing" ]; then ... fi` block):

```bash
# --- Validate SPEC- namespace: SPEC-prefixed IDs require spec/ category ---
case "$ENTRY_ID" in
  SPEC-*)
    case "$CATEGORY" in
      spec/*)
        ;; # valid: SPEC- prefix with spec/ category
      *)
        echo "ERROR: SPEC-prefixed IDs require a spec/ category prefix (got --category $CATEGORY)" >&2
        exit 1
        ;;
    esac
    ;;
esac
```

This uses `case` statements (Bash 3.2 compatible) instead of `[[ =~ ]]` regex.

### Step 3: Update the file-naming comment in create-entry.sh

Update the script header comment (line 2) to reflect the new capability:

**Before** (line 2-3):
```
# scripts/knowledge/create-entry.sh — Create a knowledge detail file and update the index
# Usage: create-entry.sh [options]
```

**After**:
```
# scripts/knowledge/create-entry.sh — Create a knowledge detail file and update the index
# Usage: create-entry.sh [options]
# Accepts --id with SPEC- prefix for spec chunks (requires --category spec/*).
# Without --id, auto-generates MEM### sequence IDs.
```

### Step 4: Verify mkdir -p handles nested paths

The existing `mkdir -p "$detail_dir"` on line 87 already handles nested category paths like `spec/requirement` because `$detail_dir` resolves to `$root/knowledge/spec/requirement`. No code change is needed here — just verify this works via the verification scripts.

### Step 5: Create verification scripts

Create the following 3 scripts under `scripts/verify/`:

**`scripts/verify/m011-p01-create-entry-spec-id.sh`** — Tests that `create-entry.sh --id SPEC-FR-001 --category spec/requirement` creates the file at the correct nested path with correct frontmatter. Uses a temp directory as `PROJECT_ROOT` to avoid polluting real knowledge/.

**`scripts/verify/m011-p01-create-entry-mem-compat.sh`** — Tests that `create-entry.sh` without `--id` still auto-generates MEM### IDs. Uses a temp directory.

**`scripts/verify/m011-p01-create-entry-spec-validation.sh`** — Tests that `create-entry.sh --id SPEC-FR-001 --category patterns` (non-spec/ category) exits non-zero with an error message.

**`scripts/verify/m011-p01-spec-dirs-exist.sh`** — Tests that all 6 spec subdirectories exist with `.gitkeep` files.

These scripts are already created as part of the phase plan and located at `scripts/verify/m011-p01-*.sh`.

### Step 6: Run verification

```
bash scripts/verify/m011-p01-create-entry-spec-id.sh
bash scripts/verify/m011-p01-create-entry-mem-compat.sh
bash scripts/verify/m011-p01-create-entry-spec-validation.sh
bash scripts/verify/m011-p01-spec-dirs-exist.sh
```

All four must print `PASS:` and exit 0.

## Must-Haves

- `create-entry.sh --id SPEC-FR-001 --category spec/requirement` creates a detail file at `knowledge/spec/requirement/SPEC-FR-001.md` with `id: SPEC-FR-001` and `category: spec/requirement` in frontmatter
- `create-entry.sh` with no `--id` flag still auto-generates MEM### IDs (backwards compatible)
- `create-entry.sh` rejects `--id` values with `SPEC-` prefix when `--category` does not start with `spec/`
- The 6 spec subdirectories exist under `knowledge/spec/` with `.gitkeep` files

## Verification

```
bash scripts/verify/m011-p01-create-entry-spec-id.sh
bash scripts/verify/m011-p01-create-entry-mem-compat.sh
bash scripts/verify/m011-p01-create-entry-spec-validation.sh
bash scripts/verify/m011-p01-spec-dirs-exist.sh
```

Each must print `PASS:` and exit 0.

## Inputs

### From Disk (Pre-existing)
- `scripts/knowledge/create-entry.sh` — the script being modified. Currently accepts `--id` for explicit IDs and auto-generates MEM### when omitted. Uses `mkdir -p "$detail_dir"` for directory creation (line 87). Sources `lib/index-utils.sh` for `next_entry_id()` and `format_index_entry()`. Argument parsing on lines 31-45 uses `while/case` (Bash 3.2 safe).
- `scripts/knowledge/lib/index-utils.sh` — shared utilities. `get_project_root()` resolves to the repo root (walks up from script dir to find `.orchestrator/` or `.git`). Respects `PROJECT_ROOT` env var when set.
- `knowledge/` — existing flat category directories: `patterns/`, `conventions/`, `lessons/`, `archive/`. The `spec/` subtree does not yet exist.

## Constraints

- Bash 3.2 compatible. No `declare -A`, `mapfile`, `${var,,}`, `[[ =~ ]]`.
- Use `case` statements for prefix matching (not regex).
- The validation must run before `mkdir -p` to avoid creating directories for rejected entries.
- `.gitkeep` files are empty (0 bytes), ensuring directories are tracked by git.
- Atomic file writes: `create-entry.sh` already uses direct `cat >` for new files (acceptable because the file did not previously exist — no partial-write risk).

## Expected Output

- 6 new directories: `knowledge/spec/{story,requirement,constraint,nfr,acceptance,non-goal}/`
- 6 new `.gitkeep` files (one per directory)
- `scripts/knowledge/create-entry.sh` modified: SPEC- namespace validation added, header comment updated
- 4 verification scripts created and passing
